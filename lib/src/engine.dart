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

/// Represents a function call request from Rust during async eval.
class _FunctionRequest {
  final int execId;
  final String functionName;
  final String argsJson;

  _FunctionRequest(this.execId, this.functionName, this.argsJson);
}

/// Represents the status of an async eval operation.
class _EvalStatus {
  final bool isComplete;
  final bool isSuccess;
  final String result;
  final String error;

  _EvalStatus.inProgress()
      : isComplete = false,
        isSuccess = false,
        result = '',
        error = '';

  _EvalStatus.success(this.result)
      : isComplete = true,
        isSuccess = true,
        error = '';

  _EvalStatus.error(this.error)
      : isComplete = true,
        isSuccess = false,
        result = '';
}

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

  /// Evaluates a Rhai script asynchronously, supporting async Dart functions.
  ///
  /// This method runs the script on a background thread, allowing the Dart
  /// event loop to remain free during execution. This enables async Dart
  /// functions (like HTTP requests, file I/O, etc.) to complete properly.
  ///
  /// **Use this method when:**
  /// - Your script calls async Dart functions
  /// - You want to avoid blocking the Dart event loop
  ///
  /// **For scripts with only synchronous functions, prefer [eval] for better performance.**
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  ///
  /// // Register an async function
  /// engine.registerFunction('fetchData', () async {
  ///   await Future.delayed(Duration(milliseconds: 100));
  ///   return {'status': 'success', 'data': [1, 2, 3]};
  /// });
  ///
  /// // Use evalAsync for scripts calling async functions
  /// final result = await engine.evalAsync('fetchData()');
  /// print(result); // {status: success, data: [1, 2, 3]}
  /// ```
  ///
  /// Throws [RhaiSyntaxError] if the script has syntax errors (includes line numbers).
  /// Throws [RhaiRuntimeError] if the script fails during execution.
  /// Throws [StateError] if the engine has been disposed.
  Future<dynamic> evalAsync(String script) async {
    // Check if disposed
    final enginePtr = _nativeEngine; // Will throw if disposed

    // Convert Dart string to C string
    final scriptPtr = script.toNativeUtf8();

    try {
      // Allocate pointer for eval ID
      final evalIdPtr = calloc<Int64>();

      try {
        // Start async eval on background thread
        final returnCode = _bindings.evalAsyncStart(
          enginePtr,
          scriptPtr.cast(),
          evalIdPtr,
        );

        // Check for errors
        if (returnCode != 0) {
          checkFFIError(_bindings);
          throw const RhaiFFIError('Failed to start async eval');
        }

        // Get the eval ID
        final evalId = evalIdPtr.value;

        // Main polling loop with request/response pattern
        while (true) {
          // Check for function call requests FIRST (higher priority)
          final request = _pollFunctionRequest();
          if (request != null) {
            // Rust needs a Dart function executed!
            await _fulfillFunctionRequest(request);
            continue; // Check for more requests immediately
          }

          // Check if eval completed
          final evalStatus = _pollEvalStatus(evalId);
          if (evalStatus.isComplete) {
            if (evalStatus.isSuccess) {
              return jsonToRhaiValue(evalStatus.result);
            } else {
              _throwParsedError(evalStatus.error);
            }
          }

          // Brief delay to avoid busy-waiting
          await Future.delayed(const Duration(milliseconds: 10));
        }
      } finally {
        calloc.free(evalIdPtr);
      }
    } finally {
      calloc.free(scriptPtr);
    }
  }

  /// Helper method to parse error message and throw appropriate exception type
  void _throwParsedError(String errorMsg) {
    if (errorMsg.contains('(line ') || errorMsg.contains('Syntax error')) {
      throw RhaiSyntaxError(errorMsg);
    } else if (errorMsg.contains('Runtime error') ||
        errorMsg.contains('timed out') ||
        errorMsg.contains('evalAsync')) {
      throw RhaiRuntimeError(errorMsg);
    } else {
      throw RhaiFFIError(errorMsg);
    }
  }

  /// Poll for pending function requests from Rust
  _FunctionRequest? _pollFunctionRequest() {
    final execIdPtr = calloc<Int64>();
    final fnNamePtrPtr = calloc<Pointer<Char>>();
    final argsPtrPtr = calloc<Pointer<Char>>();

    try {
      final result = _bindings.getPendingFunctionRequest(
        execIdPtr,
        fnNamePtrPtr,
        argsPtrPtr,
      );

      if (result != 0) {
        return null; // No pending requests
      }

      // Extract request data
      final execId = execIdPtr.value;
      final fnNamePtr = fnNamePtrPtr.value;
      final argsPtr = argsPtrPtr.value;

      if (fnNamePtr == nullptr || argsPtr == nullptr) {
        return null;
      }

      final fnName = fnNamePtr.cast<Utf8>().toDartString();
      final argsJson = argsPtr.cast<Utf8>().toDartString();

      // Free C strings
      freeNativeString(_bindings, fnNamePtr.cast());
      freeNativeString(_bindings, argsPtr.cast());

      return _FunctionRequest(execId, fnName, argsJson);
    } finally {
      calloc.free(execIdPtr);
      calloc.free(fnNamePtrPtr);
      calloc.free(argsPtrPtr);
    }
  }

  /// Execute Dart function and provide result back to Rust
  Future<void> _fulfillFunctionRequest(_FunctionRequest request) async {
    try {
      // Look up registered function
      final registry = FunctionRegistry();
      final callback = registry.getByName(request.functionName);
      if (callback == null) {
        _provideErrorResult(
          request.execId,
          'Function not found: ${request.functionName}',
        );
        return;
      }

      // Parse args
      final args = jsonDecode(request.argsJson) as List;

      // Call function (can be async!)
      dynamic result;
      if (callback is Future Function()) {
        result = await callback();
      } else {
        result = Function.apply(callback, args);
        // If result is Future, await it
        if (result is Future) {
          result = await result;
        }
      }

      // Encode result as JSON
      final resultJson = jsonEncode(_encodeResultForCallback(result));

      // Provide result to Rust
      _provideFunctionResult(request.execId, resultJson);
    } catch (e, stackTrace) {
      // Provide error to Rust
      _provideErrorResult(
        request.execId,
        'Function error: $e\nStack trace: $stackTrace',
      );
    }
  }

  /// Poll for eval status
  _EvalStatus _pollEvalStatus(int evalId) {
    final statusPtr = calloc<Int32>();
    final resultPtrPtr = calloc<Pointer<Char>>();

    try {
      final pollResult = _bindings.evalAsyncPoll(
        evalId,
        statusPtr,
        resultPtrPtr,
      );

      if (pollResult != 0) {
        checkFFIError(_bindings);
        throw const RhaiFFIError('Failed to poll async eval');
      }

      final status = statusPtr.value;
      final resultPtr = resultPtrPtr.value;

      if (status == 0) {
        // In progress
        return _EvalStatus.inProgress();
      } else if (status == 1) {
        // Success
        if (resultPtr == nullptr) {
          throw const RhaiFFIError('Result pointer is null after success');
        }
        final jsonResult = resultPtr.cast<Utf8>().toDartString();
        freeNativeString(_bindings, resultPtr.cast());
        return _EvalStatus.success(jsonResult);
      } else if (status == 2) {
        // Error
        if (resultPtr == nullptr) {
          throw const RhaiFFIError('Error message pointer is null');
        }
        final errorMsg = resultPtr.cast<Utf8>().toDartString();
        freeNativeString(_bindings, resultPtr.cast());
        return _EvalStatus.error(errorMsg);
      } else {
        throw RhaiFFIError('Invalid async eval status: $status');
      }
    } finally {
      calloc.free(statusPtr);
      calloc.free(resultPtrPtr);
    }
  }

  /// Provide function result to Rust
  void _provideFunctionResult(int execId, String resultJson) {
    final resultPtr = resultJson.toNativeUtf8();
    try {
      final returnCode = _bindings.provideFunctionResult(execId, resultPtr.cast());
      if (returnCode != 0) {
        checkFFIError(_bindings);
        // Log warning but don't throw - eval can continue
        print('Warning: Failed to provide function result for exec_id $execId');
      }
    } finally {
      calloc.free(resultPtr);
    }
  }

  /// Provide error result to Rust
  void _provideErrorResult(int execId, String error) {
    final errorJson = jsonEncode({'error': error});
    _provideFunctionResult(execId, errorJson);
  }

  /// Encode result for callback (handles different types)
  dynamic _encodeResultForCallback(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num || value is bool) return value;
    if (value is List) return value.map(_encodeResultForCallback).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encodeResultForCallback(v)));
    }
    return value.toString(); // Fallback
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
  /// asynchronous functions are supported.
  ///
  /// **Important:** Use [eval] for sync functions, [evalAsync] for async functions.
  ///
  /// The function can have up to 10 parameters of any type that can be
  /// converted between Dart and Rhai (primitives, lists, maps).
  ///
  /// Example with synchronous function:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  ///
  /// // Register a sync function
  /// engine.registerFunction('add', (int a, int b) => a + b);
  ///
  /// // Use it with eval() - fastest path
  /// final result = engine.eval('add(10, 20)');
  /// print(result); // 30
  /// ```
  ///
  /// Example with asynchronous function:
  /// ```dart
  /// // Register an async function
  /// engine.registerFunction('fetchData', () async {
  ///   await Future.delayed(Duration(milliseconds: 100));
  ///   return {'status': 'success', 'data': [1, 2, 3]};
  /// });
  ///
  /// // MUST use evalAsync() for async functions
  /// final result = await engine.evalAsync('fetchData()');
  /// print(result); // {status: success, data: [1, 2, 3]}
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

  /// Sets a mutable variable that will be available in Rhai scripts.
  ///
  /// This allows you to pass data from Dart into Rhai scripts. The variable
  /// can be modified by the script (unlike [setConstant]).
  ///
  /// Supported types:
  /// - `null`
  /// - `bool`
  /// - `int`
  /// - `double` (including special values: infinity, -infinity, NaN)
  /// - `String`
  /// - `List<dynamic>` (recursively converted)
  /// - `Map<String, dynamic>` (recursively converted)
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  ///
  /// // Set simple values
  /// engine.setVar('name', 'Alice');
  /// engine.setVar('age', 30);
  /// engine.setVar('active', true);
  ///
  /// // Set complex values
  /// engine.setVar('config', {'debug': true, 'level': 5});
  /// engine.setVar('items', [1, 2, 3]);
  ///
  /// // Use in script
  /// final result = engine.eval('name + " is " + age + " years old"');
  /// print(result); // "Alice is 30 years old"
  ///
  /// // Variable can be modified in script
  /// engine.eval('age = 31');
  /// ```
  ///
  /// Throws [RhaiFFIError] if the operation fails.
  /// Throws [StateError] if the engine has been disposed.
  void setVar(String name, dynamic value) {
    // Check if disposed
    final enginePtr = _nativeEngine; // Will throw if disposed

    // Convert value to JSON
    final valueJson = rhaiValueToJson(value);

    // Convert strings to native
    final namePtr = name.toNativeUtf8();
    final valueJsonPtr = valueJson.toNativeUtf8();

    try {
      // Call FFI function
      final returnCode = _bindings.setVar(
        enginePtr,
        namePtr.cast(),
        valueJsonPtr.cast(),
      );

      // Check for errors
      if (returnCode != 0) {
        checkFFIError(_bindings);
        throw RhaiFFIError('Failed to set variable: $name');
      }
    } finally {
      // Free native strings
      calloc.free(namePtr);
      calloc.free(valueJsonPtr);
    }
  }

  /// Sets an immutable constant that will be available in Rhai scripts.
  ///
  /// This allows you to pass data from Dart into Rhai scripts. Unlike [setVar],
  /// attempting to modify this value in a script will result in a runtime error.
  ///
  /// This is useful for configuration values, constants, or data that should
  /// not be changed by the script.
  ///
  /// Supported types are the same as [setVar].
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  ///
  /// // Set constants
  /// engine.setConstant('PI', 3.14159);
  /// engine.setConstant('APP_NAME', 'MyApp');
  /// engine.setConstant('CONFIG', {'maxRetries': 3, 'timeout': 5000});
  ///
  /// // Use in script
  /// final result = engine.eval('PI * 2');
  /// print(result); // 6.28318
  ///
  /// // Attempting to modify will throw
  /// try {
  ///   engine.eval('PI = 3'); // Throws RhaiRuntimeError
  /// } on RhaiRuntimeError catch (e) {
  ///   print('Cannot modify constant: ${e.message}');
  /// }
  /// ```
  ///
  /// Throws [RhaiFFIError] if the operation fails.
  /// Throws [StateError] if the engine has been disposed.
  void setConstant(String name, dynamic value) {
    // Check if disposed
    final enginePtr = _nativeEngine; // Will throw if disposed

    // Convert value to JSON
    final valueJson = rhaiValueToJson(value);

    // Convert strings to native
    final namePtr = name.toNativeUtf8();
    final valueJsonPtr = valueJson.toNativeUtf8();

    try {
      // Call FFI function
      final returnCode = _bindings.setConstant(
        enginePtr,
        namePtr.cast(),
        valueJsonPtr.cast(),
      );

      // Check for errors
      if (returnCode != 0) {
        checkFFIError(_bindings);
        throw RhaiFFIError('Failed to set constant: $name');
      }
    } finally {
      // Free native strings
      calloc.free(namePtr);
      calloc.free(valueJsonPtr);
    }
  }

  /// Clears all variables and constants from the engine scope.
  ///
  /// This removes all variables previously set via [setVar] and [setConstant].
  /// Registered functions are not affected.
  ///
  /// Example:
  /// ```dart
  /// final engine = RhaiEngine.withDefaults();
  /// engine.setVar('x', 10);
  /// engine.setConstant('PI', 3.14);
  ///
  /// engine.clearScope();
  ///
  /// // Variables are no longer available
  /// try {
  ///   engine.eval('x + 1'); // Throws - x not defined
  /// } on RhaiRuntimeError catch (e) {
  ///   print('Variable not found: ${e.message}');
  /// }
  /// ```
  ///
  /// Throws [RhaiFFIError] if the operation fails.
  /// Throws [StateError] if the engine has been disposed.
  void clearScope() {
    final enginePtr = _nativeEngine;

    final returnCode = _bindings.clearScope(enginePtr);

    if (returnCode != 0) {
      checkFFIError(_bindings);
      throw const RhaiFFIError('Failed to clear scope');
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
