# Test Writing Standards: Pure Dart Development

This document outlines comprehensive testing strategies for pure Dart CLI, backend, and server applications. Testing spans multiple layers: unit tests for business logic, integration tests for services, and end-to-end tests for complete workflows.

## Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Unit Testing](#unit-testing)
3. [Integration Testing](#integration-testing)
4. [Testing Best Practices](#testing-best-practices)
5. [Using package:checks](#using-packagechecks)
6. [Testing CLI Applications](#testing-cli-applications)
7. [Testing Patterns](#testing-patterns)
8. [Testing Riverpod Providers](#testing-riverpod-providers)
9. [Test Organization](#test-organization)

---

## Testing Philosophy

### Test Pyramid for Dart CLI/Backend Apps

```
        /\
       /  \        E2E Tests (Few)
      /____\       - Critical workflows
     /      \      - User scenarios
    /        \
   /__________\    Integration Tests (Some)
  /            \   - Service layer
 /              \  - Database operations
/________________\ Unit Tests (Many)
                   - Pure functions
                   - Business logic
                   - Data models
```

**Distribution Guidelines:**
- 70% Unit Tests: Fast, focused, isolated
- 20% Integration Tests: Service interactions, database operations
- 10% E2E Tests: Complete user workflows

### Test-Driven Development (TDD) Approach

**Red-Green-Refactor Cycle:**

1. **Red**: Write a failing test
2. **Green**: Write minimal code to pass
3. **Refactor**: Improve code while keeping tests green

**When to Use TDD:**
- Complex business logic
- Data transformations
- Algorithm implementations
- API contract design
- Critical security features

**When to Skip TDD:**
- Simple CRUD operations
- Obvious implementations
- Exploratory prototyping
- UI layout code

### What to Test vs What Not to Test

**DO Test:**
- Business logic and domain rules
- Data transformations and calculations
- Error handling and edge cases
- Security validations
- API contracts and responses
- Database queries and transactions
- External service integrations
- State management logic

**DON'T Test:**
- Framework internals (Dart SDK)
- Third-party package code
- Simple getters/setters
- Constructors without logic
- Private implementation details
- Generated code
- Obvious pass-through methods

### Test Organization Principles

**Structure:**
- Mirror source code structure in test directory
- One test file per source file (`user.dart` → `user_test.dart`)
- Group related tests with `group()`
- Use descriptive test names

**Independence:**
- Tests should not depend on execution order
- Each test should be self-contained
- Use `setUp()` and `tearDown()` for state management
- Clean up resources after tests

**Readability:**
- Tests serve as documentation
- Use clear, descriptive names
- Follow Arrange-Act-Assert pattern
- Avoid complex test logic

---

## Unit Testing

### Using package:test

**Installation:**

```yaml
# pubspec.yaml
dev_dependencies:
  test: ^1.25.0
  checks: ^0.3.0
  mocktail: ^1.0.0
```

**Basic Test Structure:**

```dart
import 'package:test/test.dart';

void main() {
  test('description of what this test verifies', () {
    // Arrange: Set up test data and dependencies
    final input = 'test input';

    // Act: Execute the code under test
    final result = functionUnderTest(input);

    // Assert: Verify the outcome
    expect(result, equals('expected output'));
  });
}
```

### Test Structure (Arrange-Act-Assert)

**The AAA Pattern:**

```dart
import 'package:test/test.dart';

void main() {
  group('Calculator', () {
    test('adds two numbers correctly', () {
      // Arrange
      final calculator = Calculator();
      const a = 5;
      const b = 3;

      // Act
      final result = calculator.add(a, b);

      // Assert
      expect(result, equals(8));
    });

    test('throws error when dividing by zero', () {
      // Arrange
      final calculator = Calculator();
      const numerator = 10;
      const denominator = 0;

      // Act & Assert (combined for exception testing)
      expect(
        () => calculator.divide(numerator, denominator),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

**Using setUp and tearDown:**

```dart
void main() {
  group('UserService', () {
    late UserService userService;
    late Database database;

    setUp(() {
      // Runs before each test
      database = Database.inMemory();
      userService = UserService(database);
    });

    tearDown(() {
      // Runs after each test
      database.close();
    });

    test('creates user successfully', () async {
      final user = await userService.createUser(
        username: 'testuser',
        email: 'test@example.com',
      );

      expect(user.username, equals('testuser'));
      expect(user.email, equals('test@example.com'));
    });

    test('throws error for duplicate username', () async {
      await userService.createUser(
        username: 'testuser',
        email: 'test1@example.com',
      );

      expect(
        () => userService.createUser(
          username: 'testuser',
          email: 'test2@example.com',
        ),
        throwsA(isA<DuplicateUsernameException>()),
      );
    });
  });
}
```

### Testing Pure Functions

**Pure functions are the easiest to test:**

```dart
import 'package:test/test.dart';

// Source code
String formatCurrency(double amount, String currencyCode) {
  if (amount < 0) {
    throw ArgumentError('Amount cannot be negative');
  }

  final formatted = amount.toStringAsFixed(2);
  return '$currencyCode $formatted';
}

// Tests
void main() {
  group('formatCurrency', () {
    test('formats positive amount correctly', () {
      expect(formatCurrency(42.50, 'USD'), equals('USD 42.50'));
      expect(formatCurrency(100.00, 'EUR'), equals('EUR 100.00'));
    });

    test('formats zero correctly', () {
      expect(formatCurrency(0, 'USD'), equals('USD 0.00'));
    });

    test('rounds to two decimal places', () {
      expect(formatCurrency(42.567, 'USD'), equals('USD 42.57'));
      expect(formatCurrency(42.564, 'USD'), equals('USD 42.56'));
    });

    test('throws error for negative amount', () {
      expect(
        () => formatCurrency(-10, 'USD'),
        throwsA(
          isA<ArgumentError>()
            .having((e) => e.message, 'message', contains('negative')),
        ),
      );
    });
  });
}
```

**Testing data transformations:**

```dart
// Source code
class UserDto {
  final String id;
  final String username;
  final String email;

  UserDto({
    required this.id,
    required this.username,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
  };

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
    id: json['id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
  );
}

// Tests
void main() {
  group('UserDto', () {
    test('serializes to JSON correctly', () {
      final user = UserDto(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
      );

      final json = user.toJson();

      expect(json, {
        'id': '123',
        'username': 'testuser',
        'email': 'test@example.com',
      });
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': '456',
        'username': 'anotheruser',
        'email': 'another@example.com',
      };

      final user = UserDto.fromJson(json);

      expect(user.id, equals('456'));
      expect(user.username, equals('anotheruser'));
      expect(user.email, equals('another@example.com'));
    });

    test('round-trip serialization preserves data', () {
      final original = UserDto(
        id: '789',
        username: 'roundtrip',
        email: 'roundtrip@example.com',
      );

      final json = original.toJson();
      final deserialized = UserDto.fromJson(json);

      expect(deserialized.id, equals(original.id));
      expect(deserialized.username, equals(original.username));
      expect(deserialized.email, equals(original.email));
    });
  });
}
```

### Testing Classes and Methods

**Testing stateful classes:**

```dart
import 'package:test/test.dart';

// Source code
class ShoppingCart {
  final List<CartItem> _items = [];

  void addItem(CartItem item) {
    final existingIndex = _items.indexWhere(
      (i) => i.productId == item.productId,
    );

    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + item.quantity,
      );
    } else {
      _items.add(item);
    }
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final index = _items.indexWhere((i) => i.productId == productId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
  }

  double get total => _items.fold(
    0,
    (sum, item) => sum + (item.price * item.quantity),
  );

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;
}

class CartItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  CartItem copyWith({
    String? productId,
    String? name,
    double? price,
    int? quantity,
  }) => CartItem(
    productId: productId ?? this.productId,
    name: name ?? this.name,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
  );
}

// Tests
void main() {
  group('ShoppingCart', () {
    late ShoppingCart cart;

    setUp(() {
      cart = ShoppingCart();
    });

    test('starts empty', () {
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, equals(0));
      expect(cart.total, equals(0));
    });

    test('adds item successfully', () {
      final item = CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 1,
      );

      cart.addItem(item);

      expect(cart.isEmpty, isFalse);
      expect(cart.itemCount, equals(1));
      expect(cart.items.first.productId, equals('p1'));
    });

    test('combines quantities for duplicate items', () {
      final item1 = CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 2,
      );
      final item2 = CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 3,
      );

      cart.addItem(item1);
      cart.addItem(item2);

      expect(cart.itemCount, equals(1));
      expect(cart.items.first.quantity, equals(5));
    });

    test('calculates total correctly', () {
      cart.addItem(CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 2,
      ));
      cart.addItem(CartItem(
        productId: 'p2',
        name: 'Product 2',
        price: 15.00,
        quantity: 1,
      ));

      expect(cart.total, equals(35.00));
    });

    test('removes item successfully', () {
      final item = CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 1,
      );

      cart.addItem(item);
      expect(cart.itemCount, equals(1));

      cart.removeItem('p1');
      expect(cart.isEmpty, isTrue);
    });

    test('updates quantity successfully', () {
      final item = CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 2,
      );

      cart.addItem(item);
      cart.updateQuantity('p1', 5);

      expect(cart.items.first.quantity, equals(5));
    });

    test('removes item when quantity updated to zero', () {
      final item = CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 2,
      );

      cart.addItem(item);
      cart.updateQuantity('p1', 0);

      expect(cart.isEmpty, isTrue);
    });

    test('returns immutable items list', () {
      final item = CartItem(
        productId: 'p1',
        name: 'Product 1',
        price: 10.00,
        quantity: 1,
      );

      cart.addItem(item);
      final items = cart.items;

      // This should not affect the cart
      expect(
        () => items.add(CartItem(
          productId: 'p2',
          name: 'Product 2',
          price: 20.00,
          quantity: 1,
        )),
        throwsUnsupportedError,
      );
    });
  });
}
```

### Mocking Dependencies (mocktail vs fakes)

**Prefer fakes for simple dependencies:**

```dart
// Fake: Simple implementation for testing
class FakeDatabase implements Database {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<void> insert(String table, Map<String, dynamic> data) async {
    _data['$table:${data['id']}'] = data;
  }

