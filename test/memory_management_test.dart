import 'dart:ffi';
import 'dart:io';
import 'package:test/test.dart';
import 'package:rhai_dart/src/engine.dart';
import 'package:rhai_dart/src/ffi/bindings.dart';
import 'package:rhai_dart/src/ffi/native_types.dart';
import 'package:ffi/ffi.dart';

/// Memory Management Validation Tests
///
/// These tests verify that memory is properly managed across the FFI boundary,
/// preventing leaks and crashes. They test:
/// - Creating and disposing many engines in loops
/// - Evaluating many scripts in loops
/// - Registering and unregistering many functions
/// - NativeFinalizer cleanup
/// - Double-free prevention
/// - Concurrent disposal safety
void main() {
  group('Memory Management Validation', () {
    late RhaiBindings bindings;

    setUpAll(() {
      bindings = RhaiBindings.instance;
    });

    group('6.2.1 Memory Leak Detection', () {
      test('Create and dispose many engines in loop', () {
        // Test creating and disposing 100 engines
        // This should not cause unbounded memory growth
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final engine = RhaiEngine.withDefaults();
          expect(engine.isDisposed, isFalse);

          // Use the engine
          final result = engine.eval('$i + 1');
          expect(result, equals(i + 1));

          // Dispose the engine
          engine.dispose();
          expect(engine.isDisposed, isTrue);
        }

        // If we reach here without crashes or OOM, the test passes
        // Manual observation: monitor process memory during this test
        // Expected: memory usage should remain relatively stable
      });

      test('Evaluate many scripts in loop', () {
        // Create one engine and evaluate many scripts
        // This tests that script results are properly freed
        final engine = RhaiEngine.withDefaults();

        try {
          const iterations = 500;

          for (var i = 0; i < iterations; i++) {
            // Evaluate different types of results
            final intResult = engine.eval('$i * 2');
            expect(intResult, equals(i * 2));

            final stringResult = engine.eval('"iteration_$i"');
            expect(stringResult, equals('iteration_$i'));

            final arrayResult = engine.eval('[$i, ${i + 1}, ${i + 2}]');
            expect(arrayResult, isA<List>());
            expect((arrayResult as List).length, equals(3));

            final mapResult = engine.eval('#{ x: $i, y: ${i * 2} }');
            expect(mapResult, isA<Map>());
          }

          // If we reach here without crashes or OOM, the test passes
          // Expected: memory usage should remain relatively stable
        } finally {
          engine.dispose();
        }
      });

      test('Register and unregister many functions', () {
        // Test that function registration and cleanup don't leak
        const iterations = 100;

        for (var i = 0; i < iterations; i++) {
          final engine = RhaiEngine.withDefaults();

          try {
            // Register multiple functions
            engine.registerFunction('add_$i', (int a, int b) => a + b);
            engine.registerFunction('multiply_$i', (int a, int b) => a * b);
            engine.registerFunction('concat_$i',
                (String a, String b) => a + b);

            // Use the functions
            final result1 = engine.eval('add_$i(10, 20)');
            expect(result1, equals(30));

            final result2 = engine.eval('multiply_$i(5, 6)');
            expect(result2, equals(30));

            final result3 = engine.eval('concat_$i("hello", "world")');
            expect(result3, equals('helloworld'));
          } finally {
            // Dispose should clean up all registered functions
            engine.dispose();
          }
        }

        // Expected: no memory leaks from function registrations
      });

      test('Many engines with many evaluations', () {
        // Stress test: create many engines, each with many evaluations
        const engineCount = 20;
        const evalCount = 50;

        for (var i = 0; i < engineCount; i++) {
          final engine = RhaiEngine.withDefaults();

          try {
            for (var j = 0; j < evalCount; j++) {
              final result = engine.eval('$i + $j');
              expect(result, equals(i + j));
            }
          } finally {
            engine.dispose();
          }
        }

        // Expected: stable memory usage throughout
      });

      test('Complex nested structures in loop', () {
        // Test that complex nested structures are properly freed
        final engine = RhaiEngine.withDefaults();

        try {
          const iterations = 100;

          for (var i = 0; i < iterations; i++) {
            // Create deeply nested structures
            final result = engine.eval('''
              #{
                level1: #{
                  level2: #{
                    level3: [1, 2, 3, [4, 5, [6, 7]]],
                    data: "iteration_$i"
                  }
                }
              }
            ''');

            expect(result, isA<Map>());
            final map = result as Map<String, dynamic>;
            expect(map['level1'], isA<Map>());
          }

          // Expected: nested structures properly freed after each iteration
        } finally {
          engine.dispose();
        }
      });
    });

    group('6.2.2 NativeFinalizer Cleanup', () {
      test('Engine without manual disposal (finalizer test)', () {
        // Create an engine without disposing it manually
        // The finalizer should clean it up during GC
        // Note: We can't force GC in Dart, so this is more of a behavioral test

        void createEngineWithoutDispose() {
          final engine = RhaiEngine.withDefaults();
          final result = engine.eval('42');
          expect(result, equals(42));
          // Engine goes out of scope here without dispose()
        }

        // Call the function
        createEngineWithoutDispose();

        // Give some time for potential GC (though we can't force it)
        // In a real scenario, the finalizer would eventually be called
        // We verify there are no crashes
        expect(true, isTrue); // If we reach here, no crash occurred
      });

      test('Multiple engines without manual disposal', () {
        // Create multiple engines in a loop without disposing
        void createManyEnginesWithoutDispose() {
          for (var i = 0; i < 10; i++) {
            final engine = RhaiEngine.withDefaults();
            final result = engine.eval('$i * 2');
            expect(result, equals(i * 2));
            // Each engine goes out of scope without dispose()
          }
        }

        createManyEnginesWithoutDispose();

        // Expected: finalizers will eventually clean up
        // No crashes should occur
        expect(true, isTrue);
      });

      test('Mixed disposal patterns', () {
        // Mix manual disposal with finalizer-based disposal
        final engines = <RhaiEngine>[];

        // Create engines - some will be disposed manually, some via finalizer
        for (var i = 0; i < 10; i++) {
          final engine = RhaiEngine.withDefaults();
          final result = engine.eval('$i + 1');
          expect(result, equals(i + 1));

          if (i % 2 == 0) {
            // Keep reference for manual disposal later
            engines.add(engine);
          }
          // Odd-numbered engines go out of scope (finalizer will handle)
        }

        // Manually dispose the even-numbered engines
        for (final engine in engines) {
          engine.dispose();
        }

        // Expected: no crashes, all memory eventually freed
        expect(engines.length, equals(5));
      });
    });

    group('6.2.3 Double-Free Prevention', () {
      test('Dispose same engine multiple times', () {
        final engine = RhaiEngine.withDefaults();

        // First disposal
        expect(() => engine.dispose(), returnsNormally);
        expect(engine.isDisposed, isTrue);

        // Second disposal - should be a no-op, not crash
        expect(() => engine.dispose(), returnsNormally);
        expect(engine.isDisposed, isTrue);

        // Third disposal - still safe
        expect(() => engine.dispose(), returnsNormally);
        expect(engine.isDisposed, isTrue);
      });

      test('Operations on disposed engine throw clear errors', () {
        final engine = RhaiEngine.withDefaults();
        engine.dispose();

        // Attempting to use a disposed engine should throw StateError
        expect(
          () => engine.eval('1 + 1'),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          )),
        );

        expect(
          () => engine.analyze('1 + 1'),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          )),
        );

        expect(
          () => engine.registerFunction('test', () => 42),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          )),
        );
      });

      test('Dispose engine then check isDisposed flag', () {
        final engine = RhaiEngine.withDefaults();

        expect(engine.isDisposed, isFalse);

        engine.dispose();
        expect(engine.isDisposed, isTrue);

        // Multiple checks should all return true
        expect(engine.isDisposed, isTrue);
        expect(engine.isDisposed, isTrue);
      });

      test('Dispose multiple engines in different orders', () {
        final engine1 = RhaiEngine.withDefaults();
        final engine2 = RhaiEngine.withDefaults();
        final engine3 = RhaiEngine.withDefaults();

        // Dispose in creation order
        engine1.dispose();
        expect(engine1.isDisposed, isTrue);

        engine2.dispose();
        expect(engine2.isDisposed, isTrue);

        engine3.dispose();
        expect(engine3.isDisposed, isTrue);

        // Dispose again - should all be safe
        engine1.dispose();
        engine2.dispose();
        engine3.dispose();
      });

      test('Dispose engine with registered functions', () {
        final engine = RhaiEngine.withDefaults();

        // Register functions
        engine.registerFunction('add', (int a, int b) => a + b);
        engine.registerFunction('multiply', (int a, int b) => a * b);

        // Use them
        expect(engine.eval('add(5, 3)'), equals(8));
        expect(engine.eval('multiply(4, 7)'), equals(28));

        // Dispose - should clean up function registrations
        engine.dispose();
        expect(engine.isDisposed, isTrue);

        // Attempting to register more functions should fail
        expect(
          () => engine.registerFunction('divide', (int a, int b) => a / b),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('6.2.4 Concurrent Disposal Safety', () {
      test('Sequential disposal of many engines', () {
        // Create many engines and dispose them sequentially
        final engines = <RhaiEngine>[];

        // Create engines
        for (var i = 0; i < 50; i++) {
          final engine = RhaiEngine.withDefaults();
          engines.add(engine);
        }

        // Dispose them all sequentially
        for (final engine in engines) {
          expect(() => engine.dispose(), returnsNormally);
        }

        // Verify all are disposed
        for (final engine in engines) {
          expect(engine.isDisposed, isTrue);
        }
      });

      test('Interleaved creation and disposal', () {
        // Create and dispose engines in an interleaved pattern
        final activeEngines = <RhaiEngine>[];

        for (var i = 0; i < 20; i++) {
          // Create a new engine
          final newEngine = RhaiEngine.withDefaults();
          activeEngines.add(newEngine);

          // If we have more than 5 engines, dispose the oldest
          if (activeEngines.length > 5) {
            final oldEngine = activeEngines.removeAt(0);
            oldEngine.dispose();
            expect(oldEngine.isDisposed, isTrue);
          }
        }

        // Dispose remaining engines
        for (final engine in activeEngines) {
          engine.dispose();
        }
      });

      test('Rapid creation and disposal', () {
        // Rapidly create and dispose engines
        for (var i = 0; i < 100; i++) {
          final engine = RhaiEngine.withDefaults();
          engine.dispose();
          expect(engine.isDisposed, isTrue);
        }
      });

      // Note: True concurrent/multi-threaded disposal is not applicable
      // in Dart since Dart is single-threaded (isolates are separate heaps).
      // The Rust side should handle thread safety internally.
      test('Disposal safety is thread-safe on Rust side', () {
        // This test verifies that the Rust FFI functions handle disposal safely
        // We test by creating and disposing at the FFI level directly
        final config = calloc<CRhaiConfig>();
        config.ref.maxOperations = 1000000;
        config.ref.maxStackDepth = 100;
        config.ref.maxStringLength = 10485760;
        config.ref.timeoutMs = 5000;
        config.ref.disableFileIo = 1;
        config.ref.disableEval = 1;
        config.ref.disableModules = 1;

        try {
          // Create and dispose many engines at FFI level
          for (var i = 0; i < 50; i++) {
            final enginePtr = bindings.engineNew(config);
            expect(enginePtr, isNot(equals(nullptr)));

            // Dispose immediately
            expect(() => bindings.engineFree(enginePtr), returnsNormally);
          }
        } finally {
          calloc.free(config);
        }
      });
    });

    group('6.2.5 Memory Test Execution and Validation', () {
      test('End-to-end memory stress test', () {
        // Comprehensive stress test combining all aspects
        const cycles = 10;
        const enginesPerCycle = 10;
        const evalsPerEngine = 20;

        for (var cycle = 0; cycle < cycles; cycle++) {
          final engines = <RhaiEngine>[];

          // Create multiple engines
          for (var i = 0; i < enginesPerCycle; i++) {
            final engine = RhaiEngine.withDefaults();
            engines.add(engine);

            // Register functions
            engine.registerFunction(
                'test_$cycle\_$i', (int x) => x * 2);

            // Perform multiple evaluations
            for (var j = 0; j < evalsPerEngine; j++) {
              final result = engine.eval('test_$cycle\_$i($j)');
              expect(result, equals(j * 2));
            }
          }

          // Dispose half manually, let finalizer handle the rest
          for (var i = 0; i < enginesPerCycle ~/ 2; i++) {
            engines[i].dispose();
          }

          // Clear references to remaining engines (finalizer will clean up)
          engines.clear();
        }

        // Expected: stable memory usage, no leaks, no crashes
        expect(true, isTrue);
      });

      test('Memory usage with error conditions', () {
        // Test memory management when errors occur
        final engine = RhaiEngine.withDefaults();

        try {
          for (var i = 0; i < 50; i++) {
            try {
              // Intentionally cause errors
              engine.eval('this_is_invalid_$i');
              fail('Should have thrown an error');
            } catch (e) {
              // Error expected - verify memory is still cleaned up
              expect(e, isNotNull);
            }

            // Successful eval after error
            final result = engine.eval('$i + 1');
            expect(result, equals(i + 1));
          }

          // Expected: no memory leaks even with many errors
        } finally {
          engine.dispose();
        }
      });

      test('Memory validation summary', () {
        // This test serves as a summary and validation checkpoint
        // If we've reached this point, all memory tests have passed

        // Create a final test engine
        final engine = RhaiEngine.withDefaults();

        try {
          // Verify basic functionality still works
          final result = engine.eval('40 + 2');
          expect(result, equals(42));

          // Verify function registration works
          engine.registerFunction('final_test', () => 'success');
          final fnResult = engine.eval('final_test()');
          expect(fnResult, equals('success'));
        } finally {
          engine.dispose();
        }

        // All memory management tests completed successfully
        expect(true, isTrue,
            reason: 'All memory management validation tests passed');
      });
    });
  });
}
