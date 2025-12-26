# Async Function Support - Proposed Solution

## Problem Statement

Currently, async Dart functions cannot be used with registered Rhai functions because:
1. NativeCallable FFI callbacks are synchronous
2. Dart's event loop doesn't run during FFI calls
3. Awaiting a Future in the callback blocks the entire isolate

## Proposed Solution: Rust-Side Async with Dart Callbacks

### Architecture Overview

```
Dart: engine.eval(script)
  ↓
Rust: rhai_eval() [runs in Tokio runtime]
  ↓
Rhai: executes script
  ↓
Rhai: calls registered function (e.g., fetchData())
  ↓
Rust: invoke_dart_callback()
  ↓
Dart: NativeCallable handler
  - Detects Future
  - Stores Future with ID
  - Registers completion callback
  - Returns {"status": "pending", "future_id": 123} immediately
  ↓
Rust: Receives "pending" status
  - Creates oneshot channel
  - Stores sender in PENDING_FUTURES map
  - Awaits on receiver (using Tokio)
  [Rust async runtime yields, event loop can now run!]
  ↓
[Time passes, Dart event loop runs]
  ↓
Dart: Future completes
  - Future.then() callback fires
  - Calls rhai_complete_future(future_id, result) via FFI
  ↓
Rust: rhai_complete_future()
  - Sends result through oneshot channel
  - Wakes up the awaiting task
  ↓
Rust: Resumes with result
  - Converts JSON to Rhai Dynamic
  - Returns to Rhai script
  ↓
Rhai: Continues execution with result
```

### Key Components

#### 1. Rust Side - Async Runtime

```rust
use tokio::sync::oneshot;
use std::collections::HashMap;
use std::sync::Mutex;
use lazy_static::lazy_static;

// Global registry for pending async operations
lazy_static! {
    static ref PENDING_FUTURES: Mutex<HashMap<i64, oneshot::Sender<String>>> =
        Mutex::new(HashMap::new());
    static ref TOKIO_RUNTIME: tokio::runtime::Runtime =
        tokio::runtime::Runtime::new().unwrap();
}

// Response from Dart callback
#[derive(Deserialize)]
struct CallbackResponse {
    status: String,      // "success", "pending", or "error"
    future_id: Option<i64>,
    value: Option<String>,  // JSON encoded value
    error: Option<String>,
}

// Async function to invoke Dart callback and handle async responses
async fn invoke_dart_callback_async(
    callback_id: i64,
    callback_ptr: DartCallbackFn,
    args: Vec<Dynamic>
) -> Result<Dynamic, Box<dyn std::error::Error>> {
    // Serialize args to JSON
    let args_json = rhai_args_to_json(&args)?;
    let args_cstr = CString::new(args_json)?;

    // Call Dart synchronously (FFI call)
    let result_ptr = callback_ptr(callback_id, args_cstr.as_ptr());
    let result_json = unsafe {
        CStr::from_ptr(result_ptr).to_string_lossy().into_owned()
    };

    // Parse response
    let response: CallbackResponse = serde_json::from_str(&result_json)?;

    match response.status.as_str() {
        "success" => {
            // Synchronous function - return immediately
            Ok(json_to_rhai_dynamic(&response.value.unwrap())?)
        },
        "pending" => {
            // Async function - wait for completion
            let future_id = response.future_id.unwrap();
            let (tx, rx) = oneshot::channel();

            // Store sender for later completion
            PENDING_FUTURES.lock().unwrap().insert(future_id, tx);

            // Await result from Dart (this yields to Tokio runtime)
            // During this await, Rust is "parked" and Dart can run its event loop
            let result_json = rx.await?;

            // Parse and return result
            Ok(json_to_rhai_dynamic(&result_json)?)
        },
        "error" => {
            Err(response.error.unwrap().into())
        },
        _ => Err("Invalid callback response status".into())
    }
}

// FFI function called by Dart when Future completes
#[no_mangle]
pub extern "C" fn rhai_complete_future(
    future_id: i64,
    result_json: *const c_char
) -> i32 {
    catch_panic! {
        let result_json = unsafe {
            CStr::from_ptr(result_json).to_string_lossy().into_owned()
        };

        // Find and remove the sender
        let tx = PENDING_FUTURES.lock().unwrap().remove(&future_id);

        if let Some(tx) = tx {
            // Send result to waiting async task
            let _ = tx.send(result_json);
            0 // Success
        } else {
            set_last_error("Future ID not found");
            -1 // Error
        }
    }
}

// Modified function registration to use async callback
pub fn register_function_with_async_support(
    engine: &mut Engine,
    name: &str,
    callback_id: i64,
    callback_ptr: DartCallbackFn
) {
    // Register with Rhai - example for 1 parameter
    engine.register_fn(name, move |arg1: Dynamic| -> Dynamic {
        // Block on async call (this is the key!)
        TOKIO_RUNTIME.block_on(async {
            invoke_dart_callback_async(callback_id, callback_ptr, vec![arg1])
                .await
                .unwrap_or_else(|e| Dynamic::from(format!("Error: {}", e)))
        })
    });
}

// Modified eval to run in Tokio runtime
#[no_mangle]
pub extern "C" fn rhai_eval(
    engine: *const CRhaiEngine,
    script: *const c_char,
    result_out: *mut *mut c_char
) -> i32 {
    catch_panic! {
        // ... validation ...

        // Run eval in Tokio runtime
        let eval_result = TOKIO_RUNTIME.block_on(async {
            // This is actually synchronous but allows async callbacks
            engine_ref.eval::<Dynamic>(script_str)
        });

        match eval_result {
            Ok(result) => {
                let json = rhai_dynamic_to_json(&result)?;
                // ... store result ...
                0
            },
            Err(err) => {
                set_last_error(&format_rhai_error(&err));
                -1
            }
        }
    }
}
```

