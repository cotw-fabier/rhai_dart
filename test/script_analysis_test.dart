/// Tests for script analysis functionality (analyze_rhai)
///
/// This test suite covers the script analysis feature which validates
/// Rhai scripts without executing them.
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  group('Script Analysis Tests', () {
    late RhaiEngine engine;

    setUp(() {
      // Create engine with defaults for each test
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      // Clean up after each test
      engine.dispose();
    });

    test('Test valid script analysis', () {
      // Valid script should be analyzed successfully
      final result = engine.analyze('let x = 10; x + 20');

      expect(result.isValid, isTrue);
      expect(result.syntaxErrors, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('Test invalid script analysis with syntax errors', () {
      // Script with syntax error
      final result = engine.analyze('let x = ;');

      expect(result.isValid, isFalse);
      expect(result.syntaxErrors, isNotEmpty);
      expect(result.syntaxErrors.first, contains('Syntax error'));
    });

    test('Test analysis result structure', () {
      // Test that the analysis result has the expected structure
      final validResult = engine.analyze('42');
      expect(validResult.isValid, isTrue);
      expect(validResult.syntaxErrors, isA<List<String>>());
      expect(validResult.warnings, isA<List<String>>());
      expect(validResult.astSummary, anyOf(isNull, isA<String>()));

      final invalidResult = engine.analyze('invalid {{{');
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.syntaxErrors, isNotEmpty);
    });

    test('Test multiple syntax errors detection', () {
      // Script with multiple potential issues
      final result = engine.analyze('''
        let x = ;
        let y =
        z = undefined
      ''');

      expect(result.isValid, isFalse);
      expect(result.syntaxErrors, isNotEmpty);
      // Should detect at least one syntax error
      expect(result.syntaxErrors.length, greaterThan(0));
    });

    test('Test analysis does not execute script', () {
      // This script would timeout if executed, but analysis should be fast
      final stopwatch = Stopwatch()..start();
      final result = engine.analyze('loop { let x = 1; }');
      stopwatch.stop();

      // Analysis should be quick (well under 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));

      // The script is syntactically valid
      expect(result.isValid, isTrue);
    });

    test('Test analysis on complex valid script', () {
      final script = '''
        fn calculate(a, b) {
          if a > b {
            return a + b;
          } else {
            return a - b;
          }
        }

        let result = calculate(10, 5);
        result
      ''';

      final result = engine.analyze(script);

      expect(result.isValid, isTrue);
      expect(result.syntaxErrors, isEmpty);
    });
  });
}
