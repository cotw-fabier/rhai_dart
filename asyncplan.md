# Async Function Support Implementation Plan

## Executive Summary

This document describes the current state and remaining work to enable async Dart function support in the rhai_dart library. The implementation uses a **request/response pattern** to allow background Rust threads to execute async Dart functions without blocking the Dart event loop.

**Current Status:** ~40% complete (infrastructure ready, implementation needed)
**Estimated Completion Time:** 2-3 hours
**Last Updated:** 2025-12-26

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Current Implementation Status](#current-implementation-status)
3. [Architecture Overview](#architecture-overview)
4. [Remaining Implementation Steps](#remaining-implementation-steps)
5. [Testing Strategy](#testing-strategy)
6. [Post-Implementation Tasks](#post-implementation-tasks)
7. [Known Issues and Limitations](#known-issues-and-limitations)

---

## Problem Statement

### The Core Issue

The original async infrastructure (Task Groups 1-5) attempted to support async Dart functions but encountered a fundamental deadlock:

```
Sync eval() deadlock flow:
1. Dart calls eval() → blocks in FFI call
2. Rhai script calls async Dart function
3. Dart callback returns Future with "pending" status
4. Rust awaits on oneshot channel with timeout
5. ❌ Dart thread is BLOCKED in FFI, can't run event loop
6. ❌ Future never completes
7. ❌ Timeout after 30 seconds
```

### First Attempted Solution (Failed)

Created `evalAsync()` that runs eval on background thread:
- ✅ Dart thread free (event loop can run)
- ❌ Background thread can't invoke Dart callbacks
- ❌ Error: "Cannot invoke native callback outside an isolate"

### Current Solution (In Progress)

**Request/Response Pattern** (like AI tool calling):
- Background Rust thread posts function requests to queue
- Dart polls queue, executes functions (can be async!), posts results
- Rust receives results and continues execution
- ✅ No blocking of Dart thread
- ✅ No isolate callback issues
- ✅ Natural async/await in Dart

---

## Current Implementation Status

### ✅ Completed (Step 1-2)

#### Step 1: Async Detection in Sync eval() ✅

**Files Modified:**
- `rust/src/functions.rs` - Lines 99-126
- `rust/src/engine.rs` - Lines 280-285

**What it does:**
- Thread-local flag detects when async Dart functions are called
- Sync `eval()` checks flag after script execution
- Errors immediately with helpful message: "Use evalAsync() instead"

**Status:** Working perfectly, no changes needed

**Test:**
```dart
engine.registerFunction('asyncFetch', () async => 'data');
engine.eval('asyncFetch()'); // ✅ Errors: "Use evalAsync() instead"
```

#### Step 2: Request/Response Infrastructure (Rust) ✅

**Files Modified:**
- `rust/src/async_eval.rs` - Completely rewritten (518 lines)

**What's implemented:**
1. **Data structures:**
   - `FunctionCallRequest` - Request for Dart to execute function
   - `AsyncEvalResult` - Enum for eval status (InProgress/Success/Error)

2. **Global registries:**
   - `PENDING_FUNCTION_REQUESTS` - Queue of function requests
   - `FUNCTION_RESPONSE_CHANNELS` - Response channels (oneshot)
   - `ASYNC_EVAL_RESULTS` - Eval results registry

3. **FFI functions:**
   - ✅ `rhai_get_pending_function_request()` - Dart polls for requests
   - ✅ `rhai_provide_function_result()` - Dart provides results
   - ✅ `rhai_eval_async_start()` - Start eval on background thread
   - ✅ `rhai_eval_async_poll()` - Poll for eval completion
   - ✅ `rhai_eval_async_cancel()` - Cancel eval

4. **Helper function:**
   - ✅ `request_dart_function_execution()` - Post request, await result

**Status:** Compiles successfully, ready to integrate

---

### ⏸️ Partially Complete (Step 3-4)

#### Step 3: FFI Functions ⏸️

**Status:** Functions are defined in `async_eval.rs`, but NOT wired up to function registration yet

**What's needed:** Wire these into the callback system (see Step 4)

#### Step 4: Modify Callback Handler ⏸️

**Current State:** The existing callback system uses direct FFI calls:
- File: `rust/src/functions.rs`
- Function: `invoke_dart_callback_vec_async()` (lines 496-556)
- Uses: `invoke_dart_callback_async()` (lines 134-233)

**Problem:** When called from background thread, these fail with isolate error

**What needs to change:** See [Step 4 Implementation](#step-4-modify-callback-handler) below

---

### ❌ Not Started (Step 5-7)

#### Step 5: Dart evalAsync() Request Loop ❌
- Need to replace polling logic with request/response loop
- See [Step 5 Implementation](#step-5-update-dart-evalasync)

#### Step 6: Dart FFI Bindings ❌
- Add typedefs and bindings for new FFI functions
- See [Step 6 Implementation](#step-6-add-dart-ffi-bindings)

#### Step 7: Testing ❌
- Update tests to use evalAsync()
- Verify async functions work
- See [Testing Strategy](#testing-strategy)

---

## Architecture Overview

### Request/Response Flow

```
Background Rust Thread          Main Dart Thread
        |                              |
        |--[1. Start eval]------------>|
        |                              |
    [2. Executing script]         [Returns evalId]
        |                              |
    [3. Script calls function]         |
        |                              |
    [4. Post request to queue]         |
        |                         [5. Polling loop]
        |                              |
    [6. Await response on channel] [Sees request!]
        |                              |
        |                      [7. Execute Dart function]
        |                         (can be async!)
        |                              |
        |<--[8. Post result]-----------|
        |                              |
    [9. Receive result, resume]        |
        |                              |
    [10. Continue script]         [Back to polling]
```

### Key Components

**Rust Side:**
- `PENDING_FUNCTION_REQUESTS` - VecDeque of requests
- `FUNCTION_RESPONSE_CHANNELS` - HashMap of oneshot senders
- `ASYNC_EVAL_RESULTS` - HashMap of eval results

**Dart Side:**
- Polling loop checks for requests and eval completion
- Executes functions using existing `FunctionRegistry`
- Posts results via FFI

**Communication:**
- Request: `{exec_id, function_name, args_json}`
- Response: JSON string (result or error)

---

## Remaining Implementation Steps

### Step 4: Modify Callback Handler

**Goal:** Make function registration use request pattern when in async eval context

**File to modify:** `rust/src/functions.rs`

**Option A: Context-Aware Handler (Recommended)**

Add a thread-local flag to track if we're in async eval:

```rust
// Add to functions.rs after line 126
thread_local! {
    static IN_ASYNC_EVAL: Cell<bool> = Cell::new(false);
}

pub fn set_async_eval_mode(enabled: bool) {
    IN_ASYNC_EVAL.with(|flag| flag.set(enabled));
}

fn is_async_eval_mode() -> bool {
    IN_ASYNC_EVAL.with(|flag| flag.get())
}
```

**Modify existing callback handler:**

```rust
// Replace invoke_dart_callback_vec_async (lines 496-556)
fn invoke_dart_callback_vec_async(
    callback_info: &CallbackInfo,
    args: Vec<Dynamic>,
) -> Result<Dynamic, Box<rhai::EvalAltResult>> {
    // Convert args to JSON
    let args_json = match convert_args_to_json(&args) {
        Ok(json) => json,
        Err(e) => return Err(format!("Failed to convert args to JSON: {}", e).into()),
    };

    // Check if we're in async eval mode
    if is_async_eval_mode() {
        // Use request/response pattern
        use crate::async_eval::request_dart_function_execution;

        let callback_id = callback_info.callback_id;
        let function_name = format!("callback_{}", callback_id); // Or get real name

        let result = TOKIO_RUNTIME.block_on(async {
            request_dart_function_execution(function_name, args_json).await
        });

        match result {
            Ok(json) => crate::values::json_to_rhai_dynamic(&json),
            Err(e) => Err(e.into()),
        }
    } else {
        // Use direct callback (existing code)
        let (tx, rx) = std::sync::mpsc::channel();

        TOKIO_RUNTIME.spawn(async move {
            let result = invoke_dart_callback_async(
                callback_info.callback_id,
                callback_info.callback_ptr,
                args_json,
                callback_info.async_timeout_seconds,
            ).await;
            let _ = tx.send(result);
        });

        // Pumping loop...
        let result_json = loop {
            match rx.recv_timeout(std::time::Duration::from_millis(1)) {
                Ok(result) => break result,
                Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                    return Err("Async task channel disconnected".into());
                }
            }
        };

        match result_json {
            Ok(json) => crate::values::json_to_rhai_dynamic(&json),
            Err(e) => Err(format!("Callback error: {}", e).into()),
        }
    }
}
```

**Update rhai_eval_async_start:**

```rust
// In async_eval.rs, in the spawned thread (around line 358)
thread::spawn(move || {
    // Set async eval mode for this thread
    crate::functions::set_async_eval_mode(true);

    // Execute the script
    let result = engine_arc.eval::<rhai::Dynamic>(&script_str);

    // Clear async eval mode
    crate::functions::set_async_eval_mode(false);

    // ... rest of result handling ...
});
```

**Issue to solve:** Need function names, not just callback IDs

The callback registry currently maps function names to callback IDs. We need to:
1. Pass function name to callback handler, OR
2. Create reverse mapping: callback_id → function_name

**Recommended:** Modify `CallbackInfo` struct to include function name:

```rust
// In functions.rs, modify CallbackInfo (around line 24)
#[derive(Clone)]
struct CallbackInfo {
    callback_id: i64,
    callback_ptr: DartCallback,
    async_timeout_seconds: u64,
    function_name: String,  // ADD THIS
}
```

Update registration to store function name:

```rust
// In rhai_register_function (around line 334)
let callback_info = CallbackInfo {
    callback_id,
    callback_ptr: *callback_ptr,
    async_timeout_seconds,
    function_name: function_name.to_string(),  // ADD THIS
};
```

---

### Step 5: Update Dart evalAsync()

**Goal:** Replace polling logic with request/response loop

**File to modify:** `lib/src/engine.dart`

**Add helper class:**

```dart
// Add to engine.dart after line 100
class FunctionRequest {
  final int execId;
  final String functionName;
  final String argsJson;

  FunctionRequest(this.execId, this.functionName, this.argsJson);
}

class EvalStatus {
  final bool isComplete;
  final bool isSuccess;
  final String result;
  final String error;

  EvalStatus.inProgress()
      : isComplete = false,
        isSuccess = false,
        result = '',
        error = '';

  EvalStatus.success(this.result)
      : isComplete = true,
        isSuccess = true,
        error = '';

  EvalStatus.error(this.error)
      : isComplete = true,
        isSuccess = false,
        result = '';
}
```

**Replace evalAsync() method (starts at line 313):**

```dart
Future<dynamic> evalAsync(String script) async {
  final enginePtr = _nativeEngine;
  final scriptPtr = script.toNativeUtf8();

  try {
    final evalIdPtr = calloc<Int64>();

    try {
      // Start async eval
      final returnCode = _bindings.evalAsyncStart(
        enginePtr,
        scriptPtr.cast(),
        evalIdPtr,
      );

      if (returnCode != 0) {
        checkFFIError(_bindings);
        throw const RhaiFFIError('Failed to start async eval');
      }

      final evalId = evalIdPtr.value;

      // Main polling loop
      while (true) {
        // Check for function call requests FIRST (higher priority)
        final request = _pollFunctionRequest();
        if (request != null) {
          // Rust needs a Dart function executed!
          await _fulfillFunctionRequest(request);
          continue; // Check for more requests immediately
        }

        // Check if eval completed
        final evalStatus = _pollEvalStatus(evalId);
        if (evalStatus.isComplete) {
          if (evalStatus.isSuccess) {
            return jsonToRhaiValue(evalStatus.result);
          } else {
            _throwParsedError(evalStatus.error);
          }
        }

        // Brief delay to avoid busy-waiting
        await Future.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      calloc.free(evalIdPtr);
    }
  } finally {
    calloc.free(scriptPtr);
  }
}
```

**Add helper methods:**

```dart
// Add after evalAsync()

/// Poll for pending function requests from Rust
FunctionRequest? _pollFunctionRequest() {
  final execIdPtr = calloc<Int64>();
  final fnNamePtrPtr = calloc<Pointer<Char>>();
  final argsPtrPtr = calloc<Pointer<Char>>();

  try {
    final result = _bindings.getPendingFunctionRequest(
      execIdPtr,
      fnNamePtrPtr,
      argsPtrPtr,
    );

    if (result != 0) {
      return null; // No pending requests
    }

    // Extract request data
    final execId = execIdPtr.value;
    final fnNamePtr = fnNamePtrPtr.value;
    final argsPtr = argsPtrPtr.value;

    if (fnNamePtr == nullptr || argsPtr == nullptr) {
      return null;
    }

    final fnName = fnNamePtr.cast<Utf8>().toDartString();
    final argsJson = argsPtr.cast<Utf8>().toDartString();

    // Free C strings
    freeNativeString(_bindings, fnNamePtr.cast());
    freeNativeString(_bindings, argsPtr.cast());

    return FunctionRequest(execId, fnName, argsJson);
  } finally {
    calloc.free(execIdPtr);
    calloc.free(fnNamePtrPtr);
    calloc.free(argsPtrPtr);
  }
}

/// Execute Dart function and provide result back to Rust
Future<void> _fulfillFunctionRequest(FunctionRequest request) async {
  try {
    // Look up registered function
    final callback = _functionRegistry.getCallbackById(request.functionName);
    if (callback == null) {
      _provideErrorResult(
        request.execId,
        'Function not found: ${request.functionName}',
      );
      return;
    }

    // Parse args
    final args = jsonDecode(request.argsJson) as List;

    // Call function (can be async!)
    dynamic result;
    if (callback is Future Function()) {
      result = await callback();
    } else if (callback is Function) {
      result = Function.apply(callback, args);
      // If result is Future, await it
      if (result is Future) {
        result = await result;
      }
    } else {
      throw Exception('Invalid callback type');
    }

    // Encode result as JSON
    final resultJson = jsonEncode(_encodeResultForCallback(result));

    // Provide result to Rust
    _provideFunctionResult(request.execId, resultJson);
  } catch (e, stackTrace) {
    // Provide error to Rust
    _provideErrorResult(
      request.execId,
      'Function error: $e\nStack trace: $stackTrace',
    );
  }
}

/// Poll for eval status
EvalStatus _pollEvalStatus(int evalId) {
  final statusPtr = calloc<Int32>();
  final resultPtrPtr = calloc<Pointer<Char>>();

  try {
    final pollResult = _bindings.evalAsyncPoll(
      evalId,
      statusPtr,
      resultPtrPtr,
    );

    if (pollResult != 0) {
      checkFFIError(_bindings);
      throw const RhaiFFIError('Failed to poll async eval');
    }

    final status = statusPtr.value;
    final resultPtr = resultPtrPtr.value;

    if (status == 0) {
      // In progress
      return EvalStatus.inProgress();
    } else if (status == 1) {
      // Success
      if (resultPtr == nullptr) {
        throw const RhaiFFIError('Result pointer is null after success');
      }
      final jsonResult = resultPtr.cast<Utf8>().toDartString();
      freeNativeString(_bindings, resultPtr.cast());
      return EvalStatus.success(jsonResult);
    } else if (status == 2) {
      // Error
      if (resultPtr == nullptr) {
        throw const RhaiFFIError('Error message pointer is null');
      }
      final errorMsg = resultPtr.cast<Utf8>().toDartString();
      freeNativeString(_bindings, resultPtr.cast());
      return EvalStatus.error(errorMsg);
    } else {
      throw RhaiFFIError('Invalid async eval status: $status');
    }
  } finally {
    calloc.free(statusPtr);
    calloc.free(resultPtrPtr);
  }
}

/// Provide function result to Rust
void _provideFunctionResult(int execId, String resultJson) {
  final resultPtr = resultJson.toNativeUtf8();
  try {
    final returnCode = _bindings.provideFunctionResult(execId, resultPtr.cast());
    if (returnCode != 0) {
      checkFFIError(_bindings);
      // Log warning but don't throw - eval can continue
      print('Warning: Failed to provide function result for exec_id $execId');
    }
  } finally {
    calloc.free(resultPtr);
  }
}

/// Provide error result to Rust
void _provideErrorResult(int execId, String error) {
  final errorJson = jsonEncode({'error': error});
  _provideFunctionResult(execId, errorJson);
}

/// Encode result for callback (handles different types)
dynamic _encodeResultForCallback(dynamic value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is List) return value.map(_encodeResultForCallback).toList();
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _encodeResultForCallback(v)));
  }
  return value.toString(); // Fallback
}
```

**Note:** You'll need to add a method to `FunctionRegistry` to look up by callback ID:

```dart
// In lib/src/function_registry.dart
Function? getCallbackById(String functionName) {
  return _callbacks[functionName];
}
```

---

### Step 6: Add Dart FFI Bindings

**Goal:** Wire up new FFI functions in Dart bindings

**File to modify:** `lib/src/ffi/bindings.dart`

**Add typedefs (after line 130):**

```dart
/// Get pending function request
typedef RhaiGetPendingFunctionRequestNative = Int32 Function(
    Pointer<Int64>, Pointer<Pointer<Char>>, Pointer<Pointer<Char>>);
typedef RhaiGetPendingFunctionRequestDart = int Function(
    Pointer<Int64>, Pointer<Pointer<Char>>, Pointer<Pointer<Char>>);

/// Provide function result
typedef RhaiProvideFunctionResultNative = Int32 Function(Int64, Pointer<Char>);
typedef RhaiProvideFunctionResultDart = int Function(int, Pointer<Char>);
```

**Add late fields (after line 237):**

```dart
// Function pointers - Function request/response
late final RhaiGetPendingFunctionRequestDart _getPendingFunctionRequest;
late final RhaiProvideFunctionResultDart _provideFunctionResult;
```

**Add lookups in _initializeBindings() (after line 317):**

```dart
// Function request/response
_getPendingFunctionRequest = _lib
    .lookup<NativeFunction<RhaiGetPendingFunctionRequestNative>>(
        'rhai_get_pending_function_request')
    .asFunction();

_provideFunctionResult = _lib
    .lookup<NativeFunction<RhaiProvideFunctionResultNative>>(
        'rhai_provide_function_result')
    .asFunction();
```

**Add public API methods (after line 422):**

```dart
/// Get pending function request from Rust.
///
/// Returns 0 if request retrieved, -1 if no pending requests.
int getPendingFunctionRequest(
  Pointer<Int64> execIdOut,
  Pointer<Pointer<Char>> functionNameOut,
  Pointer<Pointer<Char>> argsJsonOut,
) => _getPendingFunctionRequest(execIdOut, functionNameOut, argsJsonOut);

/// Provide function result to Rust.
///
/// Returns 0 on success, -1 if exec_id not found.
int provideFunctionResult(int execId, Pointer<Char> resultJson) =>
    _provideFunctionResult(execId, resultJson);
```

---

### Step 7: Test Implementation

**Goal:** Verify everything works end-to-end

**File to update:** `test/eval_async_test.dart` (already exists)

**Build and copy library:**

```bash
cd rust
cargo build --release
cp target/release/librhai_dart.so ../librhai_dart.so
```

**Run tests:**

```bash
cd ..
dart test test/eval_async_test.dart --reporter expanded
```

**Expected results:**
- ✅ `evalAsync with sync functions works` - Should pass
- ✅ `evalAsync with async functions` - Should NOW pass (was failing before)
- ✅ `sync eval rejects async functions` - Should pass (already works)
- ✅ `evalAsync with async function returning map` - Should pass
- ✅ `evalAsync error propagation` - Should pass
- ✅ `concurrent evalAsync calls` - Should pass

**If tests fail:**
- Check Rust build succeeded
- Check library is in correct location
- Add debug logging to track requests/responses
- Verify callback names match between Rust and Dart

---

## Testing Strategy

### Unit Tests (Rust)

Add to `rust/src/async_eval.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_request_queue() {
        let request = FunctionCallRequest {
            exec_id: 1,
            function_name: "test_fn".to_string(),
            args_json: "[]".to_string(),
        };

        PENDING_FUNCTION_REQUESTS.lock().unwrap().push_back(request.clone());

        let popped = PENDING_FUNCTION_REQUESTS.lock().unwrap().pop_front();
        assert!(popped.is_some());
        assert_eq!(popped.unwrap().exec_id, 1);
    }

    #[test]
    fn test_response_channel() {
        let (tx, rx) = oneshot::channel();
        FUNCTION_RESPONSE_CHANNELS.lock().unwrap().insert(1, tx);

        let sender = FUNCTION_RESPONSE_CHANNELS.lock().unwrap().remove(&1);
        assert!(sender.is_some());
    }
}
```

### Integration Tests (Dart)

The existing `test/eval_async_test.dart` covers the main scenarios. Add:

```dart
test('evalAsync with nested async calls', () async {
  engine.registerFunction('asyncOuter', () async {
    await Future.delayed(Duration(milliseconds: 20));
    return 'outer';
  });

  engine.registerFunction('asyncInner', () async {
    await Future.delayed(Duration(milliseconds: 10));
    return 'inner';
  });

  final result = await engine.evalAsync('''
    let outer = asyncOuter();
    let inner = asyncInner();
    outer + "_" + inner
  ''');

  expect(result, equals('outer_inner'));
});

test('evalAsync with error in async function', () async {
  engine.registerFunction('asyncError', () async {
    await Future.delayed(Duration(milliseconds: 10));
    throw Exception('Intentional error');
  });

  expect(
    () => engine.evalAsync('asyncError()'),
    throwsA(isA<RhaiRuntimeError>()),
  );
});
```

### Manual Testing

```dart
// Create test script: test_async_manual.dart
import 'package:rhai_dart/rhai_dart.dart';

void main() async {
  final engine = RhaiEngine.withDefaults();

  // Register async HTTP-like function
  engine.registerFunction('httpGet', (String url) async {
    print('Fetching $url...');
    await Future.delayed(Duration(milliseconds: 500));
    return {
      'status': 200,
      'url': url,
      'body': 'Response from $url',
    };
  });

  // Test async eval
  print('Starting async eval...');
  final result = await engine.evalAsync('''
    let response = httpGet("https://api.example.com/data");
    response.body
  ''');

  print('Result: $result');

  // Test sync eval rejection
  try {
    engine.eval('httpGet("test")');
  } catch (e) {
    print('Expected error: $e');
  }

  engine.dispose();
}
```

Run: `dart run test_async_manual.dart`

---

## Post-Implementation Tasks

### Task Group 6: Comprehensive Test Updates

**Status:** Blocked until evalAsync works

**File:** `agent-os/specs/2025-12-26-rhai-dart-async-ffi-fix/tasks.md`

**What to do:**
1. Review all skipped tests in `test/async_function_test.dart`
2. Enable tests and update to use `evalAsync()`
3. Add test for sync eval rejection (already exists in eval_async_test.dart)
4. Run full test suite

**Delegate to `implementer` agent:**

```
You are implementing Task Group 6: Comprehensive Test Updates.

Context:
- evalAsync() is now implemented using request/response pattern
- Async Dart functions work correctly
- Sync eval() errors immediately on async function calls

Tasks:
1. Update test/async_function_test.dart to use evalAsync()
2. Enable all skipped tests
3. Add any missing test coverage
4. Ensure all tests pass

Spec: agent-os/specs/2025-12-26-rhai-dart-async-ffi-fix/spec.md
Tasks: agent-os/specs/2025-12-26-rhai-dart-async-ffi-fix/tasks.md (mark complete as you go)
```

### Task Group 7: Documentation and Example Updates

**Files to update:**
1. `docs/ASYNC_FUNCTIONS.md` - Remove limitations, document evalAsync()
2. `README.md` - Highlight async support
3. `example/03_async_functions.dart` - Show real async usage
4. Add API docs to engine.dart for both eval() and evalAsync()

**Delegate to `implementer` agent:**

```
You are implementing Task Group 7: Documentation and Example Updates.

Context:
- evalAsync() is implemented and working
- Users should use eval() for sync, evalAsync() for async

Tasks:
1. Update docs/ASYNC_FUNCTIONS.md - full async support
2. Update README.md - highlight as key feature
3. Update example/03_async_functions.dart - real HTTP examples
4. Add inline docs to eval() and evalAsync() methods

Spec: agent-os/specs/2025-12-26-rhai-dart-async-ffi-fix/spec.md
Tasks: agent-os/specs/2025-12-26-rhai-dart-async-ffi-fix/tasks.md
```

---

## Known Issues and Limitations

### Current Limitations

1. **Function Name Mapping:**
   - Need to pass function names to callbacks (not just IDs)
   - Requires modifying `CallbackInfo` struct
   - Addressed in Step 4 implementation notes

2. **Error Context:**
   - Errors from Dart functions lose some stack trace info
   - Consider including more context in error JSON

3. **Performance:**
   - 10ms polling interval adds latency
   - Could be optimized with event-driven approach
   - Acceptable for async operations

4. **Cancellation:**
   - `rhai_eval_async_cancel()` doesn't actually stop background thread
   - Just discards result
   - Thread will complete on its own

### Future Improvements

1. **Event-Driven Notifications:**
   - Instead of polling, use Dart isolate ports
   - More complex but eliminates polling overhead

2. **Per-Function Timeouts:**
   - Currently 30s global timeout
   - Could add per-function configuration

3. **Cancellation Support:**
   - Actually stop background thread execution
   - Requires more complex thread management

4. **Streaming Results:**
   - Support for async generators/streams
   - Return partial results

---

## Quick Start Guide (For Resuming)

### 1. Understand Current State

```bash
# Check what's implemented
git log --oneline | head -20

# Review current code
cat rust/src/async_eval.rs  # Step 2 complete
cat rust/src/functions.rs | grep -A 10 "ASYNC_FUNCTION_INVOKED"  # Step 1 complete
```

### 2. Start with Step 4

```bash
# Open key files
code rust/src/functions.rs      # Modify callback handler
code rust/src/async_eval.rs     # Already has request_dart_function_execution
```

Follow [Step 4 Implementation](#step-4-modify-callback-handler) above

### 3. Continue Through Steps 5-7

Each step builds on the previous. Test after each step.

### 4. Verify with Tests

```bash
cargo build --release
cp rust/target/release/librhai_dart.so .
dart test test/eval_async_test.dart
```

### 5. Complete Task Groups 6 & 7

Use `implementer` agents as described in [Post-Implementation Tasks](#post-implementation-tasks)

---

## Additional Resources

### Key Files Reference

```
rust/src/
├── async_eval.rs       ✅ Request/response infrastructure (Step 2)
├── engine.rs           ✅ Async detection (Step 1)
├── functions.rs        ⏸️ Callback handler (Step 4 needed)
├── types.rs           (No changes needed)
└── lib.rs             (No changes needed - already exports async_eval)

lib/src/
├── engine.dart        ⏸️ evalAsync() method (Step 5 needed)
├── ffi/
│   └── bindings.dart  ❌ FFI bindings (Step 6 needed)
└── function_registry.dart  (Minor changes for Step 5)

test/
└── eval_async_test.dart  ❌ Tests (Step 7)
```

### Debugging Tips

**If Rust compilation fails:**
- Check all imports in modified files
- Verify function signatures match between calls
- Run `cargo check` for detailed errors

**If FFI lookup fails:**
- Verify symbols exported: `nm -D librhai_dart.so | grep rhai`
- Check function names match exactly
- Ensure library rebuilt after Rust changes

**If tests fail with timeout:**
- Add logging to request/response flow
- Check Dart event loop isn't blocked
- Verify background thread posts requests correctly

**If async functions don't execute:**
- Verify `set_async_eval_mode(true)` called
- Check function name mapping works
- Add debug prints in `_fulfillFunctionRequest()`

### Contact / Questions

If you need clarification on any step:
1. Review the detailed implementation notes in each step
2. Check the architecture diagram for flow understanding
3. Look at similar patterns in existing code (e.g., PENDING_FUTURES)

---

## Conclusion

The foundation is solid:
- ✅ Async detection works
- ✅ Infrastructure ready
- ⏸️ Integration needed (~2-3 hours)

The request/response pattern is clean, avoids dart-sys dependency, and will work reliably. Once Steps 4-7 are complete, async Dart functions will work seamlessly with `evalAsync()`.

**Good luck! You've got this. 🚀**
