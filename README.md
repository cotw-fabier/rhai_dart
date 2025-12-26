# rhai_dart

A cross-platform FFI library that enables Dart applications to execute Rhai scripts with bidirectional function calling, comprehensive type conversion, and robust error handling.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey.svg)](https://github.com/yourusername/rhai_dart)

## Overview

rhai_dart is a powerful FFI (Foreign Function Interface) bridge between Dart and the [Rhai scripting language](https://rhai.rs/). It enables you to:

- Execute Rhai scripts from Dart applications with automatic type conversion
- Register both synchronous and asynchronous Dart functions that can be called from Rhai scripts
- Safely sandbox untrusted scripts with comprehensive security features
- Build scriptable applications with a clean, type-safe API

## Features

- **Script Execution**: Execute Rhai scripts from Dart with automatic type conversion and result handling
- **Dual-Path Architecture**: Optimized paths for both sync and async function execution
  - `eval()` - Direct synchronous execution (zero overhead for sync functions)
  - `evalAsync()` - Background thread execution (full support for async functions)
- **Full Async Support**: Register and call async Dart functions from Rhai scripts (HTTP requests, file I/O, database queries, etc.)
- **Bidirectional Function Calling**: Register both synchronous and asynchronous Dart functions that can be called from Rhai scripts
- **Comprehensive Type System**: Automatic conversion between Dart and Rhai types including primitives, lists, maps, and deeply nested structures
- **Robust Error Handling**: Detailed error reporting with line numbers, stack traces, and typed exception hierarchy
- **Sandboxing & Security**: Secure execution with configurable timeouts, operation limits, stack depth limits, and string size limits
- **Cross-Platform**: Native support for macOS (ARM64/x64), Linux (x64/ARM64), and Windows (x64)
- **Memory Safe**: Automatic cleanup with NativeFinalizers plus manual dispose() for deterministic resource management
- **Zero-Copy FFI**: Efficient communication using opaque pointers and JSON serialization for complex types

## Quick Start

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  rhai_dart: ^0.1.0

# Enable native assets (required)
native_assets:
  enabled: true
```

Then run:

```bash
dart pub get
```

### Basic Usage

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  // Create a Rhai engine with secure defaults
  final engine = RhaiEngine.withDefaults();

  try {
    // Execute a simple script
    final result = engine.eval('2 + 2');
    print('Result: $result'); // Output: Result: 4

    // Execute a script with variables
    final greeting = engine.eval('''
      let name = "World";
      "Hello, " + name + "!"
    ''');
    print(greeting); // Output: Hello, World!

    // Work with arrays and maps
    final data = engine.eval('''
      let numbers = [1, 2, 3, 4, 5];
      let user = #{name: "Alice", age: 30};
      #{numbers: numbers, user: user}
    ''');
    print(data); // Output: {numbers: [1, 2, 3, 4, 5], user: {name: Alice, age: 30}}
  } catch (e) {
    print('Error: $e');
  } finally {
    // Clean up resources
    engine.dispose();
  }
}
```

### Registering Dart Functions (Synchronous)

Use `eval()` for scripts with synchronous functions for optimal performance:

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  final engine = RhaiEngine.withDefaults();

  // Register synchronous functions
  engine.registerFunction('add', (int a, int b) => a + b);

  engine.registerFunction('getUserData', () {
    return {
      'name': 'Alice',
      'age': 30,
      'roles': ['admin', 'user']
    };
  });

  try {
    // Use eval() for sync functions (zero overhead)
    final result = engine.eval('''
      let sum = add(10, 32);
      let user = getUserData();
      "Sum: " + sum + ", User: " + user.name
    ''');
    print(result); // Output: Sum: 42, User: Alice
  } finally {
    engine.dispose();
  }
}
```

### Registering Async Functions

Use `evalAsync()` for scripts calling async functions:

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() async {
  final engine = RhaiEngine.withDefaults();

  // Register an async function
  engine.registerFunction('fetchData', () async {
    await Future.delayed(Duration(milliseconds: 100));
    return {'status': 'success', 'data': [1, 2, 3]};
  });

  try {
    // Use evalAsync() for scripts with async functions
    final result = await engine.evalAsync('fetchData()');
    print(result); // {status: success, data: [1, 2, 3]}
  } finally {
    engine.dispose();
  }
}
```

## eval() vs evalAsync(): When to Use Each

rhai_dart provides **two execution methods** optimized for different use cases:

### eval() - Synchronous Execution

**Best for:** Scripts that call only synchronous functions

**Characteristics:**
- Direct function invocation on the same thread
- Zero overhead - fastest execution path
- Automatically detects if an async function is called and returns a helpful error

**Example:**
```dart
final engine = RhaiEngine.withDefaults();

// Register sync functions
engine.registerFunction('calculate', (int x) => x * 2);

// Use eval() for sync functions (fastest)
final result = engine.eval('calculate(21)'); // Returns: 42
```

**What happens if you call an async function with eval()?**
```dart
engine.registerFunction('asyncFunc', () async => 'data');

// This will throw a helpful error:
engine.eval('asyncFunc()'); // Error: "Async function detected. Use evalAsync() instead."
```

### evalAsync() - Asynchronous Execution

**Best for:** Scripts that call async functions (HTTP requests, file I/O, database queries, etc.)

**Characteristics:**
- Runs script on a background thread using request/response pattern
- Keeps Dart event loop free for async operations
- Works with both sync AND async functions
- Slight overhead for message passing (worth it for async operations)

**Example:**
```dart
final engine = RhaiEngine.withDefaults();

// Register async function
engine.registerFunction('httpGet', (String url) async {
  final response = await http.get(Uri.parse(url));
  return response.body;
});

// Use evalAsync() for async functions
final result = await engine.evalAsync('httpGet("https://api.example.com")');
```

### Performance Comparison

| Method | Use Case | Performance | Event Loop | Async Support |
|--------|----------|-------------|------------|---------------|
| `eval()` | Sync functions only | Fastest (zero overhead) | Never blocks | No (errors) |
| `evalAsync()` | Async or mixed functions | Slight overhead | Never blocks | Full support |

### Quick Decision Guide

**Use `eval()` when:**
- All your functions are synchronous
- You want maximum performance
- You're doing pure computation

**Use `evalAsync()` when:**
- You need to call async functions (HTTP, file I/O, database, etc.)
- Your functions return `Future<T>`
- You want to integrate with async Dart ecosystem

### Custom Configuration

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  // Create engine with custom security settings
  final config = RhaiConfig.custom(
    maxOperations: 100000,        // Prevent infinite loops
    maxStackDepth: 50,             // Prevent stack overflow
    maxStringLength: 1048576,      // 1 MB max string size
    timeoutMs: 1000,               // 1 second timeout
  );

  final engine = RhaiEngine.withConfig(config);

  try {
    final result = engine.eval('/* your script here */');
    print(result);
  } finally {
    engine.dispose();
  }
}
```

### Error Handling

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  final engine = RhaiEngine.withDefaults();

  try {
    engine.eval('let x = 1 / 0;'); // Division by zero
  } on RhaiRuntimeError catch (e) {
    print('Runtime error: ${e.message}');
    print('Stack trace: ${e.stackTrace}');
  } on RhaiSyntaxError catch (e) {
    print('Syntax error at line ${e.lineNumber}: ${e.message}');
  } on RhaiException catch (e) {
    print('General error: ${e.message}');
  } finally {
    engine.dispose();
  }
}
```

