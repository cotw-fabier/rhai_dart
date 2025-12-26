/// FFI bindings for the Rhai native library
///
/// This module provides low-level FFI bindings to the Rhai Rust library.
/// It uses native assets for automatic library location and loading.
library;

import 'dart:ffi';
import 'dart:io';
import 'package:rhai_dart/src/ffi/native_types.dart';
import 'package:ffi/ffi.dart';

/// Typedef for the rhai_get_last_error function
typedef RhaiGetLastErrorNative = Pointer<Char> Function();
typedef RhaiGetLastErrorDart = Pointer<Char> Function();

/// Typedef for the rhai_free_error function
typedef RhaiFreeErrorNative = Void Function(Pointer<Char>);
typedef RhaiFreeErrorDart = void Function(Pointer<Char>);

/// Typedef for the rhai_engine_new function
typedef RhaiEngineNewNative = Pointer<CRhaiEngine> Function(
    Pointer<CRhaiConfig>);
typedef RhaiEngineNewDart = Pointer<CRhaiEngine> Function(
    Pointer<CRhaiConfig>);

/// Typedef for the rhai_engine_free function
typedef RhaiEngineFreeNative = Void Function(Pointer<CRhaiEngine>);

/// Typedef for the rhai_eval function
typedef RhaiEvalNative = Int32 Function(
    Pointer<CRhaiEngine>, Pointer<Char>, Pointer<Pointer<Char>>);
typedef RhaiEvalDart = int Function(
    Pointer<CRhaiEngine>, Pointer<Char>, Pointer<Pointer<Char>>);

/// Typedef for the rhai_analyze function
typedef RhaiAnalyzeNative = Int32 Function(
    Pointer<CRhaiEngine>, Pointer<Char>, Pointer<Pointer<Char>>);
typedef RhaiAnalyzeDart = int Function(
    Pointer<CRhaiEngine>, Pointer<Char>, Pointer<Pointer<Char>>);

typedef RhaiEngineFreeDart = void Function(Pointer<CRhaiEngine>);

/// Typedef for the rhai_engine_eval function
typedef RhaiEngineEvalNative = Pointer<CRhaiValue> Function(
    Pointer<CRhaiEngine>, Pointer<Char>);
typedef RhaiEngineEvalDart = Pointer<CRhaiValue> Function(
    Pointer<CRhaiEngine>, Pointer<Char>);

/// Typedef for the rhai_value_free function
typedef RhaiValueFreeNative = Void Function(Pointer<CRhaiValue>);
typedef RhaiValueFreeDart = void Function(Pointer<CRhaiValue>);

/// Typedef for the rhai_value_to_json function
typedef RhaiValueToJsonNative = Pointer<Char> Function(Pointer<CRhaiValue>);
typedef RhaiValueToJsonDart = Pointer<Char> Function(Pointer<CRhaiValue>);

/// Typedef for Dart callback function (used by Rust)
typedef DartCallbackNative = Pointer<Utf8> Function(Int64, Pointer<Utf8>);
typedef DartCallbackDart = Pointer<Utf8> Function(int, Pointer<Utf8>);

/// Typedef for the rhai_register_function function
typedef RhaiRegisterFunctionNative = Int32 Function(
    Pointer<CRhaiEngine>,
    Pointer<Char>,
    Int64,
    Pointer<NativeFunction<DartCallbackNative>>);
typedef RhaiRegisterFunctionDart = int Function(
    Pointer<CRhaiEngine>,
    Pointer<Char>,
    int,
    Pointer<NativeFunction<DartCallbackNative>>);

/// Typedef for the rhai_complete_future function
///
/// This function is called from Dart when an async operation completes.
/// It sends the result through a oneshot channel to wake up the awaiting
/// Rust async task.
///
/// Args:
///   futureId: The unique ID of the future to complete
///   resultJson: JSON string containing the result
///
/// Returns:
///   0 on success, -1 if future ID not found or on error
typedef RhaiCompleteFutureNative = Int32 Function(Int64, Pointer<Utf8>);
typedef RhaiCompleteFutureDart = int Function(int, Pointer<Utf8>);

/// Typedef for the rhai_eval_async_start function
///
/// Starts an async evaluation on a background thread.
///
/// Args:
///   engine: Pointer to the Rhai engine
///   script: Pointer to the script string
///   evalIdOut: Pointer to store the eval ID
///
/// Returns:
///   0 on success (eval started), -1 on error
typedef RhaiEvalAsyncStartNative = Int32 Function(
    Pointer<CRhaiEngine>, Pointer<Char>, Pointer<Int64>);
typedef RhaiEvalAsyncStartDart = int Function(
    Pointer<CRhaiEngine>, Pointer<Char>, Pointer<Int64>);

