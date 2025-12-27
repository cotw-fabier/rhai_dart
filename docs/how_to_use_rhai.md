# How to Use rhai_dart: Best Practices Guide for AI Agents

This guide provides comprehensive best practices for using the rhai_dart package to embed the Rhai scripting engine in Dart applications.

## Table of Contents

- [Quick Overview](#quick-overview)
- [Core Concepts](#core-concepts)
- [Basic Usage Patterns](#basic-usage-patterns)
- [Choosing Between eval() and evalAsync()](#choosing-between-eval-and-evalasync)
- [Registering Dart Functions](#registering-dart-functions)
- [Type Conversion Best Practices](#type-conversion-best-practices)
- [Security Guidelines](#security-guidelines)
- [Error Handling](#error-handling)
- [Performance Optimization](#performance-optimization)
- [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)
- [Template Rendering with Tera](#template-rendering-with-tera)
- [Passing Variables from Dart](#passing-variables-from-dart)
- [Complete Examples](#complete-examples)

## Quick Overview

**rhai_dart** is a Dart FFI library that embeds the Rhai scripting engine, enabling:
- Execution of Rhai scripts from Dart applications
- Bidirectional function calls between Dart and Rhai
- Safe sandboxed script execution with resource limits
- Both synchronous and asynchronous function support

**Key Files:**
- Architecture: docs/architecture.md
- Async Functions: docs/ASYNC_FUNCTIONS.md
- Security: docs/security.md
- Type Conversion: docs/type_conversion.md
- Setup: docs/setup.md

## Core Concepts

### 1. RhaiEngine

The main entry point for script execution. Always dispose when done.

```dart
final engine = RhaiEngine.withDefaults();
try {
  // Use engine
} finally {
  engine.dispose(); // Always dispose to prevent memory leaks
}
```

### 2. Dual Execution Paths

- **eval()**: Fast synchronous execution, throws error if async functions detected
- **evalAsync()**: Background thread execution, supports both sync and async functions

### 3. Type Conversion via JSON

All complex types cross the FFI boundary as JSON strings. Supported types:
- Primitives: `int`, `double`, `bool`, `String`, `null`
- Collections: `List<dynamic>`, `Map<String, dynamic>`
- Special floats: `infinity`, `negativeInfinity`, `nan`

### 4. Security Model

Default configuration is secure by default:
- Sandboxing enabled (no eval, no modules, no file I/O)
- Operation limits (prevents infinite loops)
- Stack depth limits (prevents stack overflow)
- String length limits (prevents memory exhaustion)
- Timeout enforcement (prevents long-running scripts)

## Basic Usage Patterns

### Pattern 1: Simple Script Execution

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  final engine = RhaiEngine.withDefaults();

  try {
    // Execute simple calculation
    final result = engine.eval('2 + 2');
    print(result); // 4

    // Execute script with variables
    final greeting = engine.eval('''
      let name = "World";
      "Hello, " + name + "!"
    ''');
    print(greeting); // "Hello, World!"
  } finally {
    engine.dispose();
  }
}
```

### Pattern 2: Using Registered Functions (Sync)

```dart
void main() {
  final engine = RhaiEngine.withDefaults();

  // Register synchronous function
  engine.registerFunction('multiply', (int a, int b) => a * b);

  try {
    final result = engine.eval('multiply(6, 7)');
    print(result); // 42
  } finally {
    engine.dispose();
  }
}
```

### Pattern 3: Using Registered Functions (Async)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final engine = RhaiEngine.withDefaults();

  // Register async function
  engine.registerFunction('fetchUser', (int id) async {
    final response = await http.get(
      Uri.parse('https://api.example.com/users/$id')
    );
    return jsonDecode(response.body);
  });

  try {
    // MUST use evalAsync for async functions
    final result = await engine.evalAsync('''
      let user = fetchUser(123);
      user.name
    ''');
    print(result);
  } finally {
    engine.dispose();
  }
}
```

## Choosing Between eval() and evalAsync()

### Use eval() when:
- All registered functions are synchronous
- You need maximum performance (zero overhead)
- Scripts contain only pure computation/data transformations

```dart
// Good use of eval()
engine.registerFunction('calculate', (int x) => x * 2);
engine.registerFunction('format', (String s) => s.toUpperCase());

final result = engine.eval('format(calculate(21).toString())'); // "42"
```

### Use evalAsync() when:
- Any registered function is async (returns Future)
- Functions perform I/O (HTTP, file, database)
- You're mixing sync and async functions

```dart
// Must use evalAsync()
engine.registerFunction('fetchData', () async {
  await Future.delayed(Duration(milliseconds: 100));
  return 'data';
});

final result = await engine.evalAsync('fetchData()');
```

### Decision Flowchart
```
Do any registered functions return Future<T>?
  YES → Use evalAsync()
  NO  → Use eval() for better performance
```

## Registering Dart Functions

### Best Practices

#### 1. Validate All Inputs

```dart
// GOOD: Input validation
engine.registerFunction('processOrder', (int orderId, int quantity) {
  // Validate types (Dart is dynamically typed)
  if (orderId is! int || quantity is! int) {
    throw ArgumentError('Invalid types');
  }

  // Validate ranges
  if (orderId <= 0 || quantity <= 0 || quantity > 1000) {
    throw ArgumentError('Invalid values');
  }

  // Process safely
  return processOrder(orderId, quantity);
});
```

#### 2. Return Only Serializable Types

```dart
// BAD: Custom objects cannot be serialized
class User {
  final int id;
  final String name;
  User(this.id, this.name);
}

engine.registerFunction('getUser', () => User(1, 'Alice')); // ERROR!

// GOOD: Return maps/primitives
engine.registerFunction('getUser', () {
  return {'id': 1, 'name': 'Alice'};
});
```

#### 3. Handle Errors Gracefully

```dart
// GOOD: Return error info instead of throwing
engine.registerFunction('riskyOperation', () async {
  try {
    return await performOperation();
  } catch (e) {
    return {'error': true, 'message': e.toString()};
  }
});
```

#### 4. Sanitize Outputs

```dart
// GOOD: Only expose necessary data
engine.registerFunction('getUserInfo', (int userId) {
  final user = database.getUser(userId);

  // Return only public fields
  return {
    'id': user.id,
    'displayName': user.displayName,
    // Omit: passwordHash, email, privateData
  };
});
```

## Type Conversion Best Practices

### Supported Dart → Rhai Conversions

| Dart Type | Rhai Type | Example |
|-----------|-----------|---------|
| `int` | `i64` | `42` |
| `double` | `f64` | `3.14` |
| `bool` | `bool` | `true` |
| `String` | `String` | `"hello"` |
| `null` | `()` | `null` |
| `List<dynamic>` | `Array` | `[1, 2, 3]` |
| `Map<String, dynamic>` | `Map` | `#{a: 1}` |

### Key Limitations

1. **Map keys must be strings**
   ```dart
   // GOOD
   {'key1': 1, 'key2': 2}

   // BAD - will error
   {1: 'value1', 2: 'value2'}
   ```

2. **Only JSON-serializable types**
   ```dart
   // GOOD
   [1, 2.5, "hello", true, null, [1, 2], {'a': 1}]

   // BAD - will error
   [DateTime.now(), Duration(seconds: 5), User(...)]
   ```

3. **Nested structures are supported but keep depth reasonable**
   ```dart
   // GOOD: Moderate nesting (< 10 levels)
   {
     'user': {
       'profile': {
         'settings': {'theme': 'dark'}
       }
     }
   }

   // AVOID: Very deep nesting (> 10 levels) - performance impact
   ```

## Security Guidelines

### For Untrusted Scripts

**Always use RhaiEngine.withDefaults() or strict custom config:**

```dart
// Option 1: Secure defaults
final engine = RhaiEngine.withDefaults();

// Option 2: Custom strict config
final config = RhaiConfig.custom(
  maxOperations: 100000,      // 100k operations max
  maxStackDepth: 50,          // 50 call stack frames
  maxStringLength: 1048576,   // 1 MB strings
  timeoutMs: 1000,            // 1 second timeout
);
final engine = RhaiEngine.withConfig(config);
```

### Critical Security Rules

#### 1. Never Register Dangerous Functions for Untrusted Scripts

```dart
// NEVER DO THIS with untrusted scripts:
engine.registerFunction('exec', (String cmd) {
  return Process.runSync(cmd, []).stdout; // DANGEROUS!
});

engine.registerFunction('readFile', (String path) {
  return File(path).readAsStringSync(); // DANGEROUS!
});
```

#### 2. Apply Principle of Least Privilege

```dart
// GOOD: Minimal, safe API
engine.registerFunction('getConfig', (String key) {
  final allowedKeys = ['appName', 'version', 'theme'];
  if (!allowedKeys.contains(key)) {
    throw ArgumentError('Config key not allowed');
  }
  return config[key];
});
```

#### 3. Validate Script Size

```dart
if (script.length > 100000) { // 100KB limit
  throw ArgumentError('Script too large');
}
```

#### 4. Implement Rate Limiting

```dart
class ScriptExecutor {
  final rateLimiter = RateLimiter();

  Future<dynamic> execute(String userId, String script) async {
    if (!rateLimiter.allowRequest(userId)) {
      throw RateLimitException('Too many requests');
    }

    final engine = RhaiEngine.withDefaults();
    try {
      return engine.eval(script);
    } finally {
      engine.dispose();
    }
  }
}
```

#### 5. Sanitize Error Messages

```dart
try {
  final result = engine.eval(untrustedScript);
} on RhaiException catch (e) {
  // Log detailed error for debugging
  logger.error('Script error: ${e.toString()}');

  // Return generic error to user
  return 'Script execution failed'; // Don't leak details
}
```

## Error Handling

### Exception Types

```dart
sealed class RhaiException implements Exception {
  final String message;
}

class RhaiSyntaxError extends RhaiException {
  final int? lineNumber;
}

class RhaiRuntimeError extends RhaiException {
  final String? stackTrace;
}

class RhaiFFIError extends RhaiException { }
```

### Comprehensive Error Handling Pattern

```dart
try {
  final result = engine.eval(script);
  print('Success: $result');
} on RhaiSyntaxError catch (e) {
  print('Syntax error at line ${e.lineNumber}: ${e.message}');
} on RhaiRuntimeError catch (e) {
  print('Runtime error: ${e.message}');
  if (e.stackTrace != null) {
    print('Stack trace: ${e.stackTrace}');
  }
} on RhaiFFIError catch (e) {
  print('FFI error: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

### Common Error Scenarios

#### 1. Async Function Called with eval()

```dart
engine.registerFunction('asyncFunc', () async => 'data');

try {
  engine.eval('asyncFunc()'); // ERROR
} on RhaiRuntimeError catch (e) {
  // e.message: "Async function detected. Use evalAsync() instead."
}

// Solution: Use evalAsync()
await engine.evalAsync('asyncFunc()'); // OK
```

#### 2. Function Not Found

```dart
try {
  engine.eval('unknownFunction()');
} on RhaiRuntimeError catch (e) {
  // e.message: "Function not found: unknownFunction"
}

// Solution: Register the function first
engine.registerFunction('unknownFunction', () => 42);
```

#### 3. Type Conversion Error

```dart
engine.registerFunction('getDate', () => DateTime.now());

try {
  engine.eval('getDate()'); // ERROR: DateTime not serializable
} on RhaiFFIError catch (e) {
  // Type conversion failed
}

// Solution: Return serializable type
engine.registerFunction('getDate', () => DateTime.now().toIso8601String());
```

## Performance Optimization

### 1. Choose the Right Execution Method

```dart
// Fast: Use eval() for sync-only scripts
engine.registerFunction('compute', (int x) => x * 2);
final result = engine.eval('compute(21)'); // ~0.1ms

// Slower: evalAsync() has message-passing overhead
final result = await engine.evalAsync('compute(21)'); // ~1-10ms
```

### 2. Cache Converted Objects

```dart
// Slow: Converts on every call
engine.registerFunction('getConfig', () {
  return complexObject.toJson(); // Conversion overhead on each call
});

// Fast: Convert once, cache result
final cachedConfig = complexObject.toJson();
engine.registerFunction('getConfig', () => cachedConfig);
```

### 3. Limit Nesting Depth

```dart
// Fast: Flat structures
{'a': 1, 'b': 2, 'c': 3}

// Slower: Deep nesting (more JSON parsing)
{
  'level1': {
    'level2': {
      'level3': {
        'level4': {'value': 42}
      }
    }
  }
}
```

### 4. Reuse Engines When Possible

```dart
// Inefficient: Create new engine for each eval
for (var script in scripts) {
  final engine = RhaiEngine.withDefaults();
  engine.eval(script);
  engine.dispose();
}

// Better: Reuse engine
final engine = RhaiEngine.withDefaults();
try {
  for (var script in scripts) {
    engine.eval(script);
  }
} finally {
  engine.dispose();
}
```

### 5. Use Timeouts for Network Operations

```dart
engine.registerFunction('httpGet', (String url) async {
  return await http.get(Uri.parse(url))
    .timeout(Duration(seconds: 5)); // Prevent hanging
});
```

## Common Pitfalls and Solutions

### Pitfall 1: Forgetting to Dispose

```dart
// BAD: Memory leak
void processScript(String script) {
  final engine = RhaiEngine.withDefaults();
  return engine.eval(script);
  // Engine never disposed!
}

// GOOD: Always dispose
void processScript(String script) {
  final engine = RhaiEngine.withDefaults();
  try {
    return engine.eval(script);
  } finally {
    engine.dispose(); // Always runs
  }
}
```

### Pitfall 2: Using eval() with Async Functions

```dart
// BAD: Will throw error
engine.registerFunction('fetchData', () async => await http.get(...));
engine.eval('fetchData()'); // ERROR!

// GOOD: Use evalAsync
await engine.evalAsync('fetchData()');
```

### Pitfall 3: Returning Non-Serializable Types

```dart
// BAD: Custom objects cannot cross FFI boundary
class User { ... }
engine.registerFunction('getUser', () => User(...)); // ERROR!

// GOOD: Return Map
engine.registerFunction('getUser', () => {'id': 1, 'name': 'Alice'});
```

### Pitfall 4: Not Validating Inputs

```dart
// BAD: No validation
engine.registerFunction('getUser', (int id) {
  return database.getUser(id); // What if id is negative or huge?
});

// GOOD: Validate inputs
engine.registerFunction('getUser', (int id) {
  if (id < 0 || id > 1000000) {
    throw ArgumentError('Invalid user ID');
  }
  return database.getUser(id);
});
```

### Pitfall 5: Exposing Sensitive Data

```dart
// BAD: Returns too much data
engine.registerFunction('getUserInfo', (int id) {
  return database.getUser(id); // May include password, email, etc.
});

// GOOD: Sanitize output
engine.registerFunction('getUserInfo', (int id) {
  final user = database.getUser(id);
  return {
    'id': user.id,
    'displayName': user.displayName,
    // Omit sensitive fields
  };
});
```

### Pitfall 6: Not Using Timeouts for Untrusted Scripts

```dart
// BAD: Infinite loop can run forever
final engine = RhaiEngine.withConfig(
  RhaiConfig.custom(timeoutMs: null) // No timeout!
);

// GOOD: Always set timeout for untrusted scripts
final engine = RhaiEngine.withConfig(
  RhaiConfig.custom(timeoutMs: 1000) // 1 second timeout
);
```

## Template Rendering with Tera

The Rhai engine includes a built-in `render` function powered by [Tera](https://keats.github.io/tera/), a powerful template engine inspired by Jinja2/Django templates.

### Basic Usage

The `render` function takes two arguments:
1. A template string (using Tera/Jinja2 syntax)
2. A data object accessible as `data` in the template

```rhai
let user = #{
    name: "Alice",
    email: "alice@example.com"
};

let result = render("Hello, {{ data.name }}!", user);
// result: "Hello, Alice!"
```

### Template Syntax

Tera uses `{{ }}` for expressions and `{% %}` for control structures:

```rhai
let context = #{
    title: "My Page",
    items: ["Apple", "Banana", "Cherry"],
    show_footer: true
};

let html = render(`
<h1>{{ data.title }}</h1>
<ul>
{% for item in data.items %}
    <li>{{ item }}</li>
{% endfor %}
</ul>
{% if data.show_footer %}
<footer>Copyright 2024</footer>
{% endif %}
`, context);
```

### Common Tera Features

#### Variables and Filters

```rhai
let data = #{ name: "world", count: 42 };

// Basic variable
render("Hello {{ data.name }}", data);  // "Hello world"

// Filters
render("{{ data.name | upper }}", data);      // "WORLD"
render("{{ data.name | capitalize }}", data); // "World"
render("{{ data.count | plus(8) }}", data);   // "50"
```

#### Conditionals

```rhai
let user = #{ is_admin: true, name: "Bob" };

render(`
{% if data.is_admin %}
  Welcome, Admin {{ data.name }}!
{% else %}
  Welcome, {{ data.name }}!
{% endif %}
`, user);
```

#### Loops

```rhai
let data = #{ users: [
    #{ name: "Alice", active: true },
    #{ name: "Bob", active: false }
]};

render(`
{% for user in data.users %}
  {{ user.name }}: {{ user.active }}
{% endfor %}
`, data);
```

### Error Handling

The `render` function throws Rhai errors for invalid templates or render failures:

```dart
try {
  final result = engine.eval('''
    render("{{ invalid syntax", #{})
  ''');
} on RhaiRuntimeError catch (e) {
  // e.message: "Template error: ..."
}

try {
  final result = engine.eval('''
    render("{{ data.missing.field }}", #{})
  ''');
} on RhaiRuntimeError catch (e) {
  // e.message: "Render error: ..."
}
```

### Use Cases

#### Dynamic Email Templates

```rhai
let email_data = #{
    recipient: "John",
    order_id: "12345",
    items: ["Widget", "Gadget"],
    total: 99.99
};

let email_body = render(`
Dear {{ data.recipient }},

Thank you for your order #{{ data.order_id }}.

Items ordered:
{% for item in data.items %}
- {{ item }}
{% endfor %}

Total: ${{ data.total }}

Best regards,
The Team
`, email_data);
```

#### Dynamic Configuration

```rhai
let config = #{
    app_name: "MyApp",
    debug: true,
    features: ["auth", "logging"]
};

let config_file = render(`
app_name = "{{ data.app_name }}"
debug = {{ data.debug }}
features = [{% for f in data.features %}"{{ f }}"{% if not loop.last %}, {% endif %}{% endfor %}]
`, config);
```

#### HTML Generation

```rhai
let page = #{
    title: "Dashboard",
    nav_items: ["Home", "Settings", "Logout"],
    content: "Welcome to your dashboard!"
};

let html = render(`
<!DOCTYPE html>
<html>
<head><title>{{ data.title }}</title></head>
<body>
  <nav>
    {% for item in data.nav_items %}
    <a href="/{{ item | lower }}">{{ item }}</a>
    {% endfor %}
  </nav>
  <main>{{ data.content }}</main>
</body>
</html>
`, page);
```

## Complete Examples

### Example 1: Simple Calculator with Validation

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  final engine = RhaiEngine.withDefaults();

  // Register math functions with validation
  engine.registerFunction('divide', (double a, double b) {
    if (b == 0) {
      throw ArgumentError('Division by zero');
    }
    return a / b;
  });

  engine.registerFunction('sqrt', (double x) {
    if (x < 0) {
      throw ArgumentError('Cannot take square root of negative number');
    }
    return math.sqrt(x);
  });

  try {
    // Test calculations
    print(engine.eval('divide(10.0, 2.0)')); // 5.0
    print(engine.eval('sqrt(16.0)'));        // 4.0

    // This will throw
    try {
      engine.eval('divide(10.0, 0.0)');
    } on RhaiRuntimeError catch (e) {
      print('Expected error: ${e.message}');
    }
  } finally {
    engine.dispose();
  }
}
```

### Example 2: Data Processing Pipeline

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  final engine = RhaiEngine.withDefaults();

  // Sample data
  final users = [
    {'id': 1, 'name': 'Alice', 'age': 30, 'active': true},
    {'id': 2, 'name': 'Bob', 'age': 25, 'active': false},
    {'id': 3, 'name': 'Charlie', 'age': 35, 'active': true},
  ];

  // Register data access function
  engine.registerFunction('getUsers', () => users);

  try {
    // Filter active users over 25
    final result = engine.eval('''
      let users = getUsers();
      let filtered = [];

      for user in users {
        if user.active && user.age > 25 {
          filtered.push(user);
        }
      }

      filtered
    ''');

    print(result);
    // [{id: 1, name: Alice, age: 30, active: true},
    //  {id: 3, name: Charlie, age: 35, active: true}]
  } finally {
    engine.dispose();
  }
}
```

### Example 3: Async HTTP API Integration

```dart
import 'package:rhai_dart/rhai_dart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final engine = RhaiEngine.withDefaults();

  // Register async HTTP function with validation
  engine.registerFunction('httpGet', (String url) async {
    // Validate URL
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw ArgumentError('Invalid URL');
    }

    // Only allow HTTPS
    if (uri.scheme != 'https') {
      throw ArgumentError('Only HTTPS allowed');
    }

    // Make request with timeout
    final response = await http.get(uri)
      .timeout(Duration(seconds: 5));

    return jsonDecode(response.body);
  });

  try {
    final result = await engine.evalAsync('''
      let data = httpGet("https://api.github.com/users/github");
      #{
        name: data.name,
        company: data.company,
        followers: data.followers
      }
    ''');

    print(result);
  } finally {
    engine.dispose();
  }
}
```

### Example 4: Secure Script Executor for Untrusted Code

```dart
import 'package:rhai_dart/rhai_dart.dart';

class SecureScriptExecutor {
  final Map<String, int> _requestCounts = {};
  final int _maxRequestsPerMinute = 60;

  Future<dynamic> executeUserScript(String userId, String script) async {
    // 1. Rate limiting
    if (!_allowRequest(userId)) {
      throw Exception('Rate limit exceeded');
    }

    // 2. Input validation
    if (script.length > 50000) {
      throw ArgumentError('Script too large');
    }

    // 3. Create secure engine
    final config = RhaiConfig.custom(
      maxOperations: 100000,
      maxStackDepth: 50,
      maxStringLength: 1048576,
      timeoutMs: 1000,
    );
    final engine = RhaiEngine.withConfig(config);

    // 4. Register minimal, safe API
    engine.registerFunction('getData', (String key) {
      return _getSafeData(userId, key);
    });

    // 5. Execute with error handling
    try {
      final result = engine.eval(script);
      return result;
    } on RhaiException catch (e) {
      // Log but don't expose details
      print('Script error for user $userId: ${e.message}');
      throw Exception('Script execution failed');
    } finally {
      engine.dispose();
    }
  }

  bool _allowRequest(String userId) {
    final now = DateTime.now();
    final count = _requestCounts[userId] ?? 0;

    if (count >= _maxRequestsPerMinute) {
      return false;
    }

    _requestCounts[userId] = count + 1;
    return true;
  }

  Map<String, dynamic> _getSafeData(String userId, String key) {
    // Implement safe data access logic
    final allowedKeys = ['config', 'stats'];
    if (!allowedKeys.contains(key)) {
      throw ArgumentError('Key not allowed');
    }
    return {'key': key, 'value': 'safe_data'};
  }
}
```

## Summary Checklist

When implementing rhai_dart, ensure you:

- [ ] Always dispose engines using `try-finally` blocks
- [ ] Choose `eval()` for sync-only, `evalAsync()` for async functions
- [ ] Validate all inputs to registered functions
- [ ] Return only JSON-serializable types from functions
- [ ] Use `RhaiEngine.withDefaults()` for untrusted scripts
- [ ] Set appropriate timeouts and resource limits
- [ ] Never register file I/O, exec, or network functions for untrusted scripts
- [ ] Sanitize error messages before exposing to users
- [ ] Implement rate limiting for user-submitted scripts
- [ ] Keep nested structures reasonably flat (< 10 levels)
- [ ] Handle all exception types appropriately
- [ ] Use timeouts for all async I/O operations

## Additional Resources

- **Architecture**: docs/architecture.md - FFI design, memory management
- **Async Functions**: docs/ASYNC_FUNCTIONS.md - Detailed async guide
- **Security**: docs/security.md - Comprehensive security practices
- **Type Conversion**: docs/type_conversion.md - Complete type mapping
- **Setup**: docs/setup.md - Installation and configuration
- **Rhai Book**: https://rhai.rs/book/ - Rhai language documentation
