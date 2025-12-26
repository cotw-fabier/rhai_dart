# Specification: Async Function Support for Rhai-Dart FFI

## Goal
Enable true async Dart function support in Rhai scripts by replacing the current busy-wait polling mechanism with a Tokio-based async runtime that allows Dart's event loop to run during FFI callbacks, enabling HTTP requests, file I/O, and other async operations.

## User Stories
- As a Rhai script author, I want to call async Dart functions (like HTTP requests) from my scripts so that I can integrate with real-world I/O operations
- As a Dart developer, I want to register async functions with the Rhai engine without workarounds so that my code can use natural Dart async/await patterns
- As a library user, I want async support to work transparently without API changes so that existing code continues to work while gaining new capabilities

## Specific Requirements

**Tokio Runtime Integration**
- Add Tokio dependency to `rust/Cargo.toml` with features `["rt", "sync"]` (single-threaded runtime)
- Initialize global Tokio runtime using `lazy_static` or `once_cell` pattern
- Wrap `rhai_eval` execution in Tokio runtime context using `block_on`
- Ensure runtime initialization is thread-safe and happens once
- Keep binary size impact minimal (single-threaded vs multi-threaded runtime)

**Pending Futures Registry**
- Create global `PENDING_FUTURES` HashMap mapping `i64` (future ID) to `tokio::sync::oneshot::Sender<String>`
- Protect registry with `Mutex` for thread-safe access
- Generate unique future IDs using atomic counter or sequential ID generator
- Implement cleanup logic to remove entries on completion, timeout, or cancellation
- Handle edge cases like duplicate IDs or missing entries gracefully

**Async Callback Infrastructure (Rust)**
- Implement `invoke_dart_callback_async` function that handles both sync and async responses
- Create `CallbackResponse` struct with fields: status ("success", "pending", "error"), future_id (optional), value (optional), error (optional)
- For "pending" status: create oneshot channel, store sender in registry, await on receiver
- For "success" status: parse and return value immediately (existing sync path)
- For "error" status: propagate error to Rhai as exception
- Update `register_function_overloads` to use async callback invocation for all arities (0-10 parameters)

**Future Completion Bridge (Rust)**
- Add `rhai_complete_future` FFI function with signature: `(future_id: i64, result_json: *const c_char) -> i32`
- Look up and remove sender from `PENDING_FUTURES` by future ID
- Send result through oneshot channel to wake awaiting task
- Return 0 on success, -1 if future ID not found
- Handle errors gracefully with proper error messages via `set_last_error`

**Async Detection and Response (Dart)**
- Modify `_dartFunctionInvoker` in `callback_bridge.dart` to detect Future return values
- For detected Futures: generate unique future ID, attach completion callback via `.then()/.catchError()`, return "pending" response immediately
- For sync functions: return "success" response with value (existing behavior unchanged)
- For errors: return "error" response with message (existing behavior unchanged)
- Implement completion callback that calls `rhai_complete_future` via FFI when Future resolves

**Timeout Management**
- Add per-engine timeout configuration with 30-second default
- Apply timeout using `tokio::time::timeout` wrapper around oneshot channel receive
- On timeout: remove pending future from registry, return timeout error to Rhai
- Make timeout duration configurable in `CRhaiConfig` struct and `EngineConfig`
- Propagate timeout errors with clear messages indicating async operation exceeded limit

**Error Handling**
- Add specific Rhai error types for: timeout ("Async operation timed out after N seconds"), cancelled ("Async operation was cancelled"), channel closed ("Async channel closed unexpectedly")
- Propagate Dart Future errors through oneshot channel with full error messages
- Preserve error stack traces from Dart through JSON error encoding
- Maintain existing synchronous error handling paths unchanged
- Convert all async-specific errors to Rhai `EvalAltResult` with descriptive messages

