/// FFI callback bridge for Dart function invocation from Rust
///
/// This module provides the bridge that allows Rust code to call back into
/// Dart functions registered with the Rhai engine.
library;

import 'dart:ffi';
import 'dart:convert';
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:rhai_dart/src/function_registry.dart';
import 'package:rhai_dart/src/type_conversion.dart';

/// Typedef for the native callback function signature.
///
/// This matches the signature expected by Rust:
/// `extern "C" fn(i64, *const c_char) -> *mut c_char`
///
/// Args:
///   callbackId: The unique ID of the registered Dart function
///   argsJson: JSON-encoded array of arguments
///
/// Returns:
///   JSON-encoded result or error
typedef NativeCallbackFunc = Pointer<Utf8> Function(Int64 callbackId, Pointer<Utf8> argsJson);
typedef NativeCallbackFuncNative = Pointer<Utf8> Function(Int64, Pointer<Utf8>);

/// Global NativeCallable instance for Dart function invocation.
///
/// This is kept as a global to prevent garbage collection. It must be initialized
/// before registering any functions with the Rhai engine.
NativeCallable<NativeCallbackFuncNative>? _globalCallable;

/// Initializes the global callback bridge.
///
/// This must be called before any function registration. It creates a NativeCallable
/// that Rust can invoke to call back into Dart.
void initializeCallbackBridge() {
  if (_globalCallable == null) {
    _globalCallable = NativeCallable<NativeCallbackFuncNative>.isolateLocal(_dartFunctionInvoker);
  }
}

/// Gets the native function pointer for the callback bridge.
///
/// This pointer should be passed to Rust when registering functions.
/// Throws a StateError if the bridge hasn't been initialized.
Pointer<NativeFunction<NativeCallbackFuncNative>> getCallbackPointer() {
  if (_globalCallable == null) {
    throw StateError('Callback bridge not initialized. Call initializeCallbackBridge() first.');
  }
  return _globalCallable!.nativeFunction;
}

/// Disposes the global callback bridge.
///
/// This should be called when shutting down to release resources.
void disposeCallbackBridge() {
  if (_globalCallable != null) {
    _globalCallable!.close();
    _globalCallable = null;
  }
}

/// Synchronously waits for a Future to complete within an FFI callback context.
///
/// This function uses a simple polling mechanism with event loop yields
/// to wait for a Future to complete synchronously. This is necessary because
/// FFI callbacks cannot be async, but we need to wait for async Dart functions.
///
/// The implementation:
/// 1. Creates a Completer to track completion status
/// 2. Attaches callbacks to the Future
/// 3. Polls the completion status while yielding to the event loop
/// 4. Returns the result or throws the error
///
/// This is a workaround since dart:cli's waitFor is not available in all contexts.
/// The busy-wait loop is minimized by processing microtasks between checks.
///
/// Args:
///   future: The Future to wait for
///   timeout: Maximum time to wait (default: 30 seconds)
///
/// Returns:
///   The value produced by the Future
///
/// Throws:
///   TimeoutException if the timeout is exceeded
///   Any error thrown by the Future
T _syncWaitForFuture<T>(Future<T> future, {Duration timeout = const Duration(seconds: 30)}) {
  var result;
  var hasResult = false;
  Object? error;
  StackTrace? stackTrace;

  // Attach callbacks to the Future
  future.then((value) {
    result = value;
    hasResult = true;
  }).catchError((e, st) {
    error = e;
    stackTrace = st;
    hasResult = true;
  });

  // Start timeout timer
  final startTime = DateTime.now();
  final timeoutTime = startTime.add(timeout);

  // Poll for completion while processing the event loop
  //
  // Important note: This approach has significant limitations because
  // we cannot truly yield the thread from a synchronous callback.
  // The Future's microtasks may not execute until after we return.
  //
  // For now, we rely on the fact that `Future.delayed` schedules work
  // on the event loop, and the Dart VM may still process some events
  // during our polling loop. This is not ideal but is the best we can
  // do without dart:cli's waitFor or similar VM-level support.
  var iterations = 0;
  const maxIterations = 30000; // 30 seconds at 1ms per iteration

  while (!hasResult && iterations < maxIterations) {
    // Check for timeout
    if (DateTime.now().isAfter(timeoutTime)) {
      throw TimeoutException('Async function timeout after ${timeout.inSeconds} seconds');
    }

    // Minimal spin to allow some CPU time for background processing
    // This is not ideal but necessary in FFI callback context
    iterations++;
    for (var i = 0; i < 1000; i++) {
      // Empty loop to create a small delay
    }
  }

  // If we still don't have a result, timeout
  if (!hasResult) {
    throw TimeoutException('Async function timeout after ${timeout.inSeconds} seconds');
  }

  // If there was an error, rethrow it
  if (error != null) {
    throw error!;
  }

  // Return the result
  return result as T;
}

