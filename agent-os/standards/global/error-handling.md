# Error Handling Best Practices for Pure Dart Development

## Overview

This document provides comprehensive guidance on error handling in pure Dart applications. Effective error handling ensures robust, maintainable applications that gracefully handle failures and provide meaningful feedback to users and developers.

## Table of Contents

- [Error Handling Philosophy](#error-handling-philosophy)
- [Exception Hierarchy](#exception-hierarchy)
- [Try-Catch-Finally Patterns](#try-catch-finally-patterns)
- [Custom Exceptions](#custom-exceptions)
- [Result Types vs Exceptions](#result-types-vs-exceptions)
- [Async Error Handling](#async-error-handling)
- [Error Logging](#error-logging)
- [Recovery Strategies](#recovery-strategies)
- [Testing Error Scenarios](#testing-error-scenarios)

---

## Error Handling Philosophy

### Core Principles

1. **Fail Fast**: Detect and report errors as soon as possible
2. **Be Specific**: Throw typed exceptions with meaningful messages
3. **Handle or Propagate**: Either handle the error or pass it up the call stack
4. **Clean Up Resources**: Always clean up in `finally` blocks
5. **User-Friendly Messages**: Show appropriate messages to end users

### When to Use Exceptions

**DO use exceptions for:**
- Unexpected errors (file not found, network failure)
- Programming errors (null pointer, invalid state)
- Violations of preconditions
- Resource acquisition failures

**DON'T use exceptions for:**
- Normal control flow
- Expected alternate outcomes (e.g., "user not found" in a search)
- Validation failures that should return false/null

```dart
// GOOD - Exception for unexpected error
Future<File> openFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileNotFoundException('File not found: $path');
  }
  return file;
}

// GOOD - Nullable return for expected "not found"
User? findUserByEmail(String email) {
  return users.firstWhereOrNull((u) => u.email == email);
}

// BAD - Exception for control flow
String getStatus(int code) {
  try {
    return [
      'active',
      'pending',
      'inactive',
    ][code];
  } catch (e) {
    return 'unknown';  // Don't use exceptions for this
  }
}

// BETTER - Simple logic
String getStatus(int code) {
  const statuses = ['active', 'pending', 'inactive'];
  return code >= 0 && code < statuses.length ? statuses[code] : 'unknown';
}
```

---

## Exception Hierarchy

### Dart Built-in Exceptions

Dart provides several built-in exception types:

```dart
// Common Dart exceptions
Exception         // Base exception class
Error             // Programming errors (usually should not be caught)
├── ArgumentError           // Invalid function argument
├── StateError              // Object in invalid state
├── RangeError              // Index out of range
├── FormatException         // String/data format error
├── TypeError               // Type mismatch (runtime)
└── UnsupportedError        // Operation not supported

// I/O exceptions
IOException
├── FileSystemException     // File operations
└── SocketException         // Network operations

// Async exceptions
TimeoutException           // Operation timed out
```

### Exception vs Error

```dart
// Exception - Recoverable conditions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

// Error - Programming errors (usually don't catch these)
class ValidationError extends Error {
  final String message;
  ValidationError(this.message);
}

// Usage
void processData(String? data) {
  if (data == null) {
    // Throw Error for programming mistakes
    throw ArgumentError('Data cannot be null');
  }

  try {
    // Might throw Exception for runtime issues
    final result = parseData(data);
  } on FormatException catch (e) {
    // Handle recoverable Exception
    print('Invalid format: $e');
  }
  // Let Errors propagate - they indicate bugs
}
```

---

## Try-Catch-Finally Patterns

### Basic Try-Catch

```dart
// GOOD - Specific exception handling
Future<User> loadUser(String id) async {
  try {
    final response = await httpClient.get('/users/$id');
    return User.fromJson(jsonDecode(response.body));
  } on SocketException {
    throw NetworkException('No internet connection');
  } on FormatException {
    throw DataException('Invalid response format');
  } on HttpException catch (e) {
    throw NetworkException('HTTP error: ${e.message}');
  } catch (e) {
    throw UserLoadException('Failed to load user: $e');
  }
}
```

### Catch with Stack Trace

```dart
// GOOD - Capture stack trace for debugging
Future<void> processData() async {
  try {
    await complexOperation();
  } catch (e, stackTrace) {
    logError('Operation failed', error: e, stackTrace: stackTrace);
    rethrow;  // Preserve original exception
  }
}
```

### Finally for Resource Cleanup

```dart
// GOOD - Finally ensures cleanup
Future<String> readFile(String path) async {
  final file = File(path);
  RandomAccessFile? handle;

  try {
    handle = await file.open();
    final contents = await handle.readString();
    return contents;
  } catch (e) {
    throw FileReadException('Failed to read $path: $e');
  } finally {
    // ALWAYS execute, even if exception thrown
    await handle?.close();
  }
}

// GOOD - Multiple resources
Future<void> copyData(String source, String destination) async {
  File? sourceFile;
  File? destFile;

  try {
    sourceFile = File(source);
    destFile = File(destination);

    final contents = await sourceFile.readAsString();
    await destFile.writeAsString(contents);
  } finally {
    // Clean up all resources
    // Order doesn't matter since reads/writes are complete
    await sourceFile?.close();
    await destFile?.close();
  }
}
```

### Rethrowing Exceptions

```dart
// GOOD - Rethrow to preserve stack trace
Future<void> saveData(Data data) async {
  try {
    await database.save(data);
  } catch (e) {
    logError('Save failed', error: e);
    rethrow;  // Maintains original exception and stack trace
  }
}

// BAD - Throwing caught exception loses stack trace
Future<void> saveData(Data data) async {
  try {
    await database.save(data);
  } catch (e) {
    logError('Save failed', error: e);
    throw e;  // Creates new stack trace
  }
}

// GOOD - Wrap in new exception with context
Future<void> saveData(Data data) async {
  try {
    await database.save(data);
  } catch (e, stackTrace) {
    throw SaveException(
      'Failed to save data: $e',
      originalException: e,
      originalStackTrace: stackTrace,
    );
  }
}
```

### On vs Catch

```dart
// GOOD - Use 'on' for specific types, 'catch' for the exception object
try {
  riskyOperation();
} on TimeoutException {
  // Handle timeout (don't need exception object)
  print('Operation timed out');
} on IOException catch (e) {
  // Handle I/O error (need exception details)
  print('I/O error: ${e.message}');
} catch (e) {
  // Catch-all for unexpected exceptions
  print('Unexpected error: $e');
}
```

---

## Custom Exceptions

### Creating Custom Exception Classes

```dart
// GOOD - Custom exception with context
class UserNotFoundException implements Exception {
  final String userId;
  final String message;

  UserNotFoundException(this.userId, {this.message = 'User not found'});

  @override
  String toString() => 'UserNotFoundException: $message (userId: $userId)';
}

// GOOD - Exception with error code
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;

  ApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
  });

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() {
    final code = errorCode != null ? ' [$errorCode]' : '';
    return 'ApiException: $message (HTTP $statusCode)$code';
  }
}

// GOOD - Exception with original cause
class DataProcessingException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  DataProcessingException(
    this.message, {
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('DataProcessingException: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}
```

### Exception Hierarchy for Applications

```dart
// Application-specific exception hierarchy
abstract class AppException implements Exception {
  final String message;
  final Object? cause;

  AppException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

// Domain-specific exceptions
class ValidationException extends AppException {
  final Map<String, List<String>> errors;

  ValidationException(
    String message,
    this.errors, {
    Object? cause,
  }) : super(message, cause: cause);
}

class AuthenticationException extends AppException {
  AuthenticationException(String message, {Object? cause})
      : super(message, cause: cause);
}

class AuthorizationException extends AppException {
  final String resource;
  final String action;

  AuthorizationException(this.resource, this.action)
      : super('Not authorized to $action on $resource');
}

class NetworkException extends AppException {
  final int? statusCode;

  NetworkException(String message, {this.statusCode, Object? cause})
      : super(message, cause: cause);
}

class DataNotFoundException extends AppException {
  final String entityType;
  final String entityId;

  DataNotFoundException(this.entityType, this.entityId)
      : super('$entityType not found: $entityId');
}

// Usage
void processUser(String userId) {
  final user = findUser(userId);
  if (user == null) {
    throw DataNotFoundException('User', userId);
  }

  if (!user.hasPermission('admin')) {
    throw AuthorizationException('AdminPanel', 'access');
  }

  // Process user...
}
```

---

## Result Types vs Exceptions

### Result Type Pattern

For operations with expected failures, consider using a Result type:

```dart
// Result type implementation
sealed class Result<T, E> {
  const Result();
}

class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}

// Extension methods for convenience
extension ResultExtensions<T, E> on Result<T, E> {
  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  E? get errorOrNull => switch (this) {
        Success() => null,
        Failure(error: final e) => e,
      };

  T getOrElse(T Function() defaultValue) => switch (this) {
        Success(value: final v) => v,
        Failure() => defaultValue(),
      };

  Result<R, E> map<R>(R Function(T) transform) => switch (this) {
        Success(value: final v) => Success(transform(v)),
        Failure(error: final e) => Failure(e),
      };
}

// Usage example
Result<User, String> findUser(String id) {
  final user = database.find(id);
  if (user == null) {
    return Failure('User not found: $id');
  }
  return Success(user);
}

void processUser(String id) {
  final result = findUser(id);

  // Pattern matching
  switch (result) {
    case Success(value: final user):
      print('Found user: ${user.name}');
    case Failure(error: final error):
      print('Error: $error');
  }

  // Or use extension methods
  final user = result.getOrElse(() => User.guest());
}
```

### When to Use Result vs Exceptions

```dart
// GOOD - Result type for expected failures
Result<User, String> findUser(String email) {
  final user = users.firstWhereOrNull((u) => u.email == email);
  return user != null ? Success(user) : Failure('User not found');
}

// GOOD - Exception for unexpected failures
Future<File> readFile(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileNotFoundException(path);
  }
  return file;
}

// GOOD - Result for validation
Result<int, String> parseAge(String input) {
  final age = int.tryParse(input);
  if (age == null) {
    return Failure('Invalid number: $input');
  }
  if (age < 0 || age > 150) {
    return Failure('Age must be between 0 and 150');
  }
  return Success(age);
}

// Usage - Chain results
Result<User, String> createUser(String name, String ageStr) {
  final ageResult = parseAge(ageStr);

  return ageResult.map((age) => User(name: name, age: age));
}
```

---

## Async Error Handling

### Future Error Handling

```dart
// GOOD - Use try-catch with async/await
Future<User> loadUser(String id) async {
  try {
    final response = await httpClient.get('/users/$id');
    return User.fromJson(response.body);
  } on SocketException {
    throw NetworkException('No internet connection');
  } catch (e) {
    throw UserLoadException('Failed to load user: $e');
  }
}

// GOOD - Handle errors with catchError (when not using await)
Future<User> loadUser(String id) {
  return httpClient
      .get('/users/$id')
      .then((response) => User.fromJson(response.body))
      .catchError(
        (e) => throw NetworkException('Network error: $e'),
        test: (e) => e is SocketException,
      )
      .catchError(
        (e) => throw UserLoadException('Failed to load user: $e'),
      );
}
```

### Timeout Handling

```dart
// GOOD - Add timeout to async operations
Future<User> loadUser(String id) async {
  try {
    final response = await httpClient
        .get('/users/$id')
        .timeout(const Duration(seconds: 10));

    return User.fromJson(response.body);
  } on TimeoutException {
    throw NetworkException('Request timed out');
  } on SocketException {
    throw NetworkException('No internet connection');
  } catch (e) {
    throw UserLoadException('Failed to load user: $e');
  }
}
```

### Future.wait Error Handling

```dart
// GOOD - Handle errors from parallel operations
Future<Dashboard> loadDashboard() async {
  try {
    final results = await Future.wait([
      loadUsers(),
      loadProjects(),
      loadStatistics(),
    ]);

    return Dashboard(
      users: results[0] as List<User>,
      projects: results[1] as List<Project>,
      statistics: results[2] as Statistics,
    );
  } catch (e) {
    throw DashboardLoadException('Failed to load dashboard: $e');
  }
}

// GOOD - Continue on error with eagerError: false
Future<Dashboard> loadDashboard() async {
  final results = await Future.wait(
    [
      loadUsers().catchError((_) => <User>[]),
      loadProjects().catchError((_) => <Project>[]),
      loadStatistics().catchError((_) => Statistics.empty()),
    ],
    eagerError: false, // Continue even if some fail
  );

  return Dashboard(
    users: results[0] as List<User>,
    projects: results[1] as List<Project>,
    statistics: results[2] as Statistics,
  );
}
```

### Stream Error Handling

```dart
// GOOD - Handle stream errors
Stream<User> watchUsers() {
  return database
      .watchUsers()
      .handleError(
        (e) => throw DatabaseException('Watch failed: $e'),
        test: (e) => e is DatabaseError,
      )
      .handleError(
        (e) => print('Unexpected error: $e'),
      );
}

// GOOD - Transform errors
Stream<User> watchUsers() {
  return database.watchUsers().transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) {
            if (error is DatabaseError) {
              sink.addError(DatabaseException('Watch failed: $error'));
            } else {
              sink.addError(error);
            }
          },
        ),
      );
}

// GOOD - Handle errors in listen
void startWatching() {
  database.watchUsers().listen(
        (user) => print('User updated: ${user.name}'),
        onError: (e) => print('Error: $e'),
        onDone: () => print('Stream closed'),
        cancelOnError: false, // Continue on errors
      );
}
```

---

## Error Logging

### Using dart:developer

```dart
import 'dart:developer' as developer;

// GOOD - Structured logging with dart:developer
void logError(
  String message, {
  Object? error,
  StackTrace? stackTrace,
  Map<String, dynamic>? context,
}) {
  developer.log(
    message,
    name: 'app.error',
    level: 1000, // SEVERE level
    error: error,
    stackTrace: stackTrace,
    time: DateTime.now(),
  );

  // Additional context logging
  if (context != null) {
    developer.log(
      'Context: $context',
      name: 'app.error.context',
      level: 900,
    );
  }
}

// Usage
try {
  await loadUser(userId);
} catch (e, stackTrace) {
  logError(
    'Failed to load user',
    error: e,
    stackTrace: stackTrace,
    context: {'userId': userId, 'timestamp': DateTime.now()},
  );
  rethrow;
}
```

### Logger Class

```dart
// GOOD - Dedicated logger class
class Logger {
  final String name;

  Logger(this.name);

  void debug(String message, [Map<String, dynamic>? context]) {
    _log('DEBUG', message, context);
  }

  void info(String message, [Map<String, dynamic>? context]) {
    _log('INFO', message, context);
  }

  void warning(String message, [Map<String, dynamic>? context]) {
    _log('WARNING', message, context);
  }

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    _log('ERROR', message, context);

    if (error != null) {
      developer.log(
        'Error details: $error',
        name: name,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _log(String level, String message, Map<String, dynamic>? context) {
    final timestamp = DateTime.now().toIso8601String();
    final contextStr = context != null ? ' $context' : '';
    print('[$timestamp] [$level] [$name] $message$contextStr');
  }
}

// Usage
final logger = Logger('UserService');

class UserService {
  final Logger _logger = Logger('UserService');

  Future<User> loadUser(String id) async {
    _logger.info('Loading user', {'userId': id});

    try {
      final user = await _fetchUser(id);
      _logger.debug('User loaded successfully', {'userId': id});
      return user;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to load user',
        error: e,
        stackTrace: stackTrace,
        context: {'userId': id},
      );
      rethrow;
    }
  }
}
```

### Error Reporting

```dart
// GOOD - Error reporting service
class ErrorReporter {
  static final ErrorReporter _instance = ErrorReporter._internal();
  factory ErrorReporter() => _instance;
  ErrorReporter._internal();

  final _errors = <ErrorReport>[];

  void reportError(
    Object error,
    StackTrace stackTrace, {
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    final report = ErrorReport(
      error: error,
      stackTrace: stackTrace,
      context: context,
      metadata: metadata,
      timestamp: DateTime.now(),
    );

    _errors.add(report);
    _logToConsole(report);
    _sendToServer(report);
  }

  void _logToConsole(ErrorReport report) {
    developer.log(
      'Error: ${report.error}',
      name: 'ErrorReporter',
      level: 1000,
      error: report.error,
      stackTrace: report.stackTrace,
    );
  }

  Future<void> _sendToServer(ErrorReport report) async {
    try {
      // Send to error tracking service
      await errorTrackingService.send(report.toJson());
    } catch (e) {
      print('Failed to send error report: $e');
    }
  }

  List<ErrorReport> get recentErrors => List.unmodifiable(_errors);
}

class ErrorReport {
  final Object error;
  final StackTrace stackTrace;
  final String? context;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ErrorReport({
    required this.error,
    required this.stackTrace,
    this.context,
    this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'context': context,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };
}
```

---

## Recovery Strategies

### Retry Logic

```dart
// GOOD - Exponential backoff retry
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 100),
  Duration maxDelay = const Duration(seconds: 10),
  bool Function(Object error)? shouldRetry,
}) async {
  var attempt = 0;
  var delay = initialDelay;

  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;

      // Check if we should give up
      if (attempt >= maxAttempts) {
        rethrow;
      }

      // Check if error is retryable
      if (shouldRetry != null && !shouldRetry(e)) {
        rethrow;
      }

      // Wait before retrying
      await Future.delayed(delay);

      // Exponential backoff with max delay
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 2).clamp(
          initialDelay.inMilliseconds,
          maxDelay.inMilliseconds,
        ),
      );
    }
  }
}

// Usage
final user = await retryWithBackoff(
  () => httpClient.get('/users/$id'),
  maxAttempts: 3,
  shouldRetry: (e) => e is SocketException || e is TimeoutException,
);
```

### Circuit Breaker

```dart
// GOOD - Circuit breaker pattern
class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;

  int _failureCount = 0;
  DateTime? _lastFailureTime;
  CircuitState _state = CircuitState.closed;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 60),
  });

  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitState.open) {
      if (_shouldAttemptReset()) {
        _state = CircuitState.halfOpen;
      } else {
        throw CircuitBreakerException('Circuit breaker is OPEN');
      }
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
    }
  }

  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return true;
    return DateTime.now().difference(_lastFailureTime!) >= resetTimeout;
  }

  CircuitState get state => _state;
}

enum CircuitState { closed, open, halfOpen }

class CircuitBreakerException implements Exception {
  final String message;
  CircuitBreakerException(this.message);

  @override
  String toString() => 'CircuitBreakerException: $message';
}
```

### Fallback Values

```dart
// GOOD - Provide fallback values
Future<List<User>> loadUsers() async {
  try {
    return await apiClient.getUsers();
  } catch (e) {
    logger.warning('Failed to load users, using empty list', error: e);
    return [];
  }
}

// GOOD - Fallback with cache
Future<List<User>> loadUsers() async {
  try {
    final users = await apiClient.getUsers();
    await cache.save('users', users);
    return users;
  } catch (e) {
    logger.warning('Failed to load users, using cached data', error: e);
    return await cache.get('users') ?? [];
  }
}

// GOOD - Graceful degradation
Future<Dashboard> loadDashboard() async {
  final criticalData = await loadCriticalData(); // Must succeed

  List<User>? users;
  try {
    users = await loadUsers();
  } catch (e) {
    logger.warning('Failed to load users', error: e);
    users = null;
  }

  List<Project>? projects;
  try {
    projects = await loadProjects();
  } catch (e) {
    logger.warning('Failed to load projects', error: e);
    projects = null;
  }

  return Dashboard(
    critical: criticalData,
    users: users,
    projects: projects,
  );
}
```

---

## Testing Error Scenarios

### Testing Exceptions

```dart
import 'package:test/test.dart';

void main() {
  group('Error handling tests', () {
    test('throws UserNotFoundException for invalid ID', () {
      final service = UserService();

      expect(
        () => service.loadUser('invalid-id'),
        throwsA(isA<UserNotFoundException>()),
      );
    });

    test('throws NetworkException on network failure', () async {
      final service = UserService(client: MockFailingClient());

      expect(
        service.loadUser('123'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('network'),
          ),
        ),
      );
    });

    test('handles error and returns fallback', () async {
      final service = UserService(client: MockFailingClient());

      final result = await service.loadUserOrDefault('123');

      expect(result, isA<User>());
      expect(result.name, equals('Guest'));
    });
  });
}
```

### Testing Async Errors

```dart
test('handles timeout correctly', () async {
  final service = UserService(
    client: MockSlowClient(delay: Duration(seconds: 5)),
  );

  await expectLater(
    service.loadUser('123', timeout: Duration(seconds: 1)),
    throwsA(isA<TimeoutException>()),
  );
});

test('recovers from transient errors', () async {
  var callCount = 0;
  final service = UserService(
    client: MockClient((request) {
      callCount++;
      if (callCount < 3) {
        throw SocketException('Connection failed');
      }
      return Future.value(Response('{"id": "123"}', 200));
    }),
  );

  final result = await service.loadUserWithRetry('123');

  expect(result, isA<User>());
  expect(callCount, equals(3));
});
```

---

## Best Practices Summary

### Error Handling Checklist

- [ ] Use specific exception types
- [ ] Provide meaningful error messages
- [ ] Always clean up resources in `finally`
- [ ] Log errors with context
- [ ] Handle or propagate, never swallow errors
- [ ] Use Result types for expected failures
- [ ] Implement retry logic for transient failures
- [ ] Provide fallback values when appropriate
- [ ] Test error scenarios thoroughly
- [ ] Document exceptions in API documentation

### Common Patterns

**Validation:**
```dart
void validateEmail(String email) {
  if (email.isEmpty) {
    throw ArgumentError('Email cannot be empty');
  }
  if (!email.contains('@')) {
    throw FormatException('Invalid email format');
  }
}
```

**Resource Management:**
```dart
Future<T> withResource<T>(
  Future<Resource> Function() acquire,
  Future<T> Function(Resource) use,
) async {
  Resource? resource;
  try {
    resource = await acquire();
    return await use(resource);
  } finally {
    await resource?.close();
  }
}
```

**Error Context:**
```dart
class OperationContext {
  final String operation;
  final Map<String, dynamic> data;

  OperationContext(this.operation, this.data);

  Never fail(String message, {Object? cause}) {
    throw OperationException(
      operation,
      message,
      data: data,
      cause: cause,
    );
  }
}
```

### Anti-Patterns to Avoid

**DON'T:**
- Catch exceptions without handling them
- Use exceptions for control flow
- Swallow errors silently
- Have empty catch blocks
- Throw generic Exception
- Ignore stack traces
- Retry indefinitely
- Expose technical errors to users

```dart
// BAD
try {
  riskyOperation();
} catch (e) {
  // Silent failure
}

// BAD
try {
  riskyOperation();
} catch (e) {
  throw Exception('Error');  // Generic, no context
}

// BAD
while (true) {
  try {
    await operation();
    break;
  } catch (e) {
    // Infinite retry
  }
}
```

### References

- [Dart Error Handling](https://dart.dev/guides/language/language-tour#exceptions)
- [Effective Dart: Error Handling](https://dart.dev/guides/language/effective-dart/error-handling)
- [dart:developer library](https://api.dart.dev/stable/dart-developer/dart-developer-library.html)
