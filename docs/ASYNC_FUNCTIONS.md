# Async Function Support in Rhai-Dart

## Overview: Full Async Support with Dual-Path Architecture

rhai_dart now provides **complete async function support** through a dual-path architecture that handles both synchronous and asynchronous Dart functions seamlessly.

### Key Features

- **Full async support**: Call async Dart functions from Rhai scripts (HTTP requests, file I/O, database queries, etc.)
- **Two execution paths**: Optimized for different use cases
  - `eval()` - Direct synchronous execution (zero overhead)
  - `evalAsync()` - Background thread execution (async capable)
- **Automatic detection**: Sync path detects async functions and provides helpful error messages
- **Thread-safe**: Request/response pattern ensures safe cross-thread communication
- **Event loop friendly**: Never blocks Dart's event loop

## Section 1: Understanding the Dual-Path Architecture

rhai_dart uses two distinct execution paths, each optimized for specific scenarios:

### Path 1: eval() - Synchronous Execution

**Best for:** Scripts that call only synchronous functions

```dart
final engine = RhaiEngine.withDefaults();
engine.registerFunction('calculate', (int x) => x * 2);

// Fast, direct execution
final result = engine.eval('calculate(21)'); // Returns: 42
```

**How it works:**
1. Script runs on the same thread (Dart isolate main thread)
2. Function calls use direct FFI callbacks (no thread crossing)
3. Zero overhead - fastest possible execution
4. Automatically detects if an async function is called

**Limitations:**
- Cannot call async functions
- Throws helpful error if async function detected

### Path 2: evalAsync() - Asynchronous Execution

**Best for:** Scripts that call async functions

```dart
final engine = RhaiEngine.withDefaults();
engine.registerFunction('fetchData', () async {
  await Future.delayed(Duration(milliseconds: 100));
  return {'status': 'success'};
});

// Async-capable execution
final result = await engine.evalAsync('fetchData()');
```

**How it works:**
1. Script runs on a background thread (Tokio-spawned)
2. Function calls use request/response pattern
3. Dart event loop remains free to process async operations
4. Works with both sync AND async functions

**Characteristics:**
- Slight overhead for message passing
- Full async function support
- Never blocks event loop
- Thread-safe communication

## Section 2: Using eval() with Sync Functions

The `eval()` method provides the fastest execution path for synchronous functions.

### Basic Synchronous Functions

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  final engine = RhaiEngine.withDefaults();

  // Register sync functions
  engine.registerFunction('add', (int a, int b) => a + b);
  engine.registerFunction('multiply', (int a, int b) => a * b);
  engine.registerFunction('getConfig', () => {'debug': true, 'version': '1.0'});

  try {
    // Execute with eval() - zero overhead
    final result = engine.eval('''
      let x = add(10, 20);
      let y = multiply(x, 2);
      let config = getConfig();
      #{result: y, debug: config.debug}
    ''');

    print(result); // {result: 60, debug: true}
  } finally {
    engine.dispose();
  }
}
```

### Complex Return Types

Sync functions can return any JSON-serializable type:

```dart
engine.registerFunction('getUserData', (int userId) {
  return {
    'id': userId,
    'name': 'Alice',
    'roles': ['admin', 'editor'],
    'settings': {
      'theme': 'dark',
      'notifications': true
    }
  };
});

final result = engine.eval('getUserData(123)');
// Returns complex nested structure
```

### Error Detection for Async Functions

If you accidentally call an async function with `eval()`, you'll get a clear error:

```dart
engine.registerFunction('asyncFunc', () async {
  await Future.delayed(Duration(milliseconds: 10));
  return 'data';
});

try {
  // This will throw an error
  engine.eval('asyncFunc()');
} on RhaiRuntimeError catch (e) {
  print(e.message);
  // "Async function detected. Use evalAsync() to call async functions."
}
```

### Performance Characteristics

- **Zero overhead**: Direct FFI callback on same thread
- **No thread switching**: Runs on Dart isolate main thread
- **No message passing**: Direct function invocation
- **Best for**: High-frequency function calls, pure computation, data transformations

## Section 3: Using evalAsync() with Async Functions

The `evalAsync()` method enables full async function support through a background thread and request/response pattern.

### Basic Async Functions

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() async {
  final engine = RhaiEngine.withDefaults();

  // Register async function
  engine.registerFunction('delay', (int ms) async {
    await Future.delayed(Duration(milliseconds: ms));
    return 'completed after ${ms}ms';
  });

  try {
    // Use evalAsync() for async functions
    final result = await engine.evalAsync('delay(100)');
    print(result); // "completed after 100ms"
  } finally {
    engine.dispose();
  }
}
```

