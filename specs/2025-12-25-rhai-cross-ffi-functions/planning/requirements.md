# Spec Requirements: Cross-FFI Functions for Rhai Script Execution

## Initial Description
Building cross-FFI functions for creating and running Rhai scripts with Dart integration.

Core Features:
- Build cross FFI functions for creating and running Rhai scripts
- Use ~/Documents/code/embedanythingindart/ as an example project for setting up native_toolchain_rust
- Functions like eval_rhai and analyze_rhai
- Way for Rhai scripts to call back to Dart functions (possibly pass functions in an array to eval_rhai)
- Bootstrap the library, ensure Rhai is properly working and building, and setup FFI boundaries

This combines FFI foundation, native assets build integration, and Dart-to-Rhai callbacks.

## Requirements Discussion

### First Round Questions

**Q1: FFI Functions - What are the core FFI functions you need?**
I'm assuming you want at least these two functions:
- `eval_rhai(script: String) -> Dynamic` - Execute a Rhai script and return the result
- `analyze_rhai(script: String) -> AnalysisResult` - Validate/analyze a script without executing it (optional/nice-to-have)

Should we include any additional FFI entry points like compile_rhai, create_engine, or set_global_variable in this initial spec?

**Answer:** eval_rhai() and analyze_rhai() (analyze is nice-to-have)

**Q2: Callback Pattern - How should Rhai call back to Dart?**
For Rhai scripts calling Dart functions, I see three approaches:

Option A: Pre-register named functions globally before eval_rhai
```dart
engine.registerFunction('myDartFunc', (x) => x * 2);
engine.eval('let result = myDartFunc(5);');
```

Option B: Pass functions as parameters to eval_rhai
```dart
engine.eval(script, callbacks: {'myDartFunc': (x) => x * 2});
```

Option C: Both approaches (global registration + per-eval overrides)

Which pattern fits your use case best? Also, should Dart functions be able to return Future<T> (async), or only synchronous values initially?

**Answer:** Option B chosen initially, but after async discussion evolved to: engine.registerFunction with support for both sync and async Dart functions. When Rhai calls an async Dart function, the Rust bridge blocks/waits for the Future to complete before returning the result to the script. From the script's perspective it's still synchronous, but Dart gets to use async under the hood.

**Q3: Return Types - What types should cross the FFI boundary?**
I'm assuming we should support:
- Primitives: int, double, bool, String
- Collections: List<dynamic>, Map<String, dynamic>
- Null values

Should we defer custom object/class serialization to a later spec, or do you need Rhai to work with typed Dart objects (e.g., User class) from the start?

**Answer:** Support both simple and advanced types from the start:
- Primitives: int, double, bool, String, null
- Collections: List<dynamic>, Map<String, dynamic> with nesting support
- Advanced types are in scope for initial implementation

**Q4: Error Propagation - How should errors be handled?**
When a Rhai script fails (syntax error, runtime error, type mismatch), I'm thinking we should:
- Throw a Dart exception (e.g., RhaiScriptException) with the error message and line number
- Use thread-local error storage on the Rust side (FFI-safe pattern)
- Include stack traces from both Rhai and Dart sides

Is this the right approach, or do you prefer returning Result<T, Error> types that the caller checks explicitly?

**Answer:** Distinct exceptions with stack traces and line numbers:
- Create specific exception types: RhaiScriptException, RhaiSyntaxError, RhaiRuntimeError
- Include Rhai error messages with line numbers and stack traces
- Use thread-local error storage on Rust side for FFI-safe error propagation
- Throw Dart exceptions (not Result types)

**Q5: Engine Configuration - How much control over Rhai's engine do you need?**
I assume you want to create a RhaiEngine instance with some configuration options. Should we expose:
- Sandboxing settings (disable file I/O, network access, etc.)
- Operation limits (max iterations, max stack depth)
- Timeout controls

Or should we start simple with smart defaults and defer configuration to a later spec?

**Answer:** Expose sandboxing settings with smart defaults:
- Include operation limits (max operations, max stack depth)
- Timeout controls
- Sandboxing settings (disable file I/O, network, etc.)
- Provide sensible defaults but allow configuration from the start

