# Spec Requirements: Rhai-Dart Async FFI Fix

## Initial Description
Use @docs/async_solution_proposal.md to fix async calls across the library

The library currently has a documented limitation where async Dart functions cannot be properly called from Rhai scripts because the Dart event loop doesn't run during FFI callbacks. There's a detailed proposal document at `/home/fabier/Documents/code/rhai_dart/docs/async_solution_proposal.md` that outlines a solution using Tokio runtime and oneshot channels.

## Requirements Discussion

### First Round Questions

**Q1:** I assume we should implement the full async solution using Tokio runtime with oneshot channels as described in the proposal, replacing the current busy-wait polling mechanism in `_syncWaitForFuture`. Is that correct, or would you prefer a phased approach starting with just the core infrastructure?

**Answer:** Full implementation using Tokio runtime with oneshot channels, replacing current busy-wait polling - CONFIRMED

**Q2:** I'm thinking we should add Tokio as a dependency with features `["rt", "sync"]` (not `rt-multi-thread` as the proposal mentions) to keep binary size down. Should we use a single-threaded runtime, or do you need multi-threaded support for concurrent script execution?

**Answer:** Multi-threaded support needed (user initially noted: "Creating multiple engines would require threading, would it not?")

**Q3:** For backward compatibility, I assume the changes should be transparent to existing users - no API changes to `registerFunction()` or `eval()`. Is that correct, or are you open to optional parameters like timeout configuration?

**Answer:** No API changes required - should be managed automatically/transparently - CONFIRMED

**Q4:** Regarding timeout handling: I'm assuming we should implement a configurable timeout (default 30 seconds) for async operations to prevent memory leaks from abandoned futures. Should this timeout be:
- Global per-engine configuration?
- Per-function registration?
- Or both with per-function overriding global?

**Answer:** Per-engine configuration with optional per-function override

**Q5:** The proposal mentions binary size increase of ~500KB for Tokio. I assume this tradeoff is acceptable given the need for proper async support. Is that correct, or should we explore lighter alternatives first?

**Answer:** Acceptable - don't worry about binary size

**Q6:** For error handling, I'm thinking we should propagate Dart Future errors through the oneshot channel and convert them to Rhai errors with full stack traces. Should we also add specific error types for async-specific failures (timeout, cancelled, channel closed)?

**Answer:** Add specific error types for async-specific failures (timeout, cancelled, channel closed) - CONFIRMED

**Q7:** I assume we should implement cleanup logic to remove abandoned futures from `PENDING_FUTURES` when:
- A timeout occurs
- The engine is disposed
- A script execution is cancelled
Is that correct, or do you have other cleanup requirements?

**Answer:** Implement cleanup for timeout, engine disposal, and script cancellation - CONFIRMED

**Q8:** For testing, I'm assuming we need comprehensive tests covering:
- Simple async functions (Future.delayed)
- Real I/O operations (HTTP requests, file operations)
- Error propagation from async functions
- Timeout scenarios
- Concurrent async operations from multiple script executions
Are there any specific edge cases or async patterns you want tested?

**Answer:** Update current async tests to be comprehensive and functional with the new setup - CONFIRMED

**Q9:** The current implementation has a `_syncWaitForFuture` function that attempts to wait with polling. Should we completely replace this with the Tokio-based approach, or keep it as a fallback for environments where Tokio might not work?

**Answer:** Completely replace the polling approach (no fallback needed)

**Q10:** What features or integrations should we explicitly NOT include in this implementation? For example: custom async runtimes, streaming responses, cancellation tokens, or async iterators?

**Answer:** Custom async runtimes, streaming responses, cancellation tokens, async iterators - ALL OUT OF SCOPE

### Existing Code to Reference

No similar existing features identified for reference.

### Follow-up Questions

**Follow-up 1:** Multi-threaded Runtime Clarification - You mentioned "Creating multiple engines would require threading, would it not?" - I want to clarify the use case:
- Do you plan to create multiple `RhaiEngine` instances from the same Dart isolate that might execute scripts concurrently?
- Or are you concerned about multiple Dart isolates each having their own engine?

Context: A single-threaded Tokio runtime would work fine even with multiple engines if they're in the same isolate, as Tokio can handle concurrent tasks on one thread. Multi-threaded runtime is mainly needed if Rhai scripts themselves spawn blocking operations. For binary size optimization, I recommend starting with `rt` (single-threaded) rather than `rt-multi-thread` unless you have a specific need.

