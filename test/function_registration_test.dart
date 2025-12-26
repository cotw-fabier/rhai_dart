/// Tests for function registration and invocation
///
/// This test suite verifies that Dart functions can be registered with the Rhai engine
/// and called from scripts, with proper parameter passing, return value conversion,
/// and error propagation.
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  group('Function Registration', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('sync function registration and invocation', () {
      // Register a simple sync function
      engine.registerFunction('add', (int a, int b) => a + b);

      // Call it from a Rhai script
      final result = engine.eval('add(10, 20)');
      expect(result, equals(30));
    });

    test('function with multiple parameter types', () {
      // Register a function that takes different types
      engine.registerFunction('processData', (String name, int age, bool active) {
        return '$name is $age years old and ${active ? "active" : "inactive"}';
      });

      final result = engine.eval('processData("Alice", 30, true)');
      expect(result, equals('Alice is 30 years old and active'));
    });

    test('function error propagation to Rhai', () {
      // Register a function that throws an error
      engine.registerFunction('failingFunc', () {
        throw Exception('Something went wrong in Dart');
      });

      // The error should propagate to Rhai
      expect(
        () => engine.eval('failingFunc()'),
        throwsA(isA<RhaiRuntimeError>()),
      );
    });

    test('function return value conversion - primitives', () {
      // Test different return types
      engine.registerFunction('getInt', () => 42);
      engine.registerFunction('getDouble', () => 3.14);
      engine.registerFunction('getBool', () => true);
      engine.registerFunction('getString', () => 'hello');
      engine.registerFunction('getNull', () => null);

      expect(engine.eval('getInt()'), equals(42));
      expect(engine.eval('getDouble()'), closeTo(3.14, 0.01));
      expect(engine.eval('getBool()'), equals(true));
      expect(engine.eval('getString()'), equals('hello'));
      expect(engine.eval('getNull()'), isNull);
    });

    test('function return value conversion - collections', () {
      // Test list return
      engine.registerFunction('getList', () => [1, 2, 3]);
      final list = engine.eval('getList()');
      expect(list, isA<List>());
      expect(list, equals([1, 2, 3]));

      // Test map return
      engine.registerFunction('getMap', () => {'name': 'Alice', 'age': 30});
      final map = engine.eval('getMap()');
      expect(map, isA<Map>());
      expect(map['name'], equals('Alice'));
      expect(map['age'], equals(30));
    });

    test('function with list and map parameters', () {
      // Register a function that processes a list
      engine.registerFunction('sumList', (List<dynamic> numbers) {
        return numbers.fold<int>(0, (sum, n) => sum + (n as int));
      });

      final result = engine.eval('sumList([1, 2, 3, 4, 5])');
      expect(result, equals(15));

      // Register a function that processes a map
      engine.registerFunction('getField', (Map<String, dynamic> obj, String field) {
        return obj[field];
      });

      final result2 = engine.eval('getField(#{name: "Bob", age: 25}, "name")');
      expect(result2, equals('Bob'));
    });

    test('multiple functions registered', () {
      // Register several functions
      engine.registerFunction('double', (int x) => x * 2);
      engine.registerFunction('triple', (int x) => x * 3);
      engine.registerFunction('square', (int x) => x * x);

      // Use them all in one script
      final result = engine.eval('''
        let a = double(5);
        let b = triple(5);
        let c = square(5);
        a + b + c
      ''');

      expect(result, equals(10 + 15 + 25)); // 50
    });

    // ===== Task 6.2: Sync eval() Edge Case Tests =====

    test('sync function with varying arities (0 to 5 parameters)', () {
      // Test functions with different numbers of parameters
      engine.registerFunction('noParams', () => 'no params');
      engine.registerFunction('oneParam', (int a) => a + 1);
      engine.registerFunction('twoParams', (int a, int b) => a + b);
      engine.registerFunction('threeParams', (int a, int b, int c) => a + b + c);
      engine.registerFunction('fourParams', (int a, int b, int c, int d) => a + b + c + d);
      engine.registerFunction('fiveParams', (int a, int b, int c, int d, int e) => a + b + c + d + e);

      expect(engine.eval('noParams()'), equals('no params'));
      expect(engine.eval('oneParam(5)'), equals(6));
      expect(engine.eval('twoParams(1, 2)'), equals(3));
      expect(engine.eval('threeParams(1, 2, 3)'), equals(6));
      expect(engine.eval('fourParams(1, 2, 3, 4)'), equals(10));
      expect(engine.eval('fiveParams(1, 2, 3, 4, 5)'), equals(15));
    });

    test('sync function with deeply nested complex return types', () {
      // Test deeply nested structures
      engine.registerFunction('complexNested', () {
        return {
          'level1': {
            'level2': {
              'level3': {
                'data': [1, 2, 3],
                'info': {'name': 'nested', 'active': true}
              }
            }
          },
          'siblings': [
            {'id': 1, 'values': [10, 20]},
            {'id': 2, 'values': [30, 40]}
          ]
        };
      });

      final result = engine.eval('complexNested()') as Map;
      expect(result['level1']['level2']['level3']['data'], equals([1, 2, 3]));
      expect(result['level1']['level2']['level3']['info']['name'], equals('nested'));
      expect(result['siblings'][0]['id'], equals(1));
      expect(result['siblings'][1]['values'], equals([30, 40]));
    });

    test('sync function error handling with different error types', () {
      // Test different error scenarios
      engine.registerFunction('throwException', () {
        throw Exception('Exception error');
      });

      engine.registerFunction('throwFormatException', () {
        throw FormatException('Format error');
      });

      engine.registerFunction('throwArgumentError', () {
        throw ArgumentError('Argument error');
      });

      expect(() => engine.eval('throwException()'), throwsA(isA<RhaiRuntimeError>()));
      expect(() => engine.eval('throwFormatException()'), throwsA(isA<RhaiRuntimeError>()));
      expect(() => engine.eval('throwArgumentError()'), throwsA(isA<RhaiRuntimeError>()));
    });

    test('multiple sync functions called in sequence within one script', () {
      // Register multiple functions that interact
      engine.registerFunction('increment', (int x) => x + 1);
      engine.registerFunction('multiply', (int x, int y) => x * y);
      engine.registerFunction('format', (String prefix, int value) => '$prefix: $value');

      final result = engine.eval('''
        let a = increment(5);      // a = 6
        let b = increment(a);      // b = 7
        let c = multiply(a, b);    // c = 42
        let d = increment(c);      // d = 43
        format("Result", d)
      ''');

      expect(result, equals('Result: 43'));
    });

    test('sync function with edge case values (null, empty collections, large numbers)', () {
      // Test edge case parameters and returns
      engine.registerFunction('handleNull', (dynamic value) {
        return value == null ? 'was null' : 'not null';
      });

      engine.registerFunction('handleEmptyList', (List<dynamic> list) {
        return list.isEmpty ? 'empty' : 'not empty';
      });

      engine.registerFunction('handleEmptyMap', (Map<String, dynamic> map) {
        return map.isEmpty ? 'empty' : 'not empty';
      });

      engine.registerFunction('handleLargeNumber', (int value) {
        return value > 1000000;
      });

      expect(engine.eval('handleNull(())'), equals('was null'));
      expect(engine.eval('handleEmptyList([])'), equals('empty'));
      expect(engine.eval('handleEmptyList([1, 2])'), equals('not empty'));
      expect(engine.eval('handleEmptyMap(#{})'), equals('empty'));
      expect(engine.eval('handleLargeNumber(9999999)'), equals(true));
      expect(engine.eval('handleLargeNumber(100)'), equals(false));
    });
  });
}
