//! Function registration and callback management
//!
//! This module provides FFI functions for registering Dart callbacks with the Rhai engine
//! and managing the callback invocation bridge.

use crate::types::CRhaiEngine;
use crate::error::{clear_last_error, set_last_error};
use crate::{catch_panic};
use rhai::{Dynamic, Engine};
use std::ffi::{CString, CStr, c_char};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use std::sync::atomic::{AtomicI64, Ordering};
use tokio::sync::oneshot;
use serde::Deserialize;

/// Type for the Dart callback function pointer.
///
/// This matches the NativeCallable signature on the Dart side:
/// `Pointer<Utf8> Function(Int64 callbackId, Pointer<Utf8> argsJson)`
type DartCallback = extern "C" fn(i64, *const c_char) -> *mut c_char;

/// Stores information about a registered Dart callback.
#[derive(Clone)]
struct CallbackInfo {
    /// The unique ID for this callback
    callback_id: i64,

    /// The function pointer to call back into Dart
    callback_ptr: DartCallback,

    /// Async callback timeout in seconds
    async_timeout_seconds: u64,

    /// The name of the registered function
    function_name: String,
}

/// Response structure for async callback invocations.
///
/// This struct represents the response from a Dart callback, which can be:
/// - "success": The operation completed synchronously with a result
/// - "pending": The operation is async and will complete later (requires future_id)
/// - "error": The operation failed with an error message
#[derive(Debug, Deserialize)]
struct CallbackResponse {
    /// Status of the callback: "success", "pending", or "error"
    status: String,

    /// Future ID for pending async operations (only present when status is "pending")
    #[serde(default)]
    future_id: Option<i64>,

    /// Result value for successful operations (JSON string or value)
    #[serde(default)]
    value: Option<serde_json::Value>,

    /// Alternative value field as JSON string (for compatibility)
    #[serde(default)]
    value_json: Option<String>,

    /// Error message for failed operations
    #[serde(default)]
    error: Option<String>,
}

lazy_static::lazy_static! {
    /// Global registry of callback information.
    ///
    /// This maps function names to their callback information.
    /// We use Arc<Mutex<>> for thread-safe access since Rhai engine might be used
    /// from multiple threads.
    static ref CALLBACK_REGISTRY: Arc<Mutex<HashMap<String, CallbackInfo>>> =
        Arc::new(Mutex::new(HashMap::new()));

    /// Global registry of pending async futures.
    ///
    /// This maps future IDs to oneshot senders that will be used to complete
    /// async operations. When Dart completes an async operation, it calls
    /// `rhai_complete_future` which sends the result through the channel.
    ///
    /// We use Arc<Mutex<>> for thread-safe access since async operations may
    /// complete on different threads.
    static ref PENDING_FUTURES: Arc<Mutex<HashMap<i64, oneshot::Sender<String>>>> =
        Arc::new(Mutex::new(HashMap::new()));

    /// Global Tokio runtime for async operations.
    ///
    /// This is a multi-threaded runtime that allows async operations to run
    /// concurrently with the blocking operations. This is necessary because
    /// when we call block_on() to wait for async Dart callbacks, the Dart
    /// event loop needs to run on a separate thread to complete the Future.
    pub static ref TOKIO_RUNTIME: tokio::runtime::Runtime = {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .worker_threads(2)  // Keep it small - we only need one thread for async operations
            .build()
            .expect("Failed to create Tokio runtime")
    };
}

/// Thread-local flag to track if async functions were invoked during eval.
///
/// This is used by sync `eval()` to detect when async Dart functions are called,
/// allowing it to error immediately with a helpful message to use `evalAsync()` instead.
use std::cell::Cell;
thread_local! {
    static ASYNC_FUNCTION_INVOKED: Cell<bool> = Cell::new(false);
}

