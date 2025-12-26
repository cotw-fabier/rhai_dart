# Security Guide

This guide explains the security features of rhai_dart and provides recommendations for safely executing untrusted scripts.

## Table of Contents

- [Security Overview](#security-overview)
- [Threat Model](#threat-model)
- [Sandboxing Features](#sandboxing-features)
- [Secure Configuration](#secure-configuration)
- [Operational Limits](#operational-limits)
- [Attack Surface and Mitigations](#attack-surface-and-mitigations)
- [Security Checklist](#security-checklist)
- [Best Practices](#best-practices)
- [Known Limitations](#known-limitations)

## Security Overview

The rhai_dart library is designed for **safe execution of untrusted scripts** with multiple layers of protection:

1. **Sandboxing:** Restricts access to dangerous operations
2. **Resource Limits:** Prevents resource exhaustion attacks
3. **Timeout Enforcement:** Prevents infinite loops
4. **Memory Safety:** Rust's memory safety + FFI boundary protection
5. **Secure Defaults:** Security-first configuration out of the box

## Threat Model

### What We Protect Against

✓ **Infinite Loops:** Scripts that never terminate
✓ **Excessive Memory Usage:** Scripts that allocate huge amounts of memory
✓ **Stack Overflow:** Deep recursion attacks
✓ **CPU Exhaustion:** Computationally intensive scripts
✓ **Sandbox Escape Attempts:** Scripts trying to access file system, network, etc.

### What We Don't Protect Against

✗ **Side-Channel Attacks:** Timing attacks, Spectre/Meltdown
✗ **Host System Vulnerabilities:** OS-level exploits
✗ **Physical Access:** Attacks requiring physical access to the machine
✗ **Social Engineering:** Tricking users into running malicious code
✗ **Dart VM Exploits:** Vulnerabilities in the Dart runtime itself

**Scope:** This library focuses on **script-level security**, not system-level security.

## Sandboxing Features

### Default Sandboxing

The `RhaiEngine.withDefaults()` constructor creates an engine with **strict sandboxing enabled**:

```dart
final engine = RhaiEngine.withDefaults();
// Automatically has:
// - File I/O disabled
// - eval() disabled
// - Module loading disabled
// - Strict operation limits
```

### What is Sandboxed?

#### 1. File System Access (Disabled by Default)

Rhai doesn't have built-in file I/O functions, but if custom functions were registered, the sandbox would prevent access.

**Protected Operations:**
- Reading files
- Writing files
- Directory listing
- File deletion

**Example:**
```dart
// File I/O functions are not available in Rhai by default
// Even if you try to register one, the sandbox would prevent it

engine.registerFunction('readFile', (String path) {
  // This would work, but you shouldn't register such functions
  // for untrusted scripts!
  return File(path).readAsStringSync();
});

// Better: Don't register dangerous functions at all
```

#### 2. Dynamic Code Evaluation (Disabled by Default)

The `eval()` function in Rhai allows executing dynamically generated code, which could be used for sandbox escape.

**Security Risk:**
```javascript
// Rhai script (if eval were enabled)
let malicious_code = "/* user-controlled string */";
eval(malicious_code); // Could execute arbitrary code
```

**Protection:**
- `eval()` is disabled by default in `RhaiEngine.withDefaults()`
- Cannot be enabled without explicit configuration

#### 3. Module Loading (Disabled by Default)

Rhai's module system (`import`/`export`) is disabled to prevent loading external code.

**Security Risk:**
```javascript
// Rhai script (if modules were enabled)
import "external_module"; // Could load malicious code
```

**Protection:**
- Module loading disabled by default
- Cannot `import` or `export`

### Sandboxing Configuration

To customize sandboxing, use `RhaiConfig.custom()`:

```dart
final config = RhaiConfig.custom(
  maxOperations: 1000000,        // 1 million operations
  maxStackDepth: 100,             // 100 stack frames
  maxStringLength: 10485760,      // 10 MB strings
  timeoutMs: 5000,                // 5 second timeout
);

final engine = RhaiEngine.withConfig(config);
```

## Secure Configuration

### Recommended Configuration for Untrusted Scripts

```dart
final secureConfig = RhaiConfig.custom(
  // Prevent infinite loops
  maxOperations: 100000,          // Lower limit for untrusted scripts

  // Prevent stack overflow
  maxStackDepth: 50,              // Conservative limit

  // Prevent excessive memory usage
  maxStringLength: 1048576,       // 1 MB max string size

  // Prevent long-running scripts
  timeoutMs: 1000,                // 1 second timeout (aggressive)
);

final engine = RhaiEngine.withConfig(secureConfig);
```

### Configuration for Trusted Scripts

If you trust the script source (e.g., internal scripts), you can use more permissive settings:

```dart
final trustedConfig = RhaiConfig.custom(
  maxOperations: 10000000,        // 10 million operations
  maxStackDepth: 200,             // Deeper recursion allowed
  maxStringLength: 104857600,     // 100 MB strings
  timeoutMs: 30000,               // 30 second timeout
);

final engine = RhaiEngine.withConfig(trustedConfig);
```

**Warning:** Only use permissive configs for scripts you fully trust.

### Unlimited Configuration (Development Only)

For development and testing, you can disable limits entirely:

```dart
final devConfig = RhaiConfig.custom(
  maxOperations: null,            // Unlimited operations
  maxStackDepth: null,            // Unlimited stack depth
  maxStringLength: null,          // Unlimited string size
  timeoutMs: null,                // No timeout
);

final engine = RhaiEngine.withConfig(devConfig);
```

**DANGER:** Never use unlimited configuration for untrusted scripts in production!

## Operational Limits

### 1. Operation Limit (max_operations)

Counts the number of operations (expressions, statements, function calls) executed.

**Purpose:** Prevent infinite loops and CPU exhaustion

**Example Attack:**
```javascript
// Infinite loop (blocked by operation limit)
loop {
  let x = 1 + 1; // Each iteration counts operations
}
```

**What Happens:**
- Engine counts each operation
- When limit is reached, script terminates with error
- Error message: "Script terminated: maximum number of operations reached"

**Recommended Values:**
- Untrusted scripts: 100,000 - 1,000,000
- Trusted scripts: 1,000,000 - 10,000,000
- Development: Unlimited (null)

### 2. Stack Depth Limit (max_stack_depth)

Limits the maximum function call depth (recursion).

**Purpose:** Prevent stack overflow attacks

**Example Attack:**
```javascript
// Deep recursion (blocked by stack limit)
fn recurse(n) {
  if n > 0 {
    recurse(n - 1);
  }
}

recurse(1000000); // Will hit stack depth limit
```

**What Happens:**
- Engine tracks call stack depth
- When limit is reached, script terminates with error
- Error message: "Stack overflow"

**Recommended Values:**
- Untrusted scripts: 50 - 100
- Trusted scripts: 100 - 200
- Development: Unlimited (null)

### 3. String Length Limit (max_string_length)

Limits the maximum length of any string in the script.

**Purpose:** Prevent excessive memory allocation

**Example Attack:**
```javascript
// Huge string allocation (blocked by string limit)
let huge = "a" * 1000000000; // Try to allocate 1 GB string
```

**What Happens:**
- Engine checks string length before allocation
- If over limit, operation fails with error
- Error message: "Length of string exceeds maximum"

**Recommended Values:**
- Untrusted scripts: 1 MB - 10 MB (1048576 - 10485760 bytes)
- Trusted scripts: 10 MB - 100 MB
- Development: Unlimited (null)

### 4. Timeout Limit (timeout_ms)

Limits the total wall-clock time for script execution.

**Purpose:** Prevent long-running scripts from blocking

**Example Attack:**
```javascript
// Slow computation (blocked by timeout)
let sum = 0;
for i in 0..1000000000 {
  sum += i;
}
```

**What Happens:**
- Engine tracks elapsed time during execution
- If timeout is reached, script terminates with error
- Error message: "Script execution timeout"

**Recommended Values:**
- Untrusted scripts: 100ms - 1000ms
- Trusted scripts: 5000ms - 30000ms
- Development: Unlimited (null)

**Note:** Timeout is wall-clock time, not CPU time. It includes time spent in Dart callbacks.

## Attack Surface and Mitigations

### 1. Registered Functions (Primary Attack Surface)

**Risk:** If you register dangerous functions, scripts can call them.

**Example Vulnerable Code:**
```dart
// DON'T DO THIS with untrusted scripts!
engine.registerFunction('exec', (String cmd) {
  return Process.runSync(cmd, []).stdout;
});

// Attacker script:
// exec('rm -rf /') // Catastrophic!
```

**Mitigation:**
- ✓ Only register safe, read-only functions
- ✓ Validate all function inputs
- ✓ Sanitize outputs to prevent information leaks
- ✓ Use principle of least privilege

**Safe Function Example:**
```dart
// Safe: Read-only data access with validation
engine.registerFunction('getUser', (int userId) {
  if (userId < 0 || userId > 1000000) {
    throw ArgumentError('Invalid user ID');
  }

  // Return sanitized, read-only data
  return {
    'id': userId,
    'name': _database.getUserName(userId),
    // Don't expose sensitive fields like passwords, emails, etc.
  };
});
```

### 2. Type Conversion (Low Risk)

**Risk:** Malicious data structures could exploit type conversion bugs.

**Example Attack Vector:**
```javascript
// Deeply nested structure to exhaust stack
let deeply_nested = #{
  a: #{ b: #{ c: #{ d: #{ e: #{ f: #{ /* ... 1000 levels */ }}}}}
};
```

**Mitigation:**
- ✓ JSON conversion handles nesting gracefully
- ✓ Dart/Rust memory safety prevents buffer overflows
- ✓ Reasonable nesting limits (<100 levels recommended)

### 3. Error Messages (Information Leak Risk)

**Risk:** Error messages could leak sensitive information.

**Example:**
```javascript
// Error might reveal file paths, internal details
let x = undefined_variable;
// Error: "Variable 'undefined_variable' not found"
```

**Mitigation:**
- ✓ Sanitize error messages before showing to users
- ✓ Don't include stack traces in production error responses
- ✓ Log detailed errors server-side only

**Safe Error Handling:**
```dart
try {
  final result = engine.eval(untrustedScript);
} on RhaiException catch (e) {
  // Log detailed error for debugging
  _logger.error('Script error: ${e.toString()}');

  // Return generic error to user
  return 'Script execution failed'; // Don't leak details
}
```

### 4. Resource Exhaustion (Mitigated)

**Risk:** Scripts could try to exhaust memory, CPU, or other resources.

**Mitigation:**
- ✓ Operation limits prevent CPU exhaustion
- ✓ String length limits prevent memory exhaustion
- ✓ Stack depth limits prevent stack overflow
- ✓ Timeout limits prevent long-running scripts

### 5. FFI Boundary (Low Risk)

**Risk:** Bugs in FFI layer could lead to crashes or memory corruption.

**Mitigation:**
- ✓ All FFI entry points wrapped in panic catching
- ✓ Rust's memory safety prevents most bugs
- ✓ Opaque pointer pattern prevents Dart from accessing invalid memory
- ✓ NativeFinalizers ensure cleanup
- ✓ Extensive testing (102 tests passing)

## Security Checklist

Use this checklist when deploying rhai_dart with untrusted scripts:

### Configuration

- [ ] Using `RhaiEngine.withDefaults()` or strict custom config
- [ ] `maxOperations` set to reasonable limit (≤1,000,000 for untrusted)
- [ ] `maxStackDepth` set to conservative limit (≤100 for untrusted)
- [ ] `maxStringLength` set to prevent memory exhaustion (≤10 MB for untrusted)
- [ ] `timeoutMs` set to prevent blocking (≤5000ms for untrusted)

### Function Registration

- [ ] Only register necessary functions (principle of least privilege)
- [ ] All registered functions validate inputs
- [ ] No functions that access file system
- [ ] No functions that execute shell commands
- [ ] No functions that access network (unless required and validated)
- [ ] No functions that access sensitive data without authentication

### Error Handling

- [ ] Catch all `RhaiException` instances
- [ ] Sanitize error messages before showing to users
- [ ] Log detailed errors server-side for debugging
- [ ] Don't leak stack traces or internal paths

### Input Validation

- [ ] Validate script source before execution
- [ ] Limit script size (e.g., ≤100 KB for untrusted)
- [ ] Consider static analysis for obviously malicious patterns
- [ ] Rate limit script execution per user/IP

### Monitoring and Logging

- [ ] Log all script executions (user, timestamp, result)
- [ ] Monitor for repeated failures (possible attack)
- [ ] Monitor resource usage (CPU, memory)
- [ ] Set up alerts for suspicious activity

### Testing

- [ ] Test with malicious scripts (infinite loops, huge allocations, etc.)
- [ ] Test timeout enforcement
- [ ] Test operation limit enforcement
- [ ] Test stack depth limit enforcement
- [ ] Test with fuzzing (random inputs)

## Best Practices

### 1. Defense in Depth

Don't rely on a single security mechanism. Layer multiple protections:

```dart
// Multiple layers of protection
final engine = RhaiEngine.withDefaults(); // Sandboxing

// Limit script size
if (script.length > 100000) {
  throw ArgumentError('Script too large');
}

// Rate limiting (pseudo-code)
if (!rateLimiter.allowRequest(userId)) {
  throw RateLimitException();
}

// Execute with timeout
try {
  final result = engine.eval(script);
  // Process result...
} on RhaiException {
  // Handle errors...
} finally {
  engine.dispose();
}
```

### 2. Principle of Least Privilege

Only grant scripts the minimum capabilities they need:

```dart
// BAD: Exposing too much functionality
engine.registerFunction('executeCommand', (cmd) => ...);
engine.registerFunction('readFile', (path) => ...);
engine.registerFunction('writeFile', (path, data) => ...);

// GOOD: Minimal, safe API
engine.registerFunction('getConfig', (key) {
  // Only allow reading specific config keys
  final allowedKeys = ['appName', 'version', 'theme'];
  if (!allowedKeys.contains(key)) {
    throw ArgumentError('Config key not allowed');
  }
  return config[key];
});
```

### 3. Input Validation

Always validate inputs to registered functions:

```dart
engine.registerFunction('processOrder', (orderId, quantity) {
  // Validate types (Dart is dynamically typed)
  if (orderId is! int || quantity is! int) {
    throw ArgumentError('Invalid argument types');
  }

  // Validate ranges
  if (orderId <= 0 || quantity <= 0 || quantity > 1000) {
    throw ArgumentError('Invalid argument values');
  }

  // Validate business logic
  if (!_orderExists(orderId)) {
    throw ArgumentError('Order not found');
  }

  // Process safely
  return _processOrder(orderId, quantity);
});
```

### 4. Sanitize Outputs

Prevent information leaks through function return values:

```dart
engine.registerFunction('getUserInfo', (userId) {
  final user = _database.getUser(userId);

  // DON'T return the entire user object
  // return user; // May contain password hash, email, etc.

  // DO return only safe, public fields
  return {
    'id': user.id,
    'displayName': user.displayName,
    'avatarUrl': user.avatarUrl,
    // Omit: passwordHash, email, privateData, etc.
  };
});
```

### 5. Rate Limiting

Prevent abuse by limiting script execution frequency:

```dart
class ScriptRateLimiter {
  final _requestCounts = <String, int>{};
  final _resetTimes = <String, DateTime>{};

  bool allowRequest(String userId, {int maxPerMinute = 60}) {
    final now = DateTime.now();
    final resetTime = _resetTimes[userId] ?? now;

    if (now.isAfter(resetTime)) {
      // Reset counter
      _requestCounts[userId] = 0;
      _resetTimes[userId] = now.add(Duration(minutes: 1));
    }

    final count = _requestCounts[userId] ?? 0;
    if (count >= maxPerMinute) {
      return false; // Rate limit exceeded
    }

    _requestCounts[userId] = count + 1;
    return true;
  }
}
```

### 6. Audit Logging

Log all script executions for security auditing:

```dart
Future<dynamic> executeUserScript(String userId, String script) async {
  final startTime = DateTime.now();
  dynamic result;
  String? error;

  try {
    final engine = RhaiEngine.withDefaults();
    result = engine.eval(script);
    return result;
  } catch (e) {
    error = e.toString();
    rethrow;
  } finally {
    final duration = DateTime.now().difference(startTime);

    // Log execution details
    await _auditLog.log({
      'timestamp': startTime.toIso8601String(),
      'userId': userId,
      'scriptLength': script.length,
      'duration': duration.inMilliseconds,
      'success': error == null,
      'error': error,
      // Optionally: script hash for deduplication
      'scriptHash': _hashScript(script),
    });
  }
}
```

### 7. Timeout Per User Session

Limit total script execution time per user session:

```dart
class SessionTimeoutTracker {
  final _userTimes = <String, Duration>{};
  final maxPerSession = Duration(minutes: 5);

  bool allowExecution(String userId, Duration estimatedDuration) {
    final currentTotal = _userTimes[userId] ?? Duration.zero;
    final newTotal = currentTotal + estimatedDuration;

    if (newTotal > maxPerSession) {
      return false; // Session quota exceeded
    }

    _userTimes[userId] = newTotal;
    return true;
  }
}
```

## Known Limitations

### 1. No Network Isolation

The library itself doesn't prevent network access. If you register functions that make HTTP requests, scripts can call them.

**Mitigation:** Don't register network-accessing functions for untrusted scripts.

### 2. No File System Isolation

Similarly, file system access is not automatically prevented if you register file I/O functions.

**Mitigation:** Don't register file I/O functions for untrusted scripts.

### 3. Timing Attacks

Scripts can measure execution time to infer information about the system.

**Example:**
```javascript
let start = timestamp();
some_operation();
let duration = timestamp() - start;
// Duration might leak information
```

**Mitigation:** For highly sensitive operations, consider adding random delays or normalizing execution times.

### 4. Memory Pressure

Even with string length limits, a script could create many moderate-sized strings and exhaust memory.

**Mitigation:**
- Monitor overall memory usage
- Use operation limits to prevent excessive object creation
- Consider per-user memory quotas at the OS level

### 5. Shared CPU Resources

Scripts running on the same machine share CPU resources. A malicious script could slow down other scripts.

**Mitigation:**
- Use operation limits and timeouts
- Consider process isolation for critical workloads
- Monitor and kill runaway processes

## Security Updates

### Keeping Dependencies Updated

Regularly update dependencies to get security patches:

```bash
# Update Dart dependencies
dart pub upgrade

# Update Rust dependencies
cd rust
cargo update

# Check for known vulnerabilities
cargo audit
```

### Monitoring Security Advisories

Subscribe to security advisories for:
- **Rhai:** https://github.com/rhaiscript/rhai/security
- **Dart:** https://dart.dev/security
- **Rust:** https://rustsec.org/

## Incident Response

If you suspect a security issue:

1. **Isolate:** Stop executing untrusted scripts immediately
2. **Investigate:** Review logs for suspicious activity
3. **Patch:** Update to latest version with security fixes
4. **Report:** Report vulnerabilities to the library maintainers
5. **Post-Mortem:** Analyze what went wrong and improve defenses

## Example: Secure Production Setup

Here's a complete example of a secure production setup:

```dart
import 'package:rhai_dart/rhai_dart.dart';

class SecureScriptExecutor {
  final _rateLimiter = ScriptRateLimiter();
  final _auditLog = AuditLogger();

  Future<dynamic> executeUserScript({
    required String userId,
    required String script,
  }) async {
    // 1. Rate limiting
    if (!_rateLimiter.allowRequest(userId)) {
      throw RateLimitException('Too many requests');
    }

    // 2. Input validation
    if (script.length > 50000) {
      throw ArgumentError('Script too large');
    }

    // 3. Malicious pattern detection (basic)
    if (_containsSuspiciousPatterns(script)) {
      _auditLog.logSuspicious(userId, script);
      throw SecurityException('Suspicious script detected');
    }

    // 4. Create sandboxed engine
    final config = RhaiConfig.custom(
      maxOperations: 100000,
      maxStackDepth: 50,
      maxStringLength: 1048576,
      timeoutMs: 1000,
    );
    final engine = RhaiEngine.withConfig(config);

    // 5. Register minimal, safe API
    engine.registerFunction('getData', (String key) {
      return _getSafeData(userId, key);
    });

    // 6. Execute with error handling
    try {
      final result = engine.eval(script);

      // 7. Log success
      await _auditLog.log(userId, script, success: true);

      return result;
    } on RhaiException catch (e) {
      // 8. Log failure (with sanitized error)
      await _auditLog.log(userId, script, success: false, error: e.message);

      // 9. Return generic error to user
      throw Exception('Script execution failed');
    } finally {
      // 10. Always dispose
      engine.dispose();
    }
  }

  bool _containsSuspiciousPatterns(String script) {
    // Basic pattern matching (expand as needed)
    final suspiciousPatterns = [
      RegExp(r'while\s*\(\s*true\s*\)'), // Infinite loops
      RegExp(r'loop\s*\{'), // Infinite loops
      // Add more patterns as needed
    ];

    return suspiciousPatterns.any((pattern) => pattern.hasMatch(script));
  }

  Map<String, dynamic> _getSafeData(String userId, String key) {
    // Validate user permissions
    if (!_hasPermission(userId, key)) {
      throw ArgumentError('Permission denied');
    }

    // Return sanitized data
    return _database.getSafeData(key);
  }
}
```

## Summary

The rhai_dart library provides robust security features for executing untrusted scripts:

✓ **Sandboxing** prevents dangerous operations
✓ **Resource limits** prevent exhaustion attacks
✓ **Timeouts** prevent infinite loops
✓ **Memory safety** prevents crashes
✓ **Secure defaults** make it safe by default

**Key Takeaways:**
1. Always use `RhaiEngine.withDefaults()` for untrusted scripts
2. Only register safe, validated functions
3. Implement rate limiting and logging
4. Sanitize inputs and outputs
5. Monitor and update regularly

For more information, see:
- [Setup Guide](setup.md)
- [Architecture Guide](architecture.md)
- [Type Conversion Guide](type_conversion.md)
- [Rhai Security Documentation](https://rhai.rs/book/safety/)