### Real-World Example: HTTP Requests

```dart
import 'package:http/http.dart' as http;
import 'package:rhai_dart/rhai_dart.dart';
import 'dart:convert';

void main() async {
  final engine = RhaiEngine.withDefaults();

  // Register HTTP GET function
  engine.registerFunction('httpGet', (String url) async {
    final response = await http.get(Uri.parse(url));
    return jsonDecode(response.body);
  });

  try {
    // Call from Rhai script
    final result = await engine.evalAsync('''
      let data = httpGet("https://api.example.com/users/1");
      #{
        name: data.name,
        email: data.email
      }
    ''');

    print(result);
  } finally {
    engine.dispose();
  }
}
```

### Mixing Sync and Async Functions

`evalAsync()` works with BOTH sync and async functions:

```dart
void main() async {
  final engine = RhaiEngine.withDefaults();

  // Mix of sync and async functions
  engine.registerFunction('syncCalc', (int x) => x * 2);

  engine.registerFunction('asyncFetch', (String key) async {
    await Future.delayed(Duration(milliseconds: 50));
    return 'value_for_$key';
  });

  try {
    // evalAsync() handles both
    final result = await engine.evalAsync('''
      let x = syncCalc(21);           // Sync function
      let data = asyncFetch("user");   // Async function
      #{computed: x, fetched: data}
    ''');

    print(result); // {computed: 42, fetched: value_for_user}
  } finally {
    engine.dispose();
  }
}
```

### File I/O Example

```dart
import 'dart:io';

void main() async {
  final engine = RhaiEngine.withDefaults();

  // Async file operations
  engine.registerFunction('readFile', (String path) async {
    return await File(path).readAsString();
  });

  engine.registerFunction('writeFile', (String path, String content) async {
    await File(path).writeAsString(content);
    return 'success';
  });

  try {
    final result = await engine.evalAsync('''
      let content = readFile("/tmp/input.txt");
      let status = writeFile("/tmp/output.txt", content + " processed");
      #{status: status, length: content.len()}
    ''');

    print(result);
  } finally {
    engine.dispose();
  }
}
```

### Concurrent Async Operations

You can run multiple `evalAsync()` calls concurrently:

```dart
void main() async {
  final engine = RhaiEngine.withDefaults();

  engine.registerFunction('fetchUser', (int id) async {
    await Future.delayed(Duration(milliseconds: 50));
    return {'id': id, 'name': 'User$id'};
  });

  // Run multiple evals concurrently
  final results = await Future.wait([
    engine.evalAsync('fetchUser(1)'),
    engine.evalAsync('fetchUser(2)'),
    engine.evalAsync('fetchUser(3)'),
  ]);

  print(results);
  // [
  //   {id: 1, name: User1},
  //   {id: 2, name: User2},
  //   {id: 3, name: User3}
  // ]

  engine.dispose();
}
```

### Error Handling in Async Functions

Exceptions from async functions are properly propagated:

```dart
engine.registerFunction('riskyOperation', () async {
  await Future.delayed(Duration(milliseconds: 10));
  throw Exception('Something went wrong');
});

try {
  await engine.evalAsync('riskyOperation()');
} on RhaiRuntimeError catch (e) {
  print('Caught error: ${e.message}');
  // Error includes the exception message
}
```

## Section 4: Migration Guide

### Migrating from eval() to evalAsync()

If you need to add async function support to existing code:

**Before (sync only):**
```dart
void main() {
  final engine = RhaiEngine.withDefaults();

  engine.registerFunction('getData', () {
    return cachedData; // Sync data only
  });

  final result = engine.eval('getData()');
  engine.dispose();
}
```

**After (with async):**
```dart
void main() async {  // Make main async
  final engine = RhaiEngine.withDefaults();

  engine.registerFunction('getData', () async {  // Add async
    return await fetchLiveData();  // Now can use async operations
  });

  final result = await engine.evalAsync('getData()');  // Use evalAsync + await
  engine.dispose();
}
```

### Decision Flowchart

