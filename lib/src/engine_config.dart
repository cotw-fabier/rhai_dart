/// Engine configuration for Rhai script execution
///
/// This module provides configuration options for creating and configuring
/// Rhai engines with security and performance controls.
///
/// ## Example: Secure Defaults
/// ```dart
/// final config = RhaiConfig.secureDefaults();
/// final engine = RhaiEngine.withConfig(config);
/// ```
///
/// ## Example: Custom Configuration
/// ```dart
/// final config = RhaiConfig.custom(
///   maxOperations: 500000,
///   timeoutMs: 3000,
///   disableFileIo: true,
/// );
/// final engine = RhaiEngine.withConfig(config);
/// ```
///
/// ## Security Implications
///
/// Each configuration setting has security implications:
///
/// - **maxOperations**: Prevents infinite loops and resource exhaustion
/// - **maxStackDepth**: Prevents stack overflow from deep recursion
/// - **maxStringLength**: Prevents excessive memory usage from large strings
/// - **timeoutMs**: Prevents scripts from running indefinitely
/// - **disableFileIo**: Prevents file system access (recommended for untrusted scripts)
/// - **disableEval**: Prevents dynamic code execution (recommended for untrusted scripts)
/// - **disableModules**: Prevents loading external code (recommended for untrusted scripts)
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:rhai_dart/src/ffi/native_types.dart';

/// Configuration for a Rhai engine.
///
/// This class provides a type-safe Dart API for configuring Rhai engines
/// with security sandboxing and resource limits.
///
/// Use [RhaiConfig.secureDefaults] for a secure default configuration,
/// or [RhaiConfig.custom] to create a custom configuration.
///
/// ## Common Use Cases
///
/// ### Untrusted User Scripts
/// ```dart
/// // Use secure defaults to sandbox untrusted scripts
/// final config = RhaiConfig.secureDefaults();
/// ```
///
/// ### Trusted Internal Scripts
/// ```dart
/// // Increase limits for trusted scripts
/// final config = RhaiConfig.custom(
///   maxOperations: 10000000,
///   timeoutMs: 30000,
/// );
/// ```
///
/// ### Development/Testing
/// ```dart
/// // Disable all limits for testing (not recommended for production)
/// final config = RhaiConfig.unlimited();
/// ```
class RhaiConfig {
  /// Maximum number of operations before script execution is aborted.
  ///
  /// Set to 0 for unlimited operations (not recommended for untrusted scripts).
  /// Default: 1,000,000
  ///
  /// This limit prevents infinite loops and ensures scripts complete in reasonable time.
  final int maxOperations;

  /// Maximum call stack depth.
  ///
  /// Set to 0 for unlimited depth (not recommended for untrusted scripts).
  /// Default: 100
  ///
  /// This limit prevents stack overflow from excessive recursion.
  final int maxStackDepth;

  /// Maximum string length in bytes.
  ///
  /// Set to 0 for unlimited length (not recommended for untrusted scripts).
  /// Default: 10,485,760 (10 MB)
  ///
  /// This limit prevents excessive memory usage from large string allocations.
  final int maxStringLength;

  /// Script execution timeout in milliseconds.
  ///
  /// Set to 0 for no timeout (not recommended for untrusted scripts).
  /// Default: 5,000 (5 seconds)
  ///
  /// This timeout ensures scripts complete within a reasonable time frame.
  final int timeoutMs;

  /// Whether to disable file I/O operations.
  ///
  /// When true, scripts cannot access the file system.
  /// Default: true (recommended for security)
  ///
  /// **Security Impact**: Enabling file I/O allows scripts to read, write,
  /// and delete files on the system. Only enable for trusted scripts.
  final bool disableFileIo;

  /// Whether to disable the eval() function.
  ///
  /// When true, scripts cannot use eval() to execute dynamic code.
  /// Default: true (recommended for security)
  ///
  /// **Security Impact**: Enabling eval() allows scripts to execute arbitrary
  /// code strings, bypassing static analysis. Only enable for trusted scripts.
  final bool disableEval;

  /// Whether to disable module loading.
  ///
  /// When true, scripts cannot load external modules.
  /// Default: true (recommended for security)
  ///
  /// **Security Impact**: Enabling modules allows scripts to import external
  /// code, potentially from untrusted sources. Only enable for trusted scripts.
  final bool disableModules;

  /// Creates a new RhaiConfig with custom settings.
  ///
  /// All parameters are optional and will use secure defaults if not specified.
  ///
  /// Example:
  /// ```dart
  /// final config = RhaiConfig.custom(
  ///   maxOperations: 500000,
  ///   timeoutMs: 3000,
  /// );
  /// ```
  ///
  /// Throws [ArgumentError] if any value is negative.
  RhaiConfig.custom({
    int? maxOperations,
    int? maxStackDepth,
    int? maxStringLength,
    int? timeoutMs,
    bool? disableFileIo,
    bool? disableEval,
    bool? disableModules,
  })  : maxOperations = maxOperations ?? 1000000,
        maxStackDepth = maxStackDepth ?? 100,
        maxStringLength = maxStringLength ?? 10485760,
        timeoutMs = timeoutMs ?? 5000,
        disableFileIo = disableFileIo ?? true,
        disableEval = disableEval ?? true,
        disableModules = disableModules ?? true {
    _validateConfig();
  }

