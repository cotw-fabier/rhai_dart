/// Native C types for FFI
///
/// This module defines Dart representations of C types used in the Rhai FFI.
/// All types must match the exact layout of their Rust counterparts.
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Opaque handle for a Rhai engine instance.
///
/// This corresponds to the CRhaiEngine struct in Rust.
/// The actual structure is opaque and only manipulated through FFI functions.
final class CRhaiEngine extends Opaque {}

/// Configuration for creating a Rhai engine.
///
/// This struct must match the exact layout of CRhaiConfig in Rust.
/// All fields use explicit sizes to ensure cross-platform compatibility.
final class CRhaiConfig extends Struct {
  /// Maximum number of operations before script execution is aborted (0 = unlimited)
  @Uint64()
  external int maxOperations;

  /// Maximum call stack depth (0 = unlimited)
  @Uint64()
  external int maxStackDepth;

  /// Maximum string length in bytes (0 = unlimited)
  @Uint64()
  external int maxStringLength;

  /// Script execution timeout in milliseconds (0 = no timeout)
  @Uint64()
  external int timeoutMs;

  /// Async callback timeout in seconds (0 = no timeout, default: 30)
  @Uint64()
  external int asyncTimeoutSeconds;

  /// Whether to disable file I/O operations (0 = false, 1 = true)
  @Uint8()
  external int disableFileIo;

  /// Whether to disable eval() function (0 = false, 1 = true)
  @Uint8()
  external int disableEval;

  /// Whether to disable module loading (0 = false, 1 = true)
  @Uint8()
  external int disableModules;
}

/// Represents a Rhai value for passing across the FFI boundary.
///
/// Uses JSON serialization for complex types to avoid FFI alignment issues.
final class CRhaiValue extends Struct {
  /// JSON-serialized value
  external Pointer<Utf8> jsonData;

  /// Type tag for the value
  /// 0 = null, 1 = bool, 2 = int, 3 = float, 4 = string, 5 = array, 6 = map
  @Uint8()
  external int typeTag;
}

/// Structured error information for detailed error reporting.
///
/// This provides more context than a simple error message string.
final class CRhaiError extends Struct {
  /// Error message
  external Pointer<Utf8> message;

  /// Error type: 0 = syntax, 1 = runtime, 2 = ffi
  @Uint8()
  external int errorType;

  /// Line number where error occurred (0 if not applicable)
  @Uint64()
  external int lineNumber;

  /// Stack trace (may be null)
  external Pointer<Utf8> stackTrace;
}
