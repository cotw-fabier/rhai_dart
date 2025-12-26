/// Example 3: Async Function Registration and evalAsync()
///
/// This example demonstrates the dual-path architecture of rhai_dart:
/// - Part 1: Using eval() with synchronous functions (fastest)
/// - Part 2: Using evalAsync() with async functions (full async support)
/// - Part 3: Best practices and when to use each method
///
/// rhai_dart provides complete async function support through a dual-path
/// architecture that optimizes for both sync and async use cases.

import 'dart:async';
import 'package:rhai_dart/rhai_dart.dart';

void main() async {
  print('=== Example 3: Dual-Path Architecture Demo ===\n');

  // =================================================================
  // PART 1: Synchronous Functions with eval()
  // =================================================================
  print('PART 1: Synchronous Functions with eval()');
  print('=' * 50);

  await demonstrateSyncPath();

  print('\n');

  // =================================================================
  // PART 2: Asynchronous Functions with evalAsync()
  // =================================================================
  print('PART 2: Asynchronous Functions with evalAsync()');
  print('=' * 50);

  await demonstrateAsyncPath();

  print('\n');

  // =================================================================
  // PART 3: Best Practices
  // =================================================================
  print('PART 3: Best Practices and Decision Guide');
  print('=' * 50);

  await demonstrateBestPractices();

  print('\n=== All examples completed successfully! ===\n');
  printSummary();
}

/// Demonstrates the synchronous eval() path
Future<void> demonstrateSyncPath() async {
  print('\n1.1 Basic Sync Functions');
  print('-' * 30);

  final engine = RhaiEngine.withDefaults();

  try {
    // Register synchronous functions
    engine.registerFunction('add', (int a, int b) => a + b);
    engine.registerFunction('multiply', (int a, int b) => a * b);

    // Use eval() for sync functions - zero overhead
    final result = engine.eval('''
      let x = add(10, 20);
      let y = multiply(x, 2);
      #{sum: x, product: y}
    ''');

    print('Result: $result');
    print('Performance: Zero overhead - direct FFI callback');
  } finally {
    engine.dispose();
  }

  print('\n1.2 Complex Sync Data');
  print('-' * 30);

  final engine2 = RhaiEngine.withDefaults();

  try {
    // Sync function returning complex data
    engine2.registerFunction('getUserProfile', (int userId) {
      return {
        'id': userId,
        'name': 'Alice',
        'email': 'alice@example.com',
        'roles': ['admin', 'editor'],
        'settings': {'theme': 'dark', 'notifications': true}
      };
    });

    final result = engine2.eval('''
      let profile = getUserProfile(123);
      #{
        name: profile.name,
        is_admin: profile.roles.contains("admin"),
        theme: profile.settings.theme
      }
    ''');

    print('Result: $result');
  } finally {
    engine2.dispose();
  }

  print('\n1.3 Async Function Detection (Error Handling)');
  print('-' * 30);

  final engine3 = RhaiEngine.withDefaults();

  try {
    // Register an async function
    engine3.registerFunction('asyncOperation', () async {
      await Future.delayed(Duration(milliseconds: 10));
      return 'data';
    });

    try {
      // This will throw a helpful error
      engine3.eval('asyncOperation()');
    } on RhaiException catch (e) {
      // Catch the base exception class
      print('Expected error caught:');
      print('  ${e.message}');
      print('  This guides users to use evalAsync() instead');
    }
  } finally {
    engine3.dispose();
  }
}

