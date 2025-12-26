/// NativeFinalizer setup for automatic resource cleanup
///
/// This module provides finalizers that automatically clean up native resources
/// when Dart objects are garbage collected. This follows the embedanythingindart
/// pattern for safe memory management across the FFI boundary.
library;

import 'dart:ffi';
import 'package:rhai_dart/src/ffi/bindings.dart';
import 'package:rhai_dart/src/ffi/native_types.dart';

/// Finalizer for Rhai engine instances
///
/// This finalizer automatically calls rhai_engine_free when a RhaiEngine
/// Dart object is garbage collected, preventing memory leaks.
final NativeFinalizer engineFinalizer = NativeFinalizer(
  RhaiBindings.instance.addresses.engineFree.cast(),
);

/// Finalizer for Rhai value instances
///
/// This finalizer automatically calls rhai_value_free when a RhaiValue
/// Dart object is garbage collected, preventing memory leaks.
///
/// Note: This finalizer will be fully functional once rhai_value_free
/// is implemented in the Rust side (in later task groups).
final NativeFinalizer valueFinalizer = NativeFinalizer(
  RhaiBindings.instance.addresses.valueFree.cast(),
);

/// Helper function to attach engine finalizer to a Dart object
///
/// This should be called when creating a Dart wrapper around a native engine pointer.
///
/// Example:
/// ```dart
/// class RhaiEngine implements Finalizable {
///   final Pointer<CRhaiEngine> _engine;
///
///   RhaiEngine(this._engine) {
///     attachEngineFinalizer(this, _engine);
///   }
/// }
/// ```
void attachEngineFinalizer(Finalizable object, Pointer<CRhaiEngine> engine) {
  if (engine != nullptr) {
    engineFinalizer.attach(object, engine.cast(), detach: object);
  }
}

/// Helper function to attach value finalizer to a Dart object
///
/// This should be called when creating a Dart wrapper around a native value pointer.
///
/// Example:
/// ```dart
/// class RhaiValue implements Finalizable {
///   final Pointer<CRhaiValue> _value;
///
///   RhaiValue(this._value) {
///     attachValueFinalizer(this, _value);
///   }
/// }
/// ```
void attachValueFinalizer(Finalizable object, Pointer<CRhaiValue> value) {
  if (value != nullptr) {
    valueFinalizer.attach(object, value.cast(), detach: object);
  }
}

/// Helper function to manually detach engine finalizer
///
/// This should be called when manually disposing a resource to prevent
/// double-free issues.
void detachEngineFinalizer(Finalizable object) {
  engineFinalizer.detach(object);
}

/// Helper function to manually detach value finalizer
///
/// This should be called when manually disposing a resource to prevent
/// double-free issues.
void detachValueFinalizer(Finalizable object) {
  valueFinalizer.detach(object);
}
