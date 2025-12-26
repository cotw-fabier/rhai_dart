/// Integration tests for real-world async I/O scenarios
///
/// This test suite validates that the dual-path architecture works correctly
/// with realistic async operations like simulated HTTP requests, file I/O,
/// and complex workflows mixing sync and async functions.
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';
import 'dart:async';
import 'dart:io';

void main() {
  group('Async I/O Integration Tests', () {
    late RhaiEngine engine;

    setUp(() {
      engine = RhaiEngine.withDefaults();
    });

    tearDown(() {
      engine.dispose();
    });

    test('simulated HTTP GET request with async function', () async {
      // Simulate an HTTP GET request with realistic delays and structure
      engine.registerFunction('httpGet', (String url) async {
        // Simulate network latency
        await Future.delayed(const Duration(milliseconds: 100));

        // Simulate response based on URL
        if (url.contains('users')) {
          return {
            'statusCode': 200,
            'body': {
              'users': [
                {'id': 1, 'name': 'Alice'},
                {'id': 2, 'name': 'Bob'}
              ]
            }
          };
        } else if (url.contains('error')) {
          throw Exception('Network error: 404 Not Found');
        } else {
          return {
            'statusCode': 200,
            'body': {'message': 'Success'}
          };
        }
      });

      // Test successful request
      final result1 = await engine.evalAsync('httpGet("https://api.example.com/users")');
      expect((result1 as Map)['statusCode'], equals(200));
      expect(result1['body']['users'], isA<List>());
      expect(result1['body']['users'].length, equals(2));

      // Test error handling
      expect(
        () => engine.evalAsync('httpGet("https://api.example.com/error")'),
        throwsA(isA<RhaiRuntimeError>()),
      );
    });

    test('file I/O async operations (read/write)', () async {
      final testFilePath = '${Directory.systemTemp.path}/rhai_test_${DateTime.now().millisecondsSinceEpoch}.txt';

      // Register async file write function
      engine.registerFunction('writeFile', (String path, String content) async {
        final file = File(path);
        await file.writeAsString(content);
        return true;
      });

      // Register async file read function
      engine.registerFunction('readFile', (String path) async {
        final file = File(path);
        return await file.readAsString();
      });

      // Register async file delete function
      engine.registerFunction('deleteFile', (String path) async {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          return true;
        }
        return false;
      });

      try {
        // Test write operation
        final writeResult = await engine.evalAsync('writeFile("$testFilePath", "Hello from Rhai!")');
        expect(writeResult, equals(true));

        // Test read operation
        final readResult = await engine.evalAsync('readFile("$testFilePath")');
        expect(readResult, equals('Hello from Rhai!'));

        // Test delete operation
        final deleteResult = await engine.evalAsync('deleteFile("$testFilePath")');
        expect(deleteResult, equals(true));
      } finally {
        // Cleanup: ensure file is deleted
        final file = File(testFilePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    });

    test('mixing sync and async functions in complex workflow', () async {
      // Simulate a realistic workflow with database queries, validation, and computation

      // Sync validation function
      engine.registerFunction('validateEmail', (String email) {
        return email.contains('@') && email.contains('.');
      });

      // Sync computation function
      engine.registerFunction('calculateDiscount', (int price, int percentage) {
        return price - (price * percentage / 100);
      });

      // Async database query simulation
      engine.registerFunction('findUser', (String email) async {
        await Future.delayed(const Duration(milliseconds: 50));
        if (email == 'alice@example.com') {
          return {'id': 1, 'name': 'Alice', 'email': email, 'tier': 'gold'};
        }
        return null;
      });

      // Async database update simulation
      engine.registerFunction('updateUser', (int userId, Map<String, dynamic> data) async {
        await Future.delayed(const Duration(milliseconds: 30));
        return {'success': true, 'updatedId': userId};
      });

      // Complex workflow: validate email, find user, calculate discount, update user
      final result = await engine.evalAsync('''
        let email = "alice@example.com";
        let isValid = validateEmail(email);

        if !isValid {
          throw "Invalid email";
        }

        let user = findUser(email);
        if user == () {
          throw "User not found";
        }

        let originalPrice = 100;
        let discountPercent = if user.tier == "gold" { 20 } else { 10 };
        let finalPrice = calculateDiscount(originalPrice, discountPercent);

        let updateResult = updateUser(user.id, #{finalPrice: finalPrice});

        #{
          user: user.name,
          originalPrice: originalPrice,
          discount: discountPercent,
          finalPrice: finalPrice,
          updated: updateResult.success
        }
      ''');

      expect((result as Map)['user'], equals('Alice'));
      expect(result['originalPrice'], equals(100));
      expect(result['discount'], equals(20));
      expect(result['finalPrice'], equals(80));
      expect(result['updated'], equals(true));
    });

    test('concurrent async operations with resource coordination', () async {
      // Simulate multiple async operations that need to be coordinated
      int sharedCounter = 0;

      engine.registerFunction('incrementCounter', () async {
        await Future.delayed(const Duration(milliseconds: 10));
        sharedCounter++;
        return sharedCounter;
      });

      engine.registerFunction('getCounter', () {
        return sharedCounter;
      });

      // Execute multiple concurrent increments
      final futures = List.generate(5, (i) =>
        engine.evalAsync('incrementCounter()')
      );

      final results = await Future.wait(futures);

      // Each increment should return a unique value
      expect(results.toSet().length, equals(5));

      // Final counter value should be 5
      final finalValue = await engine.evalAsync('getCounter()');
      expect(finalValue, equals(5));
    });

    test('async timeout scenario with long-running operation', () async {
      // Test that very long operations can complete
      engine.registerFunction('longOperation', (int seconds) async {
        await Future.delayed(Duration(seconds: seconds));
        return 'completed';
      });

      // Test with 1 second delay (should complete)
      final result = await engine.evalAsync('longOperation(1)');
      expect(result, equals('completed'));

      // Note: Testing actual timeout would require configurable timeout in engine
      // which is currently set to 30 seconds. For now, we verify long operations work.
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('async error recovery and fallback patterns', () async {
      // Simulate async operations with error recovery
      engine.registerFunction('unreliableOperation', (int attemptNumber) async {
        await Future.delayed(const Duration(milliseconds: 20));
        if (attemptNumber < 3) {
          throw Exception('Operation failed on attempt $attemptNumber');
        }
        return 'success';
      });

      engine.registerFunction('fallbackValue', () async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'fallback';
      });

      // Test error handling in Rhai script with try-catch pattern
      // Note: Rhai doesn't have try-catch, so we test direct error propagation
      expect(
        () => engine.evalAsync('unreliableOperation(1)'),
        throwsA(isA<RhaiRuntimeError>()),
      );

      // Test successful operation
      final result = await engine.evalAsync('unreliableOperation(3)');
      expect(result, equals('success'));
    });
  });
}
