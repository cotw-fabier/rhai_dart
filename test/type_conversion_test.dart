/// Comprehensive tests for type conversion between Dart and Rhai
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  group('Type Conversion Tests', () {
    late RhaiEngine engine;

    setUp(() {
      // Create a fresh engine for each test
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      // Clean up after each test
      engine.dispose();
    });

    group('Primitive Type Conversions', () {
      test('int conversions (Rhai to Dart)', () {
        // Test various integer values
        expect(engine.eval('0'), equals(0));
        expect(engine.eval('42'), equals(42));
        expect(engine.eval('-100'), equals(-100));
        expect(engine.eval('1000000'), equals(1000000));
      });

      test('double conversions (Rhai to Dart)', () {
        // Test various floating point values
        expect(engine.eval('0.0'), closeTo(0.0, 0.001));
        expect(engine.eval('3.14'), closeTo(3.14, 0.001));
        expect(engine.eval('-2.5'), closeTo(-2.5, 0.001));
        expect(engine.eval('1.23456789'), closeTo(1.23456789, 0.0000001));
      });

      test('bool conversions (Rhai to Dart)', () {
        // Test boolean values
        expect(engine.eval('true'), equals(true));
        expect(engine.eval('false'), equals(false));
        expect(engine.eval('1 < 2'), equals(true));
        expect(engine.eval('5 > 10'), equals(false));
      });

      test('String conversions (Rhai to Dart)', () {
        // Test string values
        expect(engine.eval('"hello"'), equals('hello'));
        expect(engine.eval('""'), equals(''));
        expect(engine.eval('"a b c"'), equals('a b c'));
      });

      test('null conversions (Rhai to Dart)', () {
        // Test null/unit values
        expect(engine.eval('()'), isNull);
        expect(engine.eval('let x; x'), isNull);
      });
    });

    group('Edge Case Primitives', () {
      test('very large integers', () {
        // Test large integer values (within i64 range)
        final largeInt = engine.eval('9223372036854775806'); // i64::MAX - 1
        expect(largeInt, isA<int>());
        expect(largeInt, equals(9223372036854775806));

        final largeNegInt = engine.eval('-9223372036854775807'); // i64::MIN + 1
        expect(largeNegInt, isA<int>());
        expect(largeNegInt, equals(-9223372036854775807));
      });

      test('Unicode strings', () {
        // Test Unicode string handling
        expect(engine.eval('"Hello 世界"'), equals('Hello 世界'));
        expect(engine.eval('"🚀🌟✨"'), equals('🚀🌟✨'));
        expect(engine.eval('"Ñoño"'), equals('Ñoño'));
        expect(engine.eval('"Привет"'), equals('Привет'));
      });
    });

    group('Nested List Conversions', () {
      test('simple list conversion (Rhai to Dart)', () {
        final result = engine.eval('[1, 2, 3]');
        expect(result, isA<List>());
        expect(result, equals([1, 2, 3]));
      });

      test('empty list conversion', () {
        final result = engine.eval('[]');
        expect(result, isA<List>());
        expect(result, isEmpty);
      });

      test('nested list conversion (List<List<dynamic>>)', () {
        final result = engine.eval('[[1, 2], [3, 4], [5, 6]]');
        expect(result, isA<List>());
        expect(result, equals([
          [1, 2],
          [3, 4],
          [5, 6]
        ]));
      });

      test('deeply nested list conversion', () {
        final result = engine.eval('[[[1, 2], [3, 4]], [[5, 6], [7, 8]]]');
        expect(result, isA<List>());
        expect(result, equals([
          [
            [1, 2],
            [3, 4]
          ],
          [
            [5, 6],
            [7, 8]
          ]
        ]));
      });

      test('mixed type list conversion', () {
        final result = engine.eval('[1, "hello", true, 3.14, ()]');
        expect(result, isA<List>());
        expect(result[0], equals(1));
        expect(result[1], equals('hello'));
        expect(result[2], equals(true));
        expect(result[3], closeTo(3.14, 0.001));
        expect(result[4], isNull);
      });
    });

    group('Nested Map Conversions', () {
      test('simple map conversion (Rhai to Dart)', () {
        final result = engine.eval('#{"x": 1, "y": 2}');
        expect(result, isA<Map>());
        expect(result['x'], equals(1));
        expect(result['y'], equals(2));
      });

      test('empty map conversion', () {
        final result = engine.eval('#{}');
        expect(result, isA<Map>());
        expect(result, isEmpty);
      });

      test('nested map conversion (Map<String, Map<String, dynamic>>)', () {
        final result = engine.eval('#{"outer": #{"inner": 42}}');
        expect(result, isA<Map>());
        expect(result['outer'], isA<Map>());
        expect(result['outer']['inner'], equals(42));
      });

      test('deeply nested map conversion', () {
        final result = engine.eval('''
          #{
            "level1": #{
              "level2": #{
                "level3": "deep value"
              }
            }
          }
        ''');
        expect(result, isA<Map>());
        expect(result['level1']['level2']['level3'], equals('deep value'));
      });

      test('mixed type map conversion', () {
        final result = engine.eval('''
          #{
            "int": 42,
            "str": "hello",
            "bool": true,
            "float": 3.14,
            "null": ()
          }
        ''');
        expect(result, isA<Map>());
        expect(result['int'], equals(42));
        expect(result['str'], equals('hello'));
        expect(result['bool'], equals(true));
        expect(result['float'], closeTo(3.14, 0.001));
        expect(result['null'], isNull);
      });
    });

    group('Mixed Nested Structures', () {
      test('list of maps', () {
        final result = engine.eval('''
          [
            #{"name": "Alice", "age": 30},
            #{"name": "Bob", "age": 25}
          ]
        ''');
        expect(result, isA<List>());
        expect(result.length, equals(2));
        expect(result[0]['name'], equals('Alice'));
        expect(result[0]['age'], equals(30));
        expect(result[1]['name'], equals('Bob'));
        expect(result[1]['age'], equals(25));
      });

      test('map of lists', () {
        final result = engine.eval('''
          #{
            "numbers": [1, 2, 3],
            "strings": ["a", "b", "c"],
            "bools": [true, false, true]
          }
        ''');
        expect(result, isA<Map>());
        expect(result['numbers'], equals([1, 2, 3]));
        expect(result['strings'], equals(['a', 'b', 'c']));
        expect(result['bools'], equals([true, false, true]));
      });

      test('complex nested structure', () {
        final result = engine.eval('''
          #{
            "users": [
              #{
                "name": "Alice",
                "scores": [90, 85, 95],
                "metadata": #{"active": true}
              },
              #{
                "name": "Bob",
                "scores": [80, 75, 85],
                "metadata": #{"active": false}
              }
            ],
            "total": 2
          }
        ''');
        expect(result, isA<Map>());
        expect(result['users'], isA<List>());
        expect(result['users'].length, equals(2));
        expect(result['users'][0]['name'], equals('Alice'));
        expect(result['users'][0]['scores'], equals([90, 85, 95]));
        expect(result['users'][0]['metadata']['active'], equals(true));
        expect(result['total'], equals(2));
      });
    });

    group('Dart to Rhai Conversions (via Function Parameters)', () {
      test('primitive parameters conversion', () {
        // Register a function that receives and returns primitives
        engine.registerFunction('test_primitives', (int i, double d, bool b, String s) {
          return [i, d, b, s];
        });

        final result = engine.eval('test_primitives(42, 3.14, true, "hello")');
        expect(result, isA<List>());
        expect(result[0], equals(42));
        expect(result[1], closeTo(3.14, 0.001));
        expect(result[2], equals(true));
        expect(result[3], equals('hello'));
      });

      test('list parameter conversion', () {
        engine.registerFunction('sum_list', (List<dynamic> numbers) {
          return numbers.fold<num>(0, (sum, n) => sum + (n as num));
        });

        final result = engine.eval('sum_list([1, 2, 3, 4, 5])');
        expect(result, equals(15));
      });

      test('map parameter conversion', () {
        engine.registerFunction('get_value', (Map<String, dynamic> obj, String key) {
          return obj[key];
        });

        final result = engine.eval('get_value(#{"x": 42, "y": 99}, "x")');
        expect(result, equals(42));
      });

      test('null parameter conversion', () {
        engine.registerFunction('is_null', (dynamic value) {
          return value == null;
        });

        expect(engine.eval('is_null(())'), equals(true));
        expect(engine.eval('is_null(42)'), equals(false));
      });

      test('nested structure parameter conversion', () {
        engine.registerFunction('extract_nested', (Map<String, dynamic> data) {
          final users = data['users'] as List<dynamic>;
          final firstUser = users[0] as Map<String, dynamic>;
          return firstUser['name'];
        });

        final result = engine.eval('''
          extract_nested(#{
            "users": [
              #{"name": "Alice", "age": 30},
              #{"name": "Bob", "age": 25}
            ]
          })
        ''');
        expect(result, equals('Alice'));
      });
    });

    group('Bidirectional Roundtrip Conversions', () {
      test('roundtrip complex structure through function', () {
        // Function that receives a structure and returns it modified
        engine.registerFunction('modify_data', (Map<String, dynamic> data) {
          final scores = (data['scores'] as List<dynamic>).cast<num>();
          final doubled = scores.map((s) => s * 2).toList();
          return {
            'name': data['name'],
            'original_scores': scores,
            'doubled_scores': doubled,
          };
        });

        final result = engine.eval('''
          modify_data(#{"name": "Alice", "scores": [90, 85, 95]})
        ''');

        expect(result, isA<Map>());
        expect(result['name'], equals('Alice'));
        expect(result['original_scores'], equals([90, 85, 95]));
        expect(result['doubled_scores'], equals([180, 170, 190]));
      });

      test('roundtrip special float values', () {
        // Test that special float values survive a round trip through Dart functions
        engine.registerFunction('identity', (dynamic value) => value);

        // Create a complex structure with special float values in Dart
        final testData = {
          'infinity': double.infinity,
          'neg_infinity': double.negativeInfinity,
          'nan': double.nan,
          'normal': 3.14,
          'nested': [double.infinity, double.negativeInfinity, double.nan],
        };

        // We can't easily inject this from Dart in the eval string,
        // so we test by having a function that returns these values
        engine.registerFunction('get_special_values', () => testData);

        final result = engine.eval('get_special_values()');
        expect(result, isA<Map>());
        expect(result['infinity'], equals(double.infinity));
        expect(result['neg_infinity'], equals(double.negativeInfinity));
        expect(result['nan'], isNaN);
        expect(result['normal'], closeTo(3.14, 0.001));
        expect(result['nested'][0], equals(double.infinity));
        expect(result['nested'][1], equals(double.negativeInfinity));
        expect(result['nested'][2], isNaN);
      });
    });
  });
}