/// Demonstrates the asynchronous evalAsync() path
Future<void> demonstrateAsyncPath() async {
  print('\n2.1 Basic Async Functions');
  print('-' * 30);

  final engine = RhaiEngine.withDefaults();

  try {
    // Register async function with delay
    engine.registerFunction('fetchData', (String key) async {
      await Future.delayed(Duration(milliseconds: 50));
      return 'value_for_$key';
    });

    // Use evalAsync() for async functions
    final result = await engine.evalAsync('fetchData("user_123")');
    print('Result: $result');
    print('Performance: Slight overhead for message passing, full async support');
  } finally {
    engine.dispose();
  }

  print('\n2.2 Simulated HTTP Request');
  print('-' * 30);

  final engine2 = RhaiEngine.withDefaults();

  try {
    // Simulate HTTP GET request
    engine2.registerFunction('httpGet', (String url) async {
      print('  [Simulating HTTP GET to $url]');
      await Future.delayed(Duration(milliseconds: 100));

      // Simulate JSON response
      return {
        'status': 200,
        'data': {
          'id': 1,
          'name': 'John Doe',
          'email': 'john@example.com'
        }
      };
    });

    final result = await engine2.evalAsync('''
      let response = httpGet("https://api.example.com/users/1");
      #{
        status: response.status,
        user_name: response.data.name,
        user_email: response.data.email
      }
    ''');

    print('Result: $result');
  } finally {
    engine2.dispose();
  }

  print('\n2.3 Mixing Sync and Async Functions');
  print('-' * 30);

  final engine3 = RhaiEngine.withDefaults();

  try {
    // Mix of sync and async functions
    engine3.registerFunction('calculate', (int x) => x * 2);

    engine3.registerFunction('fetchConfig', () async {
      await Future.delayed(Duration(milliseconds: 30));
      return {'multiplier': 10, 'offset': 5};
    });

    // evalAsync() works with BOTH sync and async functions
    final result = await engine3.evalAsync('''
      let computed = calculate(21);      // Sync function
      let config = fetchConfig();        // Async function
      let final_value = computed + config.offset;
      #{computed: computed, config: config, final: final_value}
    ''');

    print('Result: $result');
  } finally {
    engine3.dispose();
  }

  print('\n2.4 Multiple Async Operations');
  print('-' * 30);

  final engine4 = RhaiEngine.withDefaults();

  try {
    engine4.registerFunction('fetchUser', (int id) async {
      await Future.delayed(Duration(milliseconds: 20));
      return {'id': id, 'name': 'User$id'};
    });

    engine4.registerFunction('fetchPosts', (int userId) async {
      await Future.delayed(Duration(milliseconds: 30));
      return [
        {'id': 1, 'title': 'Post 1'},
        {'id': 2, 'title': 'Post 2'}
      ];
    });

    final result = await engine4.evalAsync('''
      let user = fetchUser(123);
      let posts = fetchPosts(123);
      #{
        user_name: user.name,
        post_count: posts.len(),
        first_post: posts[0].title
      }
    ''');

    print('Result: $result');
  } finally {
    engine4.dispose();
  }

  print('\n2.5 Error Handling in Async Functions');
  print('-' * 30);

  final engine5 = RhaiEngine.withDefaults();

  try {
    engine5.registerFunction('riskyOperation', (bool shouldFail) async {
      await Future.delayed(Duration(milliseconds: 20));
      if (shouldFail) {
        throw Exception('Operation failed as requested');
      }
      return 'success';
    });

    // Success case
    final successResult = await engine5.evalAsync('riskyOperation(false)');
    print('Success result: $successResult');

    // Error case
    try {
      await engine5.evalAsync('riskyOperation(true)');
    } on RhaiException catch (e) {
      print('Expected error caught:');
      print('  ${e.message}');
    }
  } finally {
    engine5.dispose();
  }

  print('\n2.6 Concurrent evalAsync() Calls');
  print('-' * 30);

  final engine6 = RhaiEngine.withDefaults();

  try {
    engine6.registerFunction('processItem', (int item) async {
      await Future.delayed(Duration(milliseconds: 20));
      return item * 2;
    });

    // Run multiple eval() calls concurrently
    print('  Running 3 concurrent evalAsync() calls...');
    final results = await Future.wait([
      engine6.evalAsync('processItem(10)'),
      engine6.evalAsync('processItem(20)'),
      engine6.evalAsync('processItem(30)'),
    ]);

    print('  Results: $results');
  } finally {
    engine6.dispose();
  }
}