#### 2. Dart Side - Async Detection and Callbacks

```dart
class AsyncCallbackManager {
  static int _nextFutureId = 1;
  static final Map<int, Completer<dynamic>> _pendingFutures = {};

  static Pointer<Utf8> handleCallback(int callbackId, Pointer<Utf8> argsJson) {
    try {
      final callback = FunctionRegistry.instance.get(callbackId);
      if (callback == null) {
        return _errorResponse('Callback not found');
      }

      final args = jsonDecode(argsJson.toDartString()) as List;
      final result = Function.apply(callback, args);

      if (result is Future) {
        // Async function detected!
        return _handleAsyncCallback(result);
      } else {
        // Sync function
        return _successResponse(result);
      }
    } catch (e) {
      return _errorResponse(e.toString());
    }
  }

  static Pointer<Utf8> _handleAsyncCallback(Future<dynamic> future) {
    final futureId = _nextFutureId++;

    // Set up completion handler
    future.then((value) {
      _completeFromDart(futureId, value, null);
    }).catchError((error) {
      _completeFromDart(futureId, null, error.toString());
    });

    // Return pending status immediately
    final response = {
      'status': 'pending',
      'future_id': futureId,
    };

    return jsonEncode(response).toNativeUtf8();
  }

  static void _completeFromDart(int futureId, dynamic value, String? error) {
    final resultJson = error != null
        ? jsonEncode({'error': error})
        : jsonEncode({'value': value});

    final resultCStr = resultJson.toNativeUtf8();

    // Call back into Rust with the result
    final result = bindings.rhai_complete_future(futureId, resultCStr);

    calloc.free(resultCStr);

    if (result != 0) {
      print('Warning: Failed to complete future $futureId');
    }
  }

  static Pointer<Utf8> _successResponse(dynamic value) {
    return jsonEncode({
      'status': 'success',
      'value': value,
    }).toNativeUtf8();
  }

  static Pointer<Utf8> _errorResponse(String error) {
    return jsonEncode({
      'status': 'error',
      'error': error,
    }).toNativeUtf8();
  }
}
```