  @override
  Future<Map<String, dynamic>?> findById(String table, String id) async {
    return _data['$table:$id'];
  }

  @override
  Future<List<Map<String, dynamic>>> findAll(String table) async {
    return _data.entries
      .where((e) => e.key.startsWith('$table:'))
      .map((e) => e.value)
      .toList();
  }

  @override
  Future<void> delete(String table, String id) async {
    _data.remove('$table:$id');
  }
}

// Usage in tests
void main() {
  test('UserRepository saves user to database', () async {
    final fakeDb = FakeDatabase();
    final repository = UserRepository(fakeDb);

    final user = User(id: '1', username: 'test', email: 'test@example.com');
    await repository.save(user);

    final saved = await fakeDb.findById('users', '1');
    expect(saved?['username'], equals('test'));
  });
}
```

**Use mocktail for complex interactions:**

```dart
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Create mock class
class MockHttpClient extends Mock implements HttpClient {}
class MockLogger extends Mock implements Logger {}

// Register fallback values for custom types
void setUpAll() {
  registerFallbackValue(Uri());
  registerFallbackValue(HttpRequest());
}

void main() {
  group('ApiService', () {
    late MockHttpClient mockClient;
    late MockLogger mockLogger;
    late ApiService apiService;

    setUp(() {
      mockClient = MockHttpClient();
      mockLogger = MockLogger();
      apiService = ApiService(
        client: mockClient,
        logger: mockLogger,
      );
    });

    test('fetches user successfully', () async {
      // Arrange
      final expectedResponse = {
        'id': '123',
        'username': 'testuser',
        'email': 'test@example.com',
      };

      when(() => mockClient.get(any())).thenAnswer(
        (_) async => HttpResponse(
          statusCode: 200,
          body: jsonEncode(expectedResponse),
        ),
      );

      // Act
      final user = await apiService.getUser('123');

      // Assert
      expect(user.username, equals('testuser'));

      // Verify interactions
      verify(() => mockClient.get(Uri.parse('/api/users/123'))).called(1);
      verify(() => mockLogger.info('Fetching user: 123')).called(1);
    });

    test('logs error on failure', () async {
      // Arrange
      when(() => mockClient.get(any())).thenThrow(
        Exception('Network error'),
      );

      // Act & Assert
      expect(
        () => apiService.getUser('123'),
        throwsException,
      );

      verify(() => mockLogger.error(
        'Failed to fetch user',
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      )).called(1);
    });

    test('retries on timeout', () async {
      // Arrange
      var callCount = 0;
      when(() => mockClient.get(any())).thenAnswer((_) async {
        callCount++;
        if (callCount < 3) {
          throw TimeoutException('Timeout');
        }
        return HttpResponse(
          statusCode: 200,
          body: jsonEncode({'id': '123', 'username': 'test'}),
        );
      });

      // Act
      final user = await apiService.getUser('123');

      // Assert
      expect(user, isNotNull);
      verify(() => mockClient.get(any())).called(3);
    });
  });
}
```

**When to use fakes vs mocks:**

| Use Fakes When | Use Mocks When |
|----------------|----------------|
| Simple interface | Complex behavior verification |
| In-memory alternative exists | Testing retry logic |
| Testing data flow | Testing error handling |
| Multiple test scenarios | Verifying method calls |
| Stateful behavior needed | Testing timeouts |

### Testing Async Code (Futures, Streams)

**Testing Futures:**

```dart
import 'package:test/test.dart';

