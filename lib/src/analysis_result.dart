/// Analysis result for Rhai script validation
///
/// This module provides the AnalysisResult class which contains the results
/// of analyzing a Rhai script without executing it.
///
/// ## Example Usage
///
/// ```dart
/// final engine = RhaiEngine.withDefaults();
///
/// // Analyze a valid script
/// final result1 = engine.analyze('let x = 10; x + 20');
/// if (result1.isValid) {
///   print('Script is valid!');
///   // Execute the script
///   final output = engine.eval('let x = 10; x + 20');
/// }
///
/// // Analyze an invalid script
/// final result2 = engine.analyze('let x = ;');
/// if (!result2.isValid) {
///   print('Syntax errors found:');
///   for (final error in result2.syntaxErrors) {
///     print('  - $error');
///   }
/// }
/// ```
library;

/// Result of analyzing a Rhai script.
///
/// This class contains information about the validity of a script,
/// including any syntax errors or warnings detected during analysis.
///
/// Analysis is performed without executing the script, making it safe
/// for validating untrusted input or providing editor feedback.
///
/// ## Use Cases
///
/// - **Validation**: Check if user input is valid before execution
/// - **Editor Support**: Provide real-time syntax checking
/// - **Pre-execution Checks**: Verify scripts before deployment
/// - **Security**: Detect syntax issues without running potentially harmful code
///
/// ## Example: Interactive Editor
///
/// ```dart
/// void validateUserInput(String script) {
///   final engine = RhaiEngine.withDefaults();
///   final result = engine.analyze(script);
///
///   if (result.isValid) {
///     print('✓ Script is valid');
///   } else {
///     print('✗ Found ${result.syntaxErrors.length} syntax errors:');
///     for (final error in result.syntaxErrors) {
///       print('  $error');
///     }
///   }
/// }
/// ```
class AnalysisResult {
  /// Whether the script is syntactically valid
  ///
  /// When true, the script can be executed without syntax errors.
  /// Note: This does not guarantee the script will run without runtime errors.
  final bool isValid;

  /// List of syntax errors found in the script
  ///
  /// Empty if [isValid] is true.
  /// Each error typically includes the line number and a description of the issue.
  ///
  /// Example: `["Syntax error at line 3: Expected '}', found EOF"]`
  final List<String> syntaxErrors;

  /// List of warnings (currently unused, reserved for future use)
  ///
  /// This field is reserved for future enhancements such as:
  /// - Unused variable warnings
  /// - Deprecated function warnings
  /// - Performance warnings
  final List<String> warnings;

  /// Optional summary of the AST structure (currently unused)
  ///
  /// This field is reserved for future enhancements such as:
  /// - Function declarations
  /// - Variable declarations
  /// - Import statements
  final String? astSummary;

  /// Creates a new AnalysisResult.
  ///
  /// [isValid] - Whether the script is syntactically valid
  /// [syntaxErrors] - List of syntax errors found
  /// [warnings] - List of warnings (optional, currently unused)
  /// [astSummary] - Optional AST summary (currently unused)
  const AnalysisResult({
    required this.isValid,
    required this.syntaxErrors,
    this.warnings = const [],
    this.astSummary,
  });

  /// Creates an AnalysisResult from a JSON map.
  ///
  /// This is used to parse the JSON response from the Rust FFI layer.
  ///
  /// Example JSON:
  /// ```json
  /// {
  ///   "is_valid": false,
  ///   "syntax_errors": ["Syntax error at line 1: Expected '}'"],
  ///   "warnings": [],
  ///   "ast_summary": null
  /// }
  /// ```
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      isValid: json['is_valid'] as bool,
      syntaxErrors: (json['syntax_errors'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      astSummary: json['ast_summary'] as String?,
    );
  }

  /// Converts this AnalysisResult to a JSON map.
  ///
  /// Useful for serialization or logging.
  Map<String, dynamic> toJson() {
    return {
      'is_valid': isValid,
      'syntax_errors': syntaxErrors,
      'warnings': warnings,
      'ast_summary': astSummary,
    };
  }

  @override
  String toString() {
    if (isValid) {
      return 'AnalysisResult(valid: true)';
    } else {
      return 'AnalysisResult(valid: false, errors: ${syntaxErrors.length})';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnalysisResult &&
        other.isValid == isValid &&
        _listEquals(other.syntaxErrors, syntaxErrors) &&
        _listEquals(other.warnings, warnings) &&
        other.astSummary == astSummary;
  }

  @override
  int get hashCode {
    return Object.hash(
      isValid,
      Object.hashAll(syntaxErrors),
      Object.hashAll(warnings),
      astSummary,
    );
  }

  /// Helper to compare lists
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