**Resource Cleanup**
- Implement cleanup for pending futures when timeout occurs (remove from registry after timeout)
- Clean up all pending futures when engine is disposed (iterate and drop all senders)
- Handle script execution cancellation if supported in future (mark as out of scope for now)
- Prevent memory leaks from orphaned async operations
- Ensure thread-safe cleanup operations using Mutex guards

**Testing Infrastructure**
- Update all skipped tests in `test/async_function_test.dart` to be functional with new implementation
- Add test for simple async function with `Future.delayed` (50ms delay, verify result)
- Add test for async function returning different types (int, string, map, list)
- Add test for async function error propagation (throw in Future, catch in Rhai)
- Add test for timeout scenario (very long delay exceeding configured timeout)
- Add test for concurrent async operations (multiple scripts calling async functions simultaneously)
- Verify sync functions still work exactly as before (regression testing)

**Documentation Updates**
- Update `docs/ASYNC_FUNCTIONS.md` to remove "Limited Support" warning and document fully working async
- Update README.md to highlight async support as a key feature
- Update `example/03_async_functions.dart` to show real async usage (HTTP requests, file I/O) without workarounds
- Document timeout configuration in engine creation documentation
- Add examples of HTTP requests, file I/O, and database queries working properly
- Document any performance considerations or limitations

**FFI Bindings Update**
- Add `rhai_complete_future` function declaration to `lib/src/ffi/bindings.dart`
- Ensure proper FFI signature matching Rust function: `int Function(int, Pointer<Utf8>)`
- Update any auto-generated FFI bindings if using ffigen
- Add FFI symbol lookup and validation

## Visual Design
No visual assets provided - this is a backend infrastructure feature.

## Existing Code to Leverage

**`rust/src/functions.rs` - Callback Infrastructure**
- Reuse `CallbackInfo` struct for storing callback ID and function pointer
- Reuse `CALLBACK_REGISTRY` pattern for thread-safe global state management
- Extend `register_function_overloads` function to use new async invocation mechanism
- Reuse `convert_args_to_json` and JSON parsing/conversion logic
- Follow existing error handling patterns with `Box<rhai::EvalAltResult>`

**`lib/src/ffi/callback_bridge.dart` - Current Async Detection**
- Build on existing `_dartFunctionInvoker` function structure
- Replace `_syncWaitForFuture` implementation with new oneshot channel approach
- Reuse `_encodeResult` and `_encodeError` functions for response formatting
- Keep existing Future detection logic: `if (result is Future)`
- Maintain compatibility with sync function path

**`rust/src/engine.rs` - Eval Infrastructure**
- Modify `rhai_eval` function to run within Tokio runtime context
- Preserve existing error formatting with `format_rhai_error` function
- Keep existing JSON conversion and C string handling patterns
- Maintain existing pointer validation and null checking logic
- Follow existing panic catching patterns with `catch_panic!` macro

**`test/async_function_test.dart` - Test Structure**
- Update skipped test cases to functional tests with proper assertions
- Reuse existing test setup/teardown patterns with `RhaiEngine.withDefaults()`
- Extend test helper functions like `fetchUserData`, `simulateHttpRequest`
- Add new test scenarios building on documented limitation tests
- Keep existing sync function regression tests unchanged

**Global State Patterns from Codebase**
- Follow `lazy_static!` pattern used in `CALLBACK_REGISTRY` for `PENDING_FUTURES`
- Use `Arc<Mutex<>>` for thread-safe shared state
- Implement cleanup on engine disposal similar to callback registry cleanup
- Use atomic operations for ID generation if needed
- Follow existing FFI memory management patterns

## Out of Scope
- Custom async runtime support beyond Tokio
- Streaming responses or async iterators from Rhai scripts
- Explicit cancellation tokens or cancellation API
- Per-function timeout overrides (only per-engine timeout)
- Multi-threaded Tokio runtime (starting with single-threaded `rt` feature only)
- Fallback mechanism to polling approach for edge cases
- Support for Dart isolates spawning from Rhai scripts
- Async generator functions or yield-based async patterns
- Custom error recovery strategies for async failures
- Performance profiling or benchmarking of async operations
