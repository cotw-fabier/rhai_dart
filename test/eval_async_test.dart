import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';
import 'dart:async';

void main() {
  group('evalAsync Tests', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('evalAsync with sync functions works', () async {
      engine.registerFunction('syncFunc', () => 42);

      final result = await engine.evalAsync('syncFunc()');
      expect(result, equals(42));
    });

    test('evalAsync with simple arithmetic', () async {
      final result = await engine.evalAsync('2 + 2');
      expect(result, equals(4));
    });

    test('evalAsync with async functions', () async {
      engine.registerFunction('asyncFetch', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data';
      });

      final result = await engine.evalAsync('asyncFetch()');
      expect(result, equals('data'));
    });

    test('sync eval rejects async functions with helpful error', () {
      engine.registerFunction('asyncFetch', () async => 'data');

      expect(
        () => engine.eval('asyncFetch()'),
        throwsA(predicate((e) =>
            e.toString().contains('evalAsync') ||
            e.toString().contains('async function'))),
      );
    });

    test('evalAsync with async function returning map', () async {
      engine.registerFunction('asyncData', () async {
        await Future.delayed(const Duration(milliseconds: 30));
        return {'status': 'success', 'value': 123};
      });

      final result = await engine.evalAsync('asyncData()');
      expect(result, isA<Map>());
      expect((result as Map)['status'], equals('success'));
      expect(result['value'], equals(123));
    });

    test('evalAsync error propagation', () async {
      engine.registerFunction('asyncError', () async {
        await Future.delayed(const Duration(milliseconds: 20));
        throw Exception('Test error');
      });

      expect(
        () => engine.evalAsync('asyncError()'),
        throwsA(isA<RhaiRuntimeError>()),
      );
    });

    test('concurrent evalAsync calls', () async {
      engine.registerFunction('delay', (int ms) async {
        await Future.delayed(Duration(milliseconds: ms));
        return ms;
      });

      final futures = [
        engine.evalAsync('delay(10)'),
        engine.evalAsync('delay(20)'),
        engine.evalAsync('delay(15)'),
      ];

      final results = await Future.wait(futures);
      expect(results, equals([10, 20, 15]));
    });

    // ===== Task 6.3: evalAsync() Comprehensive Tests =====

    test('async function with delayed resolution (various delays)', () async {
      // Test different delay durations
      engine.registerFunction('delayedValue', (int ms, String value) async {
        await Future.delayed(Duration(milliseconds: ms));
        return value;
      });

      final result1 = await engine.evalAsync('delayedValue(10, "fast")');
      expect(result1, equals('fast'));

      final result2 = await engine.evalAsync('delayedValue(100, "slow")');
      expect(result2, equals('slow'));

      final result3 = await engine.evalAsync('delayedValue(50, "medium")');
      expect(result3, equals('medium'));
    });

    test('async function with immediate resolution (Future.value)', () async {
      // Test async function that completes immediately
      engine.registerFunction('immediateAsync', (int value) async {
        return Future.value(value * 2);
      });

      final result = await engine.evalAsync('immediateAsync(21)');
      expect(result, equals(42));
    });

    test('async function with error after delay', () async {
      // Test error handling with delayed errors
      engine.registerFunction('delayedError', (int ms, String message) async {
        await Future.delayed(Duration(milliseconds: ms));
        throw Exception(message);
      });

      expect(
        () => engine.evalAsync('delayedError(30, "Delayed failure")'),
        throwsA(isA<RhaiRuntimeError>()),
      );
    });

    test('async function with different Future types (Completer, delayed, value)', () async {
      // Test Future.delayed
      engine.registerFunction('futureDelayed', () async {
        await Future.delayed(const Duration(milliseconds: 20));
        return 'delayed';
      });

      // Test Future.value
      engine.registerFunction('futureValue', () async {
        return Future.value('immediate');
      });

      // Test Completer
      engine.registerFunction('futureCompleter', () async {
        final completer = Completer<String>();
        Future.delayed(const Duration(milliseconds: 10), () {
          completer.complete('completer');
        });
        return completer.future;
      });

      final result1 = await engine.evalAsync('futureDelayed()');
      expect(result1, equals('delayed'));

      final result2 = await engine.evalAsync('futureValue()');
      expect(result2, equals('immediate'));

      final result3 = await engine.evalAsync('futureCompleter()');
      expect(result3, equals('completer'));
    });

    test('async functions called multiple times in same script', () async {
      // Test multiple async function calls within one script
      engine.registerFunction('asyncAdd', (int a, int b) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return a + b;
      });

      engine.registerFunction('asyncMultiply', (int a, int b) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return a * b;
      });

      final result = await engine.evalAsync('''
        let sum = asyncAdd(10, 20);     // 30
        let product = asyncMultiply(5, 6); // 30
        sum + product                   // 60
      ''');

      expect(result, equals(60));
    });

    test('mixing sync and async functions in same evalAsync script', () async {
      // Test that both sync and async functions work together
      engine.registerFunction('syncDouble', (int x) => x * 2);

      engine.registerFunction('asyncSquare', (int x) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return x * x;
      });

      final result = await engine.evalAsync('''
        let doubled = syncDouble(5);    // 10
        let squared = asyncSquare(4);   // 16
        doubled + squared               // 26
      ''');

      expect(result, equals(26));
    });
  });
}
