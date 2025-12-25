# Project Conventions for Pure Dart Development

## Overview

This document establishes comprehensive conventions for pure Dart development, covering project structure, file organization, naming patterns, and version control practices. These conventions are based on Effective Dart guidelines and industry best practices for building maintainable Dart CLI applications, libraries, and packages.

## Table of Contents

- [Project Structure](#project-structure)
- [File Naming Conventions](#file-naming-conventions)
- [Directory Organization](#directory-organization)
- [Import Organization](#import-organization)
- [Part Files vs Libraries](#part-files-vs-libraries)
- [Version Control Practices](#version-control-practices)
- [Package Management](#package-management)
- [Build and Release](#build-and-release)

---

## Project Structure

### Standard Dart Package Structure

Every Dart project should follow the canonical package layout:

```
my_package/
├── .dart_tool/               # Build outputs (git ignored)
├── .github/                  # GitHub workflows and templates
│   └── workflows/
│       ├── ci.yml
│       └── release.yml
├── bin/                      # Executable entry points (CLI apps)
│   └── my_package.dart
├── lib/                      # Public library code
│   ├── src/                  # Private implementation
│   │   ├── commands/         # CLI commands (if CLI app)
│   │   ├── models/           # Data models
│   │   ├── services/         # Business logic
│   │   ├── utils/            # Utility functions
│   │   └── exceptions/       # Custom exceptions
│   └── my_package.dart       # Main library export
├── test/                     # Unit and integration tests
│   ├── commands/
│   ├── models/
│   ├── services/
│   └── utils/
├── example/                  # Example usage (for packages)
│   └── example.dart
├── tool/                     # Development tools and scripts
│   └── generate_docs.dart
├── doc/                      # Additional documentation
│   └── architecture.md
├── .gitignore
├── analysis_options.yaml     # Linter configuration
├── CHANGELOG.md
├── LICENSE
├── pubspec.yaml              # Package configuration
└── README.md
```

### CLI Application Structure

For command-line applications, organize around commands:

```
my_cli/
├── bin/
│   └── my_cli.dart           # Entry point
├── lib/
│   ├── src/
│   │   ├── commands/         # Command implementations
│   │   │   ├── base_command.dart
│   │   │   ├── init_command.dart
│   │   │   ├── build_command.dart
│   │   │   └── deploy_command.dart
│   │   ├── config/           # Configuration handling
│   │   │   ├── config.dart
│   │   │   └── config_loader.dart
│   │   ├── core/             # Core functionality
│   │   │   ├── logger.dart
│   │   │   └── runner.dart
│   │   ├── models/           # Data models
│   │   │   └── project.dart
│   │   └── utils/            # Utility functions
│   │       ├── file_utils.dart
│   │       └── string_utils.dart
│   └── my_cli.dart           # Public API (if library)
└── test/
    ├── commands/
    ├── config/
    └── utils/
```

### Library Package Structure

For reusable libraries, focus on clean public API:

```
my_library/
├── lib/
│   ├── src/                  # Private implementation
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   └── session.dart
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   └── api_service.dart
│   │   └── utils/
│   │       └── validators.dart
│   └── my_library.dart       # Public exports only
├── example/
│   ├── basic_usage.dart
│   └── advanced_usage.dart
└── test/
    ├── models/
    ├── services/
    └── integration/
```

### Good vs Bad Structure Examples

**GOOD - Clear Separation:**

```
lib/
├── src/
│   ├── commands/
│   │   ├── create_command.dart
│   │   └── delete_command.dart
│   ├── models/
│   │   ├── user.dart
│   │   └── project.dart
│   └── services/
│       ├── user_service.dart
│       └── project_service.dart
└── my_app.dart
```

**BAD - Mixed Concerns:**

```
lib/
├── user.dart                 # Model mixed with root
├── user_service.dart         # Service mixed with root
├── commands.dart             # All commands in one file
└── my_app.dart
```

**GOOD - Feature-Based Organization (for larger apps):**

```
lib/
├── src/
│   ├── auth/                 # Feature: Authentication
│   │   ├── models/
│   │   │   └── credentials.dart
│   │   ├── services/
│   │   │   └── auth_service.dart
│   │   └── commands/
│   │       └── login_command.dart
│   ├── projects/             # Feature: Projects
│   │   ├── models/
│   │   │   └── project.dart
│   │   ├── services/
│   │   │   └── project_service.dart
│   │   └── commands/
│   │       ├── create_project_command.dart
│   │       └── list_projects_command.dart
│   └── shared/               # Shared utilities
│       ├── config.dart
│       └── logger.dart
└── my_app.dart
```

---

## File Naming Conventions

### Core Naming Rules

Dart uses **snake_case** for file names, following these rules:

1. **All lowercase**: Use only lowercase letters
2. **Underscores for spaces**: Separate words with underscores
3. **Descriptive names**: Name files after their primary class or purpose
4. **Avoid abbreviations**: Use full words for clarity

### File Naming Patterns

**GOOD Examples:**

```
user.dart                     # Simple model
user_service.dart             # Service class
authentication_manager.dart   # Multi-word name
json_serializer.dart          # Acronym in lowercase
http_client.dart              # Acronym in lowercase
create_project_command.dart   # Command pattern
```

**BAD Examples:**

```
User.dart                     # Never use PascalCase for files
userService.dart              # Never use camelCase for files
AuthMgr.dart                  # Avoid abbreviations
HTTPClient.dart               # Acronyms should be lowercase
user_serv.dart                # No abbreviated words
```

### Special File Types

**Test Files:**
```
user_test.dart                # Unit test for user.dart
user_service_test.dart        # Unit test for user_service.dart
integration_test.dart         # Integration tests
```

**Generated Files:**
```
user.g.dart                   # Generated code (json_serializable)
user.freezed.dart             # Generated code (freezed)
```

**Part Files:**
```
user.dart                     # Main file
user_extensions.dart          # Extension methods (as part)
```

### Directory Naming

Directories also use **snake_case**:

```
GOOD:
lib/src/commands/
lib/src/user_management/
lib/src/data_models/

BAD:
lib/src/Commands/             # Never PascalCase
lib/src/userManagement/       # Never camelCase
lib/src/dataMod/              # No abbreviations
```

---

## Import Organization

### Import Order

Organize imports in the following order, with blank lines between sections:

1. **Dart SDK imports** (`dart:` libraries)
2. **Package imports** (`package:` from external packages)
3. **Relative imports** (within your package)
4. **Part directives**

**Example:**

```dart
// 1. Dart SDK imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';

// 2. Package imports
import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// 3. Relative imports (your package)
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

// 4. Part directives
part 'user_extensions.dart';
```

### Linter Configuration

Use the `directives_ordering` linter rule to automatically enforce import order:

```yaml
# analysis_options.yaml
linter:
  rules:
    - directives_ordering
```

### Import Aliases

Use import aliases to avoid naming conflicts and improve readability:

```dart
// GOOD - Clear aliases
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:test/test.dart' as test;

// Using the alias
final response = await http.get(Uri.parse(url));
final filePath = path.join('data', 'config.json');
```

### Avoiding Relative Import Hell

**GOOD - Use package imports even within your own package:**

```dart
// In lib/src/commands/create_command.dart
import 'package:my_app/src/models/project.dart';
import 'package:my_app/src/services/project_service.dart';
```

**BAD - Complex relative paths:**

```dart
// In lib/src/commands/create_command.dart
import '../../models/project.dart';           // Hard to maintain
import '../../services/project_service.dart'; // Brittle
```

### Show and Hide

Use `show` and `hide` to be explicit about what you're importing:

```dart
// GOOD - Explicit imports
import 'package:my_app/src/utils/helpers.dart' show formatDate, parseDate;
import 'package:test/test.dart' hide test;

// GOOD - When importing everything is clear
import 'package:args/args.dart';
```

---

## Part Files vs Libraries

### When to Use Libraries (Preferred)

**Default to libraries.** Each Dart file should be its own library by default.

**Example:**

```dart
// lib/src/models/user.dart
class User {
  final String id;
  final String name;

  User({required this.id, required this.name});
}
```

```dart
// lib/src/services/user_service.dart
import 'package:my_app/src/models/user.dart';

class UserService {
  User getUser(String id) {
    // Implementation
  }
}
```

### When to Use Part Files

Use `part` files **only** in these specific scenarios:

1. **Generated code** (json_serializable, freezed, etc.)
2. **Large classes split for readability** (rare, consider refactoring instead)
3. **Extensions tightly coupled to a class** (consider separate library instead)

**Example with Generated Code:**

```dart
// lib/src/models/user.dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String id;
  final String name;

  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

```dart
// lib/src/models/user.g.dart (generated)
part of 'user.dart';

User _$UserFromJson(Map<String, dynamic> json) {
  return User(
    id: json['id'] as String,
    name: json['name'] as String,
  );
}

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
    };
```

### Part Files - Good vs Bad

**GOOD - Part for generated code:**

```dart
// user.dart
import 'package:json_annotation/json_annotation.dart';
part 'user.g.dart';

@JsonSerializable()
class User {
  // ...
}
```

**BAD - Part for organizational purposes:**

```dart
// user.dart
part 'user_methods.dart';
part 'user_properties.dart';

class User {
  // This should just be one library
}
```

**BETTER - Separate libraries:**

```dart
// lib/src/models/user.dart
class User {
  // Core user model
}

// lib/src/models/user_extensions.dart
import 'package:my_app/src/models/user.dart';

extension UserHelpers on User {
  String get fullInfo => '$id: $name';
}
```

---

## Version Control Practices

### Git Configuration

#### .gitignore

Standard `.gitignore` for Dart projects:

```gitignore
# Dart files
.dart_tool/
.packages
build/
pubspec.lock              # For libraries (keep for applications)

# Generated files
*.g.dart                  # Only if you regenerate often
*.freezed.dart
*.iconfig.dart

# IDE files
.idea/
.vscode/
*.iml
*.ipr
*.iws

# OS files
.DS_Store
Thumbs.db

# Coverage
coverage/
.test_coverage.dart

# Environment files
.env
.env.local
*.env

# Build outputs
*.js
*.js.map
*.info.json
```

### Commit Message Conventions

Use **Conventional Commits** format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements

**Examples:**

```
feat(commands): add create project command

Implemented the create command that scaffolds new projects
with the standard directory structure.

Closes #123
```

```
fix(user-service): handle null email addresses

Added null check for email field to prevent NullPointerException
when loading users from legacy database.
```

```
refactor(models): extract validation logic to separate class

Moved validation logic from User model to UserValidator
to improve testability and separation of concerns.
```

### Branch Naming

Use descriptive branch names with prefixes:

```
feature/add-user-authentication
fix/null-pointer-in-user-service
refactor/extract-validation-logic
docs/update-api-documentation
chore/update-dependencies
```

### Commit Frequency

**DO:**
- Commit logical units of work
- Commit working, tested code
- Commit with clear, descriptive messages
- Commit before and after refactoring

**DON'T:**
- Commit broken code
- Commit commented-out code
- Make massive commits with unrelated changes
- Use generic messages like "fix stuff" or "WIP"

### Pull Request Guidelines

**Good PR Description:**

```markdown
## Description
Adds user authentication with email/password

## Changes
- Added `AuthService` with login/logout methods
- Created `Credentials` model
- Implemented token storage in secure storage
- Added unit tests for auth service

## Testing
- All existing tests pass
- Added 15 new tests for auth service
- Manually tested login flow

## Breaking Changes
None

Closes #45
```

---

## Package Management

### pubspec.yaml Structure

Organize your `pubspec.yaml` clearly:

```yaml
name: my_package
description: A comprehensive description of what this package does.
version: 1.0.0
repository: https://github.com/username/my_package

environment:
  sdk: ^3.5.0

dependencies:
  # Core dependencies
  args: ^2.4.0
  http: ^1.2.0

  # JSON serialization
  json_annotation: ^4.8.0

  # Utilities
  path: ^1.8.0

dev_dependencies:
  # Testing
  test: ^1.25.0
  mockito: ^5.4.0

  # Code generation
  build_runner: ^2.4.0
  json_serializable: ^6.7.0

  # Linting
  lints: ^3.0.0
```

### Dependency Guidelines

**Version Pinning:**

For **applications** (CLI tools, scripts):
```yaml
dependencies:
  args: 2.4.2              # Exact version for reproducibility
  http: 1.2.0
```

For **libraries** (packages):
```yaml
dependencies:
  args: ^2.4.0             # Caret constraints for compatibility
  http: ^1.2.0
```

**Dependency Selection:**

1. **Prefer maintained packages**: Check last update date
2. **Check pub.dev scores**: Look for high scores (>100)
3. **Review dependencies**: Avoid packages with many transitive dependencies
4. **Read the code**: For critical functionality, review the source
5. **Check nullsafety**: Ensure all dependencies support null safety

**Documenting Dependencies:**

Add comments explaining why each major dependency exists:

```yaml
dependencies:
  # CLI argument parsing - industry standard
  args: ^2.4.0

  # HTTP client with better error handling than dart:io HttpClient
  http: ^1.2.0

  # Path manipulation that works across platforms
  path: ^1.8.0
```

### Updating Dependencies

**Regular Updates:**

```bash
# Check for outdated packages
dart pub outdated

# Update all dependencies within constraints
dart pub upgrade

# Update and show resolution changes
dart pub upgrade --verbose
```

**Testing After Updates:**

Always run tests after updating dependencies:

```bash
dart pub upgrade && dart test
```

---

## Build and Release

### Version Numbers

Follow **Semantic Versioning** (SemVer):

```
MAJOR.MINOR.PATCH

1.0.0 → 1.0.1  (patch: bug fixes)
1.0.1 → 1.1.0  (minor: new features, backward compatible)
1.1.0 → 2.0.0  (major: breaking changes)
```

### CHANGELOG.md

Maintain a comprehensive changelog:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- User authentication with JWT tokens

### Changed
- Improved error messages for CLI commands

## [1.1.0] - 2024-12-01

### Added
- New `create` command for project scaffolding
- Support for custom templates
- Interactive mode for command selection

### Fixed
- Null pointer exception in user service (#45)
- File permission errors on Windows (#47)

### Changed
- Updated `args` package to 2.4.0
- Improved test coverage to 95%

## [1.0.0] - 2024-11-15

### Added
- Initial release
- Basic CLI commands: init, build, deploy
- Configuration file support
- Comprehensive documentation
```

### Pre-Release Checklist

Before releasing a new version:

- [ ] All tests pass
- [ ] Code formatted with `dart format`
- [ ] No linter warnings
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped in pubspec.yaml
- [ ] Examples tested and working
- [ ] Breaking changes documented

### Publishing to pub.dev

```bash
# Validate package before publishing
dart pub publish --dry-run

# Publish (follow prompts)
dart pub publish
```

---

## Project Templates

### Minimal CLI Application Template

```
my_cli/
├── bin/
│   └── my_cli.dart
├── lib/
│   ├── src/
│   │   ├── commands/
│   │   │   └── base_command.dart
│   │   └── runner.dart
│   └── my_cli.dart
├── test/
│   └── commands/
│       └── base_command_test.dart
├── .gitignore
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
├── pubspec.yaml
└── README.md
```

### Library Package Template

```
my_library/
├── lib/
│   ├── src/
│   │   ├── models/
│   │   ├── services/
│   │   └── utils/
│   └── my_library.dart
├── test/
│   ├── models/
│   ├── services/
│   └── utils/
├── example/
│   └── example.dart
├── doc/
│   └── api.md
├── .gitignore
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
├── pubspec.yaml
└── README.md
```

---

## Environment Configuration

### Configuration Files

Use structured configuration files:

**config.yaml:**
```yaml
app:
  name: "My Application"
  version: "1.0.0"

server:
  host: "localhost"
  port: 8080

logging:
  level: "info"
  file: "logs/app.log"
```

**Loading Configuration:**

```dart
// lib/src/config/config.dart
import 'dart:io';
import 'package:yaml/yaml.dart';

class Config {
  final String appName;
  final String appVersion;
  final String serverHost;
  final int serverPort;

  Config({
    required this.appName,
    required this.appVersion,
    required this.serverHost,
    required this.serverPort,
  });

  factory Config.fromYaml(String yamlString) {
    final yaml = loadYaml(yamlString) as Map;

    return Config(
      appName: yaml['app']['name'] as String,
      appVersion: yaml['app']['version'] as String,
      serverHost: yaml['server']['host'] as String,
      serverPort: yaml['server']['port'] as int,
    );
  }

  static Future<Config> load(String path) async {
    final file = File(path);
    final contents = await file.readAsString();
    return Config.fromYaml(contents);
  }
}
```

### Environment Variables

Use environment variables for secrets and deployment-specific config:

```dart
// lib/src/config/environment.dart
import 'dart:io';

class Environment {
  static String get apiKey => _requireEnv('API_KEY');
  static String get dbUrl => _requireEnv('DATABASE_URL');

  static String get environment =>
      Platform.environment['ENVIRONMENT'] ?? 'development';

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  static String _requireEnv(String name) {
    final value = Platform.environment[name];
    if (value == null || value.isEmpty) {
      throw StateError('Required environment variable $name is not set');
    }
    return value;
  }
}
```

**Usage:**

```bash
# Set environment variables
export API_KEY="your-secret-key"
export DATABASE_URL="postgresql://localhost/mydb"
export ENVIRONMENT="production"

# Run the application
dart run bin/my_app.dart
```

---

## Summary

Following these conventions ensures:

1. **Consistency**: Projects follow predictable patterns
2. **Maintainability**: Code is easy to understand and modify
3. **Collaboration**: Team members know where to find things
4. **Quality**: Standards promote best practices
5. **Scalability**: Structure supports project growth

### Key Takeaways

- Use **snake_case** for all file and directory names
- Organize code by **feature or layer**, not file type alone
- Keep **lib/src/** for private implementation
- Use **package imports** even within your own package
- Follow **Conventional Commits** for version control
- Maintain **CHANGELOG.md** for all releases
- Use **Semantic Versioning** for packages
- Prefer **libraries over part files** unless using generated code

### References

- [Effective Dart: Style](https://dart.dev/effective-dart/style)
- [Dart Package Layout Conventions](https://dart.dev/tools/pub/package-layout)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