**Answer:** Start with single-threaded Tokio runtime (`rt` feature, not `rt-multi-thread`) - User changed their mind from earlier - wants to start simple with single-threaded

**Follow-up 2:** Timeout Configuration API - For the per-engine timeout with optional per-function override:
- Should the per-function timeout be specified at registration time via a parameter like `engine.registerFunction('myFunc', callback, timeout: Duration(seconds: 5))`?
- Or would you prefer a separate method like `engine.setFunctionTimeout('myFunc', Duration(seconds: 5))`?
- What should the default global timeout be? (The current implementation uses 30 seconds)

**Answer:** Per-engine timeout only - Don't worry about per-function override - Keep it simple at the engine level - Default: 30 seconds (as currently implemented)

**Follow-up 3:** Existing Async Tests - You mentioned "Update current async tests to be comprehensive and functional with the new setup." Can you point me to the existing async test files so I can understand what test patterns are already established?

**Answer:** User pointed to these files:
- `test/async_function_test.dart` - Current test file with skipped tests
- `example/03_async_functions.dart` - Example showing workarounds
- `docs/ASYNC_FUNCTIONS.md` - Documentation of current limitations
- `README.md` - References to async limitations

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
No visual assets were provided. The async solution proposal document at `docs/async_solution_proposal.md` contains detailed architecture diagrams in text/ASCII format.

## Requirements Summary

### Functional Requirements

**Core Async Support:**
- Replace current busy-wait polling mechanism (`_syncWaitForFuture` in `callback_bridge.dart`) with Tokio-based async runtime
- Implement oneshot channel pattern for Future completion notification
- Enable true async Dart function calls from Rhai scripts with proper event loop execution
- Detect Future return values from Dart callbacks and handle them asynchronously
- Support all async Dart operations including HTTP requests, file I/O, database calls, and Future.delayed

**Rust-Side Implementation:**
- Add Tokio runtime with features `["rt", "sync"]` (single-threaded)
- Implement global `PENDING_FUTURES` registry using `HashMap<i64, oneshot::Sender<String>>` with Mutex for thread safety
- Create `rhai_complete_future` FFI function for Dart to call when Future completes
- Implement `invoke_dart_callback_async` function to handle async callback invocation
- Modify `rhai_eval` to run within Tokio runtime context using `block_on`
- Update `register_function_overloads` to use async callback invocation

**Dart-Side Implementation:**
- Modify `_dartFunctionInvoker` in `callback_bridge.dart` to detect Future return values
- Implement Future completion callback that calls `rhai_complete_future` via FFI
- Create callback response protocol with status types: "success", "pending", "error"
- Generate unique future IDs for tracking pending async operations
- Return immediately with "pending" status when Future is detected, allowing event loop to run

**Timeout Management:**
- Implement per-engine timeout configuration (default: 30 seconds)
- Apply timeout to all async operations to prevent indefinite waiting
- Clean up pending futures from registry when timeout occurs
- Propagate timeout errors back to Rhai as exceptions

**Error Handling:**
- Add specific error types for async-specific failures:
  - Timeout errors (when async operation exceeds configured timeout)
  - Cancelled errors (when script execution is cancelled)
  - Channel closed errors (when oneshot channel fails)
- Propagate Dart Future errors through oneshot channel with full error messages
- Convert async errors to Rhai exceptions with descriptive messages and stack traces
- Maintain existing error handling for synchronous functions

**Cleanup and Resource Management:**
- Remove abandoned futures from `PENDING_FUTURES` when timeout occurs
- Clean up all pending futures when engine is disposed
- Clean up pending futures when script execution is cancelled
- Prevent memory leaks from orphaned async operations
- Ensure thread-safe access to global registries

**Testing Updates:**
- Update existing tests in `test/async_function_test.dart` from skipped to functional
- Add comprehensive tests for simple async functions (Future.delayed)
- Add tests for real I/O operations (HTTP requests, file operations)
- Add tests for error propagation from async functions
- Add tests for timeout scenarios
- Add tests for concurrent async operations from multiple script executions
- Ensure all async patterns work correctly with the new implementation

