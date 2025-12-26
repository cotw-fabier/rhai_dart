/// Function callback registry for Rhai-Dart FFI integration
///
/// This module manages the registration and storage of Dart function callbacks
/// that can be invoked from Rhai scripts.
library;

import 'dart:collection';

/// Registry for storing Dart function callbacks that can be called from Rhai scripts.
///
/// This class provides thread-safe storage for function callbacks using unique IDs.
/// Each registered function is assigned a unique ID that is passed to the Rust side,
/// which uses it to call back into Dart when the function is invoked from a script.
///
/// The registry uses a simple incrementing counter for IDs and a HashMap for storage.
class FunctionRegistry {
  /// Storage for registered callbacks by ID
  final Map<int, Function> _callbacks = HashMap<int, Function>();

  /// Storage for registered callbacks by name
  final Map<String, Function> _callbacksByName = HashMap<String, Function>();

  /// Next available callback ID
  int _nextId = 1;

  /// Singleton instance
  static final FunctionRegistry _instance = FunctionRegistry._internal();

  /// Private constructor for singleton
  FunctionRegistry._internal();

  /// Get the singleton instance
  factory FunctionRegistry() => _instance;

  /// Registers a function callback and returns a unique ID.
  ///
  /// The returned ID should be passed to the Rust side to identify this callback
  /// when it needs to be invoked.
  ///
  /// Example:
  /// ```dart
  /// final registry = FunctionRegistry();
  /// final id = registry.register('add', (int a, int b) => a + b);
  /// // Pass id to Rust side...
  /// ```
  ///
  /// Args:
  ///   name: The name of the function (for debugging/logging purposes)
  ///   callback: The Dart function to register
  ///
  /// Returns:
  ///   A unique ID for this callback
  int register(String name, Function callback) {
    final id = _nextId++;
    _callbacks[id] = callback;
    _callbacksByName[name] = callback;
    return id;
  }

  /// Unregisters a callback by ID.
  ///
  /// This should be called when a function is no longer needed to prevent
  /// memory leaks. If the ID doesn't exist, this is a no-op.
  ///
  /// Example:
  /// ```dart
  /// final registry = FunctionRegistry();
  /// final id = registry.register('myFunc', () => 42);
  /// // ... use the function ...
  /// registry.unregister(id);
  /// ```
  ///
  /// Args:
  ///   id: The callback ID to unregister
  void unregister(int id) {
    _callbacks.remove(id);
  }

  /// Retrieves a callback by ID.
  ///
  /// Returns null if the ID doesn't exist in the registry.
  ///
  /// Example:
  /// ```dart
  /// final registry = FunctionRegistry();
  /// final id = registry.register('myFunc', () => 42);
  /// final callback = registry.get(id);
  /// if (callback != null) {
  ///   final result = Function.apply(callback, []);
  ///   print(result); // 42
  /// }
  /// ```
  ///
  /// Args:
  ///   id: The callback ID to retrieve
  ///
  /// Returns:
  ///   The registered function, or null if not found
  Function? get(int id) {
    return _callbacks[id];
  }

  /// Retrieves a callback by name.
  ///
  /// Returns null if the name doesn't exist in the registry.
  ///
  /// This is used by evalAsync to look up functions by name when
  /// handling function call requests from Rust.
  ///
  /// Example:
  /// ```dart
  /// final registry = FunctionRegistry();
  /// registry.register('myFunc', () => 42);
  /// final callback = registry.getByName('myFunc');
  /// if (callback != null) {
  ///   final result = Function.apply(callback, []);
  ///   print(result); // 42
  /// }
  /// ```
  ///
  /// Args:
  ///   name: The function name to retrieve
  ///
  /// Returns:
  ///   The registered function, or null if not found
  Function? getByName(String name) {
    return _callbacksByName[name];
  }

  /// Returns the number of registered callbacks.
  ///
  /// Useful for debugging and testing.
  int get count => _callbacks.length;

  /// Clears all registered callbacks.
  ///
  /// This should only be used in testing or when shutting down.
  void clear() {
    _callbacks.clear();
    _callbacksByName.clear();
  }
}