/// Marks that an async function was invoked during the current eval.
///
/// This is called when a "pending" status is received from a Dart callback,
/// indicating that the function returned a Future.
pub fn mark_async_invoked() {
    ASYNC_FUNCTION_INVOKED.with(|flag| flag.set(true));
}

/// Checks if async functions were invoked and clears the flag.
///
/// Returns true if async functions were called since the last clear.
/// This should be called after eval() completes to detect async usage.
pub fn check_and_clear_async_flag() -> bool {
    ASYNC_FUNCTION_INVOKED.with(|flag| {
        let was_async = flag.get();
        flag.set(false);
        was_async
    })
}

/// Thread-local flag to track if we're in async eval mode.
///
/// When true, function callbacks use the request/response pattern instead of
/// direct FFI calls, allowing them to work from background threads.
thread_local! {
    static IN_ASYNC_EVAL: Cell<bool> = Cell::new(false);
}

/// Sets whether we're in async eval mode.
///
/// This should be called by the background thread in evalAsync before executing
/// the script, and cleared after execution completes.
pub fn set_async_eval_mode(enabled: bool) {
    IN_ASYNC_EVAL.with(|flag| flag.set(enabled));
}

/// Checks if we're currently in async eval mode.
fn is_async_eval_mode() -> bool {
    IN_ASYNC_EVAL.with(|flag| flag.get())
}

/// Atomic counter for generating unique future IDs.
///
/// This counter is incremented atomically for each new async operation
/// to ensure unique IDs across all pending futures.
static NEXT_FUTURE_ID: AtomicI64 = AtomicI64::new(1);

/// Generates a unique future ID.
///
/// This uses an atomic counter to ensure thread-safe ID generation.
/// IDs are sequential and never repeat (wraps at i64::MAX but that's
/// effectively impossible to reach in practice).
pub fn generate_future_id() -> i64 {
    NEXT_FUTURE_ID.fetch_add(1, Ordering::SeqCst)
}

/// Invokes a Dart callback asynchronously, handling both sync and async responses.
///
/// This function handles three types of responses:
/// - "success": Returns the value immediately (sync path)
/// - "pending": Creates a oneshot channel, stores it in the registry, and awaits the result
/// - "error": Returns the error immediately
///
/// The timeout is configurable per-engine and is passed via the async_timeout_seconds parameter.
/// If the timeout is exceeded, the pending future is removed from the registry and an error is returned.
///
/// # Arguments
///
/// * `callback_id` - The unique ID for this callback
/// * `callback_ptr` - Function pointer to the Dart callback
/// * `args_json` - JSON string of arguments to pass to the callback
/// * `async_timeout_seconds` - Timeout in seconds for async operations
///
/// # Returns
///
/// Result containing the JSON string response or an error
async fn invoke_dart_callback_async(
    callback_id: i64,
    callback_ptr: DartCallback,
    args_json: String,
    async_timeout_seconds: u64,
) -> Result<String, String> {
    // Convert to C string
    let args_c_string = CString::new(args_json)
        .map_err(|e| format!("Failed to create C string: {}", e))?;

    // Call the Dart callback
    let result_ptr = callback_ptr(callback_id, args_c_string.as_ptr());

    // Check if result is null
    if result_ptr.is_null() {
        return Err("Dart callback returned null".into());
    }

    // Convert result to Rust string
    let result_json = unsafe {
        match CStr::from_ptr(result_ptr).to_str() {
            Ok(s) => s.to_string(),
            Err(e) => {
                // Free the string before returning error
                let _ = CString::from_raw(result_ptr);
                return Err(format!("Invalid UTF-8 in callback result: {}", e).into());
            }
        }
    };

    // Free the result string (Dart allocated it)
    unsafe {
        let _ = CString::from_raw(result_ptr);
    }

    // Parse the callback response
    let response: CallbackResponse = serde_json::from_str(&result_json)
        .map_err(|e| format!("Failed to parse callback response: {}", e))?;

    // Handle different response statuses
    match response.status.as_str() {
        "success" => {
            // Synchronous success - return the value immediately
            if let Some(value_json) = response.value_json {
                Ok(value_json)
            } else if let Some(value) = response.value {
                Ok(value.to_string())
            } else {
                Ok("null".to_string())
            }
        }
        "pending" => {
            // Asynchronous operation - mark that async was invoked
            // This allows sync eval() to detect and error on async function calls
            mark_async_invoked();

            // Asynchronous operation - wait for completion
            let future_id = response.future_id
                .ok_or("Pending response missing future_id")?;

            // Create a oneshot channel for this async operation
            let (tx, mut rx) = oneshot::channel::<String>();

            // Store the sender in the registry
            {
                let mut registry = PENDING_FUTURES.lock().unwrap();
                registry.insert(future_id, tx);
            }

            // Wait for the result with the configured timeout
            let timeout_duration = std::time::Duration::from_secs(async_timeout_seconds);
            match tokio::time::timeout(timeout_duration, rx).await {
                Ok(Ok(result)) => {
                    // Successfully received result
                    Ok(result)
                }
                Ok(Err(_)) => {
                    // Channel was closed (sender dropped)
                    // Clean up the registry
                    let mut registry = PENDING_FUTURES.lock().unwrap();
                    registry.remove(&future_id);
                    Err("Async channel closed unexpectedly".into())
                }
                Err(_) => {
                    // Timeout occurred
                    // Clean up the registry
                    let mut registry = PENDING_FUTURES.lock().unwrap();
                    registry.remove(&future_id);
                    Err(format!("Async operation timed out after {} seconds",
                        timeout_duration.as_secs()).into())
                }
            }
        }
        "error" => {
            // Error response
            let error_msg = response.error
                .unwrap_or_else(|| "Unknown error from Dart callback".to_string());
            Err(error_msg.into())
        }
        _ => {
            Err(format!("Invalid callback status: {}", response.status).into())
        }
    }
}