### Dependencies

#### Rust (Cargo.toml)
```toml
[dependencies]
tokio = { version = "1.41", features = ["rt", "sync"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### Advantages

1. ✅ **FFI calls remain synchronous** - No blocking of Dart event loop
2. ✅ **Dart event loop can run** - While Rust awaits, Dart is free to process events
3. ✅ **Rhai sees synchronous behavior** - Scripts work as expected
4. ✅ **Real async support** - HTTP requests, file I/O, database calls all work
5. ✅ **Clean error handling** - Errors propagate correctly from Future to Rhai
6. ✅ **No API changes needed** - `eval()` and `registerFunction()` stay the same

### Challenges and Considerations

#### 1. Tokio Runtime Overhead
- Need to include Tokio runtime (~500KB binary size increase)
- Runtime initialization on library load
- Minimal performance overhead for sync functions

#### 2. Thread Safety
- PENDING_FUTURES must be thread-safe (using Mutex)
- Tokio runtime is thread-safe by design
- Multiple concurrent scripts can have pending async operations

#### 3. Memory Management
- Must clean up pending futures on timeout or script cancellation
- Should implement timeout for async operations to prevent memory leaks
- Consider max concurrent async operations limit

#### 4. Error Cases to Handle
- Future ID not found (should never happen, but defensive)
- Timeout on async operation (prevent indefinite waiting)
- Script cancelled while async operation pending
- Multiple completions for same future ID (deduplicate)

### Implementation Plan

1. **Phase 1: Core Infrastructure**
   - Add Tokio dependency
   - Implement PENDING_FUTURES registry
   - Add rhai_complete_future FFI function
   - Update callback response format

2. **Phase 2: Async Callback Handling**
   - Implement invoke_dart_callback_async
   - Update function registration to use async version
   - Modify Dart callback handler to detect Futures

3. **Phase 3: Testing**
   - Test simple async function (Future.delayed)
   - Test HTTP requests (real async I/O)
   - Test error propagation
   - Test timeout handling
   - Test concurrent async operations

4. **Phase 4: Documentation**
   - Update docs/ASYNC_FUNCTIONS.md
   - Add examples with real async (HTTP, file I/O)
   - Document limitations and best practices

### Example Usage (After Implementation)

```dart
// This will work!
void main() async {
  final engine = RhaiEngine.withDefaults();

  // Register async function
  engine.registerFunction('fetchUser', (String userId) async {
    final response = await http.get(
      Uri.parse('https://api.example.com/users/$userId')
    );
    return jsonDecode(response.body);
  });

  // Call from Rhai script - it just works!
  final result = engine.eval('''
    let user = fetchUser("123");
    user.name + " (" + user.email + ")"
  ''');

  print(result); // "John Doe (john@example.com)"
}
```

### Alternative: Polling Approach (Not Recommended)

The user's original idea of polling could work but has drawbacks:

```rust
// Rust polls Dart periodically
loop {
    let status = check_future_status(future_id); // FFI call to Dart
    if status.is_complete {
        return status.result;
    }
    std::thread::sleep(Duration::from_millis(10));
}
```

**Problems:**
- Inefficient (constant polling wastes CPU)
- Fixed polling interval (too fast = CPU waste, too slow = latency)
- Harder to implement timeouts cleanly
- More FFI calls = more overhead

The callback approach is superior because:
- Event-driven (no wasted polling)
- Immediate notification when Future completes
- Natural fit with async/await paradigm

### Conclusion

This approach provides true async support while maintaining:
- Clean FFI boundaries
- Synchronous Rhai script semantics
- Efficient resource usage
- Proper error handling

The main tradeoff is adding Tokio as a dependency, but the benefits far outweigh this cost.
