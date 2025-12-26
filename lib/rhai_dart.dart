/// Rhai-Dart FFI Integration Library
///
/// A cross-platform FFI library that enables Dart applications to execute
/// Rhai scripts with bidirectional function calling, comprehensive type
/// conversion, and robust error handling.
///
/// ## Usage
///
/// Create an engine and execute scripts:
/// ```dart
/// import 'package:rhai_dart/rhai_dart.dart';
///
/// void main() {
///   // Create engine with secure defaults
///   final engine = RhaiEngine.withDefaults();
///
///   // Execute a script
///   final result = engine.eval('40 + 2');
///   print(result); // 42
///
///   // Analyze a script without executing it
///   final analysis = engine.analyze('let x = 10; x + 20');
///   print(analysis.isValid); // true
///
///   // Clean up
///   engine.dispose();
/// }
/// ```
///
/// Custom configuration:
/// ```dart
/// final config = RhaiConfig.custom(
///   maxOperations: 500000,
///   timeoutMs: 3000,
/// );
/// final engine = RhaiEngine.withConfig(config);
/// ```
library;

// Core engine API
export 'src/engine.dart';
export 'src/engine_config.dart';
export 'src/analysis_result.dart';

// Error handling
export 'src/errors.dart';

// Legacy exports (will be removed or updated in future tasks)
export 'src/rhai_dart_base.dart';
