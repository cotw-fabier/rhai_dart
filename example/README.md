# Rhai-Dart Examples

This directory contains comprehensive examples demonstrating all major features of the Rhai-Dart FFI integration library.

## Prerequisites

To run these examples, you need:

1. **Dart SDK** (3.0 or higher)
2. **Rust toolchain** (1.83.0 or higher)
3. **Native assets enabled**

## Running Examples

All examples must be run with the `--enable-experiment=native-assets` flag:

```bash
dart run --enable-experiment=native-assets example/01_simple_execution.dart
```

## Example Overview

### 01_simple_execution.dart
**Beginner | 5 minutes**

Learn the basics of Rhai-Dart:
- Creating an engine with default configuration
- Executing simple scripts
- Handling different return types (int, double, String, bool, List, Map)
- Basic error handling
- Proper resource cleanup with `dispose()`

**Key Concepts:**
- `RhaiEngine.withDefaults()`
- `engine.eval(script)`
- Try-catch error handling
- Resource disposal

**Run:**
```bash
dart run --enable-experiment=native-assets example/01_simple_execution.dart
```

---

### 02_sync_functions.dart
**Intermediate | 10 minutes**

Register Dart functions callable from Rhai scripts:
- Zero-parameter functions
- Multi-parameter functions with type conversion
- Functions returning primitives, lists, and maps
- Functions accepting complex parameters
- Error propagation from Dart to Rhai

**Key Concepts:**
- `engine.registerFunction(name, callback)`
- Type conversion (Dart ↔ Rhai)
- Parameter passing
- Return value handling
- Error propagation

**Run:**
```bash
dart run --enable-experiment=native-assets example/02_sync_functions.dart
```

---

### 03_async_functions.dart
**Advanced | 10 minutes | Reference Only**

Understand async function limitations and best practices:
- Async function registration
- Event loop limitations in FFI callbacks
- Recommended workarounds (pre-fetching data)
- Synchronous alternatives

**Important Note:**
This example documents a known limitation: event-loop-dependent async operations (Future.delayed, HTTP requests, file I/O) cannot complete when called from FFI callbacks. The example shows recommended patterns for handling async data.

**Key Concepts:**
- Async function detection
- Event loop constraints
- Pre-fetching async data
- Using closures with cached data

**Run:**
```bash
dart run --enable-experiment=native-assets example/03_async_functions.dart
```

**See Also:** `docs/ASYNC_FUNCTIONS.md` for detailed explanation

---

### 04_error_handling.dart
**Intermediate | 10 minutes**

Master comprehensive error handling:
- Catching syntax errors with line numbers
- Catching runtime errors with stack traces
- Pattern matching on exception types
- Error propagation from registered functions
- Proper cleanup with try-finally blocks

**Key Concepts:**
- `RhaiSyntaxError` with line numbers
- `RhaiRuntimeError` with stack traces
- `RhaiFFIError` for FFI failures
- Pattern matching on error types
- Finally blocks for cleanup

**Run:**
```bash
dart run --enable-experiment=native-assets example/04_error_handling.dart
```

---

### 05_configuration.dart
**Intermediate | 15 minutes**

Configure engines for security and performance:
- Default secure configuration
- Custom configuration options
- Timeout enforcement
- Operation limit enforcement
- Stack depth limit enforcement
- String length limit enforcement
- Sandboxing features

**Key Concepts:**
- `RhaiConfig.secureDefaults()`
- `RhaiConfig.custom()`
- `RhaiConfig.unlimited()` (development only)
- Security implications of each setting
- Limit enforcement in action

**Run:**
```bash
dart run --enable-experiment=native-assets example/05_configuration.dart
```

---

### 06_complex_workflow.dart
**Advanced | 15 minutes**

Real-world integration example:
- Custom engine configuration
- Multiple registered functions (sync)
- Complex business logic scripts
- Comprehensive error handling
- Data processing pipelines
- Nested data structures
- Proper resource management

**Scenario:** User scoring system for a gamification platform with achievements, leveling, and leaderboards.

**Key Concepts:**
- Real-world usage patterns
- Combining multiple features
- Business logic in scripts
- Data transformation pipelines
- Production-ready error handling

**Run:**
```bash
dart run --enable-experiment=native-assets example/06_complex_workflow.dart
```

---

## Example Progression

We recommend following the examples in order:

1. **Start with:** `01_simple_execution.dart` - Learn the basics
2. **Then:** `02_sync_functions.dart` - Add Dart functions
3. **Review:** `03_async_functions.dart` - Understand async limitations
4. **Master:** `04_error_handling.dart` - Handle errors properly
5. **Configure:** `05_configuration.dart` - Tune performance and security
6. **Integrate:** `06_complex_workflow.dart` - Build real applications