  /// Creates a RhaiConfig with secure defaults.
  ///
  /// This configuration is recommended for running untrusted scripts:
  /// - maxOperations: 1,000,000
  /// - maxStackDepth: 100
  /// - maxStringLength: 10 MB
  /// - timeoutMs: 5,000 ms (5 seconds)
  /// - All sandboxing features enabled (file I/O, eval, modules disabled)
  ///
  /// Example:
  /// ```dart
  /// final config = RhaiConfig.secureDefaults();
  /// final engine = RhaiEngine.withConfig(config);
  /// ```
  factory RhaiConfig.secureDefaults() {
    return RhaiConfig.custom();
  }

  /// Creates a RhaiConfig with no limits (dangerous for untrusted scripts).
  ///
  /// This configuration disables all limits and sandboxing.
  /// Use only for trusted scripts in controlled environments.
  ///
  /// **WARNING**: This configuration is not recommended for production use
  /// with untrusted scripts as it allows unlimited resource usage.
  ///
  /// Example:
  /// ```dart
  /// // Only for trusted scripts in development
  /// final config = RhaiConfig.unlimited();
  /// final engine = RhaiEngine.withConfig(config);
  /// ```
  factory RhaiConfig.unlimited() {
    return RhaiConfig.custom(
      maxOperations: 0,
      maxStackDepth: 0,
      maxStringLength: 0,
      timeoutMs: 0,
      disableFileIo: false,
      disableEval: false,
      disableModules: false,
    );
  }

  /// Validates the configuration values.
  ///
  /// Throws [ArgumentError] if any configuration value is invalid.
  void _validateConfig() {
    if (maxOperations < 0) {
      throw ArgumentError.value(
        maxOperations,
        'maxOperations',
        'Must be non-negative (0 for unlimited)',
      );
    }

    if (maxStackDepth < 0) {
      throw ArgumentError.value(
        maxStackDepth,
        'maxStackDepth',
        'Must be non-negative (0 for unlimited)',
      );
    }

    if (maxStringLength < 0) {
      throw ArgumentError.value(
        maxStringLength,
        'maxStringLength',
        'Must be non-negative (0 for unlimited)',
      );
    }

    if (timeoutMs < 0) {
      throw ArgumentError.value(
        timeoutMs,
        'timeoutMs',
        'Must be non-negative (0 for no timeout)',
      );
    }

    // Warn about potentially dangerous configurations in debug mode
    assert(() {
      if (maxOperations == 0) {
        print('WARNING: maxOperations is 0 (unlimited). '
            'This may allow infinite loops in untrusted scripts.');
      }
      if (maxStackDepth == 0) {
        print('WARNING: maxStackDepth is 0 (unlimited). '
            'This may allow stack overflow in untrusted scripts.');
      }
      if (timeoutMs == 0) {
        print('WARNING: timeoutMs is 0 (no timeout). '
            'This may allow scripts to run indefinitely.');
      }
      if (!disableFileIo) {
        print('WARNING: File I/O is enabled. '
            'This allows scripts to access the file system.');
      }
      if (!disableEval) {
        print('WARNING: eval() is enabled. '
            'This allows scripts to execute dynamic code.');
      }
      if (!disableModules) {
        print('WARNING: Module loading is enabled. '
            'This allows scripts to load external code.');
      }
      return true;
    }());
  }

  /// Converts this config to a native CRhaiConfig for FFI transfer.
  ///
  /// The returned pointer must be freed by the caller after use.
  /// This is an internal method used by the FFI layer.
  Pointer<CRhaiConfig> toNative() {
    final config = calloc<CRhaiConfig>();
    config.ref.maxOperations = maxOperations;
    config.ref.maxStackDepth = maxStackDepth;
    config.ref.maxStringLength = maxStringLength;
    config.ref.timeoutMs = timeoutMs;
    config.ref.disableFileIo = disableFileIo ? 1 : 0;
    config.ref.disableEval = disableEval ? 1 : 0;
    config.ref.disableModules = disableModules ? 1 : 0;
    return config;
  }

  @override
  String toString() {
    return 'RhaiConfig(\n'
        '  maxOperations: $maxOperations,\n'
        '  maxStackDepth: $maxStackDepth,\n'
        '  maxStringLength: $maxStringLength,\n'
        '  timeoutMs: $timeoutMs,\n'
        '  disableFileIo: $disableFileIo,\n'
        '  disableEval: $disableEval,\n'
        '  disableModules: $disableModules\n'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RhaiConfig &&
        other.maxOperations == maxOperations &&
        other.maxStackDepth == maxStackDepth &&
        other.maxStringLength == maxStringLength &&
        other.timeoutMs == timeoutMs &&
        other.disableFileIo == disableFileIo &&
        other.disableEval == disableEval &&
        other.disableModules == disableModules;
  }

  @override
  int get hashCode {
    return Object.hash(
      maxOperations,
      maxStackDepth,
      maxStringLength,
      timeoutMs,
      disableFileIo,
      disableEval,
      disableModules,
    );
  }
}