/// Typedef for the rhai_eval_async_poll function
///
/// Polls for the result of an async evaluation.
///
/// Args:
///   evalId: The unique ID of the async eval
///   statusOut: Pointer to store status (0=in_progress, 1=success, 2=error)
///   resultOut: Pointer to store the result string
///
/// Returns:
///   0 on success, -1 on error
typedef RhaiEvalAsyncPollNative = Int32 Function(
    Int64, Pointer<Int32>, Pointer<Pointer<Char>>);
typedef RhaiEvalAsyncPollDart = int Function(
    int, Pointer<Int32>, Pointer<Pointer<Char>>);

/// Typedef for the rhai_eval_async_cancel function
///
/// Cancels an async evaluation.
///
/// Args:
///   evalId: The unique ID of the async eval to cancel
///
/// Returns:
///   0 on success, -1 if not found
typedef RhaiEvalAsyncCancelNative = Int32 Function(Int64);
typedef RhaiEvalAsyncCancelDart = int Function(int);

/// Typedef for the rhai_get_pending_function_request function
///
/// Get pending function request from Rust.
///
/// Args:
///   execIdOut: Pointer to store the execution ID
///   functionNameOut: Pointer to store the function name string pointer
///   argsJsonOut: Pointer to store the args JSON string pointer
///
/// Returns:
///   0 if request retrieved, -1 if no pending requests
typedef RhaiGetPendingFunctionRequestNative = Int32 Function(
    Pointer<Int64>, Pointer<Pointer<Char>>, Pointer<Pointer<Char>>);
typedef RhaiGetPendingFunctionRequestDart = int Function(
    Pointer<Int64>, Pointer<Pointer<Char>>, Pointer<Pointer<Char>>);

/// Typedef for the rhai_provide_function_result function
///
/// Provide function result to Rust.
///
/// Args:
///   execId: The execution ID of the function request
///   resultJson: JSON string containing the result
///
/// Returns:
///   0 on success, -1 if exec_id not found
typedef RhaiProvideFunctionResultNative = Int32 Function(Int64, Pointer<Char>);
typedef RhaiProvideFunctionResultDart = int Function(int, Pointer<Char>);

/// FFI bindings to the Rhai native library.
///
/// This class provides access to all FFI functions in the Rhai library.
/// It uses a singleton pattern to ensure the library is only loaded once.
/// The library is automatically located using native assets.
class RhaiBindings {
  /// The loaded native library
  final DynamicLibrary _lib;

  /// Singleton instance
  static RhaiBindings? _instance;

  /// Private constructor
  RhaiBindings._(this._lib) {
    _initializeBindings();
  }

  /// Get the singleton instance
  static RhaiBindings get instance {
    if (_instance == null) {
      final lib = _loadLibrary();
      _instance = RhaiBindings._(lib);
    }
    return _instance!;
  }

