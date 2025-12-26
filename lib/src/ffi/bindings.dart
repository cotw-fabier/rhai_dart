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
