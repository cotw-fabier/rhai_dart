# Type Conversion Reference

This document provides a comprehensive reference for type conversion between Dart and Rhai in the rhai_dart library.

## Overview

The rhai_dart library automatically converts values between Dart and Rhai types using JSON as an intermediate representation. This ensures type safety and handles complex nested structures seamlessly.

## Type Conversion Table

### Dart to Rhai (Function Parameters and Script Input)

| Dart Type | Rhai Type | Example | Notes |
|-----------|-----------|---------|-------|
| `int` | `i64` | `42` | 64-bit signed integer |
| `double` | `f64` | `3.14` | 64-bit floating point |
| `bool` | `bool` | `true` | Boolean value |
| `String` | `String` | `"hello"` | UTF-8 encoded string |
| `null` | `()` (unit) | `null` | Represents absence of value |
| `List<dynamic>` | `Array` | `[1, 2, 3]` | Dynamic array, supports nesting |
| `Map<String, dynamic>` | `Map` | `#{a: 1, b: 2}` | Object map with string keys |

### Rhai to Dart (Script Results and Function Returns)

| Rhai Type | Dart Type | Example | Notes |
|-----------|-----------|---------|-------|
| `i64` | `int` | `42` | 64-bit signed integer |
| `f64` | `double` | `3.14` | 64-bit floating point |
| `bool` | `bool` | `true` | Boolean value |
| `String` | `String` | `"hello"` | UTF-8 string |
| `()` (unit) | `null` | `null` | Void/empty value |
| `Array` | `List<dynamic>` | `[1, 2, 3]` | Dynamic list, recursively converted |
| `Map` | `Map<String, dynamic>` | `{a: 1, b: 2}` | Map with string keys |

## Special Float Values

The library supports special IEEE 754 floating-point values with custom encoding:

| Dart Value | Rhai Value | JSON Encoding | Notes |
|------------|------------|---------------|-------|
| `double.infinity` | Positive infinity | `"__INFINITY__"` | Represents positive infinity |
| `double.negativeInfinity` | Negative infinity | `"__NEG_INFINITY__"` | Represents negative infinity |
| `double.nan` | NaN | `"__NAN__"` | Represents "Not a Number" |

## Nested Structures

The library supports arbitrary nesting of lists and maps:

### Example: Nested List
```dart
// Dart
final nested = [[1, 2], [3, 4], [5, 6]];

// Rhai
let nested = [[1, 2], [3, 4], [5, 6]];
```

### Example: Nested Map
```dart
// Dart
final nested = {
  'user': {
    'name': 'Alice',
    'age': 30,
    'address': {
      'city': 'NYC',
      'zip': '10001'
    }
  }
};

// Rhai
let nested = #{
  user: #{
    name: "Alice",
    age: 30,
    address: #{
      city: "NYC",
      zip: "10001"
    }
  }
};
```

### Example: Mixed Nesting
```dart
// Dart
final mixed = {
  'items': [
    {'id': 1, 'tags': ['a', 'b']},
    {'id': 2, 'tags': ['c', 'd']}
  ]
};

// Rhai
let mixed = #{
  items: [
    #{id: 1, tags: ["a", "b"]},
    #{id: 2, tags: ["c", "d"]}
  ]
};
```

## Edge Cases and Limitations

### Integer Range

- **Rhai**: Uses `i64` (signed 64-bit integer) with range: -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807
- **Dart**: Uses `int` which is 64-bit on native platforms
- **Limitation**: Values outside the `i64` range will overflow or cause errors

Example:
```dart
// Safe
engine.eval('9223372036854775807'); // i64 max value

// Unsafe - may overflow
engine.eval('9223372036854775808'); // Exceeds i64 max
```

### Floating Point Precision

- Both Dart and Rhai use IEEE 754 double-precision (64-bit) floating-point
- Precision is approximately 15-17 significant decimal digits
- Very small or very large numbers may lose precision

Example:
```dart
engine.eval('0.1 + 0.2'); // Returns 0.30000000000000004 (IEEE 754 behavior)
```

### Unicode Strings

- Full Unicode support via UTF-8 encoding
- Emoji and multi-byte characters are fully supported
- String length limits apply to byte count, not character count

Example:
```dart
engine.eval('"Hello 世界 🌍"'); // Fully supported
```

### Empty Collections

- Empty lists and maps are fully supported
- They maintain their type information

Example:
```dart
engine.eval('[]');     // Returns empty List<dynamic>
engine.eval('#{}');    // Returns empty Map<String, dynamic>
```

### Null Values

- Rhai's unit type `()` converts to Dart's `null`
- Null values in lists and maps are preserved

Example:
```dart
engine.eval('[1, (), 3]'); // Returns [1, null, 3]
```

### Map Key Types

- **Limitation**: Only string keys are supported in maps
- Rhai maps can have non-string keys, but they will be converted to strings

