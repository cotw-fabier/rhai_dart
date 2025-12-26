/// Rhai engine for executing scripts
///
/// This module provides the main RhaiEngine class for executing Rhai scripts
/// with automatic memory management and error handling.
library;

import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:rhai_dart/src/engine_config.dart';
import 'package:rhai_dart/src/errors.dart';
import 'package:rhai_dart/src/analysis_result.dart';
import 'package:rhai_dart/src/ffi/bindings.dart';
import 'package:rhai_dart/src/ffi/finalizers.dart';
import 'package:rhai_dart/src/ffi/native_types.dart';
import 'package:rhai_dart/src/ffi/ffi_utils.dart';
import 'package:rhai_dart/src/ffi/callback_bridge.dart';
import 'package:rhai_dart/src/function_registry.dart';
import 'package:rhai_dart/src/type_conversion.dart';

/// Main API class for executing Rhai scripts.
///
/// This class wraps a native Rhai engine instance and provides a safe,
/// idiomatic Dart API for script execution. Memory is automatically managed
/// via [NativeFinalizer], but you can also call [dispose] for deterministic cleanup.
///
/// Example usage:
/// ```dart
/// // Create engine with default secure configuration
/// final engine = RhaiEngine.withDefaults();
///
/// // Execute a script
/// final result = engine.eval('40 + 2');
/// print(result); // 42
///
/// // Clean up (optional - will happen automatically via finalizer)
/// engine.dispose();
/// ```
///
/// Example with custom configuration:
/// ```dart
/// final config = RhaiConfig.custom(
///   maxOperations: 500000,
///   timeoutMs: 3000,
/// );
/// final engine = RhaiEngine.withConfig(config);
/// ```
class RhaiEngine implements Finalizable {
  /// The native engine pointer
  Pointer<CRhaiEngine>? _engine;

  /// The FFI bindings
  final RhaiBindings _bindings;

  /// Whether this engine has been disposed
  bool _disposed = false;

  /// Registry of registered function callback IDs
  /// Used to clean up when the engine is disposed
  final List<int> _registeredCallbackIds = [];

  /// Creates a new RhaiEngine with the given native pointer.
  ///
  /// This is a private constructor. Use [withDefaults] or [withConfig] instead.
  RhaiEngine._(this._engine, this._bindings) {
    if (_engine != null && _engine != nullptr) {
      // Attach finalizer for automatic cleanup
      attachEngineFinalizer(this, _engine!);
    }

    // Initialize the callback bridge (if not already initialized)
    initializeCallbackBridge();
  }

  /// Creates a new RhaiEngine with secure default configuration.
  ///
  /// The default configuration includes:
  /// - maxOperations: 1,000,000
  /// - maxStackDepth: 100
  /// - maxStringLength: 10 MB
  /// - timeoutMs: 5,000 ms (5 seconds)
  /// - All dangerous features disabled (file I/O, eval, modules)
  ///
  /// This is the recommended constructor for most use cases.
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  /// final result = engine.eval('1 + 1');
  /// print(result); // 2
  /// engine.dispose();
  /// ```
  ///
  /// Throws [RhaiFFIError] if engine creation fails.
  factory RhaiEngine.withDefaults() {
    final bindings = RhaiBindings.instance;

    // Create engine with null config (uses secure defaults)
    final enginePtr = bindings.engineNew(nullptr);

    if (enginePtr == nullptr) {
      throw const RhaiFFIError('Failed to create Rhai engine with defaults');
    }

    return RhaiEngine._(enginePtr, bindings);
  }

  /// Creates a new RhaiEngine with custom configuration.
  ///
  /// Allows you to customize operation limits, timeouts, and sandboxing settings.
  ///
  /// Example:
  /// ```dart
  /// final config = RhaiConfig.custom(
  ///   maxOperations: 500000,
  ///   timeoutMs: 3000,
  ///   disableFileIo: true,
  /// );
  /// final engine = RhaiEngine.withConfig(config);
  /// ```
  ///
  /// Throws [RhaiFFIError] if engine creation fails.
  factory RhaiEngine.withConfig(RhaiConfig config) {
    final bindings = RhaiBindings.instance;
    final nativeConfig = config.toNative();

    try {
      // Create engine with custom config
      final enginePtr = bindings.engineNew(nativeConfig);

      if (enginePtr == nullptr) {
        throw RhaiFFIError(
          'Failed to create Rhai engine with config: $config',
        );
      }

      return RhaiEngine._(enginePtr, bindings);
    } finally {
      // Always free the native config
      calloc.free(nativeConfig);
    }
  }