/// Completes a pending async future with a result from Dart.
///
/// This FFI function is called by Dart when an async operation completes.
/// It looks up the future ID in the PENDING_FUTURES registry, sends the
/// result through the oneshot channel, and removes the entry from the registry.
///
/// # Safety
///
/// This function is safe to call from FFI when:
/// - `future_id` is a valid future ID from a pending async operation
/// - `result_json` is a valid null-terminated C string
///
/// # Arguments
///
/// * `future_id` - The unique ID of the future to complete
/// * `result_json` - JSON string containing the result (C string)
///
/// # Returns
///
/// 0 on success, -1 if future ID not found or on error
#[no_mangle]
pub extern "C" fn rhai_complete_future(
    future_id: i64,
    result_json: *const c_char,
) -> i32 {
    catch_panic! {{
        clear_last_error();

        // Validate pointer
        if result_json.is_null() {
            set_last_error("Result JSON pointer is null");
            return -1;
        }

        // Convert C string to Rust string
        let result_str = unsafe {
            match CStr::from_ptr(result_json).to_str() {
                Ok(s) => s.to_string(),
                Err(e) => {
                    set_last_error(&format!("Invalid UTF-8 in result JSON: {}", e));
                    return -1;
                }
            }
        };

        // Look up and remove the sender from the registry
        let sender = {
            let mut registry = PENDING_FUTURES.lock().unwrap();
            registry.remove(&future_id)
        };

        match sender {
            Some(tx) => {
                // Send the result through the channel
                match tx.send(result_str) {
                    Ok(_) => 0, // Success
                    Err(_) => {
                        // Receiver was dropped - this is unexpected but not fatal
                        set_last_error(&format!(
                            "Failed to send result for future {}: receiver dropped",
                            future_id
                        ));
                        -1
                    }
                }
            }
            None => {
                // Future ID not found
                set_last_error(&format!("Future ID {} not found in registry", future_id));
                -1
            }
        }
    }}
}

