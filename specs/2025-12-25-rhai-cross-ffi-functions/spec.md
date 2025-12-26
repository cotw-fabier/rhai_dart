# Specification: Rhai-Dart FFI Integration Library

## Goal
Build a cross-platform FFI library that enables Dart applications to execute Rhai scripts with bidirectional function calling, comprehensive type conversion, and robust error handling.

## User Stories
- As a Dart developer, I want to execute Rhai scripts from my application so that I can provide safe, sandboxed scripting capabilities to end users
- As a developer, I want to register both sync and async Dart functions in Rhai scripts so that scripts can access platform capabilities while maintaining a simple synchronous programming model

## Specific Requirements

**Core Script Execution API**
- Implement `eval_rhai(script: String) -> dynamic` to execute Rhai scripts and return results
- Implement `analyze_rhai(script: String) -> AnalysisResult` as nice-to-have for script validation without execution
- Create `RhaiEngine` class with opaque pointer pattern wrapping Rust `Arc<rhai::Engine>`
- Support script execution with configurable timeouts to prevent infinite loops
- Return script results as Dart dynamic types with automatic type conversion
- Clear engine state between executions for security isolation

**Bidirectional Function Registration**
- API: `engine.registerFunction(String name, Function callback)` for registering Dart functions
- Support both synchronous Dart functions `T Function(...)` and async functions `Future<T> Function(...)`
- When Rhai calls async Dart function, Rust FFI bridge blocks/waits for Future completion using Dart_ExecuteInternalCommand
- From script perspective all function calls appear synchronous regardless of Dart implementation
- Store function callbacks in a registry with unique IDs passed to Rust side
- Support up to 10 function parameters with automatic type conversion
- Handle function errors gracefully and propagate to Rhai as script exceptions

**Type System and Conversion**
- Primitives: bidirectional conversion for int, double, bool, String, null between Dart and Rhai
- Lists: convert `List<dynamic>` to Rhai arrays and vice versa with recursive nesting support
- Maps: convert `Map<String, dynamic>` to Rhai objects/maps and vice versa with recursive nesting
- Create C-compatible structs for passing complex data across FFI boundary
- Use JSON serialization for nested/complex structures to avoid FFI alignment issues
- Handle Rhai's `Dynamic` type by inspecting type tags and converting appropriately
- Validate type conversions and throw clear errors on unsupported type combinations

**Error Handling and Reporting**
- Create sealed class hierarchy: `RhaiException` (base), `RhaiSyntaxError`, `RhaiRuntimeError`
- Include line numbers from Rhai parser/evaluator in syntax errors
- Include stack traces from both Rhai execution context and Dart call site
- Use thread-local error storage on Rust side with `get_last_error()` FFI function
- Wrap all FFI entry points with `std::panic::catch_unwind()` to prevent crashes
- Clear error storage before each FFI call to avoid stale errors

**Engine Configuration and Sandboxing**
- Expose sandboxing controls: disable file I/O, network access, system commands
- Operation limits: max_operations (default 1M), max_stack_depth (default 100), max_string_length (default 10MB)
- Timeout controls: script execution timeout in milliseconds (default 5000ms)
- Provide sensible secure defaults via `RhaiEngine.withDefaults()` constructor
- Allow override via `RhaiEngine.withConfig(RhaiConfig config)` builder pattern
- Disable dangerous Rhai features by default (file I/O, eval, loading modules)

**Memory Management Strategy**
- Rust allocates engine and result objects on heap, returns opaque `*mut c_void` pointers to Dart
- Create Dart `Finalizable` classes that hold native pointers
- Attach `NativeFinalizer` to automatically call Rust free functions when Dart GC collects objects
- Provide manual `dispose()` method for deterministic cleanup before GC
- Follow embedanythingindart pattern: opaque handles wrapped in Dart classes
- Ensure double-free safety by nulling pointers after disposal