```
Do any of your registered functions return Future<T>?
    |
    ├─ YES ──> Use evalAsync()
    |
    └─ NO ──> Do you need maximum performance?
               |
               ├─ YES ──> Use eval()
               |
               └─ NO ──> Either works, but eval() is faster
```

### Common Migration Scenarios

#### Scenario 1: Adding HTTP Requests

```dart
// BEFORE: Cached data
engine.registerFunction('getWeather', () {
  return {'temp': 72, 'condition': 'sunny'};
});
final result = engine.eval('getWeather()');

// AFTER: Live HTTP requests
engine.registerFunction('getWeather', (String city) async {
  final response = await http.get(Uri.parse('https://api.weather.com/$city'));
  return jsonDecode(response.body);
});
final result = await engine.evalAsync('getWeather("Seattle")');
```

#### Scenario 2: Adding Database Queries

```dart
// BEFORE: In-memory data
final users = [{'id': 1, 'name': 'Alice'}];
engine.registerFunction('getUser', (int id) {
  return users.firstWhere((u) => u['id'] == id);
});

// AFTER: Real database queries
engine.registerFunction('getUser', (int id) async {
  return await database.query('SELECT * FROM users WHERE id = ?', [id]);
});
final result = await engine.evalAsync('getUser(1)');
```

#### Scenario 3: Mixing Old and New Functions

```dart
// Keep existing sync functions
engine.registerFunction('calculate', (int x) => x * 2);

// Add new async functions
engine.registerFunction('fetchData', () async {
  return await http.get(Uri.parse('...'));
});

// Use evalAsync() - works with both
final result = await engine.evalAsync('''
  let computed = calculate(21);   // Old sync function
  let fetched = fetchData();      // New async function
  #{computed: computed, fetched: fetched}
''');
```

## Section 5: Troubleshooting

### Error: "Async function detected. Use evalAsync() instead."

**Cause:** You're calling an async function from `eval()`

**Solution:** Switch to `evalAsync()`

```dart
// WRONG
engine.registerFunction('asyncFunc', () async => 'data');
engine.eval('asyncFunc()'); // ERROR

// CORRECT
engine.registerFunction('asyncFunc', () async => 'data');
await engine.evalAsync('asyncFunc()'); // WORKS
```

### Error: "This expression has type 'void'"

**Cause:** Forgot to `await` the `evalAsync()` call

**Solution:** Add `await` and make containing function `async`

```dart
// WRONG
void main() {
  final result = engine.evalAsync('script'); // Error
}

// CORRECT
void main() async {
  final result = await engine.evalAsync('script'); // Works
}
```

### Issue: Script Seems to Hang

**Possible Causes:**
1. **Infinite loop in async function** - Check your async function logic
2. **Network timeout** - HTTP request taking too long
3. **Deadlock** - Circular dependency in function calls

**Debugging:**
```dart
// Add timeout to async operations
engine.registerFunction('fetchWithTimeout', (String url) async {
  return await http.get(Uri.parse(url))
    .timeout(Duration(seconds: 5));
});

// Or use engine timeout config
final config = RhaiConfig.custom(timeoutMs: 10000); // 10 seconds
final engine = RhaiEngine.withConfig(config);
```

### Issue: "Function not found" Error

**Cause:** Typo in function name or function not registered

**Solution:** Double-check function names match exactly

```dart
// Register
engine.registerFunction('myFunction', () => 42);

// Call - must match exactly (case-sensitive)
engine.eval('myFunction()'); // Correct
engine.eval('myfunction()'); // ERROR: not found
engine.eval('my_function()'); // ERROR: not found
```

### Performance: evalAsync() Seems Slow

**Expected:** `evalAsync()` has slight overhead for message passing (typically 1-10ms)

**When it's a problem:**
- High-frequency function calls (>1000/sec)
- Very simple computations
- No actual async operations

**Solution:** Use `eval()` if all functions are truly synchronous

```dart
// If this is your use case:
engine.registerFunction('add', (int a, int b) => a + b);

// Then use eval() instead of evalAsync() for better performance
final result = engine.eval('add(1, 2)'); // Faster than evalAsync
```

### Debugging Request/Response Flow

Enable verbose logging to see the request/response pattern:

```dart
// In your async function
engine.registerFunction('debugFunc', (String input) async {
  print('[DART] Function called with: $input');
  await Future.delayed(Duration(milliseconds: 10));
  print('[DART] Function returning');
  return 'result';
});

final result = await engine.evalAsync('debugFunc("test")');
// Observe the execution flow in logs
```