/// Registers a Dart function with the Rhai engine.
///
/// This function stores the callback information and registers a Rhai function
/// that will invoke the Dart callback when called from scripts.
///
/// # Safety
///
/// This function is safe to call from FFI when:
/// - `engine` is a valid pointer created by `rhai_engine_new`
/// - `name` is a valid null-terminated C string
/// - `callback_ptr` is a valid function pointer matching the DartCallback signature
/// - `callback_id` is a unique identifier for this callback
///
/// # Arguments
///
/// * `engine` - Pointer to the Rhai engine
/// * `name` - Name of the function to register (C string)
/// * `callback_id` - Unique ID for this callback
/// * `callback_ptr` - Function pointer to the Dart callback
///
/// # Returns
///
/// 0 on success, -1 on error (check last error)
#[no_mangle]
pub extern "C" fn rhai_register_function(
    engine: *mut CRhaiEngine,
    name: *const c_char,
    callback_id: i64,
    callback_ptr: DartCallback,
) -> i32 {
    catch_panic! {{
        clear_last_error();

        // Validate pointers
        if engine.is_null() {
            set_last_error("Engine pointer is null");
            return -1;
        }

        if name.is_null() {
            set_last_error("Function name pointer is null");
            return -1;
        }

        // Get the engine (mutable reference needed to register functions)
        let engine_wrapper = unsafe { &mut *engine };

        // Get the async timeout from the engine
        let async_timeout_seconds = engine_wrapper.async_timeout_seconds();

        // Convert function name to Rust string
        let func_name = unsafe {
            match CStr::from_ptr(name).to_str() {
                Ok(s) => s.to_string(),
                Err(e) => {
                    set_last_error(&format!("Invalid UTF-8 in function name: {}", e));
                    return -1;
                }
            }
        };

        // Store callback info in registry
        let callback_info = CallbackInfo {
            callback_id,
            callback_ptr,
            async_timeout_seconds,
            function_name: func_name.clone(),
        };

        {
            let mut registry = CALLBACK_REGISTRY.lock().unwrap();
            registry.insert(func_name.clone(), callback_info.clone());
        }

        // Register the function with Rhai engine
        // We register multiple overloads for different parameter counts (0-10)
        register_function_overloads(
            Arc::get_mut(&mut engine_wrapper.inner).unwrap(),
            &func_name,
            callback_info,
        );

        0 // Success
    }}
}

/// Registers function overloads for different parameter counts.
///
/// This registers the same function name with different arities (0-10 parameters)
/// so that Rhai can call it with any number of arguments.
///
/// All registered functions now use async invocation through the Tokio runtime
/// to support both sync and async Dart callbacks.
fn register_function_overloads(engine: &mut Engine, name: &str, info: CallbackInfo) {
    // Register 0-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move || {
            invoke_dart_callback_vec_async(&info, vec![])
        });
    }

    // Register 1-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1])
        });
    }

    // Register 2-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2])
        });
    }

    // Register 3-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3])
        });
    }

    // Register 4-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3, a4])
        });
    }

    // Register 5-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3, a4, a5])
        });
    }

    // Register 6-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3, a4, a5, a6])
        });
    }

    // Register 7-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3, a4, a5, a6, a7])
        });
    }

    // Register 8-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic, a8: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3, a4, a5, a6, a7, a8])
        });
    }

    // Register 9-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic, a8: Dynamic, a9: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3, a4, a5, a6, a7, a8, a9])
        });
    }

    // Register 10-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic, a8: Dynamic, a9: Dynamic, a10: Dynamic| {
            invoke_dart_callback_vec_async(&info, vec![a1, a2, a3, a4, a5, a6, a7, a8, a9, a10])
        });
    }
}

