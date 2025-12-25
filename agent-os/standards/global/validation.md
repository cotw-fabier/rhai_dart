# Input Validation Best Practices for Pure Dart Development

## Overview

This document provides comprehensive guidance on input validation in pure Dart applications. Proper validation ensures data integrity, security, and reliability throughout your application.

## Table of Contents

- [Validation Philosophy](#validation-philosophy)
- [Where to Validate](#where-to-validate)
- [Validation Patterns](#validation-patterns)
- [String Validation](#string-validation)
- [Numeric Validation](#numeric-validation)
- [Collection Validation](#collection-validation)
- [Domain Model Validation](#domain-model-validation)
- [Async Validation](#async-validation)
- [Security Validation](#security-validation)
- [Validation Libraries](#validation-libraries)

---

## Validation Philosophy

### Core Principles

1. **Validate Early**: Check inputs as soon as they enter your system
2. **Validate Often**: Validate at boundaries (UI, API, database)
3. **Fail Fast**: Reject invalid input immediately with clear messages
4. **Be Specific**: Provide detailed error messages for each validation failure
5. **Never Trust Input**: Validate all external data, even from trusted sources

###When to Validate

```dart
// GOOD - Validate at function entry
Future<User> createUser({
  required String name,
  required String email,
  required int age,
}) async {
  // Validate immediately
  _validateName(name);
  _validateEmail(email);
  _validateAge(age);

  // Proceed with business logic
  return User(name: name, email: email, age: age);
}

// BAD - Validation scattered throughout
Future<User> createUser({
  required String name,
  required String email,
  required int age,
}) async {
  final user = User(name: name, email: email, age: age);

  // Too late - invalid object already created
  if (email.isEmpty) {
    throw ArgumentError('Email required');
  }

  return user;
}
```

---

## Where to Validate

### Multi-Layer Validation Strategy

Implement validation at multiple layers for defense in depth:

```dart
// Layer 1: Constructor validation (domain model)
class User {
  final String name;
  final String email;
  final int age;

  User({
    required String name,
    required String email,
    required int age,
  })  : name = _validateName(name),
        email = _validateEmail(email),
        age = _validateAge(age);

  static String _validateName(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Name cannot be empty');
    }
    if (name.length > 100) {
      throw ArgumentError('Name cannot exceed 100 characters');
    }
    return name.trim();
  }

  static String _validateEmail(String email) {
    final trimmed = email.trim().toLowerCase();
    if (!_emailRegex.hasMatch(trimmed)) {
      throw FormatException('Invalid email format');
    }
    return trimmed;
  }

  static int _validateAge(int age) {
    if (age < 0) {
      throw RangeError('Age cannot be negative');
    }
    if (age > 150) {
      throw RangeError('Age cannot exceed 150');
    }
    return age;
  }

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
}

// Layer 2: Service validation (business rules)
class UserService {
  Future<User> createUser({
    required String name,
    required String email,
    required int age,
  }) async {
    // Business rule: Check if email already exists
    if (await _emailExists(email)) {
      throw ValidationException('Email already registered');
    }

    // Business rule: Users must be at least 13 years old
    if (age < 13) {
      throw ValidationException('Users must be at least 13 years old');
    }

    return User(name: name, email: email, age: age);
  }

  Future<bool> _emailExists(String email) async {
    // Check database
    return false;
  }
}

// Layer 3: API/CLI validation (user input)
class UserInputValidator {
  ValidationResult validate(Map<String, dynamic> input) {
    final errors = <String, List<String>>{};

    // Validate required fields
    if (!input.containsKey('name') || input['name'] == null) {
      errors['name'] = ['Name is required'];
    }

    if (!input.containsKey('email') || input['email'] == null) {
      errors['email'] = ['Email is required'];
    }

    if (!input.containsKey('age') || input['age'] == null) {
      errors['age'] = ['Age is required'];
    }

    // Validate field types and formats
    if (input['name'] is! String) {
      (errors['name'] ??= []).add('Name must be a string');
    }

    if (input['email'] is! String) {
      (errors['email'] ??= []).add('Email must be a string');
    }

    if (input['age'] is! int) {
      (errors['age'] ??= []).add('Age must be an integer');
    }

    return ValidationResult(errors);
  }
}

class ValidationResult {
  final Map<String, List<String>> errors;

  ValidationResult(this.errors);

  bool get isValid => errors.isEmpty;
  bool get hasErrors => errors.isNotEmpty;

  String? getFirstError(String field) {
    return errors[field]?.firstOrNull;
  }

  List<String> getAllErrors() {
    return errors.values.expand((e) => e).toList();
  }
}
```

---

## Validation Patterns

### Required Field Validation

```dart
// GOOD - Helper function for required fields
T requireNonNull<T>(T? value, String fieldName) {
  if (value == null) {
    throw ArgumentError('$fieldName is required');
  }
  return value;
}

String requireNonEmpty(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    throw ArgumentError('$fieldName cannot be empty');
  }
  return value.trim();
}

// Usage
class Product {
  final String name;
  final double price;

  Product({
    required String? name,
    required double? price,
  })  : name = requireNonEmpty(name, 'Product name'),
        price = requireNonNull(price, 'Product price');
}
```

### Range Validation

```dart
// GOOD - Generic range validator
T requireInRange<T extends Comparable>(
  T value,
  T min,
  T max,
  String fieldName,
) {
  if (value.compareTo(min) < 0 || value.compareTo(max) > 0) {
    throw RangeError('$fieldName must be between $min and $max');
  }
  return value;
}

// Usage
class Product {
  final int quantity;
  final double price;

  Product({
    required int quantity,
    required double price,
  })  : quantity = requireInRange(quantity, 0, 10000, 'Quantity'),
        price = requireInRange(price, 0.01, 1000000.0, 'Price');
}
```

### Pattern Matching Validation

```dart
// GOOD - Pattern validators
bool matchesPattern(String value, RegExp pattern, String patternName) {
  if (!pattern.hasMatch(value)) {
    throw FormatException('Invalid $patternName format');
  }
  return true;
}

// Common patterns
class ValidationPatterns {
  static final email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final phone = RegExp(
    r'^\+?[1-9]\d{1,14}$', // E.164 format
  );

  static final alphanumeric = RegExp(r'^[a-zA-Z0-9]+$');

  static final username = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');

  static final hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
}

// Usage
String validateEmail(String email) {
  matchesPattern(email, ValidationPatterns.email, 'email');
  return email;
}

String validateUsername(String username) {
  matchesPattern(username, ValidationPatterns.username, 'username');
  return username;
}
```

---

## String Validation

### Length Validation

```dart
String validateLength(
  String value,
  int minLength,
  int maxLength,
  String fieldName,
) {
  final trimmed = value.trim();

  if (trimmed.length < minLength) {
    throw FormatException(
      '$fieldName must be at least $minLength characters',
    );
  }

  if (trimmed.length > maxLength) {
    throw FormatException(
      '$fieldName cannot exceed $maxLength characters',
    );
  }

  return trimmed;
}

// Usage
class Article {
  final String title;
  final String body;

  Article({
    required String title,
    required String body,
  })  : title = validateLength(title, 5, 200, 'Title'),
        body = validateLength(body, 50, 50000, 'Body');
}
```

### Email Validation

```dart
class EmailValidator {
  static final _regex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Validates email format according to RFC 5322 (simplified).
  ///
  /// Returns the normalized email (trimmed, lowercase).
  /// Throws [FormatException] if invalid.
  static String validate(String email) {
    final normalized = email.trim().toLowerCase();

    if (normalized.isEmpty) {
      throw FormatException('Email cannot be empty');
    }

    if (normalized.length > 254) {
      throw FormatException('Email cannot exceed 254 characters');
    }

    if (!_regex.hasMatch(normalized)) {
      throw FormatException('Invalid email format');
    }

    // Additional checks
    final parts = normalized.split('@');
    if (parts[0].isEmpty) {
      throw FormatException('Email local part cannot be empty');
    }

    if (parts[1].isEmpty) {
      throw FormatException('Email domain cannot be empty');
    }

    if (parts[1].startsWith('.') || parts[1].endsWith('.')) {
      throw FormatException('Invalid email domain format');
    }

    return normalized;
  }

  /// Checks if email format is valid without throwing.
  static bool isValid(String email) {
    try {
      validate(email);
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

### URL Validation

```dart
class UrlValidator {
  /// Validates and normalizes a URL.
  ///
  /// Throws [FormatException] if the URL is invalid.
  static Uri validate(String url, {bool requireHttps = false}) {
    if (url.trim().isEmpty) {
      throw FormatException('URL cannot be empty');
    }

    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      throw FormatException('Invalid URL format: $e');
    }

    if (!uri.hasScheme) {
      throw FormatException('URL must include a scheme (http/https)');
    }

    if (requireHttps && uri.scheme != 'https') {
      throw FormatException('URL must use HTTPS');
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('URL must use http or https scheme');
    }

    if (!uri.hasAuthority) {
      throw FormatException('URL must include a domain');
    }

    return uri;
  }

  static bool isValid(String url, {bool requireHttps = false}) {
    try {
      validate(url, requireHttps: requireHttps);
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

### Password Validation

```dart
class PasswordValidator {
  static const minLength = 8;
  static const maxLength = 128;

  /// Validates password strength.
  ///
  /// Requirements:
  ///   * 8-128 characters
  ///   * At least one uppercase letter
  ///   * At least one lowercase letter
  ///   * At least one digit
  ///   * At least one special character
  static ValidationResult validate(String password) {
    final errors = <String>[];

    if (password.length < minLength) {
      errors.add('Password must be at least $minLength characters');
    }

    if (password.length > maxLength) {
      errors.add('Password cannot exceed $maxLength characters');
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one digit');
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Password must contain at least one special character');
    }

    // Check for common weak passwords
    if (_isCommonPassword(password)) {
      errors.add('This password is too common');
    }

    return ValidationResult({'password': errors});
  }

  static bool _isCommonPassword(String password) {
    const common = [
      'password',
      'password123',
      '12345678',
      'qwerty',
      'abc123',
    ];
    return common.contains(password.toLowerCase());
  }

  /// Calculates password strength (0-4).
  static int calculateStrength(String password) {
    var strength = 0;

    if (password.length >= 12) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    return (strength * 4 / 5).round(); // Normalize to 0-4
  }
}
```

---

## Numeric Validation

### Integer Range Validation

```dart
int validateIntRange(
  int value,
  int min,
  int max,
  String fieldName,
) {
  if (value < min) {
    throw RangeError('$fieldName must be at least $min');
  }

  if (value > max) {
    throw RangeError('$fieldName cannot exceed $max');
  }

  return value;
}

// Usage
class Order {
  final int quantity;
  final int customerId;

  Order({
    required int quantity,
    required int customerId,
  })  : quantity = validateIntRange(quantity, 1, 1000, 'Quantity'),
        customerId = validateIntRange(customerId, 1, 999999999, 'Customer ID');
}
```

### Decimal Validation

```dart
double validateDecimal(
  double value,
  double min,
  double max,
  int decimalPlaces,
  String fieldName,
) {
  if (value < min || value > max) {
    throw RangeError('$fieldName must be between $min and $max');
  }

  // Check decimal places
  final multiplier = pow(10, decimalPlaces);
  final rounded = (value * multiplier).round() / multiplier;

  if ((value - rounded).abs() > 0.0000001) {
    throw FormatException(
      '$fieldName cannot have more than $decimalPlaces decimal places',
    );
  }

  return rounded;
}

// Usage
class Product {
  final double price;
  final double weight;

  Product({
    required double price,
    required double weight,
  })  : price = validateDecimal(price, 0.01, 1000000.0, 2, 'Price'),
        weight = validateDecimal(weight, 0.1, 10000.0, 2, 'Weight');
}
```

### Positive/Negative Validation

```dart
int requirePositive(int value, String fieldName) {
  if (value <= 0) {
    throw ArgumentError('$fieldName must be positive');
  }
  return value;
}

int requireNonNegative(int value, String fieldName) {
  if (value < 0) {
    throw ArgumentError('$fieldName cannot be negative');
  }
  return value;
}

double requirePositiveDouble(double value, String fieldName) {
  if (value <= 0.0) {
    throw ArgumentError('$fieldName must be positive');
  }
  return value;
}

// Usage
class Account {
  final double balance;
  final int transactionCount;

  Account({
    required double balance,
    required int transactionCount,
  })  : balance = requirePositiveDouble(balance, 'Balance'),
        transactionCount = requireNonNegative(transactionCount, 'Transaction count');
}
```

---

## Collection Validation

### List Validation

```dart
List<T> validateList<T>(
  List<T>? list,
  String fieldName, {
  int? minLength,
  int? maxLength,
  bool Function(T)? elementValidator,
}) {
  if (list == null) {
    throw ArgumentError('$fieldName cannot be null');
  }

  if (minLength != null && list.length < minLength) {
    throw ArgumentError('$fieldName must contain at least $minLength items');
  }

  if (maxLength != null && list.length > maxLength) {
    throw ArgumentError('$fieldName cannot contain more than $maxLength items');
  }

  if (elementValidator != null) {
    for (var i = 0; i < list.length; i++) {
      if (!elementValidator(list[i])) {
        throw ArgumentError('Invalid element at index $i in $fieldName');
      }
    }
  }

  return list;
}

// Usage
class ShoppingCart {
  final List<CartItem> items;

  ShoppingCart({required List<CartItem>? items})
      : items = validateList(
          items,
          'Cart items',
          minLength: 1,
          maxLength: 100,
          elementValidator: (item) => item.quantity > 0,
        );
}
```

### Map Validation

```dart
Map<K, V> validateMap<K, V>(
  Map<K, V>? map,
  String fieldName, {
  int? minSize,
  int? maxSize,
  List<K>? requiredKeys,
}) {
  if (map == null) {
    throw ArgumentError('$fieldName cannot be null');
  }

  if (minSize != null && map.length < minSize) {
    throw ArgumentError('$fieldName must contain at least $minSize entries');
  }

  if (maxSize != null && map.length > maxSize) {
    throw ArgumentError('$fieldName cannot contain more than $maxSize entries');
  }

  if (requiredKeys != null) {
    for (final key in requiredKeys) {
      if (!map.containsKey(key)) {
        throw ArgumentError('$fieldName must contain key: $key');
      }
    }
  }

  return map;
}

// Usage
class Configuration {
  final Map<String, dynamic> settings;

  Configuration({required Map<String, dynamic>? settings})
      : settings = validateMap(
          settings,
          'Settings',
          requiredKeys: ['apiUrl', 'timeout', 'retries'],
        );
}
```

### Set Validation

```dart
Set<T> validateSet<T>(
  Set<T>? set,
  String fieldName, {
  int? minSize,
  int? maxSize,
}) {
  if (set == null) {
    throw ArgumentError('$fieldName cannot be null');
  }

  if (minSize != null && set.length < minSize) {
    throw ArgumentError('$fieldName must contain at least $minSize unique items');
  }

  if (maxSize != null && set.length > maxSize) {
    throw ArgumentError('$fieldName cannot contain more than $maxSize unique items');
  }

  return set;
}
```

---

## Domain Model Validation

### Immutable Value Objects

```dart
/// Email address value object with built-in validation.
class EmailAddress {
  final String value;

  EmailAddress(String email) : value = EmailValidator.validate(email);

  factory EmailAddress.parse(String email) {
    return EmailAddress(email);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailAddress && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Money value object with validation.
class Money {
  final double amount;
  final String currency;

  Money(this.amount, this.currency)
      : assert(amount >= 0, 'Amount cannot be negative'),
        assert(currency.length == 3, 'Currency must be 3-letter ISO code');

  Money operator +(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot add different currencies');
    }
    return Money(amount + other.amount, currency);
  }

  @override
  String toString() => '$amount $currency';
}

// Usage - validation happens automatically
final email = EmailAddress('user@example.com'); // Valid
// final invalid = EmailAddress('bad');  // Throws FormatException

final price = Money(19.99, 'USD');
// final invalid = Money(-10, 'USD');  // Throws AssertionError
```

### Builder Pattern with Validation

```dart
class UserBuilder {
  String? _name;
  String? _email;
  int? _age;

  UserBuilder setName(String name) {
    _name = name;
    return this;
  }

  UserBuilder setEmail(String email) {
    _email = email;
    return this;
  }

  UserBuilder setAge(int age) {
    _age = age;
    return this;
  }

  User build() {
    // Validate all required fields
    if (_name == null) {
      throw StateError('Name is required');
    }
    if (_email == null) {
      throw StateError('Email is required');
    }
    if (_age == null) {
      throw StateError('Age is required');
    }

    // Build with validation
    return User(
      name: _name!,
      email: _email!,
      age: _age!,
    );
  }
}

// Usage
final user = UserBuilder()
    .setName('John Doe')
    .setEmail('john@example.com')
    .setAge(30)
    .build();
```

---

## Async Validation

### Database Uniqueness Checks

```dart
class UserValidator {
  final Database database;

  UserValidator(this.database);

  /// Validates that email is unique in the database.
  Future<void> validateUniqueEmail(String email) async {
    final exists = await database.emailExists(email);

    if (exists) {
      throw ValidationException('Email already registered');
    }
  }

  /// Validates that username is unique and meets requirements.
  Future<void> validateUniqueUsername(String username) async {
    // Synchronous validation first
    if (username.length < 3 || username.length > 20) {
      throw ValidationException('Username must be 3-20 characters');
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      throw ValidationException('Username can only contain letters, numbers, and underscores');
    }

    // Then async database check
    final exists = await database.usernameExists(username);

    if (exists) {
      throw ValidationException('Username already taken');
    }
  }
}
```

### External API Validation

```dart
class AddressValidator {
  final HttpClient client;

  AddressValidator(this.client);

  /// Validates address using external geocoding API.
  Future<ValidatedAddress> validateAddress(Address address) async {
    final response = await client.post(
      '/geocode',
      body: {
        'street': address.street,
        'city': address.city,
        'state': address.state,
        'zip': address.zipCode,
      },
    );

    if (response.statusCode != 200) {
      throw ValidationException('Unable to validate address');
    }

    final data = jsonDecode(response.body);

    if (data['valid'] != true) {
      throw ValidationException('Invalid address: ${data['message']}');
    }

    return ValidatedAddress(
      street: data['normalized_street'],
      city: data['normalized_city'],
      state: data['normalized_state'],
      zipCode: data['normalized_zip'],
      latitude: data['latitude'],
      longitude: data['longitude'],
    );
  }
}
```

---

## Security Validation

### SQL Injection Prevention

```dart
// GOOD - Always use parameterized queries
Future<List<User>> findUsersByName(String name) async {
  // Parameterized query - safe from SQL injection
  return database.query(
    'SELECT * FROM users WHERE name = ?',
    [name],
  );
}

// BAD - Never use string concatenation
Future<List<User>> findUsersByName(String name) async {
  // SQL injection vulnerable!
  return database.query(
    'SELECT * FROM users WHERE name = "$name"',
  );
}
```

### Path Traversal Prevention

```dart
String validateFilePath(String filename) {
  // Remove any path components
  final basename = path.basename(filename);

  // Ensure no directory traversal
  if (basename.contains('..') ||
      basename.contains('/') ||
      basename.contains('\\')) {
    throw SecurityException('Invalid filename: path traversal attempt');
  }

  // Validate file extension (allowlist)
  const allowedExtensions = ['.jpg', '.png', '.pdf', '.txt'];
  final extension = path.extension(basename).toLowerCase();

  if (!allowedExtensions.contains(extension)) {
    throw SecurityException('File type not allowed: $extension');
  }

  // Validate filename characters
  if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(basename)) {
    throw SecurityException('Invalid filename characters');
  }

  return basename;
}
```

### Command Injection Prevention

```dart
// NEVER pass user input directly to shell commands
// If absolutely necessary, use strict allowlist validation

String validateCommand(String command) {
  // Allowlist of safe commands
  const allowedCommands = ['ls', 'pwd', 'date'];

  if (!allowedCommands.contains(command)) {
    throw SecurityException('Command not allowed: $command');
  }

  return command;
}

// BETTER - Avoid shell commands entirely, use Dart APIs
void listFiles(String directory) {
  // Use Dart's file API instead of shell commands
  final dir = Directory(directory);
  final files = dir.listSync();

  for (final file in files) {
    print(file.path);
  }
}
```

### XSS Prevention

```dart
String sanitizeHtml(String input) {
  // Simple HTML escaping (use a proper library for production)
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#x27;')
      .replaceAll('/', '&#x2F;');
}

// Usage
String displayUserInput(String input) {
  // Always sanitize user input before displaying as HTML
  return sanitizeHtml(input);
}
```

---

## Validation Libraries

### Using Validators Package

```dart
import 'package:validators/validators.dart' as validators;

class UserInputValidator {
  static ValidationResult validateUser(Map<String, dynamic> input) {
    final errors = <String, List<String>>{};

    // Email validation
    final email = input['email'] as String?;
    if (email == null || !validators.isEmail(email)) {
      errors['email'] = ['Invalid email address'];
    }

    // URL validation
    final website = input['website'] as String?;
    if (website != null && !validators.isURL(website)) {
      errors['website'] = ['Invalid URL'];
    }

    // Credit card validation
    final creditCard = input['credit_card'] as String?;
    if (creditCard != null && !validators.isCreditCard(creditCard)) {
      errors['credit_card'] = ['Invalid credit card number'];
    }

    return ValidationResult(errors);
  }
}
```

### Custom Validation Framework

```dart
abstract class Validator<T> {
  ValidationResult validate(T value);
}

class EmailValidator implements Validator<String> {
  @override
  ValidationResult validate(String value) {
    final errors = <String, List<String>>{};

    if (!EmailValidator.isValid(value)) {
      errors['email'] = ['Invalid email format'];
    }

    return ValidationResult(errors);
  }

  static bool isValid(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }
}

class CompositeValidator<T> implements Validator<T> {
  final List<Validator<T>> validators;

  CompositeValidator(this.validators);

  @override
  ValidationResult validate(T value) {
    final allErrors = <String, List<String>>{};

    for (final validator in validators) {
      final result = validator.validate(value);
      if (result.hasErrors) {
        result.errors.forEach((key, errors) {
          (allErrors[key] ??= []).addAll(errors);
        });
      }
    }

    return ValidationResult(allErrors);
  }
}
```

---

## Best Practices Summary

### Validation Checklist

- [ ] Validate all external input (user, API, files)
- [ ] Validate at multiple layers (UI, service, model)
- [ ] Fail fast with specific error messages
- [ ] Use allowlists over blocklists for security
- [ ] Sanitize input to prevent injection attacks
- [ ] Validate both format and business rules
- [ ] Test validation with edge cases
- [ ] Document validation requirements
- [ ] Handle validation errors gracefully
- [ ] Never trust client-side validation alone

### Common Validation Patterns

**Required Field:**
```dart
if (value == null || value.isEmpty) {
  throw ArgumentError('Field is required');
}
```

**Range Check:**
```dart
if (value < min || value > max) {
  throw RangeError('Value must be between $min and $max');
}
```

**Format Check:**
```dart
if (!pattern.hasMatch(value)) {
  throw FormatException('Invalid format');
}
```

**Uniqueness Check:**
```dart
if (await database.exists(value)) {
  throw ValidationException('Value already exists');
}
```

### Anti-Patterns

**DON'T:**
- Skip validation assuming input is safe
- Use blocklists for security validation
- Expose detailed error messages to users
- Validate only on the client side
- Trust any external input
- Use string concatenation for queries
- Allow unbounded input lengths
- Forget to sanitize for output context

```dart
// BAD
void processUser(Map data) {
  // No validation - dangerous!
  final user = User.fromJson(data);
  database.save(user);
}

// GOOD
void processUser(Map data) {
  // Validate first
  final validation = UserValidator.validate(data);

  if (!validation.isValid) {
    throw ValidationException('Invalid user data', validation.errors);
  }

  final user = User.fromJson(data);
  database.save(user);
}
```

### References

- [Effective Dart: Error Handling](https://dart.dev/effective-dart/error-handling)
- [OWASP Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [Dart validators package](https://pub.dev/packages/validators)