## Best Practices

### 1. Choose the Right Execution Method

```dart
// Use eval() for sync-only scripts (fastest)
engine.registerFunction('compute', (int x) => x * 2);
final result = engine.eval('compute(21)');

// Use evalAsync() when you need async (flexibility)
engine.registerFunction('fetch', () async => await http.get(...));
final result = await engine.evalAsync('fetch()');
```

### 2. Handle Errors Gracefully

```dart
engine.registerFunction('riskyOperation', () async {
  try {
    return await someDangerousOperation();
  } catch (e) {
    // Return error info instead of throwing
    return {'error': true, 'message': e.toString()};
  }
});
```

### 3. Use Timeouts for Network Operations

```dart
engine.registerFunction('httpGet', (String url) async {
  return await http.get(Uri.parse(url))
    .timeout(Duration(seconds: 5));
});
```

### 4. Optimize for Your Use Case

```dart
// High-frequency, sync-only: Use eval()
for (var i = 0; i < 1000; i++) {
  engine.eval('calculate($i)'); // Fast
}

// Occasional async operations: Use evalAsync()
for (var item in items) {
  await engine.evalAsync('processItem("$item")'); // Async-capable
}
```

### 5. Document Your Functions

```dart
/// Fetches user data from the API.
/// This is an async function - use with evalAsync() only.
engine.registerFunction('fetchUser', (int id) async {
  return await api.getUser(id);
});

/// Calculates tax on a price.
/// This is a sync function - works with both eval() and evalAsync().
engine.registerFunction('calculateTax', (double price) {
  return price * 0.08;
});
```

## Architecture Deep-Dive

### Sync Path (eval()) Internals

```
1. Dart: engine.eval("script")
2. FFI: Call rhai_eval()
3. Rust: engine.eval() executes
4. Rust: Script encounters function call
5. Rust: invoke_dart_callback_sync() - direct FFI call
6. Dart: Callback executes on same thread
7. Dart: If Future detected, return "pending" status
8. Rust: Check ASYNC_FUNCTION_INVOKED flag
9. Rust: If set, throw error "Use evalAsync()"
10. Dart: Receive error or result
```

### Async Path (evalAsync()) Internals

```
1. Dart: engine.evalAsync("script")
2. FFI: Call rhai_eval_async_start()
3. Rust: Spawn background thread
4. Rust: Set IN_ASYNC_EVAL mode flag
5. Rust: engine.eval() executes on background thread
6. Rust: Script encounters function call
7. Rust: Post request to PENDING_FUNCTION_REQUESTS queue
8. Dart: Poll loop detects request
9. Dart: Execute function (can await if async!)
10. Dart: Post result to oneshot channel
11. Rust: Receive result, resume script
12. Rust: Complete and post to ASYNC_EVAL_RESULTS
13. Dart: Poll loop detects completion
14. Dart: Return result to user
```

### Thread-Local Mode Flag

The `IN_ASYNC_EVAL` thread-local flag determines callback routing:

```rust
// Simplified conceptual code
thread_local! {
    static IN_ASYNC_EVAL: Cell<bool> = Cell::new(false);
}

fn invoke_callback() {
    if IN_ASYNC_EVAL.get() {
        // Use request/response pattern
        use_request_response_pattern();
    } else {
        // Use direct synchronous callback
        use_direct_callback();
    }
}
```

This ensures each execution path uses the appropriate callback mechanism.

## See Also

- [README.md](../README.md) - Quick start and overview
- [Architecture Guide](./architecture.md) - Detailed FFI architecture
- [Type Conversion Guide](./type_conversion.md) - Type mapping reference
- [Examples](../example/) - Working code examples
- [Test Suite](../test/eval_async_test.dart) - Comprehensive test cases

## Summary

rhai_dart's dual-path architecture provides:

- **Full async support** through `evalAsync()` - call HTTP, file I/O, database, any async operation
- **Maximum performance** through `eval()` - zero overhead for sync-only scripts
- **Clear error messages** - automatic detection guides you to the right method
- **Thread safety** - request/response pattern ensures safe communication
- **Event loop friendly** - never blocks Dart's event loop

Choose `eval()` for speed, `evalAsync()` for flexibility, and enjoy seamless integration between Rhai scripts and Dart's async ecosystem!