/// Invokes a Dart callback synchronously from the same thread.
///
/// This is used for sync eval() to avoid crossing thread boundaries.
/// If the callback is async (returns a Future), it will set the ASYNC_FUNCTION_INVOKED
/// flag so that eval() can error with a helpful message.
fn invoke_dart_callback_sync(
    callback_info: &CallbackInfo,
    args_json: String,
) -> Result<Dynamic, Box<rhai::EvalAltResult>> {
    use serde_json;

    // Convert to C string
    let args_c_string = match CString::new(args_json) {
        Ok(s) => s,
        Err(e) => {
            return Err(format!("Failed to create C string: {}", e).into());
        }
    };

    // Call the Dart callback directly (synchronous FFI call on same thread)
    let result_ptr = (callback_info.callback_ptr)(
        callback_info.callback_id,
        args_c_string.as_ptr(),
    );

    // Check if result is null
    if result_ptr.is_null() {
        return Err("Dart callback returned null".into());
    }

    // Convert result to Rust string
    let result_json = unsafe {
        match CStr::from_ptr(result_ptr as *const c_char).to_str() {
            Ok(s) => s.to_string(),
            Err(e) => {
                return Err(format!("Invalid UTF-8 in callback result: {}", e).into());
            }
        }
    };

    // Free the result string
    unsafe {
        libc::free(result_ptr as *mut libc::c_void);
    }

    // Parse the callback response
    let response: CallbackResponse = match serde_json::from_str(&result_json) {
        Ok(r) => r,
        Err(e) => {
            return Err(format!("Failed to parse callback response: {}", e).into());
        }
    };

    // Handle response based on status
    match response.status.as_str() {
        "success" => {
            // Get the result value
            let value_json = if let Some(value) = response.value {
                serde_json::to_string(&value).unwrap_or_else(|_| "null".to_string())
            } else if let Some(value_json) = response.value_json {
                value_json
            } else {
                "null".to_string()
            };

            // Convert to Rhai Dynamic
            match crate::values::json_to_rhai_dynamic(&value_json) {
                Ok(dynamic) => Ok(dynamic),
                Err(e) => Err(format!("Failed to convert result to Rhai: {}", e).into()),
            }
        }
        "pending" => {
            // Async function detected - set flag so eval() can error
            mark_async_invoked();
            Err("Async function called in sync eval - this error should be caught by eval()".into())
        }
        "error" => {
            let error_msg = response.error.unwrap_or_else(|| "Unknown error".to_string());
            Err(format!("Callback error: {}", error_msg).into())
        }
        _ => {
            Err(format!("Unknown callback status: {}", response.status).into())
        }
    }
}

/// Invokes a Dart callback with arguments as a Vec<Dynamic>, using async runtime.
///
/// This function uses a spawned Tokio task and a pumping loop to allow the Dart
/// event loop to make progress while waiting for async operations to complete.
///
/// When in async eval mode (evalAsync), this uses the request/response pattern
/// to avoid isolate callback issues from background threads.
fn invoke_dart_callback_vec_async(
    callback_info: &CallbackInfo,
    args: Vec<Dynamic>,
) -> Result<Dynamic, Box<rhai::EvalAltResult>> {
    // Convert args to JSON array
    let args_json = match convert_args_to_json(&args) {
        Ok(json) => json,
        Err(e) => {
            return Err(format!("Failed to convert args to JSON: {}", e).into());
        }
    };

    // Check if we're in async eval mode
    if is_async_eval_mode() {
        // Use request/response pattern for async eval
        use crate::async_eval::request_dart_function_execution;

        let function_name = callback_info.function_name.clone();

        // Use block_on to wait for the async function execution
        let result = TOKIO_RUNTIME.block_on(async {
            request_dart_function_execution(function_name, args_json).await
        });

        match result {
            Ok(json) => {
                // Check if the JSON contains an error field
                if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&json) {
                    if let Some(error_msg) = parsed.get("error").and_then(|v| v.as_str()) {
                        return Err(format!("Function error: {}", error_msg).into());
                    }
                }

                // Parse the JSON result and convert to Rhai Dynamic
                match crate::values::json_to_rhai_dynamic(&json) {
                    Ok(dynamic) => Ok(dynamic),
                    Err(e) => Err(format!("Failed to convert result to Rhai: {}", e).into()),
                }
            }
            Err(e) => {
                // Propagate error to Rhai
                Err(format!("Function error: {}", e).into())
            }
        }
    } else {
        // Sync eval mode - invoke callback directly on same thread
        // This avoids crossing thread boundaries which would cause isolate errors
        invoke_dart_callback_sync(callback_info, args_json)
    }
}

