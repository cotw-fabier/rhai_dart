/// FFI callback bridge for Dart function invocation from Rust
///
/// This module provides the bridge that allows Rust code to call back into
/// Dart functions registered with the Rhai engine.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rhai_dart/src/ffi/bindings.dart';
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

/// Counter for generating unique future IDs.
///
/// This is incremented atomically (Dart is single-threaded per isolate)
/// for each new async operation to ensure unique IDs.
int _nextFutureId = 1;

/// Generates a unique future ID.
///
/// Returns a unique sequential ID for tracking async operations.
int _generateFutureId() {
  final id = _nextFutureId;
  _nextFutureId++;
  // Wrap around at max int to prevent overflow (unlikely in practice)
  if (_nextFutureId > 0x7FFFFFFFFFFFFFFF ~/ 2) {
    _nextFutureId = 1;
  }
  return id;
}

/// Initializes the global callback bridge.
///
/// This must be called before any function registration. It creates a NativeCallable
/// that Rust can invoke to call back into Dart.
void initializeCallbackBridge() {
  _globalCallable ??= NativeCallable<NativeCallbackFuncNative>.isolateLocal(_dartFunctionInvoker);
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

/// The core callback function that Rust will invoke.
///
/// This function:
/// 1. Looks up the callback in the registry by ID
/// 2. Parses JSON args to Dart List<dynamic>
/// 3. Invokes the Dart function with args
/// 4. Detects if the result is a Future (async function)
/// 5. For async functions: returns "pending" status immediately and sets up completion callback
/// 6. For sync functions: returns "success" status with value
/// 7. Catches exceptions and converts to error JSON
///
/// For async functions (returning `Future<T>`), this function:
/// - Generates a unique future ID
/// - Returns `{"status": "pending", "future_id": <id>}` immediately
/// - Attaches .then()/.catchError() callbacks to the Future
/// - Calls rhai_complete_future() via FFI when the Future completes
///
/// This allows Dart's event loop to run naturally while Rust awaits the result
/// through a oneshot channel, enabling true async support for HTTP requests,
/// file I/O, and other async operations.
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
      // Generate unique future ID
      final futureId = _generateFutureId();

      // Set up completion callbacks
      _completeFutureFromDart(futureId, result);

      // Return pending status immediately
      return _encodePendingStatus(futureId);
    } else {
      // Sync function - return result directly
      return _encodeSuccessStatus(result);
    }
  } catch (e, stackTrace) {
    return _encodeError('Error invoking Dart function: $e\nStack trace: $stackTrace');
  }
}

/// Completes a future from Dart by calling back to Rust via FFI.
///
/// This function attaches .then() and .catchError() callbacks to the Future
/// that will call rhai_complete_future() when the async operation completes.
///
/// Args:
///   futureId: The unique ID of the future
///   future: The Future to monitor
void _completeFutureFromDart(int futureId, Future<dynamic> future) {
  future.then((value) {
    // Encode the successful result as JSON
    final resultJson = json.encode({
      'status': 'success',
      'value': value,
    });

    // Convert to C string
    final resultPtr = resultJson.toNativeUtf8();

    try {
      // Call Rust FFI to complete the future
      final bindings = RhaiBindings.instance;
      final returnCode = bindings.completeFuture(futureId, resultPtr);

      // Check return code (0 = success, -1 = error)
      if (returnCode != 0) {
        // Log warning but don't crash - the Rust side will handle cleanup
        // ignore: avoid_print
        print('Warning: rhai_complete_future returned error code $returnCode for future $futureId');
      }
    } finally {
      // Free the allocated C string
      malloc.free(resultPtr);
    }
  }).catchError((Object error, StackTrace stackTrace) {
    // Encode the error as JSON
    final errorJson = json.encode({
      'status': 'error',
      'error': 'Error in async function: $error\nStack trace: $stackTrace',
    });

    // Convert to C string
    final errorPtr = errorJson.toNativeUtf8();

    try {
      // Call Rust FFI to complete the future with error
      final bindings = RhaiBindings.instance;
      final returnCode = bindings.completeFuture(futureId, errorPtr);

      // Check return code (0 = success, -1 = error)
      if (returnCode != 0) {
        // Log warning but don't crash - the Rust side will handle cleanup
        // ignore: avoid_print
        print('Warning: rhai_complete_future returned error code $returnCode for future $futureId');
      }
    } finally {
      // Free the allocated C string
      malloc.free(errorPtr);
    }
  });
}

/// Encodes a successful result as JSON with "success" status.
///
/// Uses our enhanced type conversion to handle special float values.
///
/// Returns a C string pointer that must be freed by the caller.
Pointer<Utf8> _encodeSuccessStatus(dynamic result) {
  try {
    // Use our enhanced type conversion for the value
    final valueJson = rhaiValueToJson(result);

    // Wrap in success envelope - use plain jsonEncode for the envelope structure
    final resultJson = json.encode({'status': 'success', 'value_json': valueJson});
    return resultJson.toNativeUtf8();
  } catch (e) {
    return _encodeError('Failed to encode result: $e');
  }
}

/// Encodes a pending status for async operations.
///
/// Returns JSON: `{"status": "pending", "future_id": <id>}`
///
/// Returns a C string pointer that must be freed by the caller.
Pointer<Utf8> _encodePendingStatus(int futureId) {
  final resultJson = json.encode({
    'status': 'pending',
    'future_id': futureId,
  });
  return resultJson.toNativeUtf8();
}

/// Encodes an error as JSON with "error" status.
///
/// Returns a C string pointer that must be freed by the caller.
Pointer<Utf8> _encodeError(String errorMessage) {
  final errorJson = json.encode({'status': 'error', 'error': errorMessage});
  return errorJson.toNativeUtf8();
}