**Q6: Memory Management - Should we use NativeFinalizer or manual dispose()?**
Following the EmbedAnythingInDart pattern, I'm assuming:
- Rust allocates engine/results on heap, returns opaque pointers to Dart
- Dart uses NativeFinalizer to auto-cleanup when GC collects objects
- Also provide manual dispose() for deterministic cleanup

Is this correct, or do you prefer purely manual memory management where users must call dispose()?

**Answer:** Both NativeFinalizer and manual dispose():
- NativeFinalizer for automatic cleanup when GC runs
- Manual dispose() for deterministic cleanup when needed
- Follow EmbedAnythingInDart pattern with opaque pointers

**Q7: Build Configuration - Should we pin the Rust toolchain version?**
I'm assuming we should create a rust-toolchain.toml file that pins to a specific Rust version (e.g., 1.90.0) to ensure reproducible builds. Should we also specify exact targets (aarch64-apple-darwin, x86_64-unknown-linux-gnu, etc.) or let developers install what they need?

**Answer:** Pin Rust toolchain version:
- Create rust-toolchain.toml pinning to a specific stable version
- Specify exact targets for supported platforms
- Ensure reproducible builds across development environments

**Q8: Scope Exclusions - What should we explicitly NOT include in this spec?**
To keep this spec focused on bootstrapping, I'm thinking we should defer:
- Rhai module system (import/export)
- Persistent script contexts with variables
- Script compilation caching
- Debug hooks/breakpoints

Is there anything else you want to explicitly exclude or defer to future work?

**Answer:** Defer these items to future specs:
- Rhai module system (import/export)
- Persistent script contexts with variables
- Script compilation caching
- Debug hooks/breakpoints

Focus this spec on core FFI foundation, basic execution, and bidirectional function calling.

### Existing Code to Reference

**Similar Features Identified:**
- Reference Project: ~/Documents/code/embedanythingindart/
- Purpose: Example project demonstrating native_toolchain_rust setup patterns
- Key patterns to follow:
  - Native assets build integration
  - FFI memory management with NativeFinalizer
  - Thread-safe error handling across FFI boundary
  - Rust-to-Dart type conversions

### Follow-up Questions

None required - all requirements clearly specified through initial questions and async handling discussion.

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
N/A - This is a library/SDK implementation without UI components.

## Requirements Summary

### Functional Requirements

**Core FFI Functions:**
- `eval_rhai(script: String) -> Dynamic` - Execute Rhai script and return result
- `analyze_rhai(script: String) -> AnalysisResult` - Validate/analyze script without execution (nice-to-have)

**Bidirectional Function Calling:**
- Dart can register both synchronous and asynchronous functions with the Rhai engine
- Registration API: `engine.registerFunction(String name, Function callback)`
- When Rhai calls an async Dart function, the Rust FFI bridge blocks/waits for the Future to complete
- From the script's perspective, all function calls appear synchronous
- Dart functions can use async/await internally, but the result is returned synchronously to Rhai

**Type Conversion Support:**
- Primitives: int, double, bool, String, null
- Collections: List<dynamic> (Rhai arrays)
- Maps: Map<String, dynamic> (Rhai objects/maps)
- Support nested collections (arrays of arrays, maps of maps, etc.)
- Bidirectional conversion between Rhai and Dart types

**Error Handling:**
- Distinct Dart exception types:
  - `RhaiScriptException` (base class)
  - `RhaiSyntaxError` (parse/syntax errors)
  - `RhaiRuntimeError` (execution errors)
- Include Rhai error messages with line numbers
- Include stack traces from both Rhai and Dart
- Thread-local error storage on Rust side for FFI-safe propagation

**Engine Configuration:**
- Sandboxing controls (disable file I/O, network, dangerous operations)
- Operation limits (max operations, max stack depth, max string length)
- Timeout controls for script execution
- Provide sensible secure defaults
- Allow configuration override via constructor or builder pattern