/// Invokes a Dart callback with arguments as a Vec<Dynamic>.
///
/// This is a legacy sync-only helper function kept for backward compatibility.
/// New code should use invoke_dart_callback_vec_async instead.
#[allow(dead_code)]
fn invoke_dart_callback_vec(
    callback_info: &CallbackInfo,
    args: Vec<Dynamic>,
) -> Result<Dynamic, Box<rhai::EvalAltResult>> {
    // Convert args to JSON array
    let args_json = match convert_args_to_json(&args) {
        Ok(json) => json,
        Err(e) => {
            return Err(format!("Failed to convert args to JSON: {}", e).into());
        }
    };

    // Convert to C string
    let args_c_string = match CString::new(args_json) {
        Ok(s) => s,
        Err(e) => {
            return Err(format!("Failed to create C string: {}", e).into());
        }
    };

    // Call the Dart callback
    let result_ptr = (callback_info.callback_ptr)(
        callback_info.callback_id,
        args_c_string.as_ptr(),
    );

    // Check if result is null
    if result_ptr.is_null() {
        return Err("Dart callback returned null".into());
    }

    // Convert result to Rust string
    let result_json = unsafe {
        match CStr::from_ptr(result_ptr).to_str() {
            Ok(s) => s.to_string(),
            Err(e) => {
                // Free the string before returning error
                let _ = CString::from_raw(result_ptr);
                return Err(format!("Invalid UTF-8 in callback result: {}", e).into());
            }
        }
    };

    // Free the result string (Dart allocated it)
    unsafe {
        let _ = CString::from_raw(result_ptr);
    }

    // Parse JSON result
    let result_value: serde_json::Value = match serde_json::from_str(&result_json) {
        Ok(v) => v,
        Err(e) => {
            return Err(format!("Failed to parse callback result JSON: {}", e).into());
        }
    };

    // Check if it's a success or error result
    if let Some(success) = result_value.get("success").and_then(|v| v.as_bool()) {
        if success {
            // Try new format first (value_json as a JSON string)
            if let Some(value_json) = result_value.get("value_json").and_then(|v| v.as_str()) {
                // Parse the JSON string and convert to Rhai Dynamic
                match crate::values::json_to_rhai_dynamic(value_json) {
                    Ok(dynamic) => Ok(dynamic),
                    Err(e) => Err(format!("Failed to convert result to Rhai: {}", e).into()),
                }
            }
            // Fall back to old format (value as an object)
            else if let Some(value) = result_value.get("value") {
                match crate::values::json_to_rhai_dynamic(&value.to_string()) {
                    Ok(dynamic) => Ok(dynamic),
                    Err(e) => Err(format!("Failed to convert result to Rhai: {}", e).into()),
                }
            }
            // No value field - return unit
            else {
                Ok(Dynamic::UNIT)
            }
        } else {
            // Error case
            let error_msg = result_value
                .get("error")
                .and_then(|v| v.as_str())
                .unwrap_or("Unknown error from Dart callback");
            Err(error_msg.into())
        }
    } else {
        Err("Invalid callback result format".into())
    }
}