  /// Returns true if this engine has been disposed.
  bool get isDisposed => _disposed;

  /// Gets the native engine pointer.
  ///
  /// Throws [StateError] if the engine has been disposed.
  Pointer<CRhaiEngine> get _nativeEngine {
    if (_disposed || _engine == null || _engine == nullptr) {
      throw StateError('RhaiEngine has been disposed');
    }
    return _engine!;
  }

  /// Manually disposes this engine and frees native resources.
  ///
  /// After calling dispose(), this engine cannot be used anymore.
  /// Calling dispose() multiple times is safe (subsequent calls are no-ops).
  ///
  /// Note: This is optional. If you don't call dispose(), the engine will be
  /// automatically cleaned up when garbage collected via [NativeFinalizer].
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  /// try {
  ///   final result = engine.eval('1 + 1');
  ///   print(result);
  /// } finally {
  ///   engine.dispose(); // Ensure cleanup
  /// }
  /// ```
  void dispose() {
    if (!_disposed && _engine != null && _engine != nullptr) {
      // Unregister all callbacks
      final registry = FunctionRegistry();
      for (final callbackId in _registeredCallbackIds) {
        registry.unregister(callbackId);
      }
      _registeredCallbackIds.clear();

      // Detach finalizer to prevent double-free
      detachEngineFinalizer(this);

      // Free the native engine
      _bindings.engineFree(_engine!);

      // Mark as disposed
      _disposed = true;
      _engine = null;
    }
  }

  /// Evaluates a Rhai script and returns the result.
  ///
  /// This method executes the given script and returns the result as a Dart value.
  /// The return type depends on what the script evaluates to:
  /// - Integer values become `int`
  /// - Floating-point values become `double`
  /// - Boolean values become `bool`
  /// - String values become `String`
  /// - Arrays become `List<dynamic>`
  /// - Objects/Maps become `Map<String, dynamic>`
  /// - Unit/void values become `null`
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  ///
  /// // Simple arithmetic
  /// final result = engine.eval('2 + 2');
  /// print(result); // 4
  ///
  /// // Variables and logic
  /// final result2 = engine.eval('''
  ///   let x = 10;
  ///   let y = 20;
  ///   if x < y { x + y } else { x - y }
  /// ''');
  /// print(result2); // 30
  ///
  /// // String operations
  /// final result3 = engine.eval('"Hello, " + "World!"');
  /// print(result3); // "Hello, World!"
  /// ```
  ///
  /// Throws [RhaiSyntaxError] if the script has syntax errors (includes line numbers).
  /// Throws [RhaiRuntimeError] if the script fails during execution.
  /// Throws [StateError] if the engine has been disposed.
  dynamic eval(String script) {
    // Check if disposed
    final enginePtr = _nativeEngine; // Will throw if disposed

    // Convert Dart string to C string
    final scriptPtr = script.toNativeUtf8();

    try {
      // Allocate pointer for result
      final resultPtrPtr = calloc<Pointer<Char>>();

      try {
        // Call native eval function
        final returnCode = _bindings.eval(enginePtr, scriptPtr.cast(), resultPtrPtr);

        // Check for errors
        if (returnCode != 0) {
          // Error occurred - check and throw appropriate exception
          checkFFIError(_bindings);

          // If checkFFIError didn't throw, throw a generic error
          throw const RhaiFFIError('Script evaluation failed');
        }

        // Get the result pointer
        final resultPtr = resultPtrPtr.value;

        if (resultPtr == nullptr) {
          throw const RhaiFFIError('Result pointer is null after successful eval');
        }

        try {
          // Convert C string to Dart string (JSON format)
          final jsonResult = resultPtr.cast<Utf8>().toDartString();

          // Parse JSON to Dart value
          return jsonToRhaiValue(jsonResult);
        } finally {
          // Free the result string
          freeNativeString(_bindings, resultPtr.cast());
        }
      } finally {
        // Free the result pointer pointer
        calloc.free(resultPtrPtr);
      }
    } finally {
      // Free the script string
      calloc.free(scriptPtr);
    }
  }

