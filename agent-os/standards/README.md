# Dart-Only Development Standards

This directory contains development standards for building command-line applications, backend services, and server-side applications using pure Dart (no Flutter).

## Architecture Overview

```
┌────────────────────────────────────────────────┐
│            DART APPLICATION                    │
│  CLI / Backend / Server                        │
│  (Dart 3.0+, Riverpod, dart:io)               │
└────────────────────────────────────────────────┘
                 │
        ┌────────▼────────┐
        │   Core Layers   │
        │  - Commands     │
        │  - Services     │
        │  - Models       │
        │  - Providers    │
        └────────┬────────┘
                 │
┌────────────────▼───────────────────────────────┐
│          DATA & EXTERNAL SERVICES              │
│  Local Storage (Hive, SQLite)                 │
│  HTTP APIs, Web Servers (shelf)               │
│  Scheduled Jobs (cron)                        │
└────────────────────────────────────────────────┘
```

## Directory Structure

### Global Standards
- **[tech-stack.md](./global/tech-stack.md)** - Complete technology stack for Dart CLI/backend development
- **[conventions.md](./global/conventions.md)** - Project structure, naming, file organization, version control
- **[coding-style.md](./global/coding-style.md)** - Naming conventions, formatting, code organization
- **[error-handling.md](./global/error-handling.md)** - Exception handling, error logging, recovery strategies
- **[commenting.md](./global/commenting.md)** - Documentation standards for Dart code
- **[validation.md](./global/validation.md)** - Input validation, security, type safety

### Backend/CLI Standards
- **[api.md](./backend/api.md)** - CLI command patterns, service layer design, API principles
- **[models.md](./backend/models.md)** - Data modeling, immutability, JSON serialization
- **[providers.md](./backend/providers.md)** - Riverpod patterns for dependency injection and state management
- **[async-operations.md](./backend/async-operations.md)** - Future, Stream, and Isolate patterns

### Testing Standards
- **[test-writing.md](./testing/test-writing.md)** - Unit tests, integration tests, CLI testing, package:test and package:checks

## Quick Start Checklist

### Setting Up a New Dart CLI/Backend Project

1. **Initialize Dart Project:**
   ```bash
   dart create -t console-full my_app
   cd my_app
   ```

2. **Configure pubspec.yaml:**
   ```yaml
   name: my_app
   description: A Dart CLI application
   version: 1.0.0

   environment:
     sdk: ^3.3.1

   dependencies:
     riverpod: ^2.5.1
     riverpod_annotation: ^2.3.5
     dotenv: ^4.2.0
     args: ^2.4.0
     path: ^1.9.0

   dev_dependencies:
     build_runner: ^2.4.9
     riverpod_generator: ^2.4.0
     test: ^1.24.0
     lints: ^3.0.0
   ```

3. **Create Project Structure:**
   ```
   my_app/
   ├── bin/
   │   └── my_app.dart          # Entry point
   ├── lib/
   │   ├── commands/            # CLI commands
   │   ├── models/              # Data models
   │   ├── providers/           # Riverpod providers
   │   ├── services/            # Business logic
   │   └── utils/               # Utility functions
   ├── test/
   │   ├── commands_test.dart
   │   ├── models_test.dart
   │   └── services_test.dart
   ├── .env.example             # Environment template
   ├── analysis_options.yaml    # Linter config
   └── pubspec.yaml
   ```

4. **Configure Analysis Options (analysis_options.yaml):**
   ```yaml
   include: package:lints/recommended.yaml

   linter:
     rules:
       prefer_single_quotes: true
       always_use_package_imports: true
       avoid_print: true

   analyzer:
     strong-mode:
       implicit-casts: false
       implicit-dynamic: false
   ```

5. **Create Environment File (.env):**
   ```env
   # API Keys
   API_KEY=your_api_key_here

   # Configuration
   DEBUG=true
   LOG_LEVEL=info
   ```

6. **Set Up Main Entry Point (bin/my_app.dart):**
   ```dart
   import 'package:riverpod/riverpod.dart';
   import 'package:my_app/commands/my_command.dart';

   void main(List<String> arguments) {
     final container = ProviderContainer();

     try {
       // Initialize and run your application
       runApp(container, arguments);
     } finally {
       container.dispose();
     }
   }
   ```

## Core Principles

### 1. Type Safety
- **Use null safety**: Leverage Dart 3.0+ sound null safety
- **Avoid dynamic**: Use explicit types or generics
- **Pattern matching**: Use modern Dart pattern matching for type-safe code
- **Sealed classes**: For exhaustive type checking

