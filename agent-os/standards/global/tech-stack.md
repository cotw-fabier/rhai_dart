# Dart Technology Stack

## Overview

This document defines the complete technology stack for building command-line applications, backend services, and server-side applications using pure Dart (no Flutter).

## Core Technologies

### Language

#### Dart 3.0+
- **Version**: 3.3.1 or later
- **Features**:
  - Sound null safety
  - Pattern matching
  - Records
  - Sealed classes
  - Extension types
- **Why**: Modern, type-safe, high-performance language with excellent async support

### Runtime

#### Dart VM
- **Purpose**: Primary runtime for CLI applications and servers
- **Features**:
  - JIT compilation for development
  - AOT compilation for production
  - Excellent async/await support
  - Built-in isolate support for concurrency

## Dependency Management

### Package Manager

#### pub / dart pub
- **Purpose**: Official Dart package manager
- **Commands**:
  - `dart pub add <package>` - Add dependencies
  - `dart pub get` - Fetch dependencies
  - `dart pub upgrade` - Update dependencies
  - `dart pub outdated` - Check for updates

### Package Repository

#### pub.dev
- **Purpose**: Official Dart package repository
- **Usage**: Source for all third-party packages

## State Management

### Riverpod
- **Version**: 2.5.1+
- **Purpose**: Dependency injection and state management
- **Why**: Works in any Dart environment, not just Flutter
- **Packages**:
  - `riverpod` - Core package
  - `riverpod_annotation` - Code generation annotations

**Example:**
```dart
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'my_provider.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
}

// Usage
void main() {
  final container = ProviderContainer();
  final counter = container.read(counterProvider.notifier);
  counter.increment();
}
```

## Code Generation

### build_runner
- **Version**: 2.4.9+
- **Purpose**: Code generation for providers, JSON serialization
- **Command**: `dart run build_runner build --delete-conflicting-outputs`

### Common Generators
- `riverpod_generator` - Generate Riverpod providers
- `json_serializable` - JSON serialization/deserialization
- `hive_generator` - Generate Hive adapters (if using Hive)

## Data Persistence

### Local Storage

#### Hive
- **Version**: 2.9.0+ (hive_ce fork)
- **Purpose**: Lightweight, fast NoSQL database
- **Use Cases**:
  - Caching
  - Local configuration
  - Simple data persistence
  - Queue management

**Example:**
```dart
import 'package:hive_ce/hive.dart';

// Initialize
await Hive.init(appDirectory.path);

// Register adapters
Hive.registerAdapter(MyModelAdapter());

// Open box
final box = await Hive.openBox<MyModel>('my_box');

// Use
box.add(MyModel());
final items = box.values.toList();
```

#### SQLite
- **Packages**: `sqlite3`, `drift` (formerly moor)
- **Purpose**: Relational database for complex queries
- **Use Cases**:
  - Complex data relationships
  - Full-text search
  - Transaction support

### Remote Storage

#### HTTP Clients
- **package:http** - Simple HTTP requests
- **dio** - Advanced HTTP client with interceptors
- **shelf** - HTTP server framework

## Logging

### dart:developer
- **Purpose**: Structured logging with DevTools integration
- **Features**:
  - Named loggers
  - Log levels
  - Stack traces
  - DevTools timeline integration

**Example:**
```dart
import 'dart:developer' as developer;

developer.log(
  'User logged in successfully',
  name: 'myapp.auth',
  level: 800, // INFO
);

developer.log(
  'Failed to fetch data',
  name: 'myapp.network',
  level: 1000, // SEVERE
  error: exception,
  stackTrace: stackTrace,
);
```

### Alternative: logging package
- **Package**: `logging`
- **Purpose**: Hierarchical logging system
- **Use Cases**: When you need more control over log formatting

## Asynchronous Programming

### Built-in Support
- **Future** - Single async operation
- **Stream** - Sequence of async events
- **async/await** - Async syntax
- **Isolates** - True parallelism

