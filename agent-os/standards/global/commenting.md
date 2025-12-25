# Code Commenting and Documentation Standards for Pure Dart Development

## Overview

This document provides comprehensive guidelines for writing effective comments and documentation in pure Dart applications. Good documentation makes code maintainable, helps team collaboration, and creates better developer experiences.

## Table of Contents

- [Documentation Philosophy](#documentation-philosophy)
- [Doc Comments](#doc-comments)
- [Implementation Comments](#implementation-comments)
- [When to Comment](#when-to-comment)
- [What NOT to Comment](#what-not-to-comment)
- [Code Examples in Documentation](#code-examples-in-documentation)
- [API Documentation](#api-documentation)
- [Package Documentation](#package-documentation)
- [Deprecated APIs](#deprecated-apis)

---

## Documentation Philosophy

### Core Principles

1. **Code First**: Write self-explanatory code; comments explain "why", not "what"
2. **Documentation for Public APIs**: All public-facing code must have doc comments
3. **Minimal Internal Comments**: Use sparingly for complex algorithms or non-obvious decisions
4. **Keep Comments Current**: Outdated comments are worse than no comments
5. **No Commented Code**: Delete unused code; use version control to retrieve it

### The Self-Documenting Code Ideal

```dart
// BAD - Comment explains what code does
// Get the user's name and convert to uppercase
final name = user.name.toUpperCase();

// GOOD - Code explains itself
final uppercaseName = user.name.toUpperCase();

// BAD - Comment restates the obvious
// Loop through all users
for (final user in users) {
  // Check if user is active
  if (user.isActive) {
    // Process the user
    processUser(user);
  }
}

// GOOD - Self-explanatory code
for (final user in users) {
  if (user.isActive) {
    processUser(user);
  }
}
```

### When Code Needs Comments

```dart
// GOOD - Explaining non-obvious business logic
Future<void> chargeCustomer(Customer customer, double amount) async {
  // Apply 15% discount for premium customers
  // This business rule was added per decision in ticket #1234
  if (customer.isPremium) {
    amount *= 0.85;
  }

  await paymentProcessor.charge(customer, amount);
}

// GOOD - Explaining workarounds
Future<List<User>> getUsers() async {
  // HACK: The API returns duplicate users due to a bug in v2.3
  // Remove duplicates until the backend is fixed (ticket #5678)
  final users = await api.fetchUsers();
  return users.toSet().toList();
}

// GOOD - Explaining performance considerations
List<int> findPrimes(int max) {
  // Using Sieve of Eratosthenes for O(n log log n) performance
  // Direct trial division would be O(n^2)
  final sieve = List<bool>.filled(max + 1, true);

  for (var i = 2; i * i <= max; i++) {
    if (sieve[i]) {
      for (var j = i * i; j <= max; j += i) {
        sieve[j] = false;
      }
    }
  }

  return [for (var i = 2; i <= max; i++) if (sieve[i]) i];
}
```

---

## Doc Comments

### Doc Comment Syntax

Use `///` for documentation comments:

```dart
/// Calculates the sum of two integers.
///
/// Returns the sum of [a] and [b].
int add(int a, int b) {
  return a + b;
}

// BAD - Using regular comments
// Calculates the sum of two integers
int add(int a, int b) {
  return a + b;
}
```

### Class Documentation

```dart
/// Represents a user in the system.
///
/// A [User] contains personal information and authentication data.
/// Users can be created with [User.new] or loaded from JSON with [User.fromJson].
///
/// Example:
/// ```dart
/// final user = User(
///   id: '123',
///   name: 'John Doe',
///   email: 'john@example.com',
/// );
/// ```
class User {
  /// The unique identifier for this user.
  final String id;

  /// The user's full name.
  final String name;

  /// The user's email address.
  ///
  /// Must be a valid email format. Use [EmailValidator] to validate.
  final String email;

  /// Creates a new user with the given details.
  ///
  /// All parameters are required. The [email] should be a valid email address.
  User({
    required this.id,
    required this.name,
    required this.email,
  });

  /// Creates a user from a JSON map.
  ///
  /// The JSON must contain 'id', 'name', and 'email' fields.
  /// Throws [FormatException] if the JSON is invalid.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }

  /// Converts this user to a JSON map.
  ///
  /// Returns a map suitable for serialization.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}
```

### Method Documentation

```dart
/// Loads a user by their ID.
///
/// Fetches the user from the database and returns their information.
///
/// The [id] parameter must be a valid user ID (UUID format).
///
/// Returns a [Future] that completes with the [User] if found.
///
/// Throws:
///   * [UserNotFoundException] if no user exists with the given [id]
///   * [DatabaseException] if the database query fails
///   * [ArgumentError] if [id] is empty or invalid
///
/// Example:
/// ```dart
/// try {
///   final user = await loadUser('123e4567-e89b-12d3-a456-426614174000');
///   print('Found user: ${user.name}');
/// } on UserNotFoundException {
///   print('User not found');
/// }
/// ```
Future<User> loadUser(String id) async {
  if (id.isEmpty) {
    throw ArgumentError('User ID cannot be empty');
  }

  final user = await database.find(id);

  if (user == null) {
    throw UserNotFoundException(id);
  }

  return user;
}
```

### Property Documentation

```dart
class Configuration {
  /// The API endpoint URL.
  ///
  /// Must be a valid HTTPS URL. HTTP URLs are not allowed for security reasons.
  /// Defaults to production endpoint if not specified.
  final String apiUrl;

  /// Maximum number of retry attempts for failed requests.
  ///
  /// Valid range is 0-10. Setting to 0 disables retries.
  /// Higher values may cause longer delays but improve reliability.
  final int maxRetries;

  /// Timeout duration for network requests.
  ///
  /// Requests that exceed this duration will be cancelled.
  /// The minimum allowed timeout is 1 second.
  final Duration timeout;

  /// Whether to enable debug logging.
  ///
  /// When true, detailed logs are written to the console.
  /// Should be false in production for performance reasons.
  final bool debugMode;

  const Configuration({
    this.apiUrl = 'https://api.example.com',
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
    this.debugMode = false,
  });
}
```

### Enum Documentation

```dart
/// The current state of a user account.
enum AccountStatus {
  /// Account is active and can be used normally.
  active,

  /// Account is temporarily suspended.
  ///
  /// The user cannot log in but data is preserved.
  /// Can be reactivated by an administrator.
  suspended,

  /// Account is pending email verification.
  ///
  /// User must verify their email before the account becomes active.
  pending,

  /// Account has been permanently deleted.
  ///
  /// All user data has been removed and cannot be recovered.
  deleted,
}
```

### Generic Type Documentation

```dart
/// A generic repository for managing entities.
///
/// [T] is the entity type that this repository manages.
/// [ID] is the type of the entity's identifier.
///
/// Example:
/// ```dart
/// final userRepo = Repository<User, String>(database);
/// final user = await userRepo.findById('123');
/// ```
class Repository<T, ID> {
  /// Finds an entity by its ID.
  ///
  /// Returns the entity if found, null otherwise.
  Future<T?> findById(ID id) async {
    // Implementation
  }

  /// Saves an entity to the repository.
  ///
  /// If the entity already exists (determined by ID), it will be updated.
  /// Otherwise, a new entity will be created.
  ///
  /// Returns the saved entity with any generated fields populated.
  Future<T> save(T entity) async {
    // Implementation
  }

  /// Deletes an entity by its ID.
  ///
  /// Returns true if the entity was deleted, false if it didn't exist.
  Future<bool> deleteById(ID id) async {
    // Implementation
  }
}
```

---

## Implementation Comments

### Complex Algorithms

```dart
List<int> quickSort(List<int> list) {
  if (list.length <= 1) return list;

  // Choose middle element as pivot to avoid worst-case O(n²)
  // performance on already-sorted lists
  final pivotIndex = list.length ~/ 2;
  final pivot = list[pivotIndex];

  // Partition list into three sublists
  final less = <int>[];
  final equal = <int>[];
  final greater = <int>[];

  for (final element in list) {
    if (element < pivot) {
      less.add(element);
    } else if (element == pivot) {
      equal.add(element);
    } else {
      greater.add(element);
    }
  }

  // Recursively sort sublists and concatenate
  return [...quickSort(less), ...equal, ...quickSort(greater)];
}
```

### Workarounds and TODOs

```dart
Future<Data> fetchData() async {
  try {
    return await api.getData();
  } catch (e) {
    // TODO(username): Replace with proper error handling once
    // the backend team fixes the API error responses (ticket #1234)
    return Data.empty();
  }
}

Future<void> processImage(String path) async {
  // HACK: Using deprecated method because the new one has a memory leak
  // See https://github.com/project/issues/5678
  // Remove this once the issue is fixed in package version 2.1.0
  await legacyImageProcessor.process(path);
}

void calculateScore(Player player) {
  var score = player.baseScore;

  // FIXME: This calculation is incorrect for bonus rounds
  // Current behavior: score is doubled
  // Expected behavior: score should be tripled
  // Will fix in next sprint
  if (player.isBonusRound) {
    score *= 2;
  }

  player.score = score;
}
```

### Non-Obvious Decisions

```dart
class UserCache {
  final _cache = <String, User>{};

  // Cache entries expire after 5 minutes to balance performance
  // with data freshness. This value was determined through load testing.
  // See docs/performance-analysis.md for details.
  static const cacheTimeout = Duration(minutes: 5);

  Future<User> getUser(String id) async {
    final cached = _cache[id];

    if (cached != null && _isFresh(cached)) {
      return cached;
    }

    // Cache miss or stale data - fetch from database
    final user = await database.loadUser(id);
    _cache[id] = user;
    return user;
  }

  bool _isFresh(User user) {
    // Implementation
  }
}
```

### Platform-Specific Code

```dart
import 'dart:io';

String getConfigPath() {
  if (Platform.isWindows) {
    // Windows stores config in %APPDATA%
    return '${Platform.environment['APPDATA']}\\myapp\\config.json';
  } else if (Platform.isMacOS) {
    // macOS uses ~/Library/Application Support
    return '${Platform.environment['HOME']}/Library/Application Support/myapp/config.json';
  } else {
    // Linux and other Unix-like systems use ~/.config
    return '${Platform.environment['HOME']}/.config/myapp/config.json';
  }
}
```

### Magic Numbers

```dart
// BAD - Magic numbers without explanation
final result = value * 1.609344;
if (items.length > 100) {
  compress(items);
}

// GOOD - Named constants with explanation
/// Conversion factor from miles to kilometers
const milesPerKilometer = 1.609344;

/// Threshold for compressing large item lists
/// Based on memory profiling showing optimal performance at this size
const compressionThreshold = 100;

final result = value * milesPerKilometer;
if (items.length > compressionThreshold) {
  compress(items);
}
```

---

## When to Comment

### Complex Business Logic

```dart
double calculateShipping(Order order, Address destination) {
  var cost = order.baseShippingCost;

  // Apply volume discount for orders over $100
  // This is a promotional policy that may change quarterly
  if (order.total > 100.0) {
    cost *= 0.9; // 10% discount
  }

  // International shipping incurs additional fees
  if (!destination.isInCountry('US')) {
    cost += 15.0; // International handling fee
    cost *= 1.2;  // 20% international surcharge
  }

  // Free shipping for premium members regardless of order size
  if (order.customer.isPremium) {
    cost = 0.0;
  }

  return cost;
}
```

### Performance-Critical Code

```dart
class DataProcessor {
  // Using a Set for O(1) lookup instead of List O(n)
  // Benchmarks showed 10x performance improvement for large datasets
  final _processedIds = <String>{};

  Future<void> processBatch(List<Data> batch) async {
    // Process in chunks of 100 to avoid memory spikes
    // Larger chunks caused OOM errors during load testing
    const chunkSize = 100;

    for (var i = 0; i < batch.length; i += chunkSize) {
      final chunk = batch.sublist(
        i,
        math.min(i + chunkSize, batch.length),
      );

      await _processChunk(chunk);
    }
  }
}
```

### Security-Sensitive Code

```dart
class PasswordHasher {
  /// Hashes a password using bcrypt with cost factor 12.
  ///
  /// Cost factor 12 provides strong security while maintaining
  /// acceptable performance (< 300ms on modern hardware).
  /// Do not reduce below 10 as it would weaken security.
  String hashPassword(String password) {
    // Cost factor of 12 = 2^12 = 4096 iterations
    const costFactor = 12;
    return bcrypt.hash(password, costFactor);
  }

  bool verifyPassword(String password, String hash) {
    // Constant-time comparison to prevent timing attacks
    return bcrypt.verify(password, hash);
  }
}
```

### API Contracts

```dart
/// Validates user input before processing.
///
/// This method ensures:
///   * Email addresses match RFC 5322 format
///   * Passwords are at least 8 characters
///   * Usernames contain only alphanumeric characters
///
/// Callers MUST call this before saving user data to the database.
/// Failure to validate may result in database constraint violations.
ValidationResult validateUserInput(UserInput input) {
  // Implementation
}
```

---

## What NOT to Comment

### Obvious Code

```dart
// BAD - Comments state the obvious
// Set the user name
user.name = 'John';

// Get the user age
final age = user.age;

// Check if the user is an adult
if (age >= 18) {
  // Process adult user
  processAdult(user);
}

// GOOD - No comments needed, code is self-explanatory
user.name = 'John';
final age = user.age;

if (age >= 18) {
  processAdult(user);
}
```

### Code That Should Be Refactored

```dart
// BAD - Complex comment explaining complex code
// This function calculates the total price including tax and discounts.
// First, it adds up all item prices. Then it checks if the user has
// a discount code and applies it. After that, it calculates tax based
// on the shipping address. Finally, it adds shipping costs unless
// the order qualifies for free shipping.
double calculateTotal(Order order) {
  // 50 lines of complex logic
}

// GOOD - Break into well-named functions (no comments needed)
double calculateTotal(Order order) {
  final subtotal = calculateSubtotal(order);
  final discounted = applyDiscounts(subtotal, order.discountCode);
  final withTax = addTax(discounted, order.shippingAddress);
  final total = addShipping(withTax, order);
  return total;
}
```

### Change History

```dart
// BAD - Change history in comments
// v1.0 - Created by John, 2023-01-15
// v1.1 - Fixed bug, Jane, 2023-02-20
// v1.2 - Added validation, Bob, 2023-03-10
void processData(String data) {
  // Implementation
}

// GOOD - Use version control for history
// Clean code without history comments
void processData(String data) {
  // Implementation
}
```

### Commented-Out Code

```dart
// BAD - Commented-out code clutters the file
void processUser(User user) {
  print('Processing ${user.name}');

  // final oldLogic = calculateOldWay(user);
  // if (oldLogic) {
  //   doOldThing();
  // }

  final newLogic = calculateNewWay(user);
  if (newLogic) {
    doNewThing();
  }
}

// GOOD - Delete old code, use version control if needed
void processUser(User user) {
  print('Processing ${user.name}');

  final newLogic = calculateNewWay(user);
  if (newLogic) {
    doNewThing();
  }
}
```

### Closing Brace Comments

```dart
// BAD - Closing brace comments
class LongClass {
  void method1() {
    if (condition) {
      for (final item in items) {
        while (something) {
          // Many lines of code
        } // while
      } // for
    } // if
  } // method1
} // class

// GOOD - Extract to smaller methods instead
class WellStructuredClass {
  void method1() {
    if (condition) {
      processItems();
    }
  }

  void processItems() {
    for (final item in items) {
      processItem(item);
    }
  }

  void processItem(Item item) {
    while (something) {
      // Smaller, focused code
    }
  }
}
```

---

## Code Examples in Documentation

### Good Examples

```dart
/// Formats a date as a string.
///
/// The [format] parameter uses strftime-style formatting:
///   * %Y - 4-digit year
///   * %m - 2-digit month
///   * %d - 2-digit day
///
/// Example:
/// ```dart
/// final date = DateTime(2024, 12, 1);
/// print(formatDate(date, '%Y-%m-%d')); // '2024-12-01'
/// print(formatDate(date, '%d/%m/%Y')); // '01/12/2024'
/// ```
String formatDate(DateTime date, String format) {
  // Implementation
}
```

### Multiple Examples

```dart
/// Validates an email address.
///
/// Returns true if the email is valid according to RFC 5322.
///
/// Examples:
/// ```dart
/// isValidEmail('user@example.com')     // true
/// isValidEmail('user.name@example.com') // true
/// isValidEmail('user@subdomain.example.com') // true
/// isValidEmail('invalid')               // false
/// isValidEmail('invalid@')              // false
/// isValidEmail('@invalid.com')          // false
/// ```
bool isValidEmail(String email) {
  // Implementation
}
```

### Usage Examples

```dart
/// A simple in-memory cache with expiration.
///
/// Example usage:
/// ```dart
/// // Create a cache with 5-minute expiration
/// final cache = ExpiringCache<String, User>(
///   duration: Duration(minutes: 5),
/// );
///
/// // Store a value
/// cache.put('user123', User(id: '123', name: 'John'));
///
/// // Retrieve the value (within expiration time)
/// final user = cache.get('user123');
/// if (user != null) {
///   print('Found cached user: ${user.name}');
/// }
///
/// // Values expire automatically
/// await Future.delayed(Duration(minutes: 6));
/// final expired = cache.get('user123'); // null
/// ```
class ExpiringCache<K, V> {
  // Implementation
}
```

---

## API Documentation

### Required Elements

Every public API element should document:

1. **Purpose**: What does it do?
2. **Parameters**: What do they mean?
3. **Returns**: What does it return?
4. **Throws**: What exceptions can occur?
5. **Examples**: How to use it?

```dart
/// Searches for users matching the given criteria.
///
/// Performs a case-insensitive search on the [query] string across
/// user names and email addresses.
///
/// Parameters:
///   * [query] - The search term (minimum 3 characters)
///   * [limit] - Maximum number of results to return (default: 10)
///   * [offset] - Number of results to skip for pagination (default: 0)
///
/// Returns a [Future] that completes with a list of matching [User] objects,
/// sorted by relevance. The list may be empty if no matches are found.
///
/// Throws:
///   * [ArgumentError] if [query] is less than 3 characters
///   * [ArgumentError] if [limit] is negative or zero
///   * [DatabaseException] if the search query fails
///
/// Example:
/// ```dart
/// // Simple search
/// final users = await searchUsers('john');
///
/// // With pagination
/// final firstPage = await searchUsers('john', limit: 10, offset: 0);
/// final secondPage = await searchUsers('john', limit: 10, offset: 10);
/// ```
Future<List<User>> searchUsers(
  String query, {
  int limit = 10,
  int offset = 0,
}) async {
  if (query.length < 3) {
    throw ArgumentError('Query must be at least 3 characters');
  }

  if (limit <= 0) {
    throw ArgumentError('Limit must be positive');
  }

  // Implementation
}
```

### Linking to Other Documentation

```dart
/// Represents a shopping cart.
///
/// A cart contains [CartItem]s and can calculate totals including
/// discounts and taxes.
///
/// Use [CartService] to persist carts to the database.
/// See also [Order] for converting carts to orders.
class Cart {
  /// The items in this cart.
  ///
  /// Use [addItem] and [removeItem] to modify the cart contents.
  final List<CartItem> items;

  /// Adds an item to the cart.
  ///
  /// If an item with the same product ID already exists,
  /// the quantities are combined. See [CartItem.productId].
  void addItem(CartItem item) {
    // Implementation
  }

  /// Calculates the total price.
  ///
  /// Applies discounts using [DiscountCalculator] and
  /// taxes using [TaxCalculator].
  double calculateTotal() {
    // Implementation
  }
}
```

---

## Package Documentation

### README.md

```markdown
# My Package

A comprehensive package for doing amazing things in Dart.

## Features

* Feature 1: Does something cool
* Feature 2: Does something else
* Feature 3: Does yet another thing

## Getting started

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  my_package: ^1.0.0
```

## Usage

```dart
import 'package:my_package/my_package.dart';

void main() {
  final thing = MyThing();
  thing.doSomething();
}
```

## Additional information

For more examples and API documentation, see the
[official documentation](https://example.com/docs).

To contribute, please read our [contributing guide](CONTRIBUTING.md).
```

### Library-Level Documentation

```dart
/// A library for processing user data.
///
/// This library provides utilities for:
///   * User validation
///   * Data transformation
///   * Format conversion
///
/// Example usage:
/// ```dart
/// import 'package:my_package/user_processing.dart';
///
/// final validator = UserValidator();
/// if (validator.isValid(userData)) {
///   final user = User.fromData(userData);
///   processUser(user);
/// }
/// ```
library user_processing;

import 'dart:convert';

import 'package:my_package/src/validator.dart';

export 'src/user.dart';
export 'src/validator.dart';
```

---

## Deprecated APIs

### Marking Deprecations

```dart
/// Calculates user score (old algorithm).
///
/// **Deprecated**: Use [calculateScoreV2] instead. This method will be
/// removed in version 2.0.0.
///
/// The new method provides more accurate scoring and better performance.
/// Migration guide: Replace `calculateScore(user)` with
/// `calculateScoreV2(user, ScoreOptions())`.
@Deprecated('Use calculateScoreV2 instead. Will be removed in 2.0.0')
int calculateScore(User user) {
  // Old implementation
}

/// Calculates user score using the improved algorithm.
///
/// This method provides better accuracy and performance compared to
/// the deprecated [calculateScore].
///
/// Example:
/// ```dart
/// final score = calculateScoreV2(
///   user,
///   ScoreOptions(includeBonus: true),
/// );
/// ```
int calculateScoreV2(User user, ScoreOptions options) {
  // New implementation
}
```

### Deprecation Best Practices

```dart
class DataService {
  /// **Deprecated**: Use [fetchData] instead.
  ///
  /// This method is deprecated because:
  ///   * It doesn't handle errors properly
  ///   * It lacks timeout support
  ///   * The synchronous API blocks the event loop
  ///
  /// Migration:
  /// ```dart
  /// // Old code
  /// final data = service.getData();
  ///
  /// // New code
  /// final data = await service.fetchData();
  /// ```
  @Deprecated('Use fetchData() instead. Will be removed in 2.0.0')
  Data getData() {
    // Old synchronous implementation
  }

  /// Fetches data asynchronously.
  ///
  /// Improved version of the deprecated [getData] method with:
  ///   * Proper error handling
  ///   * Configurable timeout
  ///   * Non-blocking async API
  Future<Data> fetchData({Duration? timeout}) async {
    // New async implementation
  }
}
```

---

## Documentation Tools

### Generating Documentation

```bash
# Generate HTML documentation
dart doc

# Generate and open in browser
dart doc && open doc/api/index.html

# Generate with custom options
dart doc --output=./documentation
```

### dartdoc Directives

```dart
/// A complex class with various documentation features.
///
/// {@template user_description}
/// This is a reusable description that can be included in
/// multiple places using the template mechanism.
/// {@endtemplate}
///
/// {@macro user_description}
class User {
  /// {@template user_id_field}
  /// The unique identifier for this user.
  /// {@endtemplate}
  final String id;

  /// Another field that references the ID description.
  ///
  /// {@macro user_id_field}
  final String alternateId;
}
```

### Code Snippet Annotations

```dart
/// Processes a list of items.
///
/// Example:
/// ```dart
/// // Basic usage
/// final results = processItems(['a', 'b', 'c']);
///
/// // With filtering
/// final filtered = processItems(
///   ['a', 'b', 'c'],
///   filter: (item) => item != 'b',
/// );
/// ```
///
/// You can also use it with async processing:
/// ```dart
/// final items = await loadItems();
/// final results = processItems(items);
/// ```
List<String> processItems(
  List<String> items, {
  bool Function(String)? filter,
}) {
  // Implementation
}
```

---

## Style Guidelines

### Formatting

```dart
/// Single-line summary ending with a period.
///
/// More detailed description in a separate paragraph.
/// Can span multiple lines and include various details.
///
/// Use blank lines to separate paragraphs for readability.
void method() {}

// BAD - No period, poor formatting
/// Returns the user name
void method() {}

// BAD - Everything in one paragraph
/// Single-line summary
/// More detailed description
/// All run together without breaks
void method() {}
```

### Markdown in Doc Comments

```dart
/// Processes markdown text.
///
/// Supported features:
///   * **Bold text** using `**text**`
///   * *Italic text* using `*text*`
///   * `Code spans` using backticks
///   * Links: [Dart](https://dart.dev)
///
/// Example:
/// ```dart
/// final html = markdown.toHtml('**Bold** and *italic*');
/// ```
///
/// See the [CommonMark spec](https://commonmark.org/) for details.
String processMarkdown(String text) {
  // Implementation
}
```

---

## Best Practices Summary

### Documentation Checklist

- [ ] All public APIs have doc comments
- [ ] Doc comments start with single-line summary
- [ ] Parameters and return values are documented
- [ ] Exceptions are documented
- [ ] Code examples are provided
- [ ] Examples are tested and up-to-date
- [ ] No commented-out code
- [ ] No outdated comments
- [ ] Implementation comments explain "why", not "what"
- [ ] Links to related APIs provided

### Common Patterns

**Good Documentation:**
```dart
/// Validates user input and returns validation errors.
///
/// Returns an empty map if validation succeeds, or a map of
/// field names to error messages if validation fails.
///
/// Example:
/// ```dart
/// final errors = validateUser(userData);
/// if (errors.isEmpty) {
///   saveUser(userData);
/// } else {
///   showErrors(errors);
/// }
/// ```
Map<String, String> validateUser(UserData data) {
  // Implementation
}
```

**Good Implementation Comment:**
```dart
void processLargeFile(String path) {
  // Process in 1MB chunks to avoid loading entire file into memory
  // This prevents OOM errors for files larger than available RAM
  const chunkSize = 1024 * 1024; // 1 MB

  // Implementation
}
```

### Anti-Patterns

**DON'T:**
- Write comments that repeat what the code says
- Leave commented-out code
- Write implementation comments for simple code
- Forget to update comments when code changes
- Use comments as a substitute for clear code
- Include version history in comments
- Write comment novels for simple functions

### References

- [Effective Dart: Documentation](https://dart.dev/effective-dart/documentation)
- [Dart Doc Comments](https://dart.dev/guides/language/effective-dart/documentation)
- [dartdoc Documentation](https://github.com/dart-lang/dartdoc)
- [Markdown Guide](https://www.markdownguide.org/)