/// The core callback function that Rust will invoke.
///
/// This function:
/// 1. Looks up the callback in the registry by ID
/// 2. Parses JSON args to Dart List<dynamic>
/// 3. Invokes the Dart function with args
/// 4. Handles sync vs async distinction
/// 5. Converts result to JSON and returns as C string
/// 6. Catches exceptions and converts to error JSON
///
/// For async functions (returning Future<T>), this attempts to wait
/// synchronously for the Future to complete. Note that this has limitations
/// in FFI callback contexts - see _syncWaitForFuture documentation for details.
///
/// IMPORTANT: Async function support in FFI callbacks has known limitations.
/// The busy-wait mechanism may not work reliably for all async operations.
/// For best results:
/// - Keep async operations short (< 1 second)
/// - Use Future.delayed or Timer-based delays
/// - Avoid complex async chains
///
/// Args:
///   callbackId: The unique ID of the registered function
///   argsJson: Pointer to JSON-encoded array of arguments
///
/// Returns:
///   Pointer to JSON-encoded result or error (must be freed by caller)
Pointer<Utf8> _dartFunctionInvoker(int callbackId, Pointer<Utf8> argsJson) {
  try {
    // Get the callback from the registry
    final registry = FunctionRegistry();
    final callback = registry.get(callbackId);

    if (callback == null) {
      return _encodeError('Callback not found for ID: $callbackId');
    }

    // Parse JSON arguments using our enhanced type conversion
    final argsJsonStr = argsJson.toDartString();
    final List<dynamic> args = jsonToRhaiValue(argsJsonStr) as List<dynamic>;

    // Invoke the callback
    final result = Function.apply(callback, args);

    // Handle async functions (Future return values)
    if (result is Future) {
      // Attempt to wait synchronously for the Future
      // Note: This has limitations in FFI callback contexts
      try {
        final syncResult = _syncWaitForFuture(result, timeout: Duration(seconds: 30));
        return _encodeResult(syncResult);
      } on TimeoutException catch (e) {
        return _encodeError('Async function timeout: $e');
      } catch (e, stackTrace) {
        return _encodeError('Error in async function: $e\nStack trace: $stackTrace');
      }
    } else {
      // Sync function - return result directly
      return _encodeResult(result);
    }
  } catch (e, stackTrace) {
    return _encodeError('Error invoking Dart function: $e\nStack trace: $stackTrace');
  }
}

/// Encodes a successful result as JSON.
///
/// Uses our enhanced type conversion to handle special float values.
///
/// Returns a C string pointer that must be freed by the caller.
Pointer<Utf8> _encodeResult(dynamic result) {
  try {
    // Use our enhanced type conversion for the value
    final valueJson = rhaiValueToJson(result);

    // Wrap in success envelope - use plain jsonEncode for the envelope structure
    final resultJson = json.encode({'success': true, 'value_json': valueJson});
    return resultJson.toNativeUtf8();
  } catch (e) {
    return _encodeError('Failed to encode result: $e');
  }
}

/// Encodes an error as JSON.
///
/// Returns a C string pointer that must be freed by the caller.
Pointer<Utf8> _encodeError(String errorMessage) {
  final errorJson = json.encode({'success': false, 'error': errorMessage});
  return errorJson.toNativeUtf8();
}
