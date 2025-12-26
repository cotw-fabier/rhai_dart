/// Tests for Rhai script execution functionality
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  group('Script Execution Tests', () {
    late RhaiEngine engine;

    setUp(() {
      // Create a fresh engine with default config for each test
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      // Clean up after each test
      engine.dispose();
    });

    test('simple expression evaluation', () {
      // Test basic arithmetic
      final result = engine.eval('2 + 2');
      expect(result, equals(4));
    });

    test('script returning different types - int', () {
      final result = engine.eval('42');
      expect(result, equals(42));
      expect(result, isA<int>());
    });

    test('script returning different types - string', () {
      final result = engine.eval('"hello world"');
      expect(result, equals('hello world'));
      expect(result, isA<String>());
    });

    test('script returning different types - bool', () {
      final resultTrue = engine.eval('true');
      expect(resultTrue, equals(true));
      expect(resultTrue, isA<bool>());

      final resultFalse = engine.eval('false');
      expect(resultFalse, equals(false));
    });

    test('script returning different types - float', () {
      final result = engine.eval('3.14');
      expect(result, closeTo(3.14, 0.001));
      expect(result, isA<num>());
    });

    test('script with variables and logic', () {
      final script = '''
        let x = 10;
        let y = 20;
        if x < y {
          x + y
        } else {
          x - y
        }
      ''';
      final result = engine.eval(script);
      expect(result, equals(30));
    });

    test('syntax error handling with line numbers', () {
      // Test syntax error detection
      expect(
        () => engine.eval('let x = ;'), // Missing value
        throwsA(isA<RhaiSyntaxError>().having(
          (e) => e.lineNumber,
          'line number',
          isNotNull,
        )),
      );
    });

    test('runtime error handling', () {
      // Test division by zero or similar runtime error
      expect(
        () => engine.eval('let x = 1 / 0;'),
        throwsA(isA<RhaiRuntimeError>()),
      );
    });

    test('timeout enforcement', () {
      // Create engine with very low timeout
      final timeoutEngine = RhaiEngine.withConfig(
        RhaiConfig.custom(timeoutMs: 100),
      );

      try {
        // Test that infinite loop triggers timeout
        expect(
          () => timeoutEngine.eval('loop { }'),
          throwsA(isA<RhaiRuntimeError>().having(
            (e) => e.message,
            'message',
            contains('timeout'),
          )),
        );
      } finally {
        timeoutEngine.dispose();
      }
    });
  });
}