**Memory Management:**
- Rust allocates engine and result objects on heap
- Transfer ownership via opaque pointers to Dart
- NativeFinalizer for automatic cleanup when Dart GC collects objects
- Manual `dispose()` method for deterministic cleanup
- Follow EmbedAnythingInDart patterns for FFI memory safety

**Build System:**
- Native assets integration using native_toolchain_rust
- hook/build.dart for automatic Rust compilation
- Cross-platform builds (macOS, Linux, Windows)
- Consistent asset naming across Cargo.toml, build.dart, and bindings.dart

### Reusability Opportunities

**Reference Implementation:**
- ~/Documents/code/embedanythingindart/ provides proven patterns for:
  - Native assets build configuration
  - FFI bindings structure
  - Memory management with NativeFinalizer
  - Error handling across FFI boundary
  - Type conversion utilities

**Existing Product Patterns:**
Based on the product's tech stack documentation, this spec should follow established patterns:
- Opaque handle types (CRhaiEngine wrapping Arc<Engine>)
- C-compatible structs for data transfer
- Free functions for Dart to call when disposing resources
- Panic catching via std::panic::catch_unwind()
- Thread-local error storage pattern

### Scope Boundaries

**In Scope:**
- Core FFI functions (eval_rhai, analyze_rhai)
- Bidirectional function calling (Dart to Rhai, Rhai to Dart)
- Async Dart function support (with blocking FFI bridge)
- Complete type conversion for primitives and collections
- Comprehensive error handling with distinct exception types
- Engine configuration and sandboxing controls
- Memory management (NativeFinalizer + manual dispose)
- Native assets build integration
- Cross-platform support (desktop: macOS, Linux, Windows)

**Out of Scope (Deferred to Future Specs):**
- Rhai module system (import/export statements)
- Persistent script contexts with variable management
- Script compilation caching for performance
- Debug hooks and breakpoints
- Mobile platform support (iOS, Android)
- Advanced async patterns (Rhai script yielding, cooperative multitasking)
- Custom type serialization (Dart classes to Rhai types)

### Technical Considerations

**Async Handling Architecture:**
- Pattern: Rust FFI bridge blocks on Dart Future completion
- Implementation: When Rhai calls a registered async Dart function:
  1. Rust FFI layer receives callback invocation from Rhai
  2. Rust calls into Dart via FFI callback
  3. Dart executes async function and awaits result
  4. Rust blocks/waits until Future completes
  5. Dart returns result back to Rust
  6. Rust returns result to Rhai script
- Script perspective: All function calls appear synchronous
- Dart perspective: Can use async/await internally for I/O, HTTP, etc.

**Build Configuration:**
- Pin Rust toolchain via rust-toolchain.toml (e.g., stable 1.90.0)
- Specify exact platform targets:
  - macOS: aarch64-apple-darwin, x86_64-apple-darwin
  - Linux: x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu
  - Windows: x86_64-pc-windows-msvc
- Cargo library type: staticlib + cdylib
- Native assets flag: --enable-experiment=native-assets

**FFI Safety Requirements:**
- All FFI entry points must use #[no_mangle] and extern "C"
- All FFI functions wrapped in std::panic::catch_unwind()
- Thread-local error storage for error propagation
- Never panic across FFI boundary
- Proper ownership transfer (Rust allocates, Dart frees)

**Integration Points:**
- Rhai crate from crates.io (latest stable version)
- Dart ffi package (^2.1.0)
- native_toolchain_rust (^1.0.0)
- hooks package for build.dart (^1.0.0)

**Testing Requirements:**
- Unit tests for individual FFI bindings
- Type conversion tests (all types, edge cases, null handling)
- Error handling tests (syntax errors, runtime errors, type mismatches)
- Memory management tests (no leaks, proper cleanup)
- Integration tests for complete workflows
- Cross-platform build validation

**Documentation Needs:**
- API documentation for all public Dart classes/methods
- Examples for common use cases:
  - Simple script execution
  - Registering Dart functions
  - Error handling
  - Async function usage
  - Engine configuration
- Setup guide for Rust toolchain installation
- Migration guide from EmbedAnythingInDart patterns
