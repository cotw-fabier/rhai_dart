/// Tests for async function registration and invocation
///
/// This test suite verifies full async Dart function support (returning Future<T>)
/// with the Rhai engine. The implementation uses a Tokio-based async runtime that
/// allows Dart's event loop to run during FFI callbacks, enabling HTTP requests,
/// file I/O, and other async operations.
///
/// TECHNICAL IMPLEMENTATION:
/// - Rust side uses Tokio runtime with oneshot channels for async coordination
/// - Dart detects Future return values and returns "pending" status immediately
/// - When Future completes, Dart calls rhai_complete_future FFI to wake Rust
/// - Rust awaits oneshot receiver with configurable timeout
/// - Full async support with timeout management and resource cleanup
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';
import 'dart:async';

void main() {
  group('Async Function Support', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('async function with delay (simulated HTTP call)', () {
      // Register an async function that simulates a network request
      engine.registerFunction('fetchData', () async {
        await Future.delayed(Duration(milliseconds: 50));
        return 'data from server';
      });

      // This should now work with the Tokio-based async implementation
      final result = engine.eval('fetchData()');
      expect(result, equals('data from server'));
    });

    test('async function returning int', () {
      engine.registerFunction('asyncAdd', (int a, int b) async {
        await Future.delayed(Duration(milliseconds: 10));
        return a + b;
      });

      final result = engine.eval('asyncAdd(10, 20)');
      expect(result, equals(30));
    });

    test('async function with immediate completion', () {
      // Even immediately completing Futures should work
      engine.registerFunction('asyncImmediate', () async {
        return 'immediate result';
      });

      final result = engine.eval('asyncImmediate()');
      expect(result, equals('immediate result'));
    });

    test('async function returning String', () {
      engine.registerFunction('asyncGreeting', (String name) async {
        await Future.delayed(Duration(milliseconds: 20));
        return 'Hello, $name!';
      });

      final result = engine.eval('asyncGreeting("World")');
      expect(result, equals('Hello, World!'));
    });

    test('async function returning Map', () {
      engine.registerFunction('asyncGetUser', () async {
        await Future.delayed(Duration(milliseconds: 15));
        return {
          'id': 123,
          'name': 'Alice',
          'email': 'alice@example.com',
          'active': true,
        };
      });

      final result = engine.eval('asyncGetUser()');
      expect(result, isA<Map>());
      expect(result['id'], equals(123));
      expect(result['name'], equals('Alice'));
      expect(result['email'], equals('alice@example.com'));
      expect(result['active'], equals(true));
    });

    test('async function returning List', () {
      engine.registerFunction('asyncGetItems', () async {
        await Future.delayed(Duration(milliseconds: 15));
        return [1, 2, 3, 4, 5];
      });

      final result = engine.eval('asyncGetItems()');
      expect(result, isA<List>());
      expect(result, equals([1, 2, 3, 4, 5]));
    });

    test('async function returning nested data structure', () {
      engine.registerFunction('asyncGetComplexData', () async {
        await Future.delayed(Duration(milliseconds: 20));
        return {
          'users': [
            {'id': 1, 'name': 'Alice'},
            {'id': 2, 'name': 'Bob'},
          ],
          'count': 2,
          'metadata': {
            'version': '1.0',
            'timestamp': 1234567890,
          },
        };
      });

      final result = engine.eval('asyncGetComplexData()');
      expect(result, isA<Map>());
      expect(result['count'], equals(2));
      expect(result['users'], isA<List>());
      expect(result['users'].length, equals(2));
      expect(result['metadata']['version'], equals('1.0'));
    });

    test('async function error propagation', () {
      // Register async function that throws an error
      engine.registerFunction('asyncFailure', () async {
        await Future.delayed(Duration(milliseconds: 10));
        throw Exception('Test async error');
      });

      // Error should propagate to Rhai
      expect(
        () => engine.eval('asyncFailure()'),
        throwsA(predicate((e) =>
          e.toString().contains('Test async error') ||
          e.toString().contains('Exception')
        )),
      );
    });

    test('async function immediate error', () {
      // Register async function that throws immediately
      engine.registerFunction('asyncImmediateError', () async {
        throw StateError('Immediate failure');
      });

      expect(
        () => engine.eval('asyncImmediateError()'),
        throwsA(predicate((e) =>
          e.toString().contains('Immediate failure') ||
          e.toString().contains('StateError')
        )),
      );
    });

    test('async function timeout', () {
      // Register async function with very long delay
      engine.registerFunction('asyncLongDelay', () async {
        await Future.delayed(Duration(seconds: 60));
        return 'should not complete';
      });

      // Configure engine with short timeout
      final shortTimeoutEngine = RhaiEngine.withConfig(
        RhaiConfig.custom(asyncTimeout: Duration(seconds: 1)),
      );

      try {
        shortTimeoutEngine.registerFunction('asyncLongDelay', () async {
          await Future.delayed(Duration(seconds: 60));
          return 'should not complete';
        });

        // Should timeout
        expect(
          () => shortTimeoutEngine.eval('asyncLongDelay()'),
          throwsA(predicate((e) =>
            e.toString().toLowerCase().contains('timeout') ||
            e.toString().toLowerCase().contains('timed out')
          )),
        );
      } finally {
        shortTimeoutEngine.dispose();
      }
    });

    test('concurrent async operations', () {
      // Register multiple async functions with different delays
      engine.registerFunction('async1', () async {
        await Future.delayed(Duration(milliseconds: 30));
        return 'result1';
      });

      engine.registerFunction('async2', () async {
        await Future.delayed(Duration(milliseconds: 20));
        return 'result2';
      });

      engine.registerFunction('async3', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'result3';
      });

      // Call multiple async functions in sequence from Rhai
      // Each should complete correctly without interference
      final script = '''
        let r1 = async1();
        let r2 = async2();
        let r3 = async3();
        r1 + "," + r2 + "," + r3
      ''';

      final result = engine.eval(script);
      expect(result, equals('result1,result2,result3'));
    });

    test('mixed sync and async functions', () {
      // Register both sync and async functions
      engine.registerFunction('syncAdd', (int a, int b) => a + b);

      engine.registerFunction('asyncMultiply', (int a, int b) async {
        await Future.delayed(Duration(milliseconds: 10));
        return a * b;
      });

      final script = '''
        let sum = syncAdd(5, 3);
        let product = asyncMultiply(4, 6);
        sum + product
      ''';

      final result = engine.eval(script);
      expect(result, equals(32)); // 8 + 24
    });
  });

  group('Sync Function Regression Tests', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('sync functions work correctly', () {
      // Verify that sync functions still work fine
      engine.registerFunction('syncAdd', (int a, int b) => a + b);

      final result = engine.eval('syncAdd(10, 20)');
      expect(result, equals(30));
    });

    test('sync function returning complex types', () {
      // Verify complex types work with sync functions
      engine.registerFunction('getSyncData', () {
        return {
          'name': 'Test',
          'value': 42,
          'items': [1, 2, 3],
        };
      });

      final result = engine.eval('getSyncData()');
      expect(result, isA<Map>());
      expect(result['name'], equals('Test'));
      expect(result['value'], equals(42));
      expect(result['items'], equals([1, 2, 3]));
    });

    test('sync function with multiple parameters', () {
      engine.registerFunction('syncConcat', (String a, String b, String c) {
        return '$a-$b-$c';
      });

      final result = engine.eval('syncConcat("hello", "world", "test")');
      expect(result, equals('hello-world-test'));
    });

    test('sync function with no parameters', () {
      engine.registerFunction('getConstant', () => 42);

      final result = engine.eval('getConstant()');
      expect(result, equals(42));
    });
  });

  group('Async Function Edge Cases', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('async function with null return', () {
      engine.registerFunction('asyncNull', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return null;
      });

      final result = engine.eval('asyncNull()');
      expect(result, isNull);
    });

    test('async function with boolean return', () {
      engine.registerFunction('asyncBool', (bool input) async {
        await Future.delayed(Duration(milliseconds: 10));
        return !input;
      });

      final result = engine.eval('asyncBool(true)');
      expect(result, equals(false));
    });

    test('async function with double return', () {
      engine.registerFunction('asyncDouble', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 3.14159;
      });

      final result = engine.eval('asyncDouble()');
      expect(result, equals(3.14159));
    });

    test('multiple calls to same async function', () {
      int callCount = 0;

      engine.registerFunction('asyncCounter', () async {
        await Future.delayed(Duration(milliseconds: 10));
        callCount++;
        return callCount;
      });

      final result1 = engine.eval('asyncCounter()');
      expect(result1, equals(1));

      final result2 = engine.eval('asyncCounter()');
      expect(result2, equals(2));

      final result3 = engine.eval('asyncCounter()');
      expect(result3, equals(3));
    });
  });

  group('Real Async I/O Integration', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('async function with real Future.delayed timing', () {
      final stopwatch = Stopwatch()..start();

      engine.registerFunction('delayedValue', () async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'completed';
      });

      final result = engine.eval('delayedValue()');
      stopwatch.stop();

      expect(result, equals('completed'));
      // Verify it actually waited (at least 100ms, but allow some overhead)
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(90));
    });

    test('async function with microtask', () {
      engine.registerFunction('microTask', () async {
        // Complete immediately but still async
        await Future.microtask(() {});
        return 'microtask completed';
      });

      final result = engine.eval('microTask()');
      expect(result, equals('microtask completed'));
    });

    test('async function with Future.value', () {
      engine.registerFunction('futureValue', () async {
        final value = await Future.value(42);
        return value * 2;
      });

      final result = engine.eval('futureValue()');
      expect(result, equals(84));
    });

    test('async function with Completer', () {
      engine.registerFunction('completerBased', () async {
        final completer = Completer<String>();

        // Complete after a delay
        Future.delayed(Duration(milliseconds: 20), () {
          completer.complete('completer result');
        });

        return await completer.future;
      });

      final result = engine.eval('completerBased()');
      expect(result, equals('completer result'));
    });

    test('async function with stream', () {
      engine.registerFunction('streamBased', () async {
        final stream = Stream.periodic(
          Duration(milliseconds: 10),
          (count) => count,
        ).take(5);

        final values = await stream.toList();
        return values.length;
      });

      final result = engine.eval('streamBased()');
      expect(result, equals(5));
    });

    test('chained async operations', () {
      engine.registerFunction('fetchUserId', () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 123;
      });

      engine.registerFunction('fetchUserData', (int userId) async {
        await Future.delayed(Duration(milliseconds: 10));
        return {
          'id': userId,
          'name': 'User$userId',
        };
      });

      final script = '''
        let userId = fetchUserId();
        let userData = fetchUserData(userId);
        userData
      ''';

      final result = engine.eval(script);
      expect(result, isA<Map>());
      expect(result['id'], equals(123));
      expect(result['name'], equals('User123'));
    });
  });

  group('Documentation Tests', () {
    test('document async implementation architecture', () {
      // This test documents the async implementation for reference:
      //
      // ARCHITECTURE:
      // 1. Dart callback detects Future return value
      // 2. Dart generates unique future ID and returns "pending" status
      // 3. Rust creates oneshot channel and stores sender in PENDING_FUTURES registry
      // 4. Rust awaits on oneshot receiver with configured timeout
      // 5. Dart's Future completes and calls rhai_complete_future FFI
      // 6. Rust receives completion, removes from registry, returns value to Rhai
      //
      // KEY COMPONENTS:
      // - Tokio runtime on Rust side for async coordination
      // - PENDING_FUTURES global registry (HashMap<i64, oneshot::Sender>)
      // - Future ID generation and completion callbacks on Dart side
      // - Timeout management with configurable duration
      // - Resource cleanup on timeout, error, and engine disposal
      //
      // This enables true async support with event loop running properly.

      expect(true, isTrue); // Documentation test
    });
  });
}
