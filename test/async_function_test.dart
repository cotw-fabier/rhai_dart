/// Tests for async function registration and invocation
///
/// This test suite verifies attempts to support async Dart functions (returning Future<T>)
/// with the Rhai engine. Due to limitations in Dart's FFI callback system, these tests
/// are currently skipped.
///
/// TECHNICAL LIMITATION:
/// Dart's event loop cannot run while inside a synchronous FFI callback. This means
/// that Futures cannot complete within the callback context, making async functions
/// fundamentally incompatible with the current FFI architecture.
///
/// Possible solutions (for future implementation):
/// 1. Use a thread pool on the Rust side to wait for callbacks
/// 2. Implement a message-passing system between isolates
/// 3. Use ports for async communication
/// 4. Restructure the API to be async-first
///
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';
import 'dart:async';

void main() {
  group('Async Function Handling (Currently Limited)', () {
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

      // This will timeout because the Future cannot complete in FFI callback context
      expect(
        () => engine.eval('fetchData()'),
        throwsA(anything), // Will throw timeout or other error
      );
    }, skip: 'Async functions have limitations in FFI callback context - event loop cannot run');

    test('async function returning int', () {
      engine.registerFunction('asyncAdd', (int a, int b) async {
        await Future.delayed(Duration(milliseconds: 10));
        return a + b;
      });

      expect(
        () => engine.eval('asyncAdd(10, 20)'),
        throwsA(anything),
      );
    }, skip: 'Async functions have limitations in FFI callback context - event loop cannot run');

    test('async function with immediate completion', () {
      // Even immediately completing Futures may not work in FFI callbacks
      engine.registerFunction('asyncImmediate', () async {
        return 'immediate result';
      });

      expect(
        () => engine.eval('asyncImmediate()'),
        throwsA(anything),
      );
    }, skip: 'Async functions have limitations in FFI callback context - event loop cannot run');

    test('documentation of async limitation', () {
      // This test documents the async limitation for future reference
      // Async functions cannot work in the current architecture because:
      //
      // 1. Rhai calls Rust FFI function (synchronous)
      // 2. Rust calls Dart NativeCallable (synchronous)
      // 3. Dart callback must return immediately (cannot await)
      // 4. Event loop is blocked during synchronous callback
      // 5. Future.delayed and other async operations cannot complete
      //
      // This is a fundamental limitation of Dart's FFI system when
      // using synchronous callbacks.

      expect(true, isTrue); // This test always passes, it's just documentation
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
  });

  group('Future Implementation Considerations', () {
    test('document potential solutions', () {
      // For future implementation, here are potential solutions:
      //
      // SOLUTION 1: Rust Thread Pool
      // - Spawn Rust thread to wait for callback
      // - Thread calls Dart and blocks on response
      // - Allows Dart event loop to run on main thread
      // - Requires thread-safe callback mechanism
      //
      // SOLUTION 2: Isolate Ports
      // - Use SendPort/ReceivePort for async communication
      // - Rust sends request through port
      // - Dart processes async on main isolate
      // - Sends response back through port
      // - Rust waits for port response
      //
      // SOLUTION 3: Async-First API
      // - Make eval() itself async
      // - No synchronous callbacks from Rust
      // - Rust uses async runtime (tokio)
      // - Dart functions can be naturally async
      // - Requires rethinking the API design
      //
      // SOLUTION 4: Callback Queue
      // - Queue Dart function calls
      // - Process queue after eval() returns
      // - Return results through secondary call
      // - Complex but might work for certain use cases

      expect(true, isTrue); // Documentation test
    });
  });
}