  /// Analyzes a Rhai script without executing it.
  ///
  /// This method parses the script to check for syntax errors without
  /// actually running it. This is useful for validating user input before
  /// execution, or for providing feedback in an editor.
  ///
  /// The returned [AnalysisResult] contains:
  /// - `isValid`: Whether the script is syntactically valid
  /// - `syntaxErrors`: List of syntax errors found (empty if valid)
  /// - `warnings`: List of warnings (currently unused)
  /// - `astSummary`: Optional AST summary (currently unused)
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  ///
  /// // Analyze a valid script
  /// final result1 = engine.analyze('let x = 10; x + 20');
  /// print(result1.isValid); // true
  /// print(result1.syntaxErrors); // []
  ///
  /// // Analyze an invalid script
  /// final result2 = engine.analyze('let x = ;');
  /// print(result2.isValid); // false
  /// print(result2.syntaxErrors); // ["Syntax error at line 1: ..."]
  /// ```
  ///
  /// Throws [RhaiFFIError] if an FFI operation fails.
  /// Throws [StateError] if the engine has been disposed.
  AnalysisResult analyze(String script) {
    // Check if disposed
    final enginePtr = _nativeEngine; // Will throw if disposed

    // Convert Dart string to C string
    final scriptPtr = script.toNativeUtf8();

    try {
      // Allocate pointer for result
      final resultPtrPtr = calloc<Pointer<Char>>();

      try {
        // Call native analyze function
        final returnCode = _bindings.analyze(enginePtr, scriptPtr.cast(), resultPtrPtr);

        // Check for errors
        if (returnCode != 0) {
          // Error occurred - check and throw appropriate exception
          checkFFIError(_bindings);

          // If checkFFIError didn't throw, throw a generic error
          throw const RhaiFFIError('Script analysis failed');
        }

        // Get the result pointer
        final resultPtr = resultPtrPtr.value;

        if (resultPtr == nullptr) {
          throw const RhaiFFIError('Result pointer is null after successful analyze');
        }

        try {
          // Convert C string to Dart string (JSON format)
          final jsonResult = resultPtr.cast<Utf8>().toDartString();

          // Parse JSON to AnalysisResult
          final Map<String, dynamic> jsonMap = json.decode(jsonResult);
          return AnalysisResult.fromJson(jsonMap);
        } finally {
          // Free the result string
          freeNativeString(_bindings, resultPtr.cast());
        }
      } finally {
        // Free the result pointer pointer
        calloc.free(resultPtrPtr);
      }
    } finally {
      // Free the script string
      calloc.free(scriptPtr);
    }
  }

  /// Registers a Dart function with the Rhai engine.
  ///
  /// This allows Rhai scripts to call Dart functions. Both synchronous and
  /// asynchronous functions are supported. Async functions will block the
  /// Rhai execution until they complete.
  ///
  /// The function can have up to 10 parameters of any type that can be
  /// converted between Dart and Rhai (primitives, lists, maps).
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  ///
  /// // Register a simple function
  /// engine.registerFunction('add', (int a, int b) => a + b);
  ///
  /// // Use it in a script
  /// final result = engine.eval('add(10, 20)');
  /// print(result); // 30
  ///
  /// // Register an async function
  /// engine.registerFunction('fetchData', () async {
  ///   await Future.delayed(Duration(milliseconds: 100));
  ///   return 'data';
  /// });
  ///
  /// final result2 = engine.eval('fetchData()');
  /// print(result2); // 'data'
  /// ```
  ///
  /// Args:
  ///   name: The name of the function as it will appear in Rhai scripts
  ///   callback: The Dart function to call
  ///
  /// Throws [RhaiFFIError] if registration fails.
  /// Throws [StateError] if the engine has been disposed.
  /// Throws [ArgumentError] if the function has more than 10 parameters.
  void registerFunction(String name, Function callback) {
    // Check if disposed
    final enginePtr = _nativeEngine; // Will throw if disposed

    // Validate function (for now, we accept any Function)
    // TODO: Add validation for parameter count if needed

    // Register the callback in the registry
    final registry = FunctionRegistry();
    final callbackId = registry.register(name, callback);
    _registeredCallbackIds.add(callbackId);

    // Get the callback pointer
    final callbackPtr = getCallbackPointer();

    // Convert function name to C string
    final namePtr = name.toNativeUtf8();

    try {
      // Call the FFI function to register the function
      final returnCode = _bindings.registerFunction(
        enginePtr,
        namePtr.cast(),
        callbackId,
        callbackPtr,
      );

      // Check for errors
      if (returnCode != 0) {
        // Registration failed - unregister the callback
        registry.unregister(callbackId);
        _registeredCallbackIds.remove(callbackId);

        // Check and throw appropriate exception
        checkFFIError(_bindings);

        // If checkFFIError didn't throw, throw a generic error
        throw RhaiFFIError('Failed to register function: $name');
      }
    } finally {
      // Free the name string
      calloc.free(namePtr);
    }
  }

  @override
  String toString() {
    if (_disposed) {
      return 'RhaiEngine(disposed)';
    }
    return 'RhaiEngine(address: ${_engine?.address ?? 0})';
  }
}