### 2. Error Handling
- **Custom exceptions**: Create typed exception hierarchies
- **Result types**: Consider Result<T, E> for operations that can fail
- **Logging**: Use `dart:developer.log()` for structured logging
- **Recovery**: Implement retry logic and circuit breakers where appropriate

### 3. Async Best Practices
- **async/await**: Use for I/O-bound operations
- **Isolates**: Use `Isolate.run()` for CPU-intensive work
- **Streams**: Use for sequences of async events
- **Error propagation**: Handle errors in async contexts properly

### 4. State Management
- **Riverpod**: Use for dependency injection and state
- **Immutability**: Prefer immutable data structures
- **Code generation**: Use riverpod_annotation for type-safe providers
- **Testing**: Override providers for testing

### 5. Testing
- **Test pyramid**: 70% unit, 20% integration, 10% E2E
- **package:test**: Standard testing framework
- **package:checks**: Modern assertion library
- **Coverage**: Aim for 80%+ overall, 95%+ for critical paths

## Common Patterns

### CLI Command Pattern

```dart
import 'package:args/args.dart';
import 'package:riverpod/riverpod.dart';

class MyCommand {
  final Ref ref;

  MyCommand(this.ref);

  Future<void> execute(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('verbose', abbr: 'v', help: 'Verbose output')
      ..addOption('output', abbr: 'o', help: 'Output file');

    final results = parser.parse(arguments);

    // Get dependencies from Riverpod
    final service = ref.read(myServiceProvider);

    // Execute command logic
    await service.performOperation();
  }
}
```

### Service Layer Pattern

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_service.g.dart';

@riverpod
class MyService extends _$MyService {
  @override
  Future<void> build() async {
    // Initialize service
  }

  Future<Result<Data, AppError>> fetchData(String id) async {
    try {
      final data = await _apiClient.getData(id);
      return Result.success(data);
    } on NetworkException catch (e) {
      return Result.failure(AppError.network(e.message));
    } catch (e, st) {
      _logger.severe('Unexpected error', e, st);
      return Result.failure(AppError.unknown());
    }
  }
}
```

### Data Model Pattern

```dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
    );
  }
}
```

### Riverpod Provider Pattern

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dotenv/dotenv.dart';

part 'env_provider.g.dart';

@riverpod
DotEnv env(EnvRef ref) {
  return DotEnv(includePlatformEnvironment: true)..load();
}

@riverpod
class DataRepository extends _$DataRepository {
  @override
  Future<List<Item>> build() async {
    return _loadInitialData();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _loadInitialData();
    });
  }
}
```

## Development Workflow

### 1. Development
```bash
# Run in JIT mode for fast iteration
dart run bin/my_app.dart

# Watch for changes
dart run --observe bin/my_app.dart
```

### 2. Code Generation
```bash
# Generate code (providers, JSON serialization)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch
```

### 3. Testing
```bash
# Run all tests
dart test

# Run with coverage
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json --report-on=lib
```

### 4. Analysis
```bash
# Run static analysis
dart analyze

# Format code
dart format .

# Fix common issues
dart fix --apply
```

### 5. Production Build
```bash
# Compile to native executable
dart compile exe bin/my_app.dart -o build/my_app

# Create optimized build
dart compile exe --target-os=linux bin/my_app.dart -o build/my_app-linux
```

## Key Packages

### Essential
- **riverpod** - State management and dependency injection
- **dotenv** - Environment configuration
- **args** - CLI argument parsing
- **path** - Cross-platform path manipulation

### Data
- **hive_ce** - Fast NoSQL database
- **sqlite3** / **drift** - SQL database
- **json_annotation** - JSON serialization

### Async
- **cron** - Scheduled tasks
- **stream_transform** - Stream utilities

### HTTP
- **http** - HTTP client
- **shelf** - HTTP server
- **dio** - Advanced HTTP client

### Utilities
- **uuid** - UUID generation
- **characters** - Unicode string handling
- **intl** - Internationalization

### Testing
- **test** - Testing framework
- **checks** - Modern assertions
- **mocktail** - Mocking library

### Code Quality
- **lints** - Official linter rules
- **custom_lint** - Custom lint rules
- **build_runner** - Code generation

## References

- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [pub.dev](https://pub.dev)
- [Riverpod Documentation](https://riverpod.dev)
- [Dart CLI Documentation](https://dart.dev/tutorials/server/cmdline)
- [Dart Server Documentation](https://dart.dev/tutorials/server/httpserver)

## Contributing

When adding new standards:
1. Follow the existing file structure
2. Include comprehensive code examples
3. Explain the "why" behind each practice
4. Provide GOOD vs BAD examples
5. Add relevant cross-references
6. Include testing examples

## Version

Standards Version: 1.0
Last Updated: 2025-12-01
For: Dart 3.3.1+