**Example:**
```dart
// Future for single operations
Future<User> fetchUser(String id) async {
  final response = await http.get(Uri.parse('https://api.example.com/users/$id'));
  return User.fromJson(jsonDecode(response.body));
}

// Stream for sequences
Stream<Message> watchMessages() async* {
  while (true) {
    await Future.delayed(Duration(seconds: 5));
    yield await fetchLatestMessage();
  }
}

// Isolates for CPU-intensive work
Future<List<Item>> processLargeDataset(List<RawData> data) async {
  return await Isolate.run(() => _processData(data));
}
```

## Scheduling

### cron
- **Version**: 0.6.0+
- **Purpose**: Schedule recurring tasks
- **Use Cases**:
  - Periodic cleanup
  - Scheduled jobs
  - Background tasks

**Example:**
```dart
import 'package:cron/cron.dart';

final cron = Cron();

// Run at midnight every day
cron.schedule(Schedule.parse('0 0 * * *'), () async {
  await performDailyCleanup();
});
```

## Command-Line Interface

### Built-in: dart:io
- **stdin/stdout/stderr** - Standard I/O
- **Platform** - Platform detection
- **Directory/File** - File system operations

### args package
- **Purpose**: Command-line argument parsing
- **Features**:
  - Flags and options
  - Subcommands
  - Help generation

**Example:**
```dart
import 'package:args/args.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose logging')
    ..addOption('output', abbr: 'o', help: 'Output file path');

  final results = parser.parse(arguments);

  if (results['verbose']) {
    print('Verbose mode enabled');
  }
}
```

## Environment Configuration

### dotenv
- **Version**: 4.2.0+
- **Purpose**: Load environment variables from .env files
- **Use Cases**:
  - API keys
  - Configuration
  - Secrets management

**Example:**
```dart
import 'package:dotenv/dotenv.dart';

final env = DotEnv(includePlatformEnvironment: true)..load();

final apiKey = env['API_KEY'] ?? '';
final debug = env['DEBUG'] == 'true';
```

## Testing

### Built-in: package:test
- **Purpose**: Unit testing framework
- **Features**:
  - Test organization (group/test)
  - Matchers
  - Setup/teardown
  - Async test support

### package:checks
- **Purpose**: Modern assertion library
- **Features**:
  - Type-safe assertions
  - Better error messages
  - Fluent API

**Example:**
```dart
import 'package:test/test.dart';
import 'package:checks/checks.dart';

void main() {
  group('Calculator', () {
    test('adds two numbers', () {
      check(add(2, 3)).equals(5);
    });

    test('handles null safely', () async {
      final result = await fetchUser('unknown');
      check(result).isNull();
    });
  });
}
```

## Serialization

### JSON

#### json_serializable
- **Version**: Latest
- **Purpose**: Code-generated JSON serialization
- **Annotations**: `@JsonSerializable`

**Example:**
```dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class User {
  final String firstName;
  final String lastName;
  final int age;

  User({required this.firstName, required this.lastName, required this.age});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

## Utilities

### Common Packages

#### path
- **Purpose**: Cross-platform path manipulation
- **Why**: Handles Windows/Unix path differences

**Example:**
```dart
import 'package:path/path.dart' as path;

final configPath = path.join(appDir, 'config', 'settings.json');
final fileName = path.basename(filePath);
```

#### uuid
- **Purpose**: Generate UUIDs
- **Use Cases**: Unique identifiers for entities

**Example:**
```dart
import 'package:uuid/uuid.dart';

const uuid = Uuid();
final id = uuid.v4(); // Random UUID
```

#### characters
- **Purpose**: Unicode-aware string manipulation
- **Why**: Handles grapheme clusters correctly

**Example:**
```dart
import 'package:characters/characters.dart';

