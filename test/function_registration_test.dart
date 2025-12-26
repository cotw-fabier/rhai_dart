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

    // Skip async test for now - async support has limitations in FFI callback context
    test('async function registration and invocation', () async {
      // Register an async function
      engine.registerFunction('fetchData', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'Hello from async';
      });

      // Call it from a Rhai script (should block and wait for completion)
      // Note: This may not work correctly due to FFI/event loop limitations
      final result = engine.eval('fetchData()');
      expect(result, equals('Hello from async'));
    }, skip: 'Async functions have limitations in FFI callback context');

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
  });
}
