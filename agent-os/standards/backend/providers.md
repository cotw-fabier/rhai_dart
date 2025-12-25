# Riverpod Provider Patterns for Pure Dart

Comprehensive guide for using Riverpod in pure Dart CLI and backend applications, based on kvetchbot patterns and best practices.

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Provider Types](#provider-types)
3. [Code Generation](#code-generation)
4. [Dependency Injection](#dependency-injection)
5. [State Management](#state-management)
6. [Testing with Providers](#testing-with-providers)
7. [Best Practices](#best-practices)

## Core Concepts

### Why Riverpod for Backend?

Riverpod provides:
- **Compile-time safety** - No runtime context lookups
- **Testability** - Easy to mock and override
- **Scoping** - Control provider lifecycle
- **Composability** - Providers can depend on other providers
- **No Flutter dependency** - Works in pure Dart

### Basic Setup

**pubspec.yaml:**
```yaml
dependencies:
  riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

dev_dependencies:
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
```

**main.dart:**
```dart
import 'package:riverpod/riverpod.dart';

void main() {
  // Create provider container
  final container = ProviderContainer();

  try {
    // Use providers
    final result = container.read(myProvider);
    print(result);
  } finally {
    // Always dispose
    container.dispose();
  }
}
```

## Provider Types

### 1. Simple Provider

For constants and immutable values:

**From kvetchbot - Environment Provider:**
```dart
import 'package:dotenv/dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'envprovider.g.dart';

/// Environment configuration provider
///
/// Loads .env file and provides access to environment variables
@riverpod
DotEnv envNotifier(EnvNotifierRef ref) {
  return DotEnv(includePlatformEnvironment: true)..load();
}

/// Usage in other providers
@riverpod
String weatherApiKey(WeatherApiKeyRef ref) {
  final env = ref.read(envNotifierProvider);
  final key = env['WEATHER_API_KEY'];

  if (key == null || key.isEmpty) {
    throw StateError('WEATHER_API_KEY not configured in .env file');
  }

  return key;
}

/// Usage in application
void main() {
  final container = ProviderContainer();
  
  final env = container.read(envNotifierProvider);
  print('Loaded ${env.map.length} environment variables');
  
  final apiKey = container.read(weatherApiKeyProvider);
  print('API Key: ${apiKey.substring(0, 4)}...');
  
  container.dispose();
}
```

### 2. Async Provider

For asynchronous data loading:

**From kvetchbot - Bible Data Provider:**
```dart
import 'dart:convert';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bibleprovider.g.dart';

/// Bible data provider
///
/// Loads bible JSON file and caches data
@Riverpod(keepAlive: true)
class BibleNotifier extends _$BibleNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final file = File('../bibles/NKJV.bible.json');

    if (!file.existsSync()) {
      // Fail gracefully if file doesn't exist
      return [];
    }

    final bibleString = await file.readAsString();
    final bibleData = json.decode(bibleString) as Map<String, dynamic>;

    return (bibleData['books'] as List)
        .cast<Map<String, dynamic>>();
  }
}

/// Usage
void main() async {
  final container = ProviderContainer();

  // Read async provider
  final books = await container.read(bibleNotifierProvider.future);
  print('Loaded ${books.length} books');

  // Handle loading states
  final asyncValue = container.read(bibleNotifierProvider);
  asyncValue.when(
    data: (books) => print('Books: $books'),
    loading: () => print('Loading...'),
    error: (err, stack) => print('Error: $err'),
  );

  container.dispose();
}
```

### 3. StateNotifier Provider

For mutable state with methods:

**From kvetchbot - Message History:**
```dart
import 'package:nyxx/nyxx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'messagehistory.g.dart';

/// Message history provider with state management
@Riverpod(keepAlive: true)
class MessageHistoryNotifier extends _$MessageHistoryNotifier {
  @override
  List<Message> build(String server, String channel) {
    return [];
  }

  void addMessage(Message message) {
    print('Added message: ${message.content}');

    var history = state;
    history.add(message);

    // Trim to last 500 messages
    if (history.length > 500) {
      history = history.sublist(history.length - 500);
    }

    state = history;
  }

  List<Message> pullMessages(int count) {
    final messages = state;
    final howFarBack = messages.length < count ? messages.length : count;

    print('${messages.length} - $count - $howFarBack');

    return messages
        .sublist(messages.length - howFarBack)
        .reversed
        .toList();
  }

  void clear() {
    state = [];
  }
}

/// Usage
void main() {
  final container = ProviderContainer();

  final notifier = container.read(
    messageHistoryNotifierProvider('server1', 'channel1').notifier,
  );

  notifier.addMessage(message1);
  notifier.addMessage(message2);

  final recent = notifier.pullMessages(10);
  print('Recent messages: ${recent.length}');

  container.dispose();
}
```

### 4. Service Provider with Client

**From kvetchbot - Ollama Client:**
```dart
import 'package:ollama_dart/ollama_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollamaclient.g.dart';

/// Ollama AI client provider
@riverpod
class OllamaClientNotifier extends _$OllamaClientNotifier {
  @override
  OllamaClient build() {
    final env = ref.read(envNotifierProvider);

    // Client is created and cached
    final client = OllamaClient(
      baseUrl: env['OLLAMA_URL'] ?? 'http://localhost:11434',
    );

    // Cleanup on dispose
    ref.onDispose(() {
      client.close();
    });

    return client;
  }

  /// Generate AI response
  Future<String> generateResponse({
    String model = '',
    String system = '',
    String prompt = '',
    RequestOptions? options,
    List<String>? images,
  }) async {
    final env = ref.read(envNotifierProvider);

    final modelName = model.isEmpty ? env['MODEL'] ?? 'llama2' : model;

    print('Generating response with model: $modelName');
    print('Prompt: <system>$system</system> <user>$prompt</user>');

    final client = state;

    final generated = await client.generateCompletion(
      request: GenerateCompletionRequest(
        model: modelName,
        system: system,
        prompt: prompt,
        options: options,
      ),
    );

    // Remove thinking tags
    final thinkTagPattern = RegExp(r'<think>(.*?)</think>', dotAll: true);
    final cleaned = generated.response?.replaceAll(thinkTagPattern, '')
        ?? 'No response from AI';

    print('Model response: $cleaned');
    return cleaned;
  }
}

/// Usage
void main() async {
  final container = ProviderContainer();

  final notifier = container.read(ollamaClientNotifierProvider.notifier);

  final response = await notifier.generateResponse(
    system: 'You are a helpful assistant',
    prompt: 'What is the weather like?',
  );

  print(response);

  container.dispose();
}
```

## Code Generation

### Setup build_runner

**Run code generation:**
```bash
# One-time generation
dart run build_runner build

# Watch mode (auto-regenerates)
dart run build_runner watch

# Clean and rebuild
dart run build_runner build --delete-conflicting-outputs
```

### Provider Patterns

**Simple function provider:**
```dart
@riverpod
String greeting(GreetingRef ref) {
  return 'Hello, World!';
}
```

**Provider with parameters:**
```dart
@riverpod
String greetUser(GreetUserRef ref, String name) {
  return 'Hello, $name!';
}

// Usage
final greeting = container.read(greetUserProvider('John'));
```

**Async provider:**
```dart
@riverpod
Future<User> fetchUser(FetchUserRef ref, String id) async {
  final api = ref.watch(apiClientProvider);
  return await api.getUser(id);
}
```

**KeepAlive providers:**
```dart
@Riverpod(keepAlive: true)
class ConfigNotifier extends _$ConfigNotifier {
  @override
  Config build() {
    return Config.load();
  }
}
```

## Dependency Injection

### Provider Dependencies

**Compose providers:**
```dart
/// HTTP client provider
@riverpod
http.Client httpClient(HttpClientRef ref) {
  final client = http.Client();
  ref.onDispose(() => client.close());
  return client;
}

/// API client provider
@riverpod
ApiClient apiClient(ApiClientRef ref) {
  final httpClient = ref.watch(httpClientProvider);
  final apiKey = ref.watch(apiKeyProvider);

  return ApiClient(
    httpClient: httpClient,
    apiKey: apiKey,
  );
}

/// Weather service provider (depends on API client)
@riverpod
WeatherService weatherService(WeatherServiceRef ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(cacheProvider);

  return WeatherServiceImpl(
    apiClient: apiClient,
    cache: cache,
  );
}
```

### Dependency Lifecycle

**onDispose for cleanup:**
```dart
@riverpod
Database database(DatabaseRef ref) {
  final db = Database.connect('localhost:5432');

  // Cleanup when provider is disposed
  ref.onDispose(() {
    db.close();
    print('Database connection closed');
  });

  return db;
}
```

**Listen to other providers:**
```dart
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  User? build() {
    // Listen to auth state
    ref.listen(authStateProvider, (previous, next) {
      if (next == null) {
        // User logged out, clear state
        state = null;
      }
    });

    return null;
  }
}
```

## State Management

### Immutable State Updates

**GOOD:**
```dart
@riverpod
class TodoListNotifier extends _$TodoListNotifier {
  @override
  List<Todo> build() {
    return [];
  }

  void addTodo(Todo todo) {
    state = [...state, todo]; // Create new list
  }

  void removeTodo(String id) {
    state = state.where((t) => t.id != id).toList(); // New list
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
}
```

**BAD:**
```dart
@riverpod
class TodoListNotifier extends _$TodoListNotifier {
  @override
  List<Todo> build() {
    return [];
  }

  void addTodo(Todo todo) {
    state.add(todo); // Mutates state directly - BAD!
  }

  void removeTodo(String id) {
    state.removeWhere((t) => t.id == id); // Mutates - BAD!
  }
}
```

### Complex State

**Use sealed classes for state:**
```dart
sealed class LoadingState<T> {
  const LoadingState();
}

class Initial<T> extends LoadingState<T> {
  const Initial();
}

class Loading<T> extends LoadingState<T> {
  const Loading();
}

class Loaded<T> extends LoadingState<T> {
  const Loaded(this.data);
  final T data;
}

class Error<T> extends LoadingState<T> {
  const Error(this.message);
  final String message;
}

@riverpod
class WeatherNotifier extends _$WeatherNotifier {
  @override
  LoadingState<Weather> build(String city) {
    return const Initial();
  }

  Future<void> load() async {
    state = const Loading();

    try {
      final service = ref.read(weatherServiceProvider);
      final weather = await service.getWeather(city);
      state = Loaded(weather);
    } catch (e) {
      state = Error(e.toString());
    }
  }
}
```

## Testing with Providers

### Override Providers in Tests

```dart
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MockWeatherService extends Mock implements WeatherService {}

void main() {
  group('WeatherCommand', () {
    late ProviderContainer container;
    late MockWeatherService mockService;

    setUp(() {
      mockService = MockWeatherService();

      // Override provider with mock
      container = ProviderContainer(
        overrides: [
          weatherServiceProvider.overrideWith((ref) => mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('fetches weather successfully', () async {
      // Arrange
      final weather = Weather(
        temperature: 72.0,
        condition: 'Sunny',
      );

      when(() => mockService.getWeather('Seattle'))
          .thenAnswer((_) async => weather);

      // Act
      final service = container.read(weatherServiceProvider);
      final result = await service.getWeather('Seattle');

      // Assert
      expect(result, equals(weather));
      verify(() => mockService.getWeather('Seattle')).called(1);
    });
  });
}
```

### Test State Changes

```dart
void main() {
  test('TodoListNotifier adds todos', () {
    final container = ProviderContainer();

    final notifier = container.read(todoListNotifierProvider.notifier);

    expect(container.read(todoListNotifierProvider), isEmpty);

    notifier.addTodo(Todo(id: '1', title: 'Test'));

    expect(container.read(todoListNotifierProvider), hasLength(1));

    container.dispose();
  });
}
```

## Best Practices

### 1. Provider Organization

**DO:**
- One provider per file
- Use code generation
- Group related providers in folders
- Export via barrel files

**DON'T:**
- Put multiple providers in one file
- Write providers manually (use codegen)
- Mix provider types carelessly

### 2. Dependencies

**DO:**
- Make dependencies explicit via ref.watch
- Use ref.read for one-time reads
- Dispose resources in onDispose
- Document provider dependencies

**DON'T:**
- Access providers without ref
- Forget to dispose resources
- Create circular dependencies
- Use global singletons

### 3. State Management

**DO:**
- Keep state immutable
- Use sealed classes for complex state
- Handle all state cases
- Test state transitions

**DON'T:**
- Mutate state directly
- Use nullable state unnecessarily
- Forget error states
- Skip loading states

### 4. Testing

**DO:**
- Override providers in tests
- Test providers independently
- Mock external dependencies
- Dispose containers

**DON'T:**
- Test implementation details
- Share containers between tests
- Forget to dispose
- Skip error scenarios

## Summary

This guide covers:

1. **Provider Types** - Simple, Async, StateNotifier patterns
2. **Code Generation** - Using riverpod_annotation
3. **Dependency Injection** - Provider composition
4. **State Management** - Immutable updates
5. **Testing** - Mocking and overrides

Key principles:
- Use code generation
- Compose providers
- Keep state immutable
- Test with overrides
- Dispose resources

Follow these patterns for maintainable, testable provider-based architecture in pure Dart.