Example:
```dart
// Dart to Rhai: Only string keys allowed
final map = {'key1': 1, 'key2': 2}; // OK

// Rhai to Dart: Non-string keys converted to strings
engine.eval('#{1: "one", 2: "two"}'); // Keys become "1" and "2"
```

## Type Conversion in Practice

### Script Evaluation Results

When you call `engine.eval()`, the script's final expression is converted to a Dart type:

```dart
// Returns int
final a = engine.eval('40 + 2'); // 42

// Returns double
final b = engine.eval('3.14 * 2.0'); // 6.28

// Returns String
final c = engine.eval('"hello" + " " + "world"'); // "hello world"

// Returns bool
final d = engine.eval('10 > 5'); // true

// Returns List<dynamic>
final e = engine.eval('[1, 2, 3]'); // [1, 2, 3]

// Returns Map<String, dynamic>
final f = engine.eval('#{x: 10, y: 20}'); // {x: 10, y: 20}

// Returns null
final g = engine.eval('()'); // null
```

### Function Parameters

When Rhai calls a registered Dart function, parameters are automatically converted:

```dart
final engine = RhaiEngine.withDefaults();

// Register function with various parameter types
engine.registerFunction('processData', (int id, String name, List<dynamic> tags) {
  print('ID: $id, Name: $name, Tags: $tags');
  return {'success': true, 'id': id};
});

// Call from Rhai - automatic conversion
engine.eval('processData(42, "Alice", ["admin", "user"])');
// Output: ID: 42, Name: Alice, Tags: [admin, user]
```

### Function Return Values

When a Dart function returns a value to Rhai, it's automatically converted:

```dart
final engine = RhaiEngine.withDefaults();

// Register function that returns various types
engine.registerFunction('getData', () {
  return {
    'users': [
      {'id': 1, 'name': 'Alice'},
      {'id': 2, 'name': 'Bob'}
    ],
    'count': 2
  };
});

// Use in Rhai
final result = engine.eval('''
  let data = getData();
  data.users[0].name  // "Alice"
''');
print(result); // "Alice"
```

## Type Conversion Errors

### When Type Conversion Fails

The library throws clear exceptions when type conversion fails:

```dart
try {
  // Invalid: Custom Dart objects cannot be converted
  engine.registerFunction('invalid', () => DateTime.now());
  engine.eval('invalid()');
} catch (e) {
  print(e); // Type conversion error
}
```

### Unsupported Types

The following Dart types **cannot** be converted and will cause errors:

- Custom classes (e.g., `User`, `DateTime`, `Duration`)
- Functions and closures
- Symbols
- Type objects
- Stream objects

**Workaround**: Serialize custom objects to maps before returning:

```dart
class User {
  final int id;
  final String name;

  User(this.id, this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

engine.registerFunction('getUser', () {
  final user = User(1, 'Alice');
  return user.toJson(); // Convert to Map before returning
});
```

## Performance Considerations

### Conversion Overhead

- Primitive types (int, double, bool, String) have minimal conversion overhead
- Complex nested structures require JSON serialization/deserialization
- Very deep nesting (>10 levels) may impact performance

### Best Practices

1. **Use primitives when possible**: `int`, `double`, `bool`, `String` are fastest
2. **Limit nesting depth**: Keep structures flat for better performance
3. **Avoid large collections**: Lists/maps with thousands of items may be slow
4. **Pre-convert complex objects**: Convert custom objects to maps once, not per-call

Example optimization:
```dart
// Slow: Converts complex object on every call
engine.registerFunction('getConfig', () => complexObject.toJson());

// Fast: Convert once, cache the result
final configJson = complexObject.toJson();
engine.registerFunction('getConfig', () => configJson);
```

## Bidirectional Roundtrip Conversion

Values can roundtrip between Dart and Rhai without loss of information for supported types:

```dart
final engine = RhaiEngine.withDefaults();

// Dart → Rhai → Dart
engine.registerFunction('identity', (dynamic value) => value);

final original = {
  'int': 42,
  'double': 3.14,
  'bool': true,
  'string': 'hello',
  'null': null,
  'list': [1, 2, 3],
  'map': {'nested': true}
};

final result = engine.eval('identity(...)'); // Pass original
assert(result == original); // Perfect roundtrip for supported types
```

## Summary

- **Supported Types**: Primitives (int, double, bool, String), null, List, Map
- **Nested Structures**: Fully supported with arbitrary depth
- **Special Values**: Infinity, -Infinity, NaN are supported
- **Limitations**: String keys only for maps, no custom objects
- **Performance**: Best for primitives, acceptable for moderate nesting
- **Errors**: Clear exceptions for unsupported types

For more information, see:
- [API Documentation](../README.md)
- [Error Handling Guide](../README.md#error-handling)
- [Examples](../example/)