**Documentation Updates:**
- Update `docs/ASYNC_FUNCTIONS.md` to remove limitation notices
- Update `README.md` to highlight async support as a feature
- Update `example/03_async_functions.dart` to show proper async usage without workarounds
- Document timeout configuration in engine creation docs

### Reusability Opportunities

No existing similar features identified in the codebase for reference.

**Key Files to Modify:**
- `rust/Cargo.toml` - Add Tokio dependency
- `rust/src/functions.rs` - Implement async callback infrastructure
- `rust/src/engine.rs` - Modify eval to run in Tokio context
- `lib/src/ffi/callback_bridge.dart` - Replace polling with Future completion callbacks
- `lib/src/ffi/bindings.dart` - Add `rhai_complete_future` FFI binding
- `test/async_function_test.dart` - Update skipped tests
- `example/03_async_functions.dart` - Update to show real async usage
- `docs/ASYNC_FUNCTIONS.md` - Remove limitation notices

### Scope Boundaries

**In Scope:**
- Full Tokio-based async runtime implementation with single-threaded runtime
- Oneshot channel pattern for Future completion
- Automatic detection and handling of async Dart functions
- Per-engine timeout configuration (30 second default)
- Comprehensive cleanup logic for timeouts, disposal, and cancellation
- Specific error types for async failures (timeout, cancelled, channel closed)
- Complete replacement of current busy-wait polling mechanism
- Updating existing async tests to be comprehensive and functional
- Documentation updates to reflect new async capabilities
- Transparent API - no breaking changes to existing code

**Out of Scope:**
- Custom async runtime support (only Tokio)
- Streaming responses or async iterators
- Cancellation tokens or explicit cancellation API
- Per-function timeout overrides (only per-engine)
- Multi-threaded Tokio runtime (starting with single-threaded)
- Fallback mechanism to polling approach
- Support for Dart isolates spawning (separate from async support)

**Future Enhancements (Not This Spec):**
- Multi-threaded Tokio runtime if needed based on usage patterns
- Per-function timeout configuration
- Explicit cancellation API
- Async streaming/iteration support
- Custom async runtime adapters

### Technical Considerations

**Architecture:**
- Follow the detailed async solution proposal at `docs/async_solution_proposal.md`
- Use oneshot channels from `tokio::sync::oneshot` for single-value Future completion
- Use `lazy_static` or `once_cell` for global `PENDING_FUTURES` registry initialization
- Maintain FFI safety with proper null checks and panic catching
- Ensure thread safety with Mutex-wrapped shared state

**Integration Points:**
- Integrates with existing callback registration system in `rust/src/functions.rs`
- Modifies existing `_dartFunctionInvoker` in `lib/src/ffi/callback_bridge.dart`
- Uses existing error propagation mechanism via thread-local storage
- Leverages existing JSON-based argument/result serialization
- Works with existing `FunctionRegistry` for callback lookup

**Technology Stack:**
- Tokio runtime v1.41+ with features `["rt", "sync"]`
- Existing dependencies: `serde`, `serde_json` for serialization
- Dart's built-in Future and async/await mechanisms
- Existing FFI bridge infrastructure (no new FFI patterns required)

**Binary Size Impact:**
- Tokio adds approximately 500KB to binary size (acceptable tradeoff)
- Single-threaded runtime is smaller than multi-threaded variant
- No additional dependencies beyond Tokio

**Performance Considerations:**
- Event-driven completion (no CPU waste from polling)
- Immediate notification when Future completes (no latency from polling intervals)
- Minimal overhead for synchronous functions (same code path as before)
- Efficient resource usage with cleanup on timeout/disposal

**Backward Compatibility:**
- No API changes required - existing code continues to work
- Synchronous functions work exactly as before
- Async functions that previously timed out or hung will now work correctly
- No breaking changes to `registerFunction()` or `eval()` signatures

**Testing Strategy:**
- Leverage existing test files with skipped async tests
- Add real-world async scenarios (HTTP, file I/O)
- Test error propagation and timeout handling
- Test concurrent async operations
- Ensure cleanup prevents memory leaks

**Known Limitations:**
- Starting with single-threaded Tokio runtime (may need multi-threaded in future)
- Per-engine timeout only (no per-function granularity)
- No explicit cancellation API (only implicit via timeout/disposal)
