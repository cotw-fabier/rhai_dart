# Coding Style Guide for Pure Dart Development

## Overview

This document defines comprehensive coding style guidelines for pure Dart development, based on Effective Dart and Google's Dart style guide. Consistent style makes code more readable, maintainable, and collaborative.

## Table of Contents

- [Naming Conventions](#naming-conventions)
- [Line Length and Formatting](#line-length-and-formatting)
- [Function Design](#function-design)
- [Code Organization](#code-organization)
- [Variables and Constants](#variables-and-constants)
- [Classes and Objects](#classes-and-objects)
- [Collections and Iterables](#collections-and-iterables)
- [Asynchronous Code](#asynchronous-code)
- [Modern Dart Features](#modern-dart-features)

---

## Naming Conventions

### Overview

Dart uses three naming conventions:
- **UpperCamelCase**: `MyClassName`
- **lowerCamelCase**: `myVariableName`
- **lowercase_with_underscores**: `my_file_name.dart`

### Classes, Enums, Typedefs, and Type Parameters

Use **UpperCamelCase** (also called PascalCase):

```dart
// GOOD
class UserAccount {}
class HttpClient {}
enum ConnectionState {}
typedef Predicate<T> = bool Function(T value);

// BAD
class userAccount {}
class HTTPClient {}      // Acronyms should follow same pattern
enum connection_state {}
```

### Acronyms and Abbreviations

Treat acronyms as words for readability:

```dart
// GOOD
class HttpClient {}
class JsonParser {}
class HtmlEscape {}
class DbConnection {}
class IoException {}

// BAD
class HTTPClient {}
class JSONParser {}
class HTMLEscape {}
```

### Libraries, Packages, Directories, Files

Use **lowercase_with_underscores**:

```dart
// GOOD
library my_library;
import 'my_file.dart';
// file: user_service.dart
// directory: lib/src/data_models/

// BAD
library myLibrary;
import 'MyFile.dart';
// file: UserService.dart or userService.dart
```

### Class Members

Use **lowerCamelCase** for:
- Variables
- Methods
- Parameters
- Named parameters
- Named constructors

```dart
// GOOD
class User {
  final String firstName;
  final int accountId;

  User({required this.firstName, required this.accountId});

  User.guest() : firstName = 'Guest', accountId = 0;

  String getFullName() => firstName;

  void updateEmail(String newEmail) {
    // Implementation
  }
}

// BAD
class User {
  final String FirstName;        // Never UpperCamelCase
  final int account_id;          // Never snake_case

  void UpdateEmail(String NewEmail) {  // Never UpperCamelCase
    // Implementation
  }
}
```

### Constants

Use **lowerCamelCase** for constants:

```dart
// GOOD
const maxRetries = 3;
const defaultTimeout = Duration(seconds: 30);
const apiBaseUrl = 'https://api.example.com';

// BAD
const MAX_RETRIES = 3;           // Don't use SCREAMING_CAPS
const DefaultTimeout = Duration(seconds: 30);
```

### Private Members

Prefix with underscore:

```dart
class BankAccount {
  final String _accountNumber;   // Private field
  int _balance = 0;              // Private field

  BankAccount(this._accountNumber);

  void _updateBalance(int amount) {  // Private method
    _balance += amount;
  }

  int get balance => _balance;   // Public getter
}
```

### Boolean Names

Use positive, question-like names:

```dart
// GOOD
bool isEmpty;
bool hasPermission;
bool isEnabled;
bool canDelete;
bool shouldRetry;

// BAD
bool notEmpty;        // Avoid negatives
bool permission;      // Not clear it's boolean
bool enabled;         // Ambiguous (could be verb)
```

### Complete Naming Examples

```dart
// Excellent naming example
class UserAuthenticationService {
  final HttpClient _client;
  final String _apiBaseUrl;
  bool _isAuthenticated = false;

  UserAuthenticationService({
    required HttpClient client,
    required String apiBaseUrl,
  })  : _client = client,
        _apiBaseUrl = apiBaseUrl;

  Future<bool> authenticateUser({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      return false;
    }

    final response = await _sendAuthRequest(username, password);
    _isAuthenticated = response.isSuccess;
    return _isAuthenticated;
  }

  Future<AuthResponse> _sendAuthRequest(
    String username,
    String password,
  ) async {
    // Implementation
    return AuthResponse();
  }

  bool get isAuthenticated => _isAuthenticated;
}
```

---

## Line Length and Formatting

### Line Length

**Maximum 80 characters per line** (enforced by `dart format`):

```dart
// GOOD - Under 80 characters
final user = User(
  name: 'John Doe',
  email: 'john@example.com',
);

// GOOD - Break long lines
final message = 'This is a very long message that would exceed the '
    'eighty character limit if we tried to fit it on one line.';

// GOOD - Break method chains
final result = repository
    .getUsers()
    .where((user) => user.isActive)
    .map((user) => user.email)
    .toList();

// BAD - Over 80 characters (dart format will break it)
final user = User(name: 'John Doe', email: 'john@example.com', age: 30, city: 'New York');
```

### Automated Formatting

**Always use `dart format`**:

```bash
# Format all Dart files in project
dart format .

# Format specific file
dart format lib/src/models/user.dart

# Check formatting without modifying
dart format --set-exit-if-changed .
```

### Indentation

**2 spaces** (enforced by `dart format`):

```dart
// GOOD - 2 space indentation
class User {
  final String name;

  User(this.name);

  void greet() {
    if (name.isNotEmpty) {
      print('Hello, $name!');
    }
  }
}

// BAD - Never use tabs or 4 spaces
class User {
    final String name;  // 4 spaces - wrong

	User(this.name);    // Tab - wrong
}
```

### Whitespace

Follow `dart format` conventions:

```dart
// GOOD - Proper whitespace
final sum = a + b;
final result = calculate(x, y);
if (isValid) {
  process();
}

// BAD - Inconsistent whitespace
final sum=a+b;
final result = calculate( x,y );
if(isValid){
  process();
}
```

### Line Breaks

Break lines at logical points:

```dart
// GOOD - Logical line breaks
final user = User(
  name: 'John Doe',
  email: 'john@example.com',
  age: 30,
);

// GOOD - Break before operators
final isValid = user.hasValidEmail &&
    user.hasValidAge &&
    user.hasAcceptedTerms;

// GOOD - Break after opening delimiter
final list = [
  'first',
  'second',
  'third',
];
```

---

## Function Design

### Function Length

Keep functions **under 50 lines**:

```dart
// GOOD - Focused, single responsibility
Future<User> loadUser(String id) async {
  final response = await _client.get('/users/$id');

  if (response.statusCode != 200) {
    throw HttpException('Failed to load user');
  }

  return User.fromJson(response.body);
}

// BAD - Too long, multiple responsibilities
Future<void> processUserData(String id) async {
  // 200 lines of mixed concerns
  // Loading, validation, transformation, storage
  // Should be broken into separate functions
}
```

### Function Complexity

Limit cyclomatic complexity (aim for < 10):

```dart
// GOOD - Simple, clear logic
String getUserStatus(User user) {
  if (user.isActive) {
    return 'Active';
  } else if (user.isPending) {
    return 'Pending';
  } else {
    return 'Inactive';
  }
}

// BETTER - Use early returns
String getUserStatus(User user) {
  if (user.isActive) return 'Active';
  if (user.isPending) return 'Pending';
  return 'Inactive';
}

// BAD - Too complex (multiple nested conditions)
String processUser(User user) {
  if (user.isActive) {
    if (user.hasPermission) {
      if (user.isPremium) {
        if (user.hasValidSubscription) {
          // Deep nesting makes it hard to follow
        }
      }
    }
  }
  return '';
}

// BETTER - Extract complexity
String processUser(User user) {
  if (!user.isActive) return 'Inactive user';
  if (!user.hasPermission) return 'No permission';

  return _processPremiumUser(user);
}

String _processPremiumUser(User user) {
  if (!user.isPremium) return 'Not premium';
  if (!user.hasValidSubscription) return 'Invalid subscription';

  return 'Success';
}
```

### Function Parameters

Limit to **3-4 positional parameters**; use named parameters for more:

```dart
// GOOD - Few positional parameters
void createUser(String name, String email) {
  // Implementation
}

// GOOD - Named parameters for clarity
void createUser({
  required String name,
  required String email,
  int age = 0,
  String? address,
}) {
  // Implementation
}

// BAD - Too many positional parameters
void createUser(String name, String email, int age, String address,
    String phone, String city, String country) {
  // Hard to remember order
}

// BETTER - Use a parameter object
void createUser(UserData data) {
  // Clear and extensible
}

class UserData {
  final String name;
  final String email;
  final int age;
  final String? address;

  UserData({
    required this.name,
    required this.email,
    this.age = 0,
    this.address,
  });
}
```

### Single Responsibility

Each function should do one thing:

```dart
// GOOD - Single responsibility
Future<User> loadUser(String id) async {
  final json = await _fetchUserJson(id);
  return _parseUser(json);
}

Future<Map<String, dynamic>> _fetchUserJson(String id) async {
  final response = await _client.get('/users/$id');
  _validateResponse(response);
  return jsonDecode(response.body) as Map<String, dynamic>;
}

User _parseUser(Map<String, dynamic> json) {
  return User.fromJson(json);
}

void _validateResponse(Response response) {
  if (response.statusCode != 200) {
    throw HttpException('Request failed: ${response.statusCode}');
  }
}

// BAD - Multiple responsibilities
Future<User> loadUser(String id) async {
  // Fetching
  final response = await _client.get('/users/$id');

  // Validation
  if (response.statusCode != 200) {
    throw HttpException('Failed');
  }

  // Parsing
  final json = jsonDecode(response.body);

  // Transformation
  final user = User.fromJson(json);

  // Caching
  _cache[id] = user;

  // Logging
  print('Loaded user: ${user.name}');

  return user;
}
```

---

## Code Organization

### File Structure

Organize code in consistent order:

```dart
// 1. Imports (organized by import conventions)
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:my_app/src/models/user.dart';

// 2. Part directives (if any)
part 'auth_service_extensions.dart';

// 3. Top-level constants
const defaultTimeout = Duration(seconds: 30);

// 4. Top-level functions
String formatUserId(String id) => 'USER_$id';

// 5. Classes
class AuthService {
  // Class implementation
}

// 6. Extensions
extension AuthServiceExtensions on AuthService {
  // Extension methods
}
```

### Class Organization

Order class members logically:

```dart
class UserService {
  // 1. Static constants
  static const maxRetries = 3;

  // 2. Static methods
  static String formatId(String id) => 'USER_$id';

  // 3. Instance fields (public then private)
  final HttpClient client;
  final String _apiKey;

  // 4. Constructors
  UserService({
    required this.client,
    required String apiKey,
  }) : _apiKey = apiKey;

  // 5. Named constructors
  UserService.withDefaults()
      : client = HttpClient(),
        _apiKey = '';

  // 6. Getters and setters
  bool get isConfigured => _apiKey.isNotEmpty;

  // 7. Public methods
  Future<User> getUser(String id) async {
    return _fetchUser(id);
  }

  // 8. Private methods
  Future<User> _fetchUser(String id) async {
    // Implementation
    return User(id: id, name: 'Test');
  }
}
```

### Grouping Related Code

Keep related code together:

```dart
// GOOD - Related functionality grouped
class ShoppingCart {
  final List<CartItem> _items = [];

  // Item management
  void addItem(CartItem item) => _items.add(item);
  void removeItem(CartItem item) => _items.remove(item);
  void clearItems() => _items.clear();

  // Price calculations
  double get subtotal => _calculateSubtotal();
  double get tax => _calculateTax();
  double get total => subtotal + tax;

  double _calculateSubtotal() {
    return _items.fold(0, (sum, item) => sum + item.price);
  }

  double _calculateTax() {
    return subtotal * 0.1;
  }
}

// BAD - Mixed concerns, no grouping
class ShoppingCart {
  final List<CartItem> _items = [];

  void addItem(CartItem item) => _items.add(item);

  double get subtotal => _calculateSubtotal();

  void removeItem(CartItem item) => _items.remove(item);

  double _calculateSubtotal() {
    return _items.fold(0, (sum, item) => sum + item.price);
  }

  double get tax => _calculateTax();

  void clearItems() => _items.clear();

  double _calculateTax() {
    return subtotal * 0.1;
  }
}
```

---

## Variables and Constants

### Declaring Variables

Use the most specific type:

```dart
// GOOD - Explicit types when not obvious
final String name = 'John';
final int age = 30;
final List<String> tags = ['dart', 'flutter'];

// GOOD - Type inference when obvious
final message = 'Hello';           // Clearly String
final count = 42;                  // Clearly int
final items = <String>[];          // Type specified in constructor

// BAD - Unnecessary type annotation
final String message = 'Hello';    // Type is obvious

// BAD - var when type is not obvious
var response = await client.get(url);  // What type is response?
```

### const vs final vs var

```dart
// const - Compile-time constant (deeply immutable)
const pi = 3.14159;
const emptyList = <String>[];
const greeting = 'Hello, World!';

// final - Runtime constant (reference immutable)
final now = DateTime.now();        // Value determined at runtime
final user = User(name: 'John');   // Object mutable, reference immutable

// var - Mutable variable
var counter = 0;
counter++;                          // Can be reassigned

// GOOD - Use const whenever possible
const maxRetries = 3;
const defaultConfig = {
  'timeout': 30,
  'retries': 3,
};

// GOOD - Use final for runtime values
final userId = generateUserId();
final createdAt = DateTime.now();

// GOOD - Use var only when reassignment needed
var attemptCount = 0;
for (var i = 0; i < maxRetries; i++) {
  attemptCount++;
}
```

### Late Variables

Use `late` sparingly:

```dart
// GOOD - late for expensive initialization
class DatabaseService {
  late final Database _database;

  Future<void> initialize() async {
    _database = await Database.connect();
  }
}

// GOOD - late with initializer
class Config {
  late final String apiKey = _loadApiKey();

  String _loadApiKey() {
    // Expensive operation, only run when accessed
    return Platform.environment['API_KEY'] ?? '';
  }
}

// BAD - late to avoid null safety (use nullable instead)
class UserService {
  late User user;  // Might crash if accessed before assignment

  void load() {
    user = User.load();
  }
}

// BETTER - Use nullable or required initialization
class UserService {
  User? user;

  void load() {
    user = User.load();
  }
}
```

### Variable Scope

Minimize variable scope:

```dart
// GOOD - Variables declared close to usage
void processUsers(List<User> users) {
  for (final user in users) {
    final name = user.name.trim();
    final email = user.email.toLowerCase();

    if (name.isNotEmpty && email.isNotEmpty) {
      _saveUser(name, email);
    }
  }
}

// BAD - Wide scope
void processUsers(List<User> users) {
  String name;
  String email;

  for (final user in users) {
    name = user.name.trim();
    email = user.email.toLowerCase();

    if (name.isNotEmpty && email.isNotEmpty) {
      _saveUser(name, email);
    }
  }
}
```

---

## Classes and Objects

### Constructors

```dart
// GOOD - Clear, explicit constructors
class User {
  final String id;
  final String name;
  final String email;

  // Primary constructor with named parameters
  User({
    required this.id,
    required this.name,
    required this.email,
  });

  // Named constructor for specific use case
  User.guest()
      : id = 'guest',
        name = 'Guest User',
        email = 'guest@example.com';

  // Factory constructor for deserialization
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}

// BAD - Positional parameters without clarity
class User {
  final String id;
  final String name;
  final String email;

  User(this.id, this.name, this.email);  // Hard to remember order
}
```

### Immutability

Prefer immutable objects:

```dart
// GOOD - Immutable class
class User {
  final String name;
  final String email;

  const User({required this.name, required this.email});

  // Return new instance instead of mutating
  User copyWith({String? name, String? email}) {
    return User(
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }
}

// Usage
final user = User(name: 'John', email: 'john@example.com');
final updatedUser = user.copyWith(email: 'newemail@example.com');

// BAD - Mutable class
class User {
  String name;
  String email;

  User({required this.name, required this.email});

  void updateEmail(String newEmail) {
    email = newEmail;  // Mutation makes state tracking difficult
  }
}
```

### Getters and Setters

Use getters for computed properties:

```dart
// GOOD - Getters for computed values
class Rectangle {
  final double width;
  final double height;

  const Rectangle({required this.width, required this.height});

  double get area => width * height;
  double get perimeter => 2 * (width + height);
  bool get isSquare => width == height;
}

// BAD - Methods for simple computed values
class Rectangle {
  final double width;
  final double height;

  const Rectangle({required this.width, required this.height});

  double getArea() => width * height;        // Should be getter
  double calculatePerimeter() => 2 * (width + height);  // Should be getter
}

// GOOD - Methods for complex operations
class DataProcessor {
  final List<int> data;

  DataProcessor(this.data);

  // Method because it's expensive/complex
  Future<Statistics> calculateStatistics() async {
    // Complex calculation
    return Statistics();
  }

  // Method because it has side effects
  void saveToFile(String path) {
    // I/O operation
  }
}
```

### Equality and Hash Code

Override `==` and `hashCode` together:

```dart
// GOOD - Proper equality implementation
class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}

// BETTER - Use package:equatable for complex classes
import 'package:equatable/equatable.dart';

class Point extends Equatable {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  List<Object?> get props => [x, y];

  @override
  String toString() => 'Point($x, $y)';
}
```

---

## Collections and Iterables

### Collection Literals

Use collection literals:

```dart
// GOOD - Collection literals
final numbers = <int>[1, 2, 3];
final names = <String>{'Alice', 'Bob'};
final config = <String, int>{'retries': 3, 'timeout': 30};

// BAD - Constructors
final numbers = List<int>();
final names = Set<String>();
final config = Map<String, int>();
```

### Collection If and For

Use collection if and for:

```dart
// GOOD - Collection if
final items = [
  'Home',
  if (user.isAuthenticated) 'Profile',
  if (user.isAdmin) 'Admin Panel',
];

// GOOD - Collection for
final numbers = [1, 2, 3, 4, 5];
final doubled = [
  for (final n in numbers) n * 2,
];

// BAD - Imperative style
final items = ['Home'];
if (user.isAuthenticated) {
  items.add('Profile');
}
if (user.isAdmin) {
  items.add('Admin Panel');
}
```

### Spread Operator

Use spread operator for combining collections:

```dart
// GOOD - Spread operator
final defaults = ['option1', 'option2'];
final custom = ['option3'];
final all = [...defaults, ...custom];

// GOOD - Conditional spread
final items = [
  'always',
  ...?optionalItems,  // null-safe spread
];

// BAD - addAll
final all = <String>[];
all.addAll(defaults);
all.addAll(custom);
```

### Cascade Notation

Use cascades for sequential operations:

```dart
// GOOD - Cascade notation
final list = []
  ..add('first')
  ..add('second')
  ..addAll(['third', 'fourth']);

// GOOD - Cascade with methods
final buffer = StringBuffer()
  ..write('Hello')
  ..write(' ')
  ..write('World');

// BAD - Repetitive
final list = [];
list.add('first');
list.add('second');
list.addAll(['third', 'fourth']);
```

---

## Asynchronous Code

### Future vs async/await

Prefer `async`/`await` over `.then()`:

```dart
// GOOD - async/await
Future<User> loadUser(String id) async {
  try {
    final response = await client.get('/users/$id');
    return User.fromJson(response.body);
  } catch (e) {
    throw LoadUserException('Failed to load user: $e');
  }
}

// BAD - Nested .then()
Future<User> loadUser(String id) {
  return client.get('/users/$id').then((response) {
    return User.fromJson(response.body);
  }).catchError((e) {
    throw LoadUserException('Failed to load user: $e');
  });
}
```

### Avoid async When Not Needed

```dart
// GOOD - No async needed
Future<String> getGreeting() {
  return Future.value('Hello');
}

// BAD - Unnecessary async
Future<String> getGreeting() async {
  return 'Hello';
}

// GOOD - async needed for await
Future<User> loadUser() async {
  final data = await fetchData();
  return User.fromJson(data);
}
```

### Error Handling in Async Code

```dart
// GOOD - Proper error handling
Future<User> loadUser(String id) async {
  try {
    final response = await client.get('/users/$id');

    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }

    return User.fromJson(jsonDecode(response.body));
  } on SocketException {
    throw NetworkException('No internet connection');
  } on FormatException {
    throw ParseException('Invalid JSON response');
  } catch (e) {
    throw LoadUserException('Failed to load user: $e');
  }
}
```

### Parallel Execution

Use `Future.wait()` for parallel execution:

```dart
// GOOD - Parallel execution
Future<Dashboard> loadDashboard() async {
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
}

// BAD - Sequential execution (slower)
Future<Dashboard> loadDashboard() async {
  final users = await loadUsers();
  final projects = await loadProjects();
  final statistics = await loadStatistics();

  return Dashboard(
    users: users,
    projects: projects,
    statistics: statistics,
  );
}
```

---

## Modern Dart Features

### Null Safety

Embrace null safety:

```dart
// GOOD - Explicit nullability
String? findUser(String id) {
  final user = database.find(id);
  return user?.name;
}

// GOOD - Null-aware operators
final name = user?.name ?? 'Unknown';
final length = items?.length ?? 0;
items?.forEach(print);

// GOOD - Null assertion when guaranteed non-null
String getUserName(User? user) {
  if (user == null) {
    throw ArgumentError('User cannot be null');
  }
  return user.name;  // No need for ! here, compiler knows it's non-null
}

// BAD - Unnecessary null checks
String getUserName(User user) {
  if (user != null) {  // user is non-nullable, check is useless
    return user.name;
  }
  return 'Unknown';
}
```

### Pattern Matching (Dart 3.0+)

Use pattern matching:

```dart
// GOOD - Pattern matching in switch
String describe(Object obj) {
  return switch (obj) {
    int value => 'Integer: $value',
    String value => 'String: $value',
    List<int> value => 'List of integers: ${value.length}',
    _ => 'Unknown type',
  };
}

// GOOD - Destructuring
final (x, y) = getCoordinates();
final {'name': name, 'age': age} = userJson;
```

### Records (Dart 3.0+)

Use records for multiple return values:

```dart
// GOOD - Record return type
(String, int) getUserInfo(String id) {
  final user = getUser(id);
  return (user.name, user.age);
}

// Usage
final (name, age) = getUserInfo('123');
print('$name is $age years old');

// GOOD - Named record fields
({String name, int age, String email}) getUserInfo(String id) {
  final user = getUser(id);
  return (name: user.name, age: user.age, email: user.email);
}

// Usage
final info = getUserInfo('123');
print('${info.name} - ${info.email}');
```

### Extension Methods

Use extensions to add functionality:

```dart
// GOOD - Extension methods
extension StringExtensions on String {
  bool get isValidEmail {
    return contains('@') && contains('.');
  }

  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

// Usage
final email = 'test@example.com';
if (email.isValidEmail) {
  print('Valid email');
}

final name = 'john'.capitalize();  // 'John'
```

---

## Summary

### Key Principles

1. **Consistency**: Follow Dart conventions, use `dart format`
2. **Clarity**: Write code that explains itself
3. **Simplicity**: Prefer simple solutions over clever ones
4. **Type Safety**: Leverage Dart's type system
5. **Modern Features**: Use latest Dart features appropriately

### Checklist

- [ ] All names follow correct case conventions
- [ ] Lines are under 80 characters
- [ ] Functions are focused and under 50 lines
- [ ] Code is formatted with `dart format`
- [ ] `const` used wherever possible
- [ ] Null safety patterns followed
- [ ] Async/await used properly
- [ ] Modern Dart features utilized

### References

- [Effective Dart: Style](https://dart.dev/effective-dart/style)
- [Effective Dart: Usage](https://dart.dev/effective-dart/usage)
- [Dart Language Tour](https://dart.dev/language)