## Common Patterns

### Creating an Engine

```dart
// Default secure configuration
final engine = RhaiEngine.withDefaults();

// Custom configuration
final engine = RhaiEngine.withConfig(
  RhaiConfig.custom(
    maxOperations: 1000000,
    timeoutMs: 5000,
  ),
);
```

### Executing Scripts

```dart
try {
  final result = engine.eval('2 + 2');
  print(result); // 4
} on RhaiSyntaxError catch (e) {
  print('Syntax error at line ${e.lineNumber}: ${e.message}');
} on RhaiRuntimeError catch (e) {
  print('Runtime error: ${e.message}');
} finally {
  engine.dispose();
}
```

### Registering Functions

```dart
// Simple function
engine.registerFunction('add', (int a, int b) => a + b);

// Function with error handling
engine.registerFunction('divide', (num a, num b) {
  if (b == 0) throw Exception('Division by zero');
  return a / b;
});

// Call from script
final result = engine.eval('add(10, 20)'); // 30
```

### Error Handling

```dart
try {
  engine.eval(script);
} on RhaiSyntaxError catch (e) {
  // Handle syntax errors
  print('Fix syntax at line ${e.lineNumber}');
} on RhaiRuntimeError catch (e) {
  // Handle runtime errors
  print('Runtime error: ${e.message}');
} on RhaiFFIError catch (e) {
  // Handle FFI errors
  print('FFI error: ${e.message}');
}
```

## Type Conversion Reference

| Rhai Type | Dart Type | Example |
|-----------|-----------|---------|
| Integer | `int` | `42` |
| Float | `double` | `3.14` |
| Boolean | `bool` | `true` |
| String | `String` | `"hello"` |
| Array | `List<dynamic>` | `[1, 2, 3]` |
| Object/Map | `Map<String, dynamic>` | `#{key: "value"}` |
| Unit/void | `null` | `()` |

See `docs/type_conversion.md` for detailed type conversion documentation.

## Security Best Practices

1. **Use secure defaults** for untrusted scripts:
   ```dart
   final engine = RhaiEngine.withDefaults();
   ```

2. **Set appropriate timeouts** to prevent infinite loops:
   ```dart
   final config = RhaiConfig.custom(timeoutMs: 5000);
   ```

3. **Limit operations** for resource control:
   ```dart
   final config = RhaiConfig.custom(maxOperations: 1000000);
   ```

4. **Validate input** from registered functions:
   ```dart
   engine.registerFunction('process', (int value) {
     if (value < 0) throw ArgumentError('Value must be positive');
     return value * 2;
   });
   ```

5. **Always dispose engines** or use try-finally:
   ```dart
   final engine = RhaiEngine.withDefaults();
   try {
     // Use engine
   } finally {
     engine.dispose();
   }
   ```

## Troubleshooting

### Native library not found

Ensure you're using the `--enable-experiment=native-assets` flag and that the Rust library has been compiled:

```bash
dart pub get
dart run --enable-experiment=native-assets example/01_simple_execution.dart
```

### Script timeout

Increase the timeout or reduce script complexity:

```dart
final config = RhaiConfig.custom(timeoutMs: 10000); // 10 seconds
```

### Operation limit exceeded

Increase the operation limit or optimize the script:

```dart
final config = RhaiConfig.custom(maxOperations: 5000000);
```

### Async functions don't work

See `03_async_functions.dart` and `docs/ASYNC_FUNCTIONS.md`. Pre-fetch async data before calling `eval()`:

```dart
// Good: Pre-fetch data
final data = await fetchData();
engine.registerFunction('getData', () => data);

// Bad: Async in callback (won't work)
engine.registerFunction('getData', () async {
  return await fetchData(); // Will hang
});
```

## Additional Resources

- **API Documentation:** Run `dart doc` to generate full API documentation
- **Type Conversion Guide:** `docs/type_conversion.md`
- **Async Functions Guide:** `docs/ASYNC_FUNCTIONS.md`
- **Platform Support:** See main `README.md` for platform compatibility
- **Rhai Language Guide:** https://rhai.rs/book/

## Contributing Examples

If you have a useful example to contribute:

1. Follow the existing example format
2. Include clear comments explaining each step
3. Demonstrate a specific use case or feature
4. Test thoroughly on all supported platforms
5. Update this README with your example description

## License

These examples are part of the rhai_dart package and are distributed under the same license.