/// Demonstrates best practices and decision-making
Future<void> demonstrateBestPractices() async {
  print('\n3.1 When to Use eval() vs evalAsync()');
  print('-' * 30);

  print('''
Use eval() when:
  - All functions are synchronous
  - You want maximum performance (zero overhead)
  - You're doing pure computation

Use evalAsync() when:
  - Any function is async (returns Future<T>)
  - You need HTTP requests, file I/O, database queries
  - You want to integrate with async Dart ecosystem
''');

  print('\n3.2 Performance Comparison');
  print('-' * 30);

  // Sync path performance
  final syncEngine = RhaiEngine.withDefaults();
  syncEngine.registerFunction('syncFunc', () => 42);

  final syncStart = DateTime.now();
  for (var i = 0; i < 100; i++) {
    syncEngine.eval('syncFunc()');
  }
  final syncDuration = DateTime.now().difference(syncStart);
  print('  eval() - 100 calls: ${syncDuration.inMilliseconds}ms');
  syncEngine.dispose();

  // Async path performance
  final asyncEngine = RhaiEngine.withDefaults();
  asyncEngine.registerFunction('syncFunc', () => 42);

  final asyncStart = DateTime.now();
  for (var i = 0; i < 100; i++) {
    await asyncEngine.evalAsync('syncFunc()');
  }
  final asyncDuration = DateTime.now().difference(asyncStart);
  print(
      '  evalAsync() - 100 calls: ${asyncDuration.inMilliseconds}ms (sequential)');
  asyncEngine.dispose();

  print(
      '\n  Note: eval() is faster for sync functions due to zero overhead.');
  print('  evalAsync() overhead is worth it when you need async support.');

  print('\n3.3 Migration Example');
  print('-' * 30);

  print('Before (sync only):');
  print('''
  final engine = RhaiEngine.withDefaults();
  engine.registerFunction('getData', () => cachedData);
  final result = engine.eval('getData()');
''');

  print('\nAfter (with async):');
  print('''
  final engine = RhaiEngine.withDefaults();
  engine.registerFunction('getData', () async => await fetchLiveData());
  final result = await engine.evalAsync('getData()');
''');

  print('\n3.4 Real-World Use Case');
  print('-' * 30);

  final engine = RhaiEngine.withDefaults();

  try {
    // Simulate a real-world scenario
    engine.registerFunction('getUserById', (int id) async {
      // Simulates database query
      await Future.delayed(Duration(milliseconds: 40));
      return {'id': id, 'name': 'User$id', 'credits': id * 10};
    });

    engine.registerFunction('calculateDiscount', (int credits) {
      // Pure computation - synchronous
      if (credits > 100) return 0.2;
      if (credits > 50) return 0.1;
      return 0.0;
    });

    engine.registerFunction('applyDiscount', (double price, double discount) {
      // Pure computation - synchronous
      return price * (1.0 - discount);
    });

    final result = await engine.evalAsync('''
      let user = getUserById(15);              // Async DB query
      let discount = calculateDiscount(user.credits);  // Sync calc
      let price = 100.0;
      let final_price = applyDiscount(price, discount);  // Sync calc

      #{
        user_name: user.name,
        credits: user.credits,
        discount_percent: discount * 100.0,
        original_price: price,
        final_price: final_price
      }
    ''');

    print('  Business logic result:');
    print('  $result');
    print('\n  This demonstrates mixing async (DB) with sync (calculations)');
  } finally {
    engine.dispose();
  }
}

/// Print summary of key takeaways
void printSummary() {
  print('KEY TAKEAWAYS:');
  print('=' * 50);
  print('''
1. Dual-Path Architecture:
   - eval()      : Direct sync callback (zero overhead)
   - evalAsync() : Background thread + request/response (async capable)

2. When to Use Each:
   - eval()      : Sync functions only, maximum performance
   - evalAsync() : Async functions, HTTP, file I/O, database

3. Full Async Support:
   - Register functions with async/await
   - Call Future-returning functions from Rhai scripts
   - Mix sync and async functions in the same script

4. Automatic Detection:
   - eval() detects async functions and provides helpful error
   - Guides users to use evalAsync() when needed

5. Performance:
   - eval()      : Fastest (direct FFI, no overhead)
   - evalAsync() : Slight overhead, worth it for async operations

6. Examples Shown:
   - Sync functions with eval()
   - Async functions with evalAsync()
   - HTTP requests simulation
   - Error handling
   - Concurrent operations
   - Real-world mixed sync/async scenario

For more details, see:
- README.md - Quick start and overview
- docs/ASYNC_FUNCTIONS.md - Complete async guide
- Architecture documentation in docs/
''');
}
