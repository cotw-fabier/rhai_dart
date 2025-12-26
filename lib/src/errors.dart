/// Error handling for Rhai-Dart FFI
///
/// This module provides a sealed error class hierarchy for all Rhai-related errors.
///
/// ## Error Handling Examples
///
/// ```dart
/// final engine = RhaiEngine.withDefaults();
///
/// try {
///   final result = engine.eval('let x = 10; x + y'); // 'y' is undefined
/// } on RhaiSyntaxError catch (e) {
///   print('Syntax error at line ${e.lineNumber}: ${e.message}');
/// } on RhaiRuntimeError catch (e) {
///   print('Runtime error: ${e.message}');
///   if (e.stackTrace != null) {
///     print('Stack trace: ${e.stackTrace}');
///   }
/// } on RhaiFFIError catch (e) {
///   print('FFI error: ${e.message}');
/// } on RhaiException catch (e) {
///   // Catch-all for any Rhai error
///   print('Rhai error: ${e.message}');
/// }
/// ```
library;

/// Base exception class for all Rhai-related errors.
///
/// This is a sealed class, meaning all subclasses are defined in this file
/// and the type can be exhaustively pattern-matched.
///
/// ## Subclasses
///
/// - [RhaiSyntaxError]: Thrown when a script has syntax errors
/// - [RhaiRuntimeError]: Thrown when a script fails during execution
/// - [RhaiFFIError]: Thrown when an FFI operation fails
///
/// ## Example: Pattern Matching
///
/// ```dart
/// try {
///   engine.eval(script);
/// } on RhaiException catch (e) {
///   switch (e) {
///     case RhaiSyntaxError():
///       print('Fix syntax at line ${e.lineNumber}');
///     case RhaiRuntimeError():
///       print('Runtime error: ${e.message}');
///     case RhaiFFIError():
///       print('FFI error: ${e.message}');
///   }
/// }
/// ```
sealed class RhaiException implements Exception {
  /// The error message
  final String message;

  /// Creates a new RhaiException with the given message
  const RhaiException(this.message);

  @override
  String toString() => 'RhaiException: $message';
}

/// Exception thrown when a syntax error occurs during script parsing.
///
/// This typically includes the line number where the error occurred.
///
/// ## Common Causes
///
/// - Missing semicolons or commas
/// - Unmatched parentheses, brackets, or braces
/// - Invalid variable names or keywords
/// - Malformed expressions or statements
///
/// ## Example
///
/// ```dart
/// final engine = RhaiEngine.withDefaults();
///
/// try {
///   // Missing closing brace
///   engine.eval('if true { let x = 10;');
/// } on RhaiSyntaxError catch (e) {
///   print('Syntax error at line ${e.lineNumber}: ${e.message}');
///   // Output: Syntax error at line 1: Expected '}'
/// }
/// ```
final class RhaiSyntaxError extends RhaiException {
  /// The line number where the syntax error occurred (1-indexed)
  ///
  /// This can be null if the line number is not available or cannot be determined.
  final int? lineNumber;

  /// Creates a new RhaiSyntaxError
  ///
  /// [message] - The error message describing the syntax issue
  /// [lineNumber] - Optional line number where the error occurred (1-indexed)
  const RhaiSyntaxError(super.message, [this.lineNumber]);

  @override
  String toString() {
    if (lineNumber != null) {
      return 'RhaiSyntaxError at line $lineNumber: $message';
    }
    return 'RhaiSyntaxError: $message';
  }
}

/// Exception thrown when a runtime error occurs during script execution.
///
/// This includes errors like type mismatches, undefined variables, division by zero, etc.
///
/// ## Common Causes
///
/// - Accessing undefined variables
/// - Type mismatches in operations
/// - Division by zero
/// - Array index out of bounds
/// - Calling undefined functions
/// - Errors thrown from registered Dart functions
///
/// ## Examples
///
/// ```dart
/// final engine = RhaiEngine.withDefaults();
///
/// // Example 1: Undefined variable
/// try {
///   engine.eval('let x = 10; x + y');
/// } on RhaiRuntimeError catch (e) {
///   print('Runtime error: ${e.message}');
///   // Output: Runtime error: Variable 'y' not found
/// }
///
/// // Example 2: Type mismatch
/// try {
///   engine.eval('let x = "hello"; x + 42');
/// } on RhaiRuntimeError catch (e) {
///   print('Runtime error: ${e.message}');
///   // Output: Runtime error: Cannot add string and number
/// }
///
/// // Example 3: Function error propagation
/// engine.registerFunction('divide', (int a, int b) {
///   if (b == 0) throw Exception('Division by zero');
///   return a / b;
/// });
///
/// try {
///   engine.eval('divide(10, 0)');
/// } on RhaiRuntimeError catch (e) {
///   print('Runtime error: ${e.message}');
///   // Output: Runtime error: Exception: Division by zero
/// }
/// ```
final class RhaiRuntimeError extends RhaiException {
  /// The stack trace from the Rhai execution context (if available)
  ///
  /// This provides information about where the error occurred in the script
  /// and the call chain leading to the error.
  final String? stackTrace;

  /// Creates a new RhaiRuntimeError
  ///
  /// [message] - The error message describing the runtime issue
  /// [stackTrace] - Optional stack trace from Rhai execution context
  const RhaiRuntimeError(super.message, [this.stackTrace]);

  @override
  String toString() {
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      return 'RhaiRuntimeError: $message\nStack trace:\n$stackTrace';
    }
    return 'RhaiRuntimeError: $message';
  }
}

/// Exception thrown when an FFI operation fails.
///
/// This includes errors in the FFI boundary itself, such as null pointer errors,
/// memory allocation failures, or other low-level FFI issues.
///
/// ## Common Causes
///
/// - Engine already disposed
/// - Failed to create native engine
/// - FFI function returned an error code
/// - Memory allocation failures
/// - Invalid pointer operations
///
/// ## Examples
///
/// ```dart
/// final engine = RhaiEngine.withDefaults();
///
/// // Example 1: Using disposed engine
/// engine.dispose();
/// try {
///   engine.eval('1 + 1');
/// } catch (e) {
///   print('Error: $e');
///   // Output: Error: StateError: RhaiEngine has been disposed
/// }
///
/// // Example 2: Engine creation failure
/// try {
///   // This would fail if native library is not available
///   final engine = RhaiEngine.withDefaults();
/// } on RhaiFFIError catch (e) {
///   print('FFI error: ${e.message}');
///   // Output: FFI error: Failed to create Rhai engine with defaults
/// }
/// ```
final class RhaiFFIError extends RhaiException {
  /// Creates a new RhaiFFIError
  ///
  /// [message] - The error message describing the FFI issue
  const RhaiFFIError(super.message);

  @override
  String toString() => 'RhaiFFIError: $message';
}