## Platform Support

| Platform | Architecture | Build Target | Status |
|----------|-------------|--------------|--------|
| macOS | ARM64 (Apple Silicon) | aarch64-apple-darwin | Supported |
| macOS | x64 (Intel) | x86_64-apple-darwin | Supported |
| Linux | x64 | x86_64-unknown-linux-gnu | Fully Tested |
| Linux | ARM64 | aarch64-unknown-linux-gnu | Supported |
| Windows | x64 | x86_64-pc-windows-msvc | Supported |

**Testing Status:**
- **Linux x64**: Fully tested with 31 tests passing (function registration, async execution, integration tests)
- **Other Platforms**: Code compiles successfully but requires native hardware for runtime verification

## Prerequisites

- **Dart SDK**: 3.10.1 or later
- **Rust Toolchain**: 1.83.0 (automatically installed via rust-toolchain.toml)
- **Platform Tools**:
  - macOS: Xcode Command Line Tools (`xcode-select --install`)
  - Linux: build-essential (`sudo apt-get install build-essential`)
  - Windows: Visual Studio with "Desktop development with C++" workload

For detailed setup instructions, see the [Setup Guide](docs/setup.md).

## Documentation

### Guides

- **[Setup Guide](docs/setup.md)** - Installation, toolchain setup, and platform-specific instructions
- **[Architecture Documentation](docs/architecture.md)** - FFI boundary design, memory management, and internal architecture
- **[Async Functions Guide](docs/ASYNC_FUNCTIONS.md)** - Complete guide to using eval() vs evalAsync() with async functions
- **[Type Conversion Guide](docs/type_conversion.md)** - Comprehensive type mapping reference and examples
- **[Security Guide](docs/security.md)** - Sandboxing features, security best practices, and production checklist