final text = 'Hello 👋';
final length = text.characters.length; // Correct count
final truncated = text.characters.take(10).toString();
```

## Code Quality

### Linting

#### package:lints
- **Version**: 3.0.0+
- **Purpose**: Official Dart linter rules
- **Presets**:
  - `package:lints/core.yaml` - Essential rules
  - `package:lints/recommended.yaml` - Recommended rules

**analysis_options.yaml:**
```yaml
include: package:lints/recommended.yaml

linter:
  rules:
    # Additional rules
    prefer_single_quotes: true
    always_use_package_imports: true
    avoid_print: true

analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false
```

### Custom Linting

#### custom_lint
- **Version**: 0.7.1+
- **Purpose**: Create custom lint rules
- **Use Cases**: Project-specific conventions

## HTTP/Network

### HTTP Client

#### http package
- **Purpose**: Basic HTTP requests
- **Use Cases**: Simple REST API calls

**Example:**
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<User> fetchUser(String id) async {
  final response = await http.get(
    Uri.parse('https://api.example.com/users/$id'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    return User.fromJson(jsonDecode(response.body));
  } else {
    throw Exception('Failed to load user');
  }
}
```

### HTTP Server

#### shelf
- **Purpose**: Composable web server
- **Features**:
  - Middleware
  - Routing
  - Static file serving

**Example:**
```dart
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

void main() async {
  final handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(_handleRequest);

  await io.serve(handler, 'localhost', 8080);
}

shelf.Response _handleRequest(shelf.Request request) {
  return shelf.Response.ok('Hello, World!');
}
```

## Development Tools

### Formatting

#### dart format
- **Purpose**: Official Dart formatter
- **Command**: `dart format .`
- **Configuration**: Line length in analysis_options.yaml

### Analysis

#### dart analyze
- **Purpose**: Static analysis
- **Command**: `dart analyze`
- **Integration**: CI/CD pipelines

### Compilation

#### dart compile
- **Targets**:
  - `exe` - Standalone executable (AOT)
  - `aot-snapshot` - AOT snapshot
  - `jit-snapshot` - JIT snapshot
  - `kernel` - Kernel snapshot

**Example:**
```bash
# Create standalone executable
dart compile exe bin/myapp.dart -o build/myapp

# Create optimized executable
dart compile exe --target-os=linux bin/myapp.dart -o build/myapp-linux
```

## Architecture Layers

### Typical Dart CLI/Backend Architecture

```
├── bin/              # Entry points (executables)
├── lib/              # Application code
│   ├── commands/     # CLI commands
│   ├── models/       # Data models
│   ├── providers/    # Riverpod providers
│   ├── services/     # Business logic
│   └── utils/        # Utility functions
├── test/             # Tests
└── pubspec.yaml      # Dependencies
```

## Anti-Patterns to Avoid

### Don't Use These in Pure Dart Projects
- `flutter_*` packages (Flutter-specific)
- `widget` or `build` methods (Flutter concepts)
- `BuildContext` (Flutter-specific)
- `StatefulWidget` / `StatelessWidget` (Flutter-specific)

### Use These Instead
- `riverpod` for state management
- `shelf` for web servers
- `dart:io` for file system
- `package:args` for CLI arguments
- `package:test` for testing

## Performance Considerations

### Compilation Strategies
- **Development**: Use JIT for fast iteration
- **Production**: Use AOT for best performance

### Async Best Practices
- Use `async`/`await` for I/O operations
- Use `Isolate.run()` for CPU-intensive work
- Batch database operations
- Use `StreamController` for event streams

### Memory Management
- Close streams when done
- Dispose resources in `finally` blocks
- Use weak references when appropriate
- Profile with DevTools

## Version Compatibility

### Minimum Versions
- **Dart SDK**: 3.3.1+
- **riverpod**: 2.5.1+
- **build_runner**: 2.4.9+
- **lints**: 3.0.0+

### Platform Support
- Linux
- macOS
- Windows
- Docker containers

## References

- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [pub.dev](https://pub.dev)
- [Riverpod Documentation](https://riverpod.dev)
