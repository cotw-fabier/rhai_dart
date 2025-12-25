# Product Roadmap

1. [ ] FFI Foundation and Basic Execution — Set up Rust workspace with Rhai dependency, create C-compatible FFI functions for engine initialization and script execution, implement Dart FFI bindings with proper memory management using NativeFinalizer, and enable running simple Rhai scripts that return primitive types (int, float, string, bool) back to Dart `M`

2. [ ] Native Assets Build Integration — Create hook/build.dart using native_toolchain_rust to automatically compile the Rust library during dart/flutter run, ensure asset name consistency across Cargo.toml/build.dart/bindings.dart, configure rust-toolchain.toml with required targets, and validate cross-platform builds work on macOS/Linux/Windows `S`

3. [ ] Error Handling and Thread Safety — Implement thread-local error storage in Rust for FFI-safe error propagation, wrap all FFI functions in panic::catch_unwind to prevent undefined behavior, create Dart exception classes for script errors (syntax errors, runtime errors, type errors), and surface Rhai error messages with line numbers and stack traces to Dart `M`

4. [ ] Complex Type Conversion (Collections) — Support converting Rhai arrays to Dart List<dynamic>, convert Rhai maps/objects to Dart Map<String, dynamic>, implement bidirectional conversion for nested collections, and add comprehensive tests for all type conversion edge cases including null handling and type mismatches `M`

5. [ ] Expose Dart Functions to Rhai — Design FFI callback mechanism for Rhai to invoke Dart functions, implement Engine::register_fn equivalent in Rust FFI layer, create Dart API for registering typed functions (e.g., registerFunction<int>(String name, int Function(int) callback)), and ensure proper lifetime management of Dart callbacks across the FFI boundary `L`

6. [ ] Connect Rhai Built-ins to Dart I/O — Wire Rhai's print() function to call Dart's print() for standard output, connect Rhai's debug() function to Dart logging, implement custom I/O handlers so scripts can integrate with Dart's stdout/stderr, and add configurable output callbacks for testing and custom logging scenarios `S`

7. [ ] High-Level Dart API — Create idiomatic RhaiEngine Dart class wrapping low-level FFI bindings, implement fluent API for common operations (eval, call, registerFunction), provide typed result extraction (evalAs<T>, callAs<T>), and add factory methods for common engine configurations (sandboxed, unrestricted, custom limits) `M`

8. [ ] Script Variable Management — Support setting and getting global variables in the Rhai scope from Dart, implement scope isolation for multiple script executions, add API for creating and managing persistent script contexts, and ensure variables properly handle Dart/Rhai type conversions `M`

9. [ ] Rhai Module System Support — Enable loading and importing Rhai module files from disk or strings, support Rhai's export/import syntax for shared functionality, implement module caching and dependency resolution, and provide Dart API for preloading common modules `L`

10. [ ] Sandboxing and Security Controls — Expose Rhai's operation limits (max operations, max modules, max string length) to Dart configuration, implement function blacklisting/whitelisting for registered functions, add configurable resource limits (execution timeout, memory limits), and create security presets for common use cases (safe, restricted, unrestricted) `M`

11. [ ] Advanced Script Execution Modes — Support calling Rhai functions by name with typed arguments, implement script compilation and caching for repeated execution performance, add support for async Rhai operations with proper Dart Future integration, and provide script debugging hooks (breakpoints, variable inspection) `L`

12. [ ] Comprehensive Testing and Examples — Create test suite covering all FFI boundary edge cases, add integration tests for bidirectional calling patterns, develop example applications (CLI with user scripts, configurable backend service, plugin system), write documentation with migration guide from pure Dart solutions, and add benchmarks comparing performance to alternatives `L`

> Notes
> - Order items by technical dependencies (FFI foundation before high-level API, basic execution before advanced features)
> - Each item represents end-to-end functionality testable from Dart
> - Focus on incremental value: items 1-6 deliver core scripting capability, items 7-12 add polish and advanced features
