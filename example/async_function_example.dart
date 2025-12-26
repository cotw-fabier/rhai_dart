/// Example demonstrating async function registration and invocation
///
/// This example shows how to register async Dart functions (returning Future<T>)
/// with the Rhai engine and call them from scripts. The FFI bridge automatically
/// blocks until the Future completes, making async functions appear synchronous
/// to the Rhai script.
library;

import 'package:rhai_dart/rhai_dart.dart';
import 'dart:async';

void main() {
  // Create a Rhai engine with default configuration
  final engine = RhaiEngine.withDefaults();

  try {
    print('=== Async Function Examples ===\n');

    // Example 1: Simulated HTTP request
    print('Example 1: Simulated HTTP Request');
    engine.registerFunction('fetchUser', (int userId) async {
      print('  [Dart] Starting async HTTP request for user $userId...');

      // Simulate network delay
      await Future.delayed(Duration(milliseconds: 100));

      print('  [Dart] HTTP request completed');

      // Return mock user data
      return {
        'id': userId,
        'name': 'User $userId',
        'email': 'user$userId@example.com',
        'status': 'active',
      };
    });

    final user = engine.eval('''
      print("Calling fetchUser(42)...");
      let user = fetchUser(42);
      print("Got user: " + user.name);
      user
    ''');

    print('  Result: $user\n');

    // Example 2: Async data processing
    print('Example 2: Async Data Processing');
    engine.registerFunction('processData', (List<dynamic> data) async {
      print('  [Dart] Starting async data processing...');

      // Simulate processing delay
      await Future.delayed(Duration(milliseconds: 50));

      // Process the data
      final processed = data.map((item) => (item as int) * 2).toList();

      print('  [Dart] Processing completed');
      return processed;
    });

    final processed = engine.eval('''
      let input = [1, 2, 3, 4, 5];
      print("Processing data: " + input);
      let output = processData(input);
      print("Processed: " + output);
      output
    ''');

    print('  Result: $processed\n');

    // Example 3: Multiple async calls in sequence
    print('Example 3: Multiple Async Calls in Sequence');
    var stepCounter = 0;
    engine.registerFunction('asyncStep', (String step) async {
      stepCounter++;
      print('  [Dart] Executing step $stepCounter: $step');
      await Future.delayed(Duration(milliseconds: 30));
      return 'Step $stepCounter: $step completed';
    });

    final steps = engine.eval('''
      let step1 = asyncStep("Initialize");
      let step2 = asyncStep("Process");
      let step3 = asyncStep("Finalize");
      [step1, step2, step3]
    ''');

    print('  Result: $steps\n');

    // Example 4: Async function with error handling
    print('Example 4: Async Function Error Handling');
    engine.registerFunction('riskyOperation', (bool shouldFail) async {
      print('  [Dart] Starting risky operation (shouldFail=$shouldFail)...');
      await Future.delayed(Duration(milliseconds: 20));

      if (shouldFail) {
        print('  [Dart] Operation failed!');
        throw Exception('Operation failed as requested');
      }

      print('  [Dart] Operation succeeded');
      return 'Success!';
    });

    // Successful call
    try {
      final success = engine.eval('riskyOperation(false)');
      print('  Success case result: $success');
    } catch (e) {
      print('  Unexpected error: $e');
    }

    // Failing call
    try {
      engine.eval('riskyOperation(true)');
      print('  Error: Should have thrown!');
    } catch (e) {
      print('  Expected error caught: ${e.runtimeType}');
    }

    print();

    // Example 5: Async file-like operation (simulated)
    print('Example 5: Simulated Async File Operation');
    final Map<String, String> mockFileSystem = {
      'config.txt': 'timeout=5000\nmax_ops=1000000',
      'data.txt': 'Hello, World!',
    };

    engine.registerFunction('readFile', (String filename) async {
      print('  [Dart] Reading file: $filename');
      await Future.delayed(Duration(milliseconds: 40));

      if (mockFileSystem.containsKey(filename)) {
        return mockFileSystem[filename];
      } else {
        throw Exception('File not found: $filename');
      }
    });

    final configContent = engine.eval('readFile("config.txt")');
    print('  Config file content:\n    ${configContent.toString().replaceAll('\n', '\n    ')}\n');

    // Example 6: Chaining async operations
    print('Example 6: Chaining Async Operations');
    engine.registerFunction('asyncMultiply', (int x, int y) async {
      await Future.delayed(Duration(milliseconds: 10));
      return x * y;
    });

    engine.registerFunction('asyncAdd', (int x, int y) async {
      await Future.delayed(Duration(milliseconds: 10));
      return x + y;
    });

    final chainedResult = engine.eval('''
      let a = asyncMultiply(3, 4);  // 12
      let b = asyncAdd(a, 8);        // 20
      let c = asyncMultiply(b, 2);   // 40
      c
    ''');

    print('  Chained result: $chainedResult\n');

    print('=== All async examples completed successfully! ===');

  } finally {
    // Always dispose the engine when done
    engine.dispose();
  }
}
