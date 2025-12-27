import 'package:rhai_dart/rhai_dart.dart';
import 'package:test/test.dart';

void main() {
  group('setVar', () {
    test('sets a string variable', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('name', 'Alice');
      final result = engine.eval('name');
      expect(result, equals('Alice'));
      engine.dispose();
    });

    test('sets an integer variable', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('age', 30);
      final result = engine.eval('age + 5');
      expect(result, equals(35));
      engine.dispose();
    });

    test('sets a double variable', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('pi', 3.14159);
      final result = engine.eval('pi * 2.0');
      expect(result, closeTo(6.28318, 0.0001));
      engine.dispose();
    });

    test('sets a boolean variable', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('active', true);
      final result = engine.eval('if active { "yes" } else { "no" }');
      expect(result, equals('yes'));
      engine.dispose();
    });

    test('sets a list variable', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('items', [1, 2, 3]);
      final result = engine.eval('items.len()');
      expect(result, equals(3));
      engine.dispose();
    });

    test('sets a map variable', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('config', {'debug': true, 'level': 5});
      final result = engine.eval('config.level');
      expect(result, equals(5));
      engine.dispose();
    });

    test('variable can be modified by script', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('count', 10);
      engine.eval('count = 20');
      final result = engine.eval('count');
      expect(result, equals(20));
      engine.dispose();
    });
  });

  group('setConstant', () {
    test('sets a string constant', () {
      final engine = RhaiEngine.withDefaults();
      engine.setConstant('APP_NAME', 'MyApp');
      final result = engine.eval('APP_NAME');
      expect(result, equals('MyApp'));
      engine.dispose();
    });

    test('sets a numeric constant', () {
      final engine = RhaiEngine.withDefaults();
      engine.setConstant('MAX_VALUE', 100);
      final result = engine.eval('MAX_VALUE * 2');
      expect(result, equals(200));
      engine.dispose();
    });

    test('constant cannot be modified by script', () {
      final engine = RhaiEngine.withDefaults();
      engine.setConstant('PI', 3.14);
      expect(
        () => engine.eval('PI = 3'),
        throwsA(isA<RhaiRuntimeError>()),
      );
      engine.dispose();
    });
  });

  group('clearScope', () {
    test('removes all variables', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('x', 10);
      engine.setConstant('y', 20);

      // Variables should exist
      expect(engine.eval('x + y'), equals(30));

      // Clear scope
      engine.clearScope();

      // Variables should no longer exist
      expect(
        () => engine.eval('x'),
        throwsA(isA<RhaiRuntimeError>()),
      );
      engine.dispose();
    });
  });

  group('integration', () {
    test('works with eval()', () {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('multiplier', 2);
      engine.setConstant('BASE', 100);
      final result = engine.eval('BASE * multiplier');
      expect(result, equals(200));
      engine.dispose();
    });

    test('works with evalAsync()', () async {
      final engine = RhaiEngine.withDefaults();
      engine.setVar('data', {'value': 42});
      final result = await engine.evalAsync('data.value');
      expect(result, equals(42));
      engine.dispose();
    });

    test('throws on disposed engine', () {
      final engine = RhaiEngine.withDefaults();
      engine.dispose();
      expect(
        () => engine.setVar('x', 10),
        throwsStateError,
      );
    });
  });
}
