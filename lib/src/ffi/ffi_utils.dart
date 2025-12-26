/// FFI utility functions
///
/// This module provides helper functions for working with FFI, particularly
/// error handling and native string management.
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rhai_dart/src/ffi/bindings.dart';
import 'package:rhai_dart/src/errors.dart';

/// Checks if an FFI error occurred and throws an appropriate exception.
///
/// This function should be called after FFI operations that may fail.
/// It retrieves the last error from thread-local storage and throws
/// a RhaiException if an error is present.
///
/// [bindings] - The FFI bindings instance to use for error retrieval
///
/// Throws [RhaiFFIError] if an error occurred in the FFI layer
void checkFFIError(RhaiBindings bindings) {
  final errorPtr = bindings.getLastError();

  if (errorPtr == nullptr) {
    return; // No error
  }

  try {
    final errorStr = errorPtr.cast<Utf8>().toDartString();

    // Parse error type from message if possible
    // Error messages from Rust will be in format "Error: message"
    // or "Panic in FFI call: message" for panics

    if (errorStr.contains('Panic in FFI call')) {
      throw RhaiFFIError(errorStr);
    } else if (errorStr.contains('syntax error') ||
        errorStr.contains('Syntax error')) {
      // Try to extract line number if present
      final lineMatch = RegExp(r'line (\d+)').firstMatch(errorStr);
      final lineNumber = lineMatch != null ? int.parse(lineMatch.group(1)!) : null;
      throw RhaiSyntaxError(errorStr, lineNumber);
    } else if (errorStr.contains('runtime error') ||
        errorStr.contains('Runtime error')) {
      throw RhaiRuntimeError(errorStr);
    } else {
      // Default to FFI error for unknown error types
      throw RhaiFFIError(errorStr);
    }
  } finally {
    // Always free the error string
    bindings.freeError(errorPtr);
  }
}

/// Frees a native string allocated by Rust.
///
/// This is a wrapper around the FFI free function for clarity.
///
/// [bindings] - The FFI bindings instance
/// [ptr] - Pointer to the native string to free
void freeNativeString(RhaiBindings bindings, Pointer<Utf8> ptr) {
  if (ptr != nullptr) {
    bindings.freeError(ptr.cast());
  }
}