**Build System Integration**
- Use `native_toolchain_rust` package for automatic Rust compilation
- Create `hook/build.dart` with `RustBuilder` pointing to library crate
- Asset name must match across Cargo.toml, build.dart, and Dart bindings
- Pin Rust toolchain via `rust-toolchain.toml` to stable 1.83.0
- Specify exact targets: aarch64-apple-darwin, x86_64-apple-darwin, x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu, x86_64-pc-windows-msvc
- Cargo library type: `["staticlib", "cdylib"]` for cross-platform compatibility
- Enable native assets in pubspec.yaml and use `--enable-experiment=native-assets` flag

**Testing Requirements**
- Unit tests for FFI bindings: engine creation, disposal, error handling
- Type conversion tests covering all primitives, nested collections, edge cases, null values
- Error propagation tests for syntax errors, runtime errors, type mismatches with line number validation
- Memory leak tests using valgrind or similar tools to verify proper cleanup
- Bidirectional function calling tests for sync functions, async functions with delays, error throwing
- Sandboxing tests to verify disabled features actually throw errors
- Cross-platform build validation on macOS (ARM64 + x64), Linux (x64 + ARM64), Windows (x64)

**Documentation and Examples**
- API documentation with dartdoc comments for all public classes and methods
- Example: simple script execution with result handling
- Example: registering sync Dart function and calling from Rhai script
- Example: registering async Dart function (HTTP request) called from Rhai
- Example: error handling with try-catch and exception type checking
- Example: engine configuration with custom timeout and operation limits
- Setup guide for installing Rust toolchain and configuring IDE
- Architecture documentation explaining FFI boundary, memory ownership, type conversion flow

## Existing Code to Leverage

**embedanythingindart - Build System Pattern**
- Use `hook/build.dart` with `RustBuilder` for native assets integration
- Asset name consistency across Cargo.toml (`name = "rhai_dart"`), build.dart (`assetName: 'rhai_dart'`), and bindings
- Follow pattern of `[package]` name in Cargo.toml matching asset name
- Cargo library types: `["staticlib", "cdylib"]` for cross-platform support

**embedanythingindart - FFI Error Handling**
- Thread-local error storage with `thread_local! { static LAST_ERROR: RefCell<Option<String>> }`
- Functions: `set_last_error(error: &str)`, `clear_last_error()`, `get_last_error() -> *mut c_char`
- Wrap all FFI entry points with `panic::catch_unwind(|| { ... })` to catch Rust panics
- Return error codes (0 for success, -1 for error) and use `get_last_error()` to retrieve message

**embedanythingindart - Opaque Handle Pattern**
- Define opaque struct in Rust: `pub struct CRhaiEngine { inner: Arc<rhai::Engine> }`
- Return `*mut CRhaiEngine` from constructor, accept `*const CRhaiEngine` in methods
- Dart side: `final class CRhaiEngine extends Opaque {}` with `Pointer<CRhaiEngine>` fields
- Implement `_finalizer = NativeFinalizer(bindings.addresses.engineFree)` for automatic cleanup

**embedanythingindart - Native Type Definitions**
- Use `#[repr(C)]` structs for complex data: `CRhaiValue`, `CRhaiConfig`, `CRhaiError`
- Dart mirrors with `extends Struct` and exact field layout matching
- Pointer fields: `external Pointer<Float> values;` for arrays
- Primitives: `@Size() external int len;`, `@Float() external double ratio;`
- Strings: `external Pointer<Utf8> message;` with manual conversion

**embedanythingindart - Sealed Error Class Pattern**
- Create sealed base class: `sealed class RhaiException implements Exception`
- Specific error types extend base: `class RhaiSyntaxError extends RhaiException`
- Include structured fields: `final String message;`, `final int? lineNumber;`, `final String? stackTrace;`
- Override `toString()` for clear error messages in logs

## Out of Scope
- Rhai module system with import/export statements for code organization
- Persistent script contexts that retain variables across multiple eval calls
- Script compilation caching for improved performance on repeated execution
- Debug hooks, breakpoints, or step-through debugging capabilities
- Mobile platform support (iOS and Android) - desktop platforms only for now
- Advanced async patterns like Rhai script yielding or cooperative multitasking
- Custom Dart class serialization (e.g., converting User class instances to Rhai types)
- Streaming or chunked script execution with partial results
- Multi-isolate support or parallel script execution
- Integration with Dart's DevTools or profiling infrastructure