  /// Load the native library based on platform
  ///
  /// This function attempts to load the library in the following order:
  /// 1. Try native assets location (from build output)
  /// 2. Try local development paths
  /// 3. Fall back to system paths
  static DynamicLibrary _loadLibrary() {
    // Get the expected library name based on platform
    final String libName;
    if (Platform.isMacOS) {
      libName = 'librhai_dart.dylib';
    } else if (Platform.isLinux) {
      libName = 'librhai_dart.so';
    } else if (Platform.isWindows) {
      libName = 'rhai_dart.dll';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    // Try native assets location first
    // This is where the build hook places the compiled library
    try {
      // Native assets are automatically resolved by the Dart VM
      // when using the native_assets experimental feature
      return DynamicLibrary.open(libName);
    } catch (e) {
      // If native assets don't work, try development paths
    }

    // Try development paths for local testing
    final devPaths = [
      './$libName',
      '../$libName',
      './rust/target/release/$libName',
      './rust/target/debug/$libName',
    ];

    for (final path in devPaths) {
      try {
        return DynamicLibrary.open(path);
      } catch (e) {
        // Try next path
        continue;
      }
    }

    // If all else fails, throw a clear error
    throw UnsupportedError(
      'Could not load $libName. Make sure to:\n'
      '1. Run with --enable-experiment=native-assets flag\n'
      '2. Build the Rust library first (cd rust && cargo build --release)\n'
      '3. Verify the library exists in the expected location'
    );
  }

  // Function pointers - Error handling
  late final RhaiGetLastErrorDart _getLastError;
  late final RhaiFreeErrorDart _freeError;

  // Function pointers - Engine lifecycle
  late final RhaiEngineNewDart _engineNew;
  late final RhaiEngineFreeDart _engineFree;
  late final RhaiEvalDart _eval;
  late final RhaiAnalyzeDart _analyze;
  late final RhaiEngineEvalDart _engineEval;

  // Function pointers - Value handling
  late final RhaiValueFreeDart _valueFree;
  late final RhaiValueToJsonDart _valueToJson;

  // Function pointers - Function registration
  late final RhaiRegisterFunctionDart _registerFunction;

  // Function pointers - Async future completion
  late final RhaiCompleteFutureDart _completeFuture;

  // Function pointers - Async eval
  late final RhaiEvalAsyncStartDart _evalAsyncStart;
  late final RhaiEvalAsyncPollDart _evalAsyncPoll;
  late final RhaiEvalAsyncCancelDart _evalAsyncCancel;

  // Function pointers - Function request/response
  late final RhaiGetPendingFunctionRequestDart _getPendingFunctionRequest;
  late final RhaiProvideFunctionResultDart _provideFunctionResult;

  /// Initialize all FFI bindings
  void _initializeBindings() {
    // Error handling functions
    _getLastError = _lib
        .lookup<NativeFunction<RhaiGetLastErrorNative>>('rhai_get_last_error')
        .asFunction();

    _freeError = _lib
        .lookup<NativeFunction<RhaiFreeErrorNative>>('rhai_free_error')
        .asFunction();

    // Engine lifecycle functions
    _engineNew = _lib
        .lookup<NativeFunction<RhaiEngineNewNative>>('rhai_engine_new')
        .asFunction();

    _engineFree = _lib
        .lookup<NativeFunction<RhaiEngineFreeNative>>('rhai_engine_free')
        .asFunction();

    _eval = _lib
        .lookup<NativeFunction<RhaiEvalNative>>('rhai_eval')
        .asFunction();

    _analyze = _lib
        .lookup<NativeFunction<RhaiAnalyzeNative>>('rhai_analyze')
        .asFunction();

    // Engine evaluation function (will be implemented in later task groups)
    try {
      _engineEval = _lib
          .lookup<NativeFunction<RhaiEngineEvalNative>>('rhai_engine_eval')
          .asFunction();
    } catch (e) {
      // Not yet implemented, use a stub
      _engineEval = (_, __) => nullptr;
    }

    // Value handling functions (will be implemented in later task groups)
    try {
      _valueFree = _lib
          .lookup<NativeFunction<RhaiValueFreeNative>>('rhai_value_free')
          .asFunction();
    } catch (e) {
      // Not yet implemented, use a stub
      _valueFree = (_) {};
    }

    try {
      _valueToJson = _lib
          .lookup<NativeFunction<RhaiValueToJsonNative>>('rhai_value_to_json')
          .asFunction();
    } catch (e) {
      // Not yet implemented, use a stub
      _valueToJson = (_) => nullptr;
    }

    // Function registration
    _registerFunction = _lib
        .lookup<NativeFunction<RhaiRegisterFunctionNative>>('rhai_register_function')
        .asFunction();

    // Async future completion
    _completeFuture = _lib
        .lookup<NativeFunction<RhaiCompleteFutureNative>>('rhai_complete_future')
        .asFunction();

    // Async eval functions
    _evalAsyncStart = _lib
        .lookup<NativeFunction<RhaiEvalAsyncStartNative>>('rhai_eval_async_start')
        .asFunction();

    _evalAsyncPoll = _lib
        .lookup<NativeFunction<RhaiEvalAsyncPollNative>>('rhai_eval_async_poll')
        .asFunction();

    _evalAsyncCancel = _lib
        .lookup<NativeFunction<RhaiEvalAsyncCancelNative>>('rhai_eval_async_cancel')
        .asFunction();

    // Function request/response
    _getPendingFunctionRequest = _lib
        .lookup<NativeFunction<RhaiGetPendingFunctionRequestNative>>(
            'rhai_get_pending_function_request')
        .asFunction();

    _provideFunctionResult = _lib
        .lookup<NativeFunction<RhaiProvideFunctionResultNative>>(
            'rhai_provide_function_result')
        .asFunction();
  }

  // Public API - Error handling

  /// Get the last error message from thread-local storage
  Pointer<Char> getLastError() => _getLastError();

  /// Free an error string allocated by Rust
  void freeError(Pointer<Char> ptr) => _freeError(ptr);

  // Public API - Engine lifecycle

  /// Create a new Rhai engine
  Pointer<CRhaiEngine> engineNew(Pointer<CRhaiConfig> config) =>
      _engineNew(config);

  /// Free a Rhai engine
  void engineFree(Pointer<CRhaiEngine> engine) => _engineFree(engine);

  /// Evaluate a Rhai script
  int eval(Pointer<CRhaiEngine> engine, Pointer<Char> script, Pointer<Pointer<Char>> result) =>
      _eval(engine, script, result);

  /// Analyze a Rhai script without executing it
  int analyze(Pointer<CRhaiEngine> engine, Pointer<Char> script, Pointer<Pointer<Char>> result) =>
      _analyze(engine, script, result);

  /// Evaluate a Rhai script
  Pointer<CRhaiValue> engineEval(Pointer<CRhaiEngine> engine, Pointer<Char> script) =>
      _engineEval(engine, script);

  // Public API - Value handling

  /// Free a Rhai value
  void valueFree(Pointer<CRhaiValue> value) => _valueFree(value);

  /// Convert a Rhai value to JSON
  Pointer<Char> valueToJson(Pointer<CRhaiValue> value) => _valueToJson(value);

  // Public API - Function registration

  /// Register a Dart function with the Rhai engine
  int registerFunction(
    Pointer<CRhaiEngine> engine,
    Pointer<Char> name,
    int callbackId,
    Pointer<NativeFunction<DartCallbackNative>> callbackPtr,
  ) => _registerFunction(engine, name, callbackId, callbackPtr);

  // Public API - Async future completion

  /// Complete an async future from Dart.
  ///
  /// This function is called when a Dart Future completes to send the result
  /// back to the awaiting Rust async task through a oneshot channel.
  ///
  /// Args:
  ///   futureId: The unique ID of the future to complete
  ///   resultJson: Pointer to JSON string containing the result
  ///
  /// Returns:
  ///   0 on success, -1 if future ID not found or on error
  int completeFuture(int futureId, Pointer<Utf8> resultJson) =>
      _completeFuture(futureId, resultJson);

  // Public API - Async eval

  /// Start an async evaluation on a background thread.
  ///
  /// Args:
  ///   engine: Pointer to the Rhai engine
  ///   script: Pointer to the script string
  ///   evalIdOut: Pointer to store the unique eval ID
  ///
  /// Returns:
  ///   0 on success (eval started), -1 on error
  int evalAsyncStart(
    Pointer<CRhaiEngine> engine,
    Pointer<Char> script,
    Pointer<Int64> evalIdOut,
  ) => _evalAsyncStart(engine, script, evalIdOut);

  /// Poll for the result of an async evaluation.
  ///
  /// Args:
  ///   evalId: The unique ID of the async eval
  ///   statusOut: Pointer to store status (0=in_progress, 1=success, 2=error)
  ///   resultOut: Pointer to store the result string
  ///
  /// Returns:
  ///   0 on success, -1 on error
  int evalAsyncPoll(
    int evalId,
    Pointer<Int32> statusOut,
    Pointer<Pointer<Char>> resultOut,
  ) => _evalAsyncPoll(evalId, statusOut, resultOut);

  /// Cancel an async evaluation.
  ///
  /// Args:
  ///   evalId: The unique ID of the async eval to cancel
  ///
  /// Returns:
  ///   0 on success, -1 if not found
  int evalAsyncCancel(int evalId) => _evalAsyncCancel(evalId);

  /// Get pending function request from Rust.
  ///
  /// Returns 0 if request retrieved, -1 if no pending requests.
  int getPendingFunctionRequest(
    Pointer<Int64> execIdOut,
    Pointer<Pointer<Char>> functionNameOut,
    Pointer<Pointer<Char>> argsJsonOut,
  ) => _getPendingFunctionRequest(execIdOut, functionNameOut, argsJsonOut);

  /// Provide function result to Rust.
  ///
  /// Returns 0 on success, -1 if exec_id not found.
  int provideFunctionResult(int execId, Pointer<Char> resultJson) =>
      _provideFunctionResult(execId, resultJson);

  /// Function addresses for use with NativeFinalizer
  BindingAddresses get addresses => BindingAddresses(this);
}

/// Helper class to provide function addresses for NativeFinalizer
///
/// This class exposes the raw function pointers needed by NativeFinalizer
/// to automatically clean up native resources when Dart objects are garbage collected.
class BindingAddresses {
  final RhaiBindings _bindings;

  BindingAddresses(this._bindings);

  /// Address of rhai_get_last_error
  Pointer<NativeFunction<RhaiGetLastErrorNative>> get getLastError =>
      _bindings._lib.lookup('rhai_get_last_error');

  /// Address of rhai_free_error
  Pointer<NativeFunction<RhaiFreeErrorNative>> get freeError =>
      _bindings._lib.lookup('rhai_free_error');

  /// Address of rhai_engine_new
  Pointer<NativeFunction<RhaiEngineNewNative>> get engineNew =>
      _bindings._lib.lookup('rhai_engine_new');

  /// Address of rhai_engine_free
  Pointer<NativeFunction<RhaiEngineFreeNative>> get engineFree =>
      _bindings._lib.lookup('rhai_engine_free');

  /// Address of rhai_value_free
  Pointer<NativeFunction<RhaiValueFreeNative>> get valueFree {
    try {
      return _bindings._lib.lookup('rhai_value_free');
    } catch (e) {
      // Not yet implemented
      return nullptr;
    }
  }
}