/// Converts Rhai Dynamic arguments to a JSON array string.
///
/// # Arguments
///
/// * `args` - Slice of Rhai Dynamic values
///
/// # Returns
///
/// JSON string representation of the arguments array
fn convert_args_to_json(args: &[Dynamic]) -> Result<String, String> {
    let mut json_args = Vec::new();

    for arg in args {
        let json = crate::values::rhai_dynamic_to_json(arg)
            .map_err(|e| format!("Failed to convert arg to JSON: {}", e))?;
        json_args.push(json);
    }

    // Create a JSON array
    Ok(format!("[{}]", json_args.join(",")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_future_id_uniqueness() {
        let id1 = generate_future_id();
        let id2 = generate_future_id();
        let id3 = generate_future_id();

        assert_ne!(id1, id2);
        assert_ne!(id2, id3);
        assert_ne!(id1, id3);

        // IDs should be sequential
        assert_eq!(id2, id1 + 1);
        assert_eq!(id3, id2 + 1);
    }

    #[test]
    fn test_convert_args_to_json() {
        let args = vec![
            Dynamic::from(42),
            Dynamic::from("hello"),
            Dynamic::from(true),
        ];

        let json = convert_args_to_json(&args).unwrap();
        assert!(json.starts_with('['));
        assert!(json.ends_with(']'));
        assert!(json.contains("42"));
        assert!(json.contains("hello"));
        assert!(json.contains("true"));
    }

    #[test]
    fn test_convert_empty_args() {
        let args: Vec<Dynamic> = vec![];
        let json = convert_args_to_json(&args).unwrap();
        assert_eq!(json, "[]");
    }

    /// Test that timeout cleans up registry entries
    #[tokio::test]
    async fn test_timeout_cleanup() {
        // Create a mock callback that returns pending status
        extern "C" fn mock_callback(_id: i64, _args: *const c_char) -> *mut c_char {
            let response = r#"{"status":"pending","future_id":12345}"#;
            CString::new(response).unwrap().into_raw()
        }

        // Invoke with very short timeout
        let result = invoke_dart_callback_async(
            1,
            mock_callback,
            "[]".to_string(),
            1, // 1 second timeout
        ).await;

        // Should timeout
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("timed out") || err_msg.contains("timeout"));

        // Verify the registry was cleaned up
        let registry = PENDING_FUTURES.lock().unwrap();
        assert!(!registry.contains_key(&12345));
    }


    /// Test that completing a future removes it from registry
    #[test]
    fn test_future_registry_cleanup_on_completion() {
        // Manually add a future to the registry
        let (tx, mut rx) = oneshot::channel::<String>();
        let future_id = 88888;

        {
            let mut registry = PENDING_FUTURES.lock().unwrap();
            registry.insert(future_id, tx);
            assert!(registry.contains_key(&future_id));
        }

        // Complete the future
        let result_json = CString::new("\"test_result\"").unwrap();
        let ret = rhai_complete_future(future_id, result_json.as_ptr());

        // Should succeed
        assert_eq!(ret, 0);

        // Verify it was removed from registry
        let registry = PENDING_FUTURES.lock().unwrap();
        assert!(!registry.contains_key(&future_id));
        
        // Also verify the result was received
        drop(registry);
        let result = rx.try_recv();
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), "\"test_result\"");
    }

    /// Test that completing a nonexistent future returns error
    #[test]
    fn test_complete_nonexistent_future() {
        let nonexistent_id = 77777;
        let result_json = CString::new("\"test_result\"").unwrap();

        let ret = rhai_complete_future(nonexistent_id, result_json.as_ptr());

        // Should return -1 for not found
        assert_eq!(ret, -1);
    }


    /// Test custom timeout configuration
    #[test]
    fn test_custom_timeout_in_callback_info() {
        // Test that we can create CallbackInfo with different timeout values
        extern "C" fn dummy_callback(_id: i64, _args: *const c_char) -> *mut c_char {
            std::ptr::null_mut()
        }
        
        let info = CallbackInfo {
            callback_id: 123,
            callback_ptr: dummy_callback,
            async_timeout_seconds: 60,
            function_name: "test_function".to_string(),
        };
        
        assert_eq!(info.async_timeout_seconds, 60);
    }
}