void main() {
  group('Async Operations', () {
    test('completes successfully', () async {
      final result = await fetchData();
      expect(result, isNotNull);
    });

    test('throws error on failure', () async {
      expect(
        () => fetchDataThatFails(),
        throwsA(isA<DataException>()),
      );
    });

    test('times out after specified duration', () async {
      expect(
        () => fetchDataWithTimeout().timeout(
          const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('completes in expected time', () async {
      final stopwatch = Stopwatch()..start();

      await fetchData();

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
```

**Testing Streams:**

```dart
import 'package:test/test.dart';

void main() {
  group('Stream Operations', () {
    test('emits expected values', () async {
      final stream = countStream(5);

      expect(
        stream,
        emitsInOrder([1, 2, 3, 4, 5]),
      );
    });

    test('emits then completes', () async {
      final stream = countStream(3);

      expect(
        stream,
        emitsInOrder([
          1,
          2,
          3,
          emitsDone,
        ]),
      );
    });

    test('emits error on failure', () async {
      final stream = streamThatFails();

      expect(
        stream,
        emitsError(isA<StreamException>()),
      );
    });

    test('can be transformed', () async {
      final stream = countStream(5);
      final doubled = stream.map((n) => n * 2);

      expect(
        doubled,
        emitsInOrder([2, 4, 6, 8, 10]),
      );
    });

    test('handles backpressure correctly', () async {
      final stream = Stream.periodic(
        const Duration(milliseconds: 10),
        (count) => count,
      ).take(100);

      var processedCount = 0;
      await for (final value in stream) {
        processedCount++;
        // Simulate slow processing
        await Future.delayed(const Duration(milliseconds: 5));
      }

      expect(processedCount, equals(100));
    });

    test('cancels subscription properly', () async {
      final stream = Stream.periodic(
        const Duration(milliseconds: 10),
        (count) => count,
      );

      final values = <int>[];
      final subscription = stream.listen(values.add);

      await Future.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(values.length, greaterThan(0));
      expect(values.length, lessThan(10));
    });
  });

  group('StreamController', () {
    late StreamController<String> controller;

    setUp(() {
      controller = StreamController<String>();
    });

    tearDown(() {
      controller.close();
    });

    test('broadcasts to multiple listeners', () async {
      final broadcastController = StreamController<int>.broadcast();

      final values1 = <int>[];
      final values2 = <int>[];

      broadcastController.stream.listen(values1.add);
      broadcastController.stream.listen(values2.add);

      broadcastController.add(1);
      broadcastController.add(2);
      broadcastController.add(3);

      await Future.delayed(Duration.zero);

      expect(values1, equals([1, 2, 3]));
      expect(values2, equals([1, 2, 3]));

      broadcastController.close();
    });

    test('handles errors in stream', () async {
      final errors = <Object>[];

      controller.stream.listen(
        (_) {},
        onError: errors.add,
      );

      controller.addError(Exception('Test error'));

      await Future.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isA<Exception>());
    });
  });
}

// Example functions for testing
Stream<int> countStream(int max) async* {
  for (var i = 1; i <= max; i++) {
    await Future.delayed(const Duration(milliseconds: 10));
    yield i;
  }
}

Stream<int> streamThatFails() async* {
  yield 1;
  yield 2;
  throw StreamException('Stream failed');
}
```

### Testing Riverpod Providers

**Testing simple providers:**

```dart
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

// Source code
final counterProvider = StateProvider<int>((ref) => 0);

final doubledCounterProvider = Provider<int>((ref) {
  final count = ref.watch(counterProvider);
  return count * 2;
});

// Tests
void main() {
  group('Providers', () {
    test('counterProvider starts at zero', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(counterProvider), equals(0));
    });

    test('counterProvider can be incremented', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(counterProvider.notifier).state = 5;

      expect(container.read(counterProvider), equals(5));
    });

    test('doubledCounterProvider doubles the counter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(counterProvider.notifier).state = 7;

      expect(container.read(doubledCounterProvider), equals(14));
    });
  });
}
```

**Testing async providers:**

```dart
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

// Source code
final userProvider = FutureProvider.family<User, String>((ref, userId) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUser(userId);
});

// Tests
void main() {
  group('userProvider', () {
    test('fetches user successfully', () async {
      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final user = await container.read(userProvider('123').future);

      expect(user.id, equals('123'));
      expect(user.username, isNotEmpty);
    });

    test('throws error for invalid user', () async {
      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(shouldFail: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(userProvider('invalid').future),
        throwsA(isA<UserNotFoundException>()),
      );
    });
  });
}
```

**Testing notifier providers:**

```dart
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

// Source code
class TodoListNotifier extends StateNotifier<List<Todo>> {
  TodoListNotifier() : super([]);

  void addTodo(String title) {
    state = [
      ...state,
      Todo(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        completed: false,
      ),
    ];
  }

  void toggleTodo(String id) {
    state = [
      for (final todo in state)
        if (todo.id == id)
          todo.copyWith(completed: !todo.completed)
        else
          todo,
    ];
  }

  void removeTodo(String id) {
    state = state.where((todo) => todo.id != id).toList();
  }
}

final todoListProvider = StateNotifierProvider<TodoListNotifier, List<Todo>>(
  (ref) => TodoListNotifier(),
);

// Tests
void main() {
  group('TodoListNotifier', () {
    test('starts with empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(todoListProvider), isEmpty);
    });

    test('adds todo successfully', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(todoListProvider.notifier).addTodo('Test Todo');

      final todos = container.read(todoListProvider);
      expect(todos, hasLength(1));
      expect(todos.first.title, equals('Test Todo'));
      expect(todos.first.completed, isFalse);
    });

    test('toggles todo completion', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(todoListProvider.notifier);
      notifier.addTodo('Test Todo');

      final todoId = container.read(todoListProvider).first.id;
      notifier.toggleTodo(todoId);

      expect(container.read(todoListProvider).first.completed, isTrue);

      notifier.toggleTodo(todoId);
      expect(container.read(todoListProvider).first.completed, isFalse);
    });

    test('removes todo successfully', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(todoListProvider.notifier);
      notifier.addTodo('Todo 1');
      notifier.addTodo('Todo 2');

      final todoId = container.read(todoListProvider).first.id;
      notifier.removeTodo(todoId);

      final todos = container.read(todoListProvider);
      expect(todos, hasLength(1));
      expect(todos.first.title, equals('Todo 2'));
    });
  });
}
```

---

## Integration Testing

### Testing Service Layer Integration

**Testing services with dependencies:**

```dart
import 'package:test/test.dart';

class UserService {
  final Database database;
  final EmailService emailService;
  final Logger logger;

  UserService({
    required this.database,
    required this.emailService,
    required this.logger,
  });

  Future<User> createUser({
    required String username,
    required String email,
    required String password,
  }) async {
    logger.info('Creating user: $username');

    // Validate inputs
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      throw ValidationException('All fields are required');
    }

    // Check for duplicate username
    final existing = await database.findUserByUsername(username);
    if (existing != null) {
      throw DuplicateUsernameException(username);
    }

    // Hash password
    final hashedPassword = hashPassword(password);

    // Save to database
    final user = User(
      id: generateId(),
      username: username,
      email: email,
      passwordHash: hashedPassword,
      createdAt: DateTime.now(),
    );

    await database.saveUser(user);

    // Send welcome email
    await emailService.sendWelcomeEmail(email, username);

    logger.info('User created successfully: $username');

    return user;
  }
}

