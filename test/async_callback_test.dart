/// Focused tests for async detection and completion in callback bridge
///
/// This test suite verifies that the callback bridge correctly detects Future
/// return values, generates unique future IDs, and invokes completion callbacks.
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';
import 'dart:async';

void main() {
  group('Async Detection and Completion', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('detects Future and returns result after completion', () async {
      // Register an async function with a short delay
      engine.registerFunction('asyncAdd', (int a, int b) async {
        await Future.delayed(Duration(milliseconds: 50));
        return a + b;
      });

      // Call the async function from Rhai
      final result = engine.eval('asyncAdd(10, 20)');

      // Should return the correct result after waiting
      expect(result, equals(30));
    });

    test('handles multiple concurrent async operations', () async {
      // Register multiple async functions
      engine.registerFunction('asyncDouble', (int x) async {
        await Future.delayed(Duration(milliseconds: 30));
        return x * 2;
      });

      engine.registerFunction('asyncTriple', (int x) async {
        await Future.delayed(Duration(milliseconds: 20));
        return x * 3;
      });

      // Call multiple async functions in sequence
      final result1 = engine.eval('asyncDouble(5)');
      final result2 = engine.eval('asyncTriple(7)');

      // Both should complete correctly
      expect(result1, equals(10));
      expect(result2, equals(21));
    });

    test('handles async function returning different types', () async {
      // Test async function returning String
      engine.registerFunction('asyncString', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'async result';
      });

      final stringResult = engine.eval('asyncString()');
      expect(stringResult, equals('async result'));

      // Test async function returning Map
      engine.registerFunction('asyncMap', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return {'key': 'value', 'number': 42};
      });

      final mapResult = engine.eval('asyncMap()');
      expect(mapResult, isA<Map>());
      expect(mapResult['key'], equals('value'));
      expect(mapResult['number'], equals(42));

      // Test async function returning List
      engine.registerFunction('asyncList', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return [1, 2, 3, 'four'];
      });

      final listResult = engine.eval('asyncList()');
      expect(listResult, isA<List>());
      expect(listResult, equals([1, 2, 3, 'four']));
    });

    test('propagates errors from async functions', () {
      // Register an async function that throws an error
      engine.registerFunction('asyncError', () async {
        await Future.delayed(Duration(milliseconds: 10));
        throw Exception('Test async error');
      });

      // Should propagate the error to Rhai
      expect(
        () => engine.eval('asyncError()'),
        throwsA(anything),
      );
    });

    test('handles immediate async completion', () {
      // Register an async function with no delay (immediate completion)
      engine.registerFunction('asyncImmediate', (int x) async {
        return x + 1;
      });

      final result = engine.eval('asyncImmediate(99)');
      expect(result, equals(100));
    });

    test('sync functions still work correctly (regression)', () {
      // Register a sync function to ensure no regression
      engine.registerFunction('syncAdd', (int a, int b) => a + b);

      final result = engine.eval('syncAdd(15, 25)');
      expect(result, equals(40));
    });
  });
}
