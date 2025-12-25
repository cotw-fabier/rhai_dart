# Product Mission

## Pitch
Rhai Dart is a native FFI library that helps Dart developers embed scripting capabilities into their applications by providing seamless integration with the Rhai scripting engine from Rust. It enables dynamic script execution, bidirectional function calling, and flexible runtime behavior without requiring application rebuilds.

## Users

### Primary Customers
- **Dart CLI Developers**: Building command-line tools that need user-configurable automation or plugins
- **Backend Developers**: Creating server applications with dynamic business logic or user-defined workflows
- **Library Authors**: Developing extensible Dart packages that allow users to customize behavior via scripts
- **Game Developers**: Building Dart-based games that need moddable content or scripting support

### User Personas

**Backend Developer** (25-40 years)
- **Role:** Senior Software Engineer building server-side applications
- **Context:** Needs to allow customers to define custom business rules or data transformations without deploying new code
- **Pain Points:** Recompiling and redeploying for every business logic change is slow and risky; current options like JSON-based DSLs are limited and hard to maintain
- **Goals:** Enable non-developers to safely write custom logic; reduce deployment frequency; maintain type safety and performance

**CLI Tool Developer** (22-35 years)
- **Role:** Developer creating automation tools and utilities
- **Context:** Building a Dart CLI that needs user-customizable automation scripts
- **Pain Points:** Existing scripting options are either too heavyweight (embedding Node.js) or too limited (simple config files); wants a small, fast, and safe scripting solution
- **Goals:** Provide users with a powerful yet sandboxed scripting environment; keep binary size small; maintain Dart's ease of use

**Library Author** (28-45 years)
- **Role:** Open-source maintainer building reusable Dart packages
- **Context:** Creating extensible libraries where users need to customize behavior without forking
- **Pain Points:** Callback-based APIs become unwieldy with complex logic; wants users to have full scripting power while maintaining library control
- **Goals:** Offer a clean plugin/extension API; ensure user scripts can't crash the host application; maintain backward compatibility

## The Problem

### Limited Runtime Flexibility in Compiled Languages
Dart applications are compiled (JIT or AOT), which means adding new functionality or changing business logic requires recompilation and redeployment. This creates friction in scenarios where end-users or operators need to customize behavior without developer intervention. While Dart excels at type safety and performance, it lacks a lightweight, embeddable scripting solution for runtime customization.

**Our Solution:** Embed the Rhai scripting engine (a Rust-based, lightweight scripting language) directly into Dart applications using native assets. Rhai provides a safe, fast, and simple scripting environment designed specifically for embedding, with syntax similar to JavaScript/Rust.

### Lack of Safe Scripting Options for Dart
Existing options for adding scripting to Dart applications are limited:
- Parsing and executing strings with Dart's analyzer/VM is not officially supported
- Embedding JavaScript engines (V8, QuickJS) adds significant binary bloat
- Creating custom DSLs requires extensive parsing and validation work
- Allowing arbitrary code execution creates security risks

**Our Solution:** Leverage Rhai's built-in sandboxing, small footprint (~250KB), and simple syntax to provide a secure and efficient scripting solution. The FFI bridge ensures Dart maintains full control over what Rhai scripts can access.

## Differentiators

### Native Asset Integration with Rust
Unlike pure-Dart scripting attempts or JavaScript engine embeddings, Rhai Dart uses Dart's native_assets system to seamlessly integrate Rust's high-performance Rhai engine. This results in zero-config builds where the Rust library is automatically compiled for the target platform during `dart run` or `flutter run`, eliminating manual build steps and cross-compilation headaches.

### Bidirectional Function Calling
Unlike simple script evaluation libraries, Rhai Dart enables true interoperability: Dart functions can be exposed to Rhai scripts, and Rhai functions can call back into Dart. This allows scripts to leverage the full power of the host application's APIs while keeping the scripting environment isolated and controlled.

### Built on Proven EmbedAnythingInDart Patterns
By following the same architecture as the successful EmbedAnythingInDart library, Rhai Dart benefits from battle-tested FFI patterns including automatic memory management via NativeFinalizer, thread-safe error handling, and robust async operation support. This reduces risk and accelerates development.

### Lightweight and Fast
Rhai is designed specifically for embedding with minimal overhead. Unlike V8 or other JavaScript engines that can add 20-50MB to binary size, Rhai adds only ~250KB. Its interpreter is fast enough for most scripting use cases while maintaining predictable performance and memory usage.

## Key Features

### Core Features
- **Embed Rhai Engine:** Compile and link the Rhai Rust library into Dart using native_assets, providing automatic cross-platform builds with zero manual configuration
- **Execute Scripts:** Run Rhai scripts from Dart code and receive typed results back, supporting all Rhai data types including integers, floats, strings, arrays, maps, and custom types
- **Automatic Memory Management:** Leverage NativeFinalizer for automatic cleanup of Rust resources when Dart objects are garbage collected, preventing memory leaks

### Bidirectional Communication Features
- **Expose Dart Functions to Rhai:** Register Dart functions with the Rhai engine so scripts can call back into the host application, enabling powerful plugin and extension patterns
- **Connect Built-in Functions:** Wire Rhai's built-in functions (like `print`, `debug`) to Dart's standard output, ensuring seamless debugging and logging experiences
- **Type Conversion:** Automatically convert between Rhai and Dart types, handling primitives, collections, and custom data structures with type safety

### Advanced Features
- **Script Modules:** Support Rhai's module system for organizing scripts and sharing functionality across multiple script files
- **Sandboxing Controls:** Configure the Rhai engine to restrict access to certain operations (file I/O, network, etc.), ensuring scripts run in a secure environment
- **Error Handling:** Provide detailed script error messages including line numbers, stack traces, and syntax errors, surfaced as Dart exceptions for easy debugging