// Tests
void main() {
  group('UserService Integration', () {
    late Database database;
    late EmailService emailService;
    late Logger logger;
    late UserService userService;

    setUp(() async {
      database = await Database.inMemory();
      emailService = FakeEmailService();
      logger = FakeLogger();
      userService = UserService(
        database: database,
        emailService: emailService,
        logger: logger,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('creates user with all dependencies', () async {
      final user = await userService.createUser(
        username: 'testuser',
        email: 'test@example.com',
        password: 'securepassword123',
      );

      // Verify user was saved to database
      expect(user.id, isNotEmpty);
      expect(user.username, equals('testuser'));

      final savedUser = await database.findUserById(user.id);
      expect(savedUser, isNotNull);
      expect(savedUser!.email, equals('test@example.com'));

      // Verify email was sent
      expect(
        (emailService as FakeEmailService).sentEmails,
        contains('test@example.com'),
      );

      // Verify logging occurred
      expect(
        (logger as FakeLogger).logs,
        contains('Creating user: testuser'),
      );
    });

    test('throws error for duplicate username', () async {
      await userService.createUser(
        username: 'duplicate',
        email: 'user1@example.com',
        password: 'password123',
      );

      expect(
        () => userService.createUser(
          username: 'duplicate',
          email: 'user2@example.com',
          password: 'password123',
        ),
        throwsA(isA<DuplicateUsernameException>()),
      );
    });

    test('rolls back on email failure', () async {
      final failingEmailService = FakeEmailService(shouldFail: true);
      final serviceWithFailingEmail = UserService(
        database: database,
        emailService: failingEmailService,
        logger: logger,
      );

      expect(
        () => serviceWithFailingEmail.createUser(
          username: 'testuser',
          email: 'test@example.com',
          password: 'password123',
        ),
        throwsA(isA<EmailException>()),
      );

      // Verify user was not saved (rollback occurred)
      final users = await database.findAllUsers();
      expect(users, isEmpty);
    });
  });
}
```

### Testing Database Operations

**Testing with in-memory database:**

```dart
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

class UserRepository {
  final Connection connection;

  UserRepository(this.connection);

  Future<User> create(User user) async {
    final result = await connection.execute(
      '''
      INSERT INTO users (id, username, email, created_at)
      VALUES (\$1, \$2, \$3, \$4)
      RETURNING *
      ''',
      parameters: [
        user.id,
        user.username,
        user.email,
        user.createdAt.toIso8601String(),
      ],
    );

    return User.fromRow(result.first);
  }

  Future<User?> findById(String id) async {
    final result = await connection.execute(
      'SELECT * FROM users WHERE id = \$1',
      parameters: [id],
    );

    if (result.isEmpty) return null;
    return User.fromRow(result.first);
  }

  Future<List<User>> findAll() async {
    final result = await connection.execute('SELECT * FROM users');
    return result.map((row) => User.fromRow(row)).toList();
  }

  Future<void> delete(String id) async {
    await connection.execute(
      'DELETE FROM users WHERE id = \$1',
      parameters: [id],
    );
  }
}

void main() {
  group('UserRepository', () {
    late Connection connection;
    late UserRepository repository;

    setUp(() async {
      // Use test database or in-memory SQLite
      connection = await Connection.open(
        Endpoint(
          host: 'localhost',
          database: 'test_db',
          username: 'test',
          password: 'test',
        ),
      );

      // Create schema
      await connection.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          username TEXT NOT NULL UNIQUE,
          email TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL
        )
      ''');

      repository = UserRepository(connection);
    });

    tearDown(() async {
      // Clean up
      await connection.execute('DROP TABLE IF EXISTS users');
      await connection.close();
    });

    test('creates user successfully', () async {
      final user = User(
        id: '123',
        username: 'testuser',
        email: 'test@example.com',
        createdAt: DateTime.now(),
      );

      final created = await repository.create(user);

      expect(created.id, equals(user.id));
      expect(created.username, equals(user.username));
    });

    test('finds user by id', () async {
      final user = User(
        id: '456',
        username: 'findme',
        email: 'findme@example.com',
        createdAt: DateTime.now(),
      );

      await repository.create(user);
      final found = await repository.findById('456');

      expect(found, isNotNull);
      expect(found!.username, equals('findme'));
    });

    test('returns null for non-existent user', () async {
      final found = await repository.findById('nonexistent');
      expect(found, isNull);
    });

    test('finds all users', () async {
      await repository.create(User(
        id: '1',
        username: 'user1',
        email: 'user1@example.com',
        createdAt: DateTime.now(),
      ));
      await repository.create(User(
        id: '2',
        username: 'user2',
        email: 'user2@example.com',
        createdAt: DateTime.now(),
      ));

      final users = await repository.findAll();

      expect(users, hasLength(2));
      expect(users.map((u) => u.username), containsAll(['user1', 'user2']));
    });

    test('deletes user successfully', () async {
      final user = User(
        id: '789',
        username: 'deleteme',
        email: 'deleteme@example.com',
        createdAt: DateTime.now(),
      );

      await repository.create(user);
      await repository.delete('789');

      final found = await repository.findById('789');
      expect(found, isNull);
    });

    test('enforces unique username constraint', () async {
      final user1 = User(
        id: '1',
        username: 'duplicate',
        email: 'user1@example.com',
        createdAt: DateTime.now(),
      );
      final user2 = User(
        id: '2',
        username: 'duplicate',
        email: 'user2@example.com',
        createdAt: DateTime.now(),
      );

      await repository.create(user1);

      expect(
        () => repository.create(user2),
        throwsA(isA<PostgreSQLException>()),
      );
    });
  });
}
```

### Testing HTTP Clients

**Testing HTTP service integration:**

```dart
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class ApiClient {
  final http.Client client;
  final String baseUrl;

  ApiClient({
    required this.client,
    required this.baseUrl,
  });

  Future<User> getUser(String id) async {
    final response = await client.get(
      Uri.parse('$baseUrl/users/$id'),
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      throw UserNotFoundException(id);
    } else {
      throw ApiException(
        'Failed to fetch user: ${response.statusCode}',
      );
    }
  }

  Future<User> createUser(UserCreateDto dto) async {
    final response = await client.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dto.toJson()),
    );

    if (response.statusCode == 201) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException(
        'Failed to create user: ${response.statusCode}',
      );
    }
  }
}

void main() {
  group('ApiClient', () {
    late MockHttpClient mockClient;
    late ApiClient apiClient;

    setUp(() {
      mockClient = MockHttpClient();
      apiClient = ApiClient(
        client: mockClient,
        baseUrl: 'https://api.example.com',
      );
    });

    test('fetches user successfully', () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'id': '123',
            'username': 'testuser',
            'email': 'test@example.com',
          }),
          200,
        ),
      );

      final user = await apiClient.getUser('123');

      expect(user.id, equals('123'));
      expect(user.username, equals('testuser'));

      verify(() => mockClient.get(
        Uri.parse('https://api.example.com/users/123'),
      )).called(1);
    });

    test('throws UserNotFoundException for 404', () async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response('Not Found', 404),
      );

      expect(
        () => apiClient.getUser('nonexistent'),
        throwsA(isA<UserNotFoundException>()),
      );
    });

    test('creates user successfully', () async {
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'id': '456',
            'username': 'newuser',
            'email': 'newuser@example.com',
          }),
          201,
        ),
      );

      final dto = UserCreateDto(
        username: 'newuser',
        email: 'newuser@example.com',
      );

      final user = await apiClient.createUser(dto);

      expect(user.id, equals('456'));
      expect(user.username, equals('newuser'));
    });
  });
}
```

### Testing External Dependencies

**Using test fixtures:**

```dart
import 'package:test/test.dart';

void main() {
  group('ExternalService Integration', () {
    late ExternalService service;

    setUp(() {
      // Use test environment configuration
      service = ExternalService(
        apiKey: 'test-api-key',
        endpoint: 'https://test-api.example.com',
      );
    });

    test('validates API key format', () {
      expect(
        () => ExternalService(
          apiKey: 'invalid',
          endpoint: 'https://api.example.com',
        ),
        throwsArgumentError,
      );
    });

    test('handles rate limiting', () async {
      // Simulate multiple rapid requests
      final futures = List.generate(
        100,
        (_) => service.makeRequest(),
      );

      // Should handle rate limiting gracefully
      final results = await Future.wait(
        futures,
        eagerError: false,
      );

      // Some requests should succeed
      expect(
        results.where((r) => r != null),
        isNotEmpty,
      );
    });
  });
}
```

### Test Fixtures and Data Builders

**Creating test data builders:**

```dart
class UserBuilder {
  String _id = 'default-id';
  String _username = 'defaultuser';
  String _email = 'default@example.com';
  DateTime _createdAt = DateTime(2024, 1, 1);

  UserBuilder withId(String id) {
    _id = id;
    return this;
  }

  UserBuilder withUsername(String username) {
    _username = username;
    return this;
  }

  UserBuilder withEmail(String email) {
    _email = email;
    return this;
  }

  UserBuilder withCreatedAt(DateTime createdAt) {
    _createdAt = createdAt;
    return this;
  }

  User build() => User(
    id: _id,
    username: _username,
    email: _email,
    createdAt: _createdAt,
  );
}

// Usage in tests
void main() {
  test('user builder creates user', () {
    final user = UserBuilder()
      .withId('123')
      .withUsername('testuser')
      .withEmail('test@example.com')
      .build();

    expect(user.id, equals('123'));
    expect(user.username, equals('testuser'));
  });

  test('user builder uses defaults', () {
    final user = UserBuilder().build();

    expect(user.username, equals('defaultuser'));
    expect(user.email, equals('default@example.com'));
  });
}
```

**Loading fixtures from files:**

```dart
import 'dart:io';
import 'package:test/test.dart';

class Fixtures {
  static Future<Map<String, dynamic>> loadJson(String name) async {
    final file = File('test/fixtures/$name.json');
    final contents = await file.readAsString();
    return jsonDecode(contents) as Map<String, dynamic>;
  }

  static Future<String> loadText(String name) async {
    final file = File('test/fixtures/$name.txt');
    return file.readAsString();
  }
}

void main() {
  test('loads user from fixture', () async {
    final userData = await Fixtures.loadJson('user');
    final user = User.fromJson(userData);

    expect(user.username, equals('fixtureuser'));
  });
}
```

---

## Testing Best Practices

### Test Naming Conventions

**Good test names describe behavior:**

```dart
void main() {
  group('Calculator', () {
    // ❌ Bad: Vague, doesn't describe behavior
    test('test1', () {});
    test('add works', () {});

    // ✅ Good: Descriptive, states expected behavior
    test('adds two positive numbers correctly', () {});
    test('throws ArgumentError when dividing by zero', () {});
    test('returns cached result on second call', () {});
  });

  group('User', () {
    // Use consistent format: "context_whenAction_thenExpectedResult"
    test('validation fails when username is empty', () {});
    test('validation fails when email is invalid', () {});
    test('validation succeeds when all fields are valid', () {});
  });
}
```

### Test Independence and Isolation

**Ensure tests don't depend on each other:**

```dart
void main() {
  group('ShoppingCart', () {
    // ❌ Bad: Tests depend on shared state
    final cart = ShoppingCart();

    test('adds first item', () {
      cart.addItem(item1);
      expect(cart.itemCount, equals(1));
    });

    test('adds second item', () {
      // This test depends on previous test
      cart.addItem(item2);
      expect(cart.itemCount, equals(2)); // Fails if run in isolation
    });

    // ✅ Good: Each test is independent
    test('adds item to empty cart', () {
      final cart = ShoppingCart();
      cart.addItem(item1);
      expect(cart.itemCount, equals(1));
    });

    test('adds item to cart with existing items', () {
      final cart = ShoppingCart();
      cart.addItem(item1);
      cart.addItem(item2);
      expect(cart.itemCount, equals(2));
    });

    // ✅ Better: Use setUp for common initialization
    late ShoppingCart cart;

    setUp(() {
      cart = ShoppingCart();
    });

    test('adds item successfully', () {
      cart.addItem(item1);
      expect(cart.itemCount, equals(1));
    });

    test('removes item successfully', () {
      cart.addItem(item1);
      cart.removeItem(item1.id);
      expect(cart.isEmpty, isTrue);
    });
  });
}
```

### Test Data Management

**Create focused test data:**

```dart
void main() {
  group('UserValidator', () {
    // ❌ Bad: Reusing complex object for all tests
    final user = User(
      id: '123',
      username: 'testuser',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User',
      age: 25,
      address: Address(...),
      // Many more fields...
    );

    test('validates email format', () {
      // Test only cares about email, but has all this other data
      expect(UserValidator.validateEmail(user.email), isTrue);
    });

    // ✅ Good: Test data only includes what's relevant
    test('validates email format', () {
      expect(UserValidator.validateEmail('test@example.com'), isTrue);
      expect(UserValidator.validateEmail('invalid-email'), isFalse);
    });

    test('validates username length', () {
      expect(UserValidator.validateUsername('ab'), isFalse); // Too short
      expect(UserValidator.validateUsername('validuser'), isTrue);
      expect(UserValidator.validateUsername('a' * 100), isFalse); // Too long
    });
  });
}
```

**Use test data builders for complex objects:**

```dart
// Create builder for complex objects
class OrderBuilder {
  String _id = 'order-1';
  String _userId = 'user-1';
  List<OrderItem> _items = [];
  OrderStatus _status = OrderStatus.pending;
  DateTime _createdAt = DateTime(2024, 1, 1);

  OrderBuilder withId(String id) {
    _id = id;
    return this;
  }

  OrderBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  OrderBuilder withItems(List<OrderItem> items) {
    _items = items;
    return this;
  }

  OrderBuilder withStatus(OrderStatus status) {
    _status = status;
    return this;
  }

  OrderBuilder withCreatedAt(DateTime createdAt) {
    _createdAt = createdAt;
    return this;
  }

  Order build() => Order(
    id: _id,
    userId: _userId,
    items: _items,
    status: _status,
    createdAt: _createdAt,
  );
}

void main() {
  test('calculates order total correctly', () {
    final order = OrderBuilder()
      .withItems([
        OrderItem(productId: 'p1', quantity: 2, price: 10.00),
        OrderItem(productId: 'p2', quantity: 1, price: 15.00),
      ])
      .build();

    expect(order.total, equals(35.00));
  });
}
```

### Code Coverage Goals

**Aim for high coverage, but focus on value:**

```dart
// Run tests with coverage
// dart test --coverage=coverage

// Generate coverage report
// dart run coverage:format_coverage \
//   --lcov \
//   --in=coverage \
//   --out=coverage/lcov.info \
//   --report-on=lib

// Coverage goals:
// - Critical business logic: 95%+
// - Service layer: 85%+
// - Data models: 80%+
// - Overall project: 80%+

// Don't obsess over 100% coverage
// Focus on testing important behavior
```

### Performance Testing

**Test performance-critical code:**

```dart
import 'package:test/test.dart';

void main() {
  group('Performance', () {
    test('processes large dataset efficiently', () {
      final data = List.generate(100000, (i) => i);

      final stopwatch = Stopwatch()..start();

      final result = processData(data);

      stopwatch.stop();

      // Should complete in under 100ms
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(result, hasLength(100000));
    });

    test('memory usage stays reasonable', () {
      final initialMemory = ProcessInfo.currentRss;

      // Perform memory-intensive operation
      final data = generateLargeDataset();
      processData(data);

      final finalMemory = ProcessInfo.currentRss;
      final memoryIncrease = finalMemory - initialMemory;

      // Memory increase should be reasonable
      expect(memoryIncrease, lessThan(100 * 1024 * 1024)); // 100 MB
    });
  });
}
```

### Test Maintainability

**Write maintainable tests:**

```dart
void main() {
  group('UserService', () {
    // ❌ Bad: Duplicated setup code
    test('creates user', () {
      final db = Database.inMemory();
      final logger = FakeLogger();
      final emailService = FakeEmailService();
      final service = UserService(
        database: db,
        logger: logger,
        emailService: emailService,
      );

      // Test code...
    });

    test('updates user', () {
      final db = Database.inMemory();
      final logger = FakeLogger();
      final emailService = FakeEmailService();
      final service = UserService(
        database: db,
        logger: logger,
        emailService: emailService,
      );

      // Test code...
    });

    // ✅ Good: Shared setup with setUp()
    late UserService service;
    late Database database;

    setUp(() {
      database = Database.inMemory();
      final logger = FakeLogger();
      final emailService = FakeEmailService();
      service = UserService(
        database: database,
        logger: logger,
        emailService: emailService,
      );
    });

    tearDown(() {
      database.close();
    });

    test('creates user', () {
      // Test code...
    });

    test('updates user', () {
      // Test code...
    });
  });

  // ✅ Better: Extract helper functions
  UserService createTestService() {
    return UserService(
      database: Database.inMemory(),
      logger: FakeLogger(),
      emailService: FakeEmailService(),
    );
  }

  User createTestUser({
    String? username,
    String? email,
  }) {
    return User(
      id: 'test-id',
      username: username ?? 'testuser',
      email: email ?? 'test@example.com',
      createdAt: DateTime(2024, 1, 1),
    );
  }
}
```

---

## Using package:checks

### Modern Assertion Library

**Installation:**

```yaml
dev_dependencies:
  checks: ^0.3.0
```

**Basic usage:**

```dart
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  test('string assertions with checks', () {
    check('hello world')
      ..startsWith('hello')
      ..endsWith('world')
      ..contains('o w')
      ..hasLength(11);
  });

  test('number assertions with checks', () {
    check(42)
      ..isGreaterThan(40)
      ..isLessThan(50)
      ..isNotZero();
  });

  test('list assertions with checks', () {
    check([1, 2, 3, 4, 5])
      ..hasLength(5)
      ..contains(3)
      ..first.isLessThan(2)
      ..last.equals(5);
  });
}
```

### Type-Safe Assertions

**Better type safety than expect():**

```dart
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  test('type-safe assertions', () {
    final user = User(
      id: '123',
      username: 'testuser',
      email: 'test@example.com',
    );

    check(user)
      ..has((u) => u.id, 'id').equals('123')
      ..has((u) => u.username, 'username').equals('testuser')
      ..has((u) => u.email, 'email').contains('@');
  });

  test('nullable type handling', () {
    String? nullableString;

    check(nullableString).isNull();

    nullableString = 'not null';

    check(nullableString)
      ..isNotNull()
      ..equals('not null');
  });
}
```

### Better Error Messages

**Clearer failure messages:**

```dart
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  test('clear error messages', () {
    final user = User(
      id: '123',
      username: 'testuser',
      email: 'invalid-email',
    );

    // Instead of:
    // expect(user.email.contains('@'), isTrue);
    // Output: Expected: <true> Actual: <false>

    // Use checks:
    check(user)
      .has((u) => u.email, 'email')
      .contains('@');
    // Output: Expected email to contain '@'
    //         Actual: 'invalid-email'
  });
}
```

### Fluent Assertion API

**Chainable assertions:**

```dart
import 'package:checks/checks.dart';
import 'package:test/test.dart';

void main() {
  test('fluent API', () {
    final list = [1, 2, 3, 4, 5];

    check(list)
      ..isNotEmpty()
      ..hasLength(5)
      ..first.isLessThan(2)
      ..last.equals(5)
      ..every((item) => item.isGreaterThan(0))
      ..any((item) => item.equals(3));
  });

  test('nested object assertions', () {
    final order = Order(
      id: '123',
      user: User(
        id: 'u1',
        username: 'testuser',
        email: 'test@example.com',
      ),
      items: [
        OrderItem(productId: 'p1', quantity: 2),
        OrderItem(productId: 'p2', quantity: 1),
      ],
    );

    check(order)
      ..has((o) => o.id, 'id').equals('123')
      ..has((o) => o.user.username, 'user.username').equals('testuser')
      ..has((o) => o.items, 'items')
        ..hasLength(2)
        ..first.has((i) => i.quantity, 'quantity').equals(2);
  });
}
```

**Custom assertions:**

```dart
import 'package:checks/checks.dart';

extension UserChecks on Subject<User> {
  void hasValidEmail() {
    context.expect(
      () => ['has valid email'],
      (actual) {
        final email = actual.email;
        if (!email.contains('@') || !email.contains('.')) {
          return Rejection(
            which: ['does not have valid email format'],
            actual: [email],
          );
        }
        return null;
      },
    );
  }

  void isActive() {
    context.expect(
      () => ['is active'],
      (actual) {
        if (!actual.isActive) {
          return Rejection(
            which: ['is not active'],
          );
        }
        return null;
      },
    );
  }
}

void main() {
  test('custom assertions', () {
    final user = User(
      id: '123',
      username: 'testuser',
      email: 'test@example.com',
      isActive: true,
    );

    check(user)
      ..hasValidEmail()
      ..isActive();
  });
}
```

---

## Testing CLI Applications

### Testing Command Parsing

**Using package:args:**

```dart
import 'package:args/args.dart';
import 'package:test/test.dart';

class CliApp {
  final ArgParser parser;

  CliApp() : parser = _buildParser();

  static ArgParser _buildParser() {
    return ArgParser()
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Enable verbose output',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output file path',
      )
      ..addCommand('build', _buildCommandParser())
      ..addCommand('test', _testCommandParser());
  }

  static ArgParser _buildCommandParser() {
    return ArgParser()
      ..addFlag(
        'release',
        negatable: false,
        help: 'Build in release mode',
      );
  }

  static ArgParser _testCommandParser() {
    return ArgParser()
      ..addOption(
        'coverage',
        help: 'Generate coverage report',
      );
  }

  ArgResults parse(List<String> arguments) {
    return parser.parse(arguments);
  }
}

void main() {
  group('CLI Argument Parsing', () {
    late CliApp app;

    setUp(() {
      app = CliApp();
    });

    test('parses verbose flag', () {
      final results = app.parse(['--verbose']);

      expect(results['verbose'], isTrue);
    });

    test('parses abbreviated flag', () {
      final results = app.parse(['-v']);

      expect(results['verbose'], isTrue);
    });

    test('parses option', () {
      final results = app.parse(['--output', 'result.txt']);

      expect(results['output'], equals('result.txt'));
    });

    test('parses build command', () {
      final results = app.parse(['build', '--release']);

      expect(results.command?.name, equals('build'));
      expect(results.command!['release'], isTrue);
    });

    test('parses test command', () {
      final results = app.parse(['test', '--coverage=html']);

      expect(results.command?.name, equals('test'));
      expect(results.command!['coverage'], equals('html'));
    });

    test('throws on invalid arguments', () {
      expect(
        () => app.parse(['--invalid-option']),
        throwsFormatException,
      );
    });
  });
}
```

### Testing stdout/stderr Output

**Capturing console output:**

```dart
import 'dart:io';
import 'package:test/test.dart';

class CliRunner {
  final StringBuffer _stdout = StringBuffer();
  final StringBuffer _stderr = StringBuffer();

  void println(String message) {
    _stdout.writeln(message);
  }

  void printError(String message) {
    _stderr.writeln(message);
  }

  String get stdout => _stdout.toString();
  String get stderr => _stderr.toString();

  void clear() {
    _stdout.clear();
    _stderr.clear();
  }
}

void main() {
  group('CLI Output', () {
    late CliRunner runner;

    setUp(() {
      runner = CliRunner();
    });

    test('prints to stdout', () {
      runner.println('Hello, World!');

      expect(runner.stdout, contains('Hello, World!'));
    });

    test('prints error to stderr', () {
      runner.printError('Error occurred');

      expect(runner.stderr, contains('Error occurred'));
    });

    test('formats output correctly', () {
      runner.println('Line 1');
      runner.println('Line 2');
      runner.println('Line 3');

      expect(
        runner.stdout,
        equals('Line 1\nLine 2\nLine 3\n'),
      );
    });
  });

  group('Process Output', () {
    test('captures process stdout', () async {
      final result = await Process.run(
        'dart',
        ['--version'],
      );

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains('Dart'));
    });

    test('captures process stderr', () async {
      final result = await Process.run(
        'dart',
        ['invalid-command'],
      );

      expect(result.exitCode, isNot(equals(0)));
      expect(result.stderr, isNotEmpty);
    });
  });
}
```

### Testing File Operations

**Testing file I/O:**

```dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

class FileManager {
  Future<void> writeFile(String filePath, String content) async {
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<String> readFile(String filePath) async {
    final file = File(filePath);
    return file.readAsString();
  }

  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<String>> listFiles(String dirPath) async {
    final dir = Directory(dirPath);
    final files = await dir.list().toList();
    return files
      .whereType<File>()
      .map((f) => path.basename(f.path))
      .toList();
  }
}

void main() {
  group('File Operations', () {
    late Directory tempDir;
    late FileManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('test_');
      manager = FileManager();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes file successfully', () async {
      final filePath = path.join(tempDir.path, 'test.txt');

      await manager.writeFile(filePath, 'Hello, World!');

      final file = File(filePath);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals('Hello, World!'));
    });

    test('reads file successfully', () async {
      final filePath = path.join(tempDir.path, 'test.txt');
      await File(filePath).writeAsString('Test content');

      final content = await manager.readFile(filePath);

      expect(content, equals('Test content'));
    });

    test('deletes file successfully', () async {
      final filePath = path.join(tempDir.path, 'test.txt');
      await File(filePath).writeAsString('Test');

      await manager.deleteFile(filePath);

      expect(await File(filePath).exists(), isFalse);
    });

    test('lists files in directory', () async {
      await File(path.join(tempDir.path, 'file1.txt')).create();
      await File(path.join(tempDir.path, 'file2.txt')).create();
      await File(path.join(tempDir.path, 'file3.txt')).create();

      final files = await manager.listFiles(tempDir.path);

      expect(files, hasLength(3));
      expect(files, containsAll(['file1.txt', 'file2.txt', 'file3.txt']));
    });

    test('creates nested directories', () async {
      final filePath = path.join(
        tempDir.path,
        'nested',
        'dir',
        'test.txt',
      );

      await manager.writeFile(filePath, 'Nested file');

      expect(await File(filePath).exists(), isTrue);
    });
  });
}
```

### Testing Process Execution

**Testing subprocess execution:**

```dart
import 'dart:io';
import 'package:test/test.dart';

class ProcessRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  }

  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );

    // Forward stdout/stderr
    process.stdout.pipe(stdout);
    process.stderr.pipe(stderr);

    return process.exitCode;
  }
}

void main() {
  group('Process Execution', () {
    late ProcessRunner runner;

    setUp(() {
      runner = ProcessRunner();
    });

    test('runs command successfully', () async {
      final result = await runner.run('echo', ['Hello']);

      expect(result.exitCode, equals(0));
      expect(result.stdout.toString().trim(), equals('Hello'));
    });

    test('captures error output', () async {
      final result = await runner.run('dart', ['nonexistent-file.dart']);

      expect(result.exitCode, isNot(equals(0)));
      expect(result.stderr.toString(), isNotEmpty);
    });

    test('runs in specified directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_');

      try {
        final result = await runner.run(
          'pwd',
          [],
          workingDirectory: tempDir.path,
        );

        expect(
          result.stdout.toString().trim(),
          equals(tempDir.path),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
```

---

## Testing Patterns

### Builder Pattern for Test Data

**Create flexible test data builders:**

```dart
class UserBuilder {
  String _id = 'user-${DateTime.now().millisecondsSinceEpoch}';
  String _username = 'testuser';
  String _email = 'test@example.com';
  String _firstName = 'Test';
  String _lastName = 'User';
  DateTime _createdAt = DateTime.now();
  UserRole _role = UserRole.user;
  bool _isActive = true;

  UserBuilder withId(String id) {
    _id = id;
    return this;
  }

  UserBuilder withUsername(String username) {
    _username = username;
    return this;
  }

  UserBuilder withEmail(String email) {
    _email = email;
    return this;
  }

  UserBuilder withFullName(String firstName, String lastName) {
    _firstName = firstName;
    _lastName = lastName;
    return this;
  }

  UserBuilder withRole(UserRole role) {
    _role = role;
    return this;
  }

  UserBuilder inactive() {
    _isActive = false;
    return this;
  }

  UserBuilder createdAt(DateTime date) {
    _createdAt = date;
    return this;
  }

  User build() => User(
    id: _id,
    username: _username,
    email: _email,
    firstName: _firstName,
    lastName: _lastName,
    createdAt: _createdAt,
    role: _role,
    isActive: _isActive,
  );
}

// Usage
void main() {
  test('admin users have special permissions', () {
    final admin = UserBuilder()
      .withUsername('admin')
      .withRole(UserRole.admin)
      .build();

    expect(admin.hasPermission(Permission.manageUsers), isTrue);
  });

  test('inactive users cannot login', () {
    final user = UserBuilder()
      .inactive()
      .build();

    expect(() => loginService.login(user), throwsA(isA<InactiveUserException>()));
  });
}
```

### Test Doubles (Fakes, Stubs, Mocks)

**Fakes: Working implementations:**

```dart
class FakeUserRepository implements UserRepository {
  final Map<String, User> _users = {};

  @override
  Future<User?> findById(String id) async {
    return _users[id];
  }

  @override
  Future<void> save(User user) async {
    _users[user.id] = user;
  }

  @override
  Future<void> delete(String id) async {
    _users.remove(id);
  }

  @override
  Future<List<User>> findAll() async {
    return _users.values.toList();
  }
}
```

**Stubs: Predetermined responses:**

```dart
class StubEmailService implements EmailService {
  final bool shouldSucceed;
  final List<String> sentEmails = [];

  StubEmailService({this.shouldSucceed = true});

  @override
  Future<void> sendEmail(String to, String subject, String body) async {
    if (!shouldSucceed) {
      throw EmailException('Failed to send email');
    }
    sentEmails.add(to);
  }
}
```

**Mocks: Behavior verification:**

```dart
import 'package:mocktail/mocktail.dart';

class MockLogger extends Mock implements Logger {}

void main() {
  test('logs user creation', () {
    final mockLogger = MockLogger();
    final service = UserService(logger: mockLogger);

    service.createUser(username: 'test', email: 'test@example.com');

    verify(() => mockLogger.info('Creating user: test')).called(1);
  });
}
```

### Parameterized Tests

**Test multiple scenarios efficiently:**

```dart
import 'package:test/test.dart';

void main() {
  group('Email Validation', () {
    final validEmails = [
      'user@example.com',
      'test.user@example.com',
      'user+tag@example.co.uk',
      'user_name@example-domain.com',
    ];

    for (final email in validEmails) {
      test('accepts valid email: $email', () {
        expect(EmailValidator.isValid(email), isTrue);
      });
    }

    final invalidEmails = [
      'invalid',
      '@example.com',
      'user@',
      'user@.com',
      'user name@example.com',
    ];

    for (final email in invalidEmails) {
      test('rejects invalid email: $email', () {
        expect(EmailValidator.isValid(email), isFalse);
      });
    }
  });

  group('Calculator', () {
    final testCases = [
      (a: 2, b: 3, expected: 5),
      (a: -1, b: 1, expected: 0),
      (a: 0, b: 0, expected: 0),
      (a: 100, b: 200, expected: 300),
    ];

    for (final testCase in testCases) {
      test('adds ${testCase.a} + ${testCase.b} = ${testCase.expected}', () {
        final calculator = Calculator();
        final result = calculator.add(testCase.a, testCase.b);
        expect(result, equals(testCase.expected));
      });
    }
  });
}
```

### Testing Error Scenarios

**Comprehensive error testing:**

```dart
import 'package:test/test.dart';

void main() {
  group('Error Handling', () {
    test('throws ArgumentError for null input', () {
      expect(
        () => processData(null),
        throwsArgumentError,
      );
    });

    test('throws custom exception with message', () {
      expect(
        () => divideNumbers(10, 0),
        throwsA(
          isA<DivisionException>()
            .having((e) => e.message, 'message', contains('zero')),
        ),
      );
    });

    test('throws StateError when not initialized', () {
      final service = UserService();

      expect(
        () => service.getUser('123'),
        throwsA(
          isA<StateError>()
            .having(
              (e) => e.message,
              'message',
              contains('not initialized'),
            ),
        ),
      );
    });

    test('returns error result instead of throwing', () {
      final result = tryProcessData('invalid');

      expect(result.isError, isTrue);
      expect(result.error, isA<ValidationException>());
    });

    test('recovers from error gracefully', () async {
      final service = ResilientService();

      // First attempt fails
      await expectLater(
        service.fetchData(),
        throwsA(isA<NetworkException>()),
      );

      // But service is still usable
      final result = await service.fetchData();
      expect(result, isNotNull);
    });

    test('propagates nested errors correctly', () async {
      final service = ServiceWithDependencies();

      expect(
        () async => await service.performOperation(),
        throwsA(
          isA<ServiceException>()
            .having((e) => e.cause, 'cause', isA<DatabaseException>()),
        ),
      );
    });
  });
}
```

---

## Test Organization

### Directory Structure

```
project/
├── lib/
│   ├── src/
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   └── order.dart
│   │   ├── services/
│   │   │   ├── user_service.dart
│   │   │   └── order_service.dart
│   │   ├── repositories/
│   │   │   ├── user_repository.dart
│   │   │   └── order_repository.dart
│   │   └── utils/
│   │       ├── validators.dart
│   │       └── formatters.dart
│   └── app.dart
├── test/
│   ├── unit/
│   │   ├── models/
│   │   │   ├── user_test.dart
│   │   │   └── order_test.dart
│   │   ├── services/
│   │   │   ├── user_service_test.dart
│   │   │   └── order_service_test.dart
│   │   └── utils/
│   │       ├── validators_test.dart
│   │       └── formatters_test.dart
│   ├── integration/
│   │   ├── repositories/
│   │   │   ├── user_repository_test.dart
│   │   │   └── order_repository_test.dart
│   │   └── services/
│   │       └── user_service_integration_test.dart
│   ├── e2e/
│   │   ├── user_workflow_test.dart
│   │   └── order_workflow_test.dart
│   ├── fixtures/
│   │   ├── user.json
│   │   └── order.json
│   ├── helpers/
│   │   ├── builders.dart
│   │   ├── fakes.dart
│   │   └── test_helpers.dart
│   └── test_config.dart
└── pubspec.yaml
```

### Test File Naming

```dart
// Source file: lib/src/services/user_service.dart
// Test file:    test/unit/services/user_service_test.dart

// Source file: lib/src/repositories/user_repository.dart
// Test file:    test/integration/repositories/user_repository_test.dart

// E2E test:     test/e2e/user_registration_workflow_test.dart
```

### Running Tests

```bash
# Run all tests
dart test

# Run specific test file
dart test test/unit/services/user_service_test.dart

# Run tests matching pattern
dart test --name="UserService"

# Run tests with tags
dart test --tags=unit
dart test --exclude-tags=integration

# Run with coverage
dart test --coverage=coverage

# Run in watch mode (requires fswatch or inotify-tools)
while inotifywait -r -e modify lib/ test/; do dart test; done

# Parallel execution
dart test --concurrency=4

# Run with specific platform
dart test --platform vm
dart test --platform chrome
```

### Test Configuration

**dart_test.yaml:**

```yaml
# test/dart_test.yaml

# Set test timeout (default: 30s)
timeout: 60s

# Specify test tags
tags:
  unit:
    timeout: 10s
  integration:
    timeout: 30s
  e2e:
    timeout: 120s

# Platform configuration
platforms:
  - vm
  - chrome

# Path configuration
paths:
  - test/

# Exclude patterns
exclude:
  - test/**/*_skip_test.dart

# Reporter configuration
reporter: expanded

# Concurrency
concurrency: 4

# Add preset configurations
presets:
  fast:
    tags: unit
    concurrency: 8

  integration:
    tags: integration
    concurrency: 2

  all:
    tags:
```

---

## Best Practices Summary

### Testing Checklist

**Unit Tests:**
- [ ] Test pure functions thoroughly
- [ ] Test business logic independently
- [ ] Test error conditions and edge cases
- [ ] Use descriptive test names
- [ ] Keep tests focused and isolated
- [ ] Avoid testing implementation details
- [ ] Use test builders for complex objects
- [ ] Clean up resources in tearDown

**Integration Tests:**
- [ ] Test service layer interactions
- [ ] Test database operations with transactions
- [ ] Test external API integrations
- [ ] Use fakes instead of mocks when possible
- [ ] Test error handling and retry logic
- [ ] Verify resource cleanup
- [ ] Use test fixtures for data

**Testing Standards:**
- [ ] Aim for 80%+ code coverage on critical paths
- [ ] Follow Arrange-Act-Assert pattern
- [ ] One logical assertion per test
- [ ] Use setUp/tearDown for common initialization
- [ ] Keep tests fast (< 1s for unit tests)
- [ ] Make tests deterministic (no flaky tests)
- [ ] Use package:checks for better assertions
- [ ] Document complex test scenarios

**CLI Testing:**
- [ ] Test command parsing thoroughly
- [ ] Capture and verify stdout/stderr
- [ ] Test file operations with temp directories
- [ ] Test process execution and exit codes
- [ ] Verify error messages are helpful
- [ ] Test interactive prompts

**Maintenance:**
- [ ] Run tests before committing
- [ ] Keep tests up to date with code changes
- [ ] Refactor tests alongside production code
- [ ] Remove obsolete tests
- [ ] Review test failures promptly
- [ ] Update test documentation

---

## Additional Resources

### Package Documentation

- [package:test](https://pub.dev/packages/test) - Official Dart testing framework
- [package:checks](https://pub.dev/packages/checks) - Modern assertion library
- [package:mocktail](https://pub.dev/packages/mocktail) - Mock library
- [package:riverpod](https://pub.dev/packages/riverpod) - State management with testability

### Testing Guidelines

- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Google Testing Blog](https://testing.googleblog.com/)
- [Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)

### Examples and Patterns

```dart
// For more examples, see:
// - Dart SDK tests: https://github.com/dart-lang/sdk/tree/main/tests
// - Riverpod tests: https://github.com/rrousselGit/riverpod/tree/master/packages/riverpod/test
// - Shelf tests: https://github.com/dart-lang/shelf/tree/master/pkgs/shelf/test
```

---

## Conclusion

Comprehensive testing is essential for building reliable Dart applications. Follow these standards to create maintainable, high-quality test suites that give you confidence in your code.

**Remember:**
- Write tests that document behavior
- Keep tests simple and focused
- Test the right things at the right level
- Maintain your tests like production code
- Use testing to drive better design

**Key Principles:**
1. **Test behavior, not implementation**
2. **Prefer simple fakes over complex mocks**
3. **Make tests readable and maintainable**
4. **Use the test pyramid as a guide**
5. **Keep tests fast and reliable**

Happy testing!
