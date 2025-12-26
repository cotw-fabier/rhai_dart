# Async Function Support in Rhai-Dart

## Current Status: Limited Support

**IMPORTANT**: Async function support in Rhai-Dart is currently **limited** due to fundamental constraints in Dart's FFI callback system. While the infrastructure for detecting and handling async functions is in place, **async functions cannot reliably complete** in the current architecture.

## Technical Limitation

The core issue is that **Dart's event loop cannot run while inside a synchronous FFI callback**:

1. Rhai calls Rust FFI function (synchronous)
2. Rust calls Dart NativeCallable (synchronous callback)
3. Dart callback invokes the user's async function
4. The function returns a Future, but we're still in the synchronous callback
5. Event loop is blocked during the callback → Future cannot complete
6. Timeout occurs

### Why This Matters

Common async operations that **will not work**:
- `Future.delayed()` - timers cannot fire
- HTTP requests - I/O operations cannot complete
- File I/O - reads/writes cannot finish
- Database queries - async drivers cannot return results
- Any operation that requires event loop processing

## Current Implementation

The current implementation includes:

### Detection and Handling

```dart
// Async functions ARE detected
engine.registerFunction('asyncFunc', () async {
  await Future.delayed(Duration(seconds: 1));
  return 'result';
});

// But calling them will timeout
try {
  engine.eval('asyncFunc()'); // WILL TIMEOUT
} catch (e) {
  print(e); // "Async function timeout after 30 seconds"
}
```

### What Works

- **Sync functions**: Work perfectly
- **Immediately returning values**: Sync functions can return any value
- **Complex data structures**: Lists, maps, nested objects all work

```dart
// ✅ This works great
engine.registerFunction('getData', () {
  return {'key': 'value', 'numbers': [1, 2, 3]};
});

// ✅ This also works
engine.registerFunction('processSync', (List data) {
  return data.map((x) => x * 2).toList();
});
```

### What Doesn't Work

- **Any async function**: Functions returning `Future<T>` will timeout
- **Event-based operations**: Anything requiring the event loop
- **Delayed computations**: Cannot wait for timers or delays

```dart
// ❌ This will timeout
engine.registerFunction('fetchData', () async {
  await Future.delayed(Duration(milliseconds: 100));
  return 'data';
});

// ❌ This will also timeout
engine.registerFunction('httpGet', (String url) async {
  final response = await http.get(Uri.parse(url));
  return response.body;
});
```

## Potential Future Solutions

Several approaches could enable proper async support:

### Solution 1: Rust Thread Pool

**Concept**: Spawn a Rust thread to handle the callback, allowing Dart's main thread to process the event loop.

**Pros**:
- Least impact on API design
- Transparent to users
- Allows natural async Dart code

**Cons**:
- Requires thread-safe Dart callback mechanism
- Complex cross-thread coordination
- May have performance overhead

**Implementation**:
```rust
// Pseudo-code
fn call_dart_callback() {
    thread::spawn(|| {
        // Call Dart from background thread
        // Dart main thread can process event loop
        let result = dart_callback();
        result
    }).join()
}
```

### Solution 2: Isolate Ports

**Concept**: Use SendPort/ReceivePort for async message passing between isolates.

**Pros**:
- Native Dart async mechanism
- Clean separation of concerns
- Natural for Dart developers

**Cons**:
- Requires API redesign
- More complex setup
- Higher latency for simple calls

**Implementation**:
```dart
// Pseudo-code
final port = ReceivePort();
rustSendRequest(port.sendPort, request);
final result = await port.first;
```

### Solution 3: Async-First API

**Concept**: Make the entire eval() API async, allowing natural async throughout.

**Pros**:
- Most Dart-idiomatic approach
- Simplest for async operations
- No FFI callback limitations

**Cons**:
- Breaking API change
- Requires async Rust (tokio)
- All scripts become async even for sync operations

**Implementation**:
```dart
// New API
final result = await engine.evalAsync('myScript()');
```

### Solution 4: Callback Queue

**Concept**: Queue async function calls and process them after script execution.

**Pros**:
- Minimal API changes
- Works for certain use cases

**Cons**:
- Very complex to implement
- Doesn't work for all scenarios
- Confusing execution model

## Recommendations

### For Current Users

**Use synchronous functions** whenever possible:

```dart
// Instead of this (won't work):
engine.registerFunction('fetchUser', (int id) async {
  final data = await database.getUserById(id);
  return data;
});

// Do this:
engine.registerFunction('fetchUser', (int id) {
  // Pre-fetch data before eval(), or use sync data source
  return cachedUsers[id];
});
```

**Pre-compute async data**:

```dart
// Fetch data before creating/using engine
final users = await fetchAllUsers();

// Register sync function that uses pre-fetched data
engine.registerFunction('getUser', (int id) {
  return users[id];
});
```

**Use synchronous alternatives**:

```dart
// Instead of async HTTP:
// - Use sync HTTP library (if available)
// - Pre-fetch all needed data
// - Use cached/mocked data

// Instead of async file I/O:
// - Read files before eval()
// - Use in-memory data
// - Provide file contents as parameters
```

### For Future Development

The most promising solution for full async support is **Solution 1 (Rust Thread Pool)**, as it:
- Preserves the current API
- Enables natural async Dart code
- Has precedent in other FFI libraries

Implementation would require:
1. Rust thread pool for callback handling
2. Thread-safe Dart callback invocation
3. Proper synchronization primitives
4. Extensive testing for race conditions

## Current Code Structure

The async handling infrastructure exists but is limited:

### Dart Side (callback_bridge.dart)

```dart
// Detects Future return values
if (result is Future) {
  // Attempts to wait synchronously (won't work)
  final syncResult = _syncWaitForFuture(result);
  return _encodeResult(syncResult);
}
```

### Implementation

```dart
T _syncWaitForFuture<T>(Future<T> future) {
  // Polls for completion
  // Event loop cannot run → Future cannot complete
  // Eventually times out after 30 seconds
}
```

This infrastructure is in place for when a proper solution is implemented.

## See Also

- [Function Registration Guide](./FUNCTION_REGISTRATION.md)
- [Sync Function Examples](../example/function_registration_example.dart)
- [Error Handling Guide](./ERROR_HANDLING.md)
- [Test Suite](../test/async_function_test.dart) - Documents the limitations

## Contributing

If you're interested in implementing proper async support, please:
1. Review the potential solutions above
2. Open an issue to discuss the approach
3. Consider the thread-safety implications
4. Provide test cases for various async scenarios

Async support is a high-priority feature for future development.