### API Reference

Generate the API documentation locally:

```bash
dart doc
# Open doc/api/index.html in your browser
```

Online API documentation: Coming soon to pub.dev

### Examples

The [example/](example/) directory contains comprehensive examples:

- **01_simple_execution.dart** - Basic script execution
- **02_sync_functions.dart** - Synchronous function registration with eval()
- **03_async_functions.dart** - Async function registration with evalAsync()
- **04_error_handling.dart** - Comprehensive error handling patterns
- **05_configuration.dart** - Custom engine configuration
- **06_complex_workflow.dart** - Real-world integration examples

Run examples with:

```bash
dart run --enable-experiment=native-assets example/01_simple_execution.dart
```

## Architecture

This library uses Dart's FFI (Foreign Function Interface) to communicate with a Rust library that wraps the Rhai scripting engine.

### Dual-Path Execution Architecture

rhai_dart uses two optimized execution paths:

```
SYNC PATH (eval())                    ASYNC PATH (evalAsync())
==================                    ==========================

Dart isolate (main thread)            Dart isolate (main)    Background thread
        |                                     |                      |
   eval("script")                       evalAsync("script")          |
        |                                     |                      |
Rhai engine.eval()                      Start thread ────────────────>
        |                                     |                Set async mode
Function call                            Poll loop              engine.eval()
        |                                     |                      |
Direct FFI callback ──────────>           Request ←──────[queue]─── Function call
        |                                     |                      |
Execute Dart function                  Execute function         Await response
(sync only)                            (sync OR async!)               |
        |                                     |                      |
Return result                           Return ─────────[channel]──> Resume
        |                                     |                      |
    Complete                               Complete               Complete
```

**Key Differences:**

| Aspect | eval() | evalAsync() |
|--------|--------|-------------|
| Thread | Same thread | Background thread |
| Callback method | Direct FFI | Request/response |
| Async function support | No (errors) | Yes (full) |
| Performance | Fastest | Slight overhead |
| Event loop blocking | Never | Never |
| Recommended for | Sync functions | Async functions |

### Key Architectural Patterns

- **Opaque Handle Pattern**: Rust objects are wrapped in opaque pointers, preventing direct memory access from Dart
- **Native Finalizers**: Automatic memory cleanup when Dart objects are garbage collected
- **Thread-Local Error Storage**: Safe error propagation across the FFI boundary
- **JSON Serialization**: Complex types are converted via JSON for simplicity and safety
- **Panic Catching**: All FFI entry points catch Rust panics to prevent crashes
- **Request/Response Pattern**: Async functions use message passing for thread-safe communication

### Data Flow

```
Dart Application
    ↕ (FFI Boundary)
Rust FFI Layer
    ↕
Rhai Engine
```

For detailed architecture information, see the [Architecture Guide](docs/architecture.md).

## Security

rhai_dart is designed for **safe execution of untrusted scripts** with multiple security layers:

### Security Features

- **Sandboxing**: File I/O, eval(), and module loading disabled by default
- **Operation Limits**: Configurable maximum operations to prevent infinite loops
- **Stack Depth Limits**: Prevents stack overflow from deep recursion
- **String Size Limits**: Prevents excessive memory allocation
- **Timeout Enforcement**: Scripts are terminated if they exceed time limits
- **Memory Safety**: Rust's memory safety plus FFI boundary protection

### Secure Defaults

The `RhaiEngine.withDefaults()` constructor provides secure defaults suitable for untrusted scripts:

- Maximum operations: 1,000,000
- Maximum stack depth: 100 frames
- Maximum string length: 10 MB
- Timeout: 5 seconds
- File I/O: Disabled
- eval(): Disabled
- Modules: Disabled

For production security guidelines, see the [Security Guide](docs/security.md).

## Development

### Building the Project

The project uses native assets for automatic Rust compilation:

```bash
# Get dependencies (builds Rust library automatically)
dart pub get

# Run tests
dart test --enable-experiment=native-assets

# Run specific test files
dart test --enable-experiment=native-assets test/function_registration_test.dart test/eval_async_test.dart test/integration_async_test.dart --concurrency=1

# Run with coverage
dart test --enable-experiment=native-assets --coverage

# Run examples
dart run --enable-experiment=native-assets example/01_simple_execution.dart
```

### Manual Rust Build

To build the Rust library manually:

```bash
cd rust
cargo build --release --target <your-target>
```

