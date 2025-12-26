/// Integration tests for Rhai-Dart FFI library
///
/// This test suite focuses on end-to-end workflows and critical integration scenarios
/// that aren't fully covered by unit tests. These tests verify that all components
/// work together correctly across the FFI boundary.
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  group('Integration Tests - Critical Workflows', () {
    test('Complete workflow: create → register → eval → dispose', () {
      // Test the full lifecycle in one flow
      final engine = RhaiEngine.withDefaults();

      try {
        // Register multiple functions
        engine.registerFunction('add', (int a, int b) => a + b);
        engine.registerFunction('multiply', (int a, int b) => a * b);
        engine.registerFunction('greet', (String name) => 'Hello, $name!');

        // Execute a script that uses all registered functions
        final result = engine.eval('''
          let sum = add(10, 20);
          let product = multiply(sum, 2);
          let greeting = greet("Integration Test");
          #{
            sum: sum,
            product: product,
            greeting: greeting
          }
        ''');

        expect(result, isA<Map>());
        expect(result['sum'], equals(30));
        expect(result['product'], equals(60));
        expect(result['greeting'], equals('Hello, Integration Test!'));
      } finally {
        // Verify disposal works after complex operations
        engine.dispose();
      }
    });

    test('Error propagation through all layers: script → function → error', () {
      final engine = RhaiEngine.withDefaults();

      try {
        // Register a function that throws under certain conditions
        engine.registerFunction('divide', (int a, int b) {
          if (b == 0) {
            throw ArgumentError('Cannot divide by zero');
          }
          return a / b;
        });

        // Test normal execution
        final normalResult = engine.eval('divide(10, 2)');
        expect(normalResult, equals(5.0));

        // Test error propagation from Dart function to Rhai
        expect(
          () => engine.eval('divide(10, 0)'),
          throwsA(isA<RhaiRuntimeError>().having(
            (e) => e.message,
            'error message',
            contains('Cannot divide by zero'),
          )),
        );

        // Test error in script itself
        expect(
          () => engine.eval('let x = divide(10, 2) + ;'), // Syntax error
          throwsA(isA<RhaiSyntaxError>()),
        );

        // Test runtime error in script logic
        expect(
          () => engine.eval('let x = undefined_function()'),
          throwsA(isA<RhaiRuntimeError>()),
        );
      } finally {
        engine.dispose();
      }
    });

    test('Memory stress: create and dispose many engines rapidly', () {
      // This test verifies memory management under stress
      const engineCount = 50;
      final engines = <RhaiEngine>[];

      // Create many engines
      for (var i = 0; i < engineCount; i++) {
        final engine = RhaiEngine.withDefaults();
        engines.add(engine);

        // Execute a simple script on each to verify it works
        final result = engine.eval('$i * 2');
        expect(result, equals(i * 2));
      }

      // Dispose all engines
      for (final engine in engines) {
        engine.dispose();
      }

      // Create new engines after cleanup to verify no resource leaks
      for (var i = 0; i < 10; i++) {
        final engine = RhaiEngine.withDefaults();
        final result = engine.eval('42');
        expect(result, equals(42));
        engine.dispose();
      }
    });

    test('Registered function calling another registered function', () {
      final engine = RhaiEngine.withDefaults();

      try {
        // Register base functions
        engine.registerFunction('square', (int x) => x * x);
        engine.registerFunction('double', (int x) => x * 2);

        // Register a function that conceptually uses other functions
        // (Note: Dart functions can't directly call Rhai, but they can share logic)
        engine.registerFunction('processNumber', (int x) {
          // This simulates complex processing
          final doubled = x * 2; // double logic
          final squared = doubled * doubled; // square logic
          return squared;
        });

        // Test that the script can orchestrate function calls
        final result = engine.eval('''
          let x = 5;
          let doubled = double(x);
          let squared = square(doubled);
          let processed = processNumber(x);
          #{
            doubled: doubled,
            squared: squared,
            processed: processed
          }
        ''');

        expect(result['doubled'], equals(10));
        expect(result['squared'], equals(100));
        expect(result['processed'], equals(100)); // processNumber should match
      } finally {
        engine.dispose();
      }
    });

    test('Multiple sequential evaluations with state isolation', () {
      final engine = RhaiEngine.withDefaults();

      try {
        // First evaluation
        final result1 = engine.eval('''
          let x = 42;
          x
        ''');
        expect(result1, equals(42));

        // Second evaluation - x should not exist from previous eval
        // Rhai should throw an error for undefined variable
        expect(
          () => engine.eval('x'), // x was defined in previous eval
          throwsA(isA<RhaiRuntimeError>()), // Should fail - no persistent state
        );

        // Third evaluation - define and use a variable
        final result3 = engine.eval('''
          let y = 100;
          y * 2
        ''');
        expect(result3, equals(200));

        // Fourth evaluation - y should also not exist
        expect(
          () => engine.eval('y'),
          throwsA(isA<RhaiRuntimeError>()),
        );
      } finally {
        engine.dispose();
      }
    });

    test('Complex nested structures through multiple layers', () {
      final engine = RhaiEngine.withDefaults();

      try {
        // Register a function that processes complex nested data
        engine.registerFunction('processNestedData', (Map<String, dynamic> data) {
          final users = data['users'] as List;
          final totalAge = users.fold<int>(0, (sum, user) {
            final userMap = user as Map<String, dynamic>;
            return sum + (userMap['age'] as int);
          });
          return totalAge;
        });

        // Test with deeply nested structure
        final result = engine.eval('''
          let data = #{
            users: [
              #{name: "Alice", age: 30, address: #{city: "NYC", zip: 10001}},
              #{name: "Bob", age: 25, address: #{city: "LA", zip: 90001}},
              #{name: "Charlie", age: 35, address: #{city: "Chicago", zip: 60601}}
            ],
            metadata: #{
              created: "2025-12-25",
              version: 1
            }
          };

          let totalAge = processNestedData(data);

          #{
            totalAge: totalAge,
            userCount: data.users.len(),
            firstUser: data.users[0].name
          }
        ''');

        expect(result['totalAge'], equals(90)); // 30 + 25 + 35
        expect(result['userCount'], equals(3));
        expect(result['firstUser'], equals('Alice'));
      } finally {
        engine.dispose();
      }
    });

    test('Timeout enforcement with registered functions', () {
      // Create engine with short timeout
      final engine = RhaiEngine.withConfig(
        RhaiConfig.custom(
          timeoutMs: 500,
          maxOperations: 100000,
        ),
      );

      try {
        // Register a function that executes quickly
        engine.registerFunction('fastFunc', () => 'quick');

        // Normal execution should work
        final result1 = engine.eval('fastFunc()');
        expect(result1, equals('quick'));

        // Script with infinite loop should timeout
        expect(
          () => engine.eval('loop { }'),
          throwsA(isA<RhaiRuntimeError>().having(
            (e) => e.message,
            'timeout or operation limit',
            anyOf(contains('timeout'), contains('operation'), contains('limit')),
          )),
        );

        // After timeout, engine should still work for new evals
        final result2 = engine.eval('fastFunc()');
        expect(result2, equals('quick'));
      } finally {
        engine.dispose();
      }
    });

    test('Mixed workflow: multiple features simultaneously', () {
      final engine = RhaiEngine.withConfig(
        RhaiConfig.custom(
          maxOperations: 1000000,
          maxStackDepth: 100,
          timeoutMs: 5000,
        ),
      );

      try {
        // Register various function types
        engine.registerFunction('calculate', (int a, int b, String op) {
          switch (op) {
            case 'add':
              return a + b;
            case 'sub':
              return a - b;
            case 'mul':
              return a * b;
            case 'div':
              if (b == 0) throw ArgumentError('Division by zero');
              return a / b;
            default:
              throw ArgumentError('Unknown operation: $op');
          }
        });

        engine.registerFunction('transformList', (List<dynamic> items) {
          return items.map((item) {
            if (item is int) return item * 2;
            if (item is String) return item.toUpperCase();
            return item;
          }).toList();
        });

        engine.registerFunction('validateData', (Map<String, dynamic> data) {
          final required = ['name', 'age'];
          for (final field in required) {
            if (!data.containsKey(field)) {
              throw ArgumentError('Missing required field: $field');
            }
          }
          return true;
        });

        // Execute a complex script using all features
        final result = engine.eval('''
          // Use calculate function
          let sum = calculate(100, 50, "add");
          let product = calculate(sum, 2, "mul");

          // Use transformList function
          let items = [1, 2, "hello", 3, "world"];
          let transformed = transformList(items);

          // Use validateData function
          let user = #{name: "Alice", age: 30, active: true};
          let isValid = validateData(user);

          // Complex nested logic
          let scores = [85, 92, 78, 95, 88];
          let totalScore = 0;
          for score in scores {
            totalScore += score;
          }
          // Force float division by converting to float first
          let avgScore = totalScore.to_float() / scores.len().to_float();

          // Return complex result
          #{
            calculations: #{
              sum: sum,
              product: product
            },
            transformed: transformed,
            validation: isValid,
            scores: #{
              total: totalScore,
              average: avgScore,
              count: scores.len()
            }
          }
        ''');

        // Verify all aspects
        expect(result['calculations']['sum'], equals(150));
        expect(result['calculations']['product'], equals(300));
        expect(result['transformed'], equals([2, 4, 'HELLO', 6, 'WORLD']));
        expect(result['validation'], equals(true));
        expect(result['scores']['total'], equals(438)); // 85+92+78+95+88
        expect(result['scores']['average'], closeTo(87.6, 0.1));
        expect(result['scores']['count'], equals(5));
      } finally {
        engine.dispose();
      }
    });

    test('Resource cleanup under error conditions', () {
      // Test that resources are properly cleaned up even when errors occur
      final engines = <RhaiEngine>[];

      try {
        for (var i = 0; i < 10; i++) {
          final engine = RhaiEngine.withDefaults();
          engines.add(engine);

          engine.registerFunction('mayFail', (int x) {
            if (x < 0) throw Exception('Negative not allowed');
            return x * 2;
          });

          // Execute some successful and some failing operations
          if (i % 2 == 0) {
            // Success case
            final result = engine.eval('mayFail(5)');
            expect(result, equals(10));
          } else {
            // Error case
            try {
              engine.eval('mayFail(-1)');
              fail('Should have thrown an error');
            } on RhaiRuntimeError catch (e) {
              expect(e.message, contains('Negative not allowed'));
            }
          }
        }
      } finally {
        // Cleanup all engines even after errors
        for (final engine in engines) {
          engine.dispose();
        }
      }

      // Verify that new engines can still be created after cleanup
      final newEngine = RhaiEngine.withDefaults();
      try {
        final result = newEngine.eval('42');
        expect(result, equals(42));
      } finally {
        newEngine.dispose();
      }
    });

    test('Type conversion consistency across eval and function boundaries', () {
      final engine = RhaiEngine.withDefaults();

      try {
        // Register an identity function that just returns what it receives
        engine.registerFunction('identity', (dynamic value) => value);

        // Test various types round-tripping through function calls
        final testCases = [
          {'input': '42', 'expected': 42},
          {'input': '3.14', 'expected': closeTo(3.14, 0.01)},
          {'input': 'true', 'expected': true},
          {'input': 'false', 'expected': false},
          {'input': '"hello"', 'expected': 'hello'},
          {'input': '[1, 2, 3]', 'expected': [1, 2, 3]},
          {
            'input': '#{a: 1, b: "test"}',
            'expected': {'a': 1, 'b': 'test'}
          },
        ];

        for (final testCase in testCases) {
          final input = testCase['input'];
          final expected = testCase['expected'];

          // Test direct eval
          final evalResult = engine.eval('$input');
          if (expected is Matcher) {
            expect(evalResult, expected);
          } else {
            expect(evalResult, equals(expected));
          }

          // Test round-trip through function
          final funcResult = engine.eval('identity($input)');
          if (expected is Matcher) {
            expect(funcResult, expected);
          } else {
            expect(funcResult, equals(expected));
          }
        }

        // Test null specifically
        final nullResult = engine.eval('identity(())');
        expect(nullResult, isNull);
      } finally {
        engine.dispose();
      }
    });
  });
}