Available targets:
- macOS ARM64: `aarch64-apple-darwin`
- macOS x64: `x86_64-apple-darwin`
- Linux x64: `x86_64-unknown-linux-gnu`
- Linux ARM64: `aarch64-unknown-linux-gnu`
- Windows x64: `x86_64-pc-windows-msvc`

### Running Tests

```bash
# Run all tests
dart test --enable-experiment=native-assets

# Run specific test file
dart test --enable-experiment=native-assets test/eval_async_test.dart
```

**Test Results (Linux x64):**
- Total: 31 tests across 3 test files
- Passing: 31 tests (100%)
- Coverage: Sync eval, async eval, function registration, type conversion, error handling, integration workflows

### Code Quality

```bash
# Analyze Dart code
dart analyze

# Format Dart code
dart format .

# Lint Rust code
cd rust
cargo clippy

# Format Rust code
cd rust
cargo fmt
```

## Platform-Specific Notes

### macOS

- Library file: `.dylib`
- Requires Xcode Command Line Tools
- Both ARM64 (Apple Silicon) and x64 (Intel) supported
- Universal binaries not currently supported

### Linux

- Library file: `.so`
- Requires GCC and standard build tools
- Both x64 and ARM64 targets supported
- glibc dependency (standard on most distributions)

### Windows

- Library file: `.dll`
- Requires Visual Studio or Build Tools
- MSVC runtime dependency
- Currently x64 only (no ARM64 support yet)

## Troubleshooting

### Build Failures

**macOS: "xcrun: error: unable to find utility"**
```bash
xcode-select --install
```

**Linux: "error: linker 'cc' not found"**
```bash
sudo apt-get install build-essential
```

**Windows: "error: linker 'link.exe' not found"**
- Install Visual Studio with "Desktop development with C++" workload

### Runtime Issues

**"Failed to load dynamic library"**
- Ensure native assets enabled in `pubspec.yaml`
- Run with `--enable-experiment=native-assets` flag
- Verify Rust library built successfully

**"Symbol not found" or "Undefined symbol"**
```bash
cd rust
cargo clean
cargo build --release
```

**"Async function detected. Use evalAsync()"**
- You're calling an async function from `eval()`
- Switch to `evalAsync()` for async function support
- See [Async Functions Guide](docs/ASYNC_FUNCTIONS.md)

For more troubleshooting help, see the [Setup Guide](docs/setup.md).

## Contributing

Contributions are welcome! Here's how you can help:

1. **Report Issues**: Found a bug? Open an issue with reproduction steps
2. **Suggest Features**: Have an idea? Open an issue to discuss it
3. **Submit Pull Requests**: Ready to code? Fork, branch, code, test, and submit a PR
4. **Improve Documentation**: Fix typos, add examples, clarify explanations
5. **Write Tests**: Expand test coverage for edge cases

### Contribution Guidelines

- Follow Dart style guidelines (`dart format`)
- Follow Rust style guidelines (`cargo fmt`)
- Add tests for new features
- Update documentation for API changes
- Ensure all tests pass before submitting PR
- Write clear commit messages

### Development Setup

1. Fork and clone the repository
2. Follow the [Setup Guide](docs/setup.md) to install dependencies
3. Make your changes
4. Run tests: `dart test --enable-experiment=native-assets`
5. Submit a pull request

## License

This project is dual-licensed under your choice of:

- **Apache License, Version 2.0** ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
- **MIT License** ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

You may use this project under the terms of either license.

## Acknowledgments

- **[Rhai](https://rhai.rs/)** - The embedded scripting language for Rust that powers this library
- **Dart FFI Team** - For providing excellent FFI capabilities in Dart
- **embedanythingindart** - For FFI patterns and inspiration
- **Rust Community** - For memory safety and excellent tooling
- **All Contributors** - Thank you for your contributions!

## Links

- **Documentation**: [docs/](docs/)
- **Examples**: [example/](example/)
- **Issues**: GitHub Issues (coming soon)
- **Rhai Language**: https://rhai.rs/
- **Rhai Book**: https://rhai.rs/book/

## Project Status

This project is in active development. The core functionality is complete and tested on Linux x64.

**Current Version**: 0.1.0 (Initial Release)

**Recent Updates:**
- Full async function support with dual-path architecture
- 31 tests passing including integration tests
- Complete documentation for eval() vs evalAsync()

**Roadmap:**
- Multi-platform testing on macOS and Windows
- Performance optimizations
- Additional Rhai feature exposure
- Integration with pub.dev

---

**Made with love using Dart and Rust**
