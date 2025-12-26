//! Asynchronous eval implementation using request/response pattern.
//!
//! This module provides infrastructure for `evalAsync()` which runs scripts on
//! background threads while allowing Dart to execute async functions.
//!
//! Instead of calling Dart callbacks directly (which fails from background threads),
//! we use a request/response pattern:
//! 1. When script needs Dart function, Rust posts request and blocks
//! 2. Dart polls for requests, executes them (can be async!), posts results
//! 3. Rust receives result and resumes execution

use crate::types::CRhaiEngine;
use crate::error::{set_last_error, clear_last_error};
use crate::engine::format_rhai_error;
use crate::values::rhai_dynamic_to_json;
use crate::catch_panic;
use std::ffi::{CStr, CString, c_char};
use std::sync::{Arc, Mutex};
use std::collections::{HashMap, VecDeque};
use std::sync::atomic::{AtomicI64, Ordering};
use std::thread;
use tokio::sync::oneshot;
use std::time::Duration;

/// A request for Dart to execute a function.
#[derive(Debug, Clone)]
struct FunctionCallRequest {
    /// Unique ID for this request
    exec_id: i64,
    /// Name of the Dart function to call
    function_name: String,
    /// JSON-encoded arguments
    args_json: String,
}

/// Result of an async eval operation.
#[derive(Debug, Clone)]
enum AsyncEvalResult {
    /// Evaluation is still in progress
    InProgress,
    /// Evaluation completed successfully with a JSON result
    Success(String),
    /// Evaluation failed with an error message
    Error(String),
}

lazy_static::lazy_static! {
    /// Queue of pending function call requests.
    ///
    /// When a Rhai script calls a Dart function from a background thread,
    /// the request is posted here. Dart polls this queue and executes the functions.
    static ref PENDING_FUNCTION_REQUESTS: Arc<Mutex<VecDeque<FunctionCallRequest>>> =
        Arc::new(Mutex::new(VecDeque::new()));

    /// Registry of response channels for function calls.
    ///
    /// When Dart finishes executing a function, it posts the result via FFI.
    /// The result is sent through the oneshot channel, waking up the waiting Rust thread.
    static ref FUNCTION_RESPONSE_CHANNELS: Arc<Mutex<HashMap<i64, oneshot::Sender<String>>>> =
        Arc::new(Mutex::new(HashMap::new()));

    /// Registry of async eval results.
    ///
    /// Maps eval IDs to their results. Background threads store results here,
    /// and Dart polls to retrieve them.
    static ref ASYNC_EVAL_RESULTS: Arc<Mutex<HashMap<i64, AsyncEvalResult>>> =
        Arc::new(Mutex::new(HashMap::new()));
}

/// Atomic counter for generating unique function request IDs.
static NEXT_REQUEST_ID: AtomicI64 = AtomicI64::new(1);

/// Atomic counter for generating unique async eval IDs.
static NEXT_ASYNC_EVAL_ID: AtomicI64 = AtomicI64::new(1);

/// Requests execution of a Dart function and waits for the result.
///
/// This function posts a request to the global queue and blocks waiting for
/// Dart to provide the result. The calling thread (background eval thread)
/// is blocked, but the Dart main thread remains free to handle async work.
///
/// # Arguments
///
/// * `function_name` - Name of the Dart function to call
/// * `args_json` - JSON-encoded arguments
///
/// # Returns
///
/// JSON-encoded result from the Dart function, or error message
pub async fn request_dart_function_execution(
    function_name: String,
    args_json: String,
) -> Result<String, String> {
    let request_id = NEXT_REQUEST_ID.fetch_add(1, Ordering::SeqCst);

    // Create oneshot channel for response
    let (tx, rx) = oneshot::channel();

    // Store response channel
    {
        let mut channels = FUNCTION_RESPONSE_CHANNELS.lock().unwrap();
        channels.insert(request_id, tx);
    }

    // Post request to queue
    let request = FunctionCallRequest {
        exec_id: request_id,
        function_name,
        args_json,
    };
    {
        let mut requests = PENDING_FUNCTION_REQUESTS.lock().unwrap();
        requests.push_back(request);
    }

    // Wait for Dart to provide result (with timeout)
    match tokio::time::timeout(Duration::from_secs(30), rx).await {
        Ok(Ok(result)) => Ok(result),
        Ok(Err(_)) => Err("Response channel closed unexpectedly".into()),
        Err(_) => {
            // Clean up on timeout
            let mut channels = FUNCTION_RESPONSE_CHANNELS.lock().unwrap();
            channels.remove(&request_id);
            Err("Function call timed out after 30 seconds".into())
        }
    }
}

/// Get a pending function call request (polled by Dart).
///
/// Dart calls this repeatedly to check for pending function requests.
/// If a request is available, it's removed from the queue and returned.
///
/// # Safety
///
/// Safe to call from FFI when pointers are valid.
///
/// # Arguments
///
/// * `exec_id_out` - Pointer to store the request ID
/// * `function_name_out` - Pointer to store the function name C string
/// * `args_json_out` - Pointer to store the args JSON C string
///
/// # Returns
///
/// 0 if request was retrieved, -1 if no pending requests
#[no_mangle]
pub extern "C" fn rhai_get_pending_function_request(
    exec_id_out: *mut i64,
    function_name_out: *mut *mut c_char,
    args_json_out: *mut *mut c_char,
) -> i32 {
    catch_panic! {{
        clear_last_error();

        // Validate pointers
        if exec_id_out.is_null() {
            set_last_error("Exec ID output pointer is null");
            return -1;
        }

        if function_name_out.is_null() {
            set_last_error("Function name output pointer is null");
            return -1;
        }

        if args_json_out.is_null() {
            set_last_error("Args JSON output pointer is null");
            return -1;
        }

        // Try to pop a request from the queue
        let request = {
            let mut requests = PENDING_FUNCTION_REQUESTS.lock().unwrap();
            requests.pop_front()
        };

        match request {
            Some(req) => {
                // Store exec_id
                unsafe {
                    *exec_id_out = req.exec_id;
                }

                // Convert function name to C string
                match CString::new(req.function_name) {
                    Ok(c_fn_name) => {
                        unsafe {
                            *function_name_out = c_fn_name.into_raw();
                        }
                    }
                    Err(e) => {
                        set_last_error(&format!("Failed to create function name C string: {}", e));
                        return -1;
                    }
                }

                // Convert args JSON to C string
                match CString::new(req.args_json) {
                    Ok(c_args) => {
                        unsafe {
                            *args_json_out = c_args.into_raw();
                        }
                    }
                    Err(e) => {
                        set_last_error(&format!("Failed to create args JSON C string: {}", e));
                        // Free the function name string we already allocated
                        unsafe {
                            let _ = CString::from_raw(*function_name_out);
                        }
                        return -1;
                    }
                }

                0 // Success - request retrieved
            }
            None => {
                -1 // No pending requests
            }
        }
    }}
}

/// Provide a function call result (called by Dart after executing function).
///
/// When Dart finishes executing a requested function, it calls this to provide
/// the result. This sends the result through the oneshot channel, waking up
/// the waiting Rust background thread.
///
/// # Safety
///
/// Safe to call from FFI when pointers are valid.
///
/// # Arguments
///
/// * `exec_id` - The request ID
/// * `result_json` - JSON-encoded result or error
///
/// # Returns
///
/// 0 on success, -1 if exec_id not found or on error
#[no_mangle]
pub extern "C" fn rhai_provide_function_result(
    exec_id: i64,
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

        // Look up and remove the response channel
        let sender = {
            let mut channels = FUNCTION_RESPONSE_CHANNELS.lock().unwrap();
            channels.remove(&exec_id)
        };

        match sender {
            Some(tx) => {
                // Send result through channel (wakes up Rust thread!)
                if tx.send(result_str).is_err() {
                    set_last_error("Failed to send result through channel (receiver dropped)");
                    return -1;
                }
                0 // Success
            }
            None => {
                set_last_error(&format!("Function request ID not found: {}", exec_id));
                -1 // ID not found
            }
        }
    }}
}

/// Starts an async evaluation on a background thread.
///
/// This spawns a new thread to evaluate the script. The thread will post
/// function call requests when needed, and Dart will fulfill them.
///
/// # Safety
///
/// Safe to call from FFI when pointers are valid.
///
/// # Arguments
///
/// * `engine` - Pointer to the Rhai engine
/// * `script` - Pointer to the script string
/// * `eval_id_out` - Pointer to store the unique eval ID
///
/// # Returns
///
/// 0 on success (eval started), -1 on error
#[no_mangle]
pub extern "C" fn rhai_eval_async_start(
    engine: *const CRhaiEngine,
    script: *const c_char,
    eval_id_out: *mut i64,
) -> i32 {
    catch_panic! {{
        clear_last_error();

        // Validate pointers
        if engine.is_null() {
            set_last_error("Engine pointer is null");
            return -1;
        }

        if script.is_null() {
            set_last_error("Script pointer is null");
            return -1;
        }

        if eval_id_out.is_null() {
            set_last_error("Eval ID output pointer is null");
            return -1;
        }

        // Convert script to Rust string
        let script_str = unsafe {
            match CStr::from_ptr(script).to_str() {
                Ok(s) => s.to_string(),
                Err(e) => {
                    set_last_error(&format!("Invalid UTF-8 in script: {}", e));
                    return -1;
                }
            }
        };

        // Get engine wrapper and clone Arc
        let engine_wrapper = unsafe { &*engine };
        let engine_arc = engine_wrapper.inner.clone();

        // Generate unique eval ID
        let eval_id = NEXT_ASYNC_EVAL_ID.fetch_add(1, Ordering::SeqCst);

        // Mark eval as in progress
        {
            let mut results = ASYNC_EVAL_RESULTS.lock().unwrap();
            results.insert(eval_id, AsyncEvalResult::InProgress);
        }

        // Spawn background thread to execute eval
        thread::spawn(move || {
            // Set async eval mode for this thread
            crate::functions::set_async_eval_mode(true);

            // Execute the script
            let result = engine_arc.eval::<rhai::Dynamic>(&script_str);

            // Clear async eval mode
            crate::functions::set_async_eval_mode(false);

            // Store the result in the registry
            let async_result = match result {
                Ok(value) => {
                    // Convert to JSON
                    match rhai_dynamic_to_json(&value) {
                        Ok(json) => AsyncEvalResult::Success(json),
                        Err(e) => AsyncEvalResult::Error(format!("Failed to convert result to JSON: {}", e)),
                    }
                }
                Err(err) => {
                    // Format error with line numbers
                    let error_msg = format_rhai_error(&err);
                    AsyncEvalResult::Error(error_msg)
                }
            };

            // Store result in registry
            let mut results = ASYNC_EVAL_RESULTS.lock().unwrap();
            results.insert(eval_id, async_result);
        });

        // Return eval ID to caller
        unsafe {
            *eval_id_out = eval_id;
        }

        0 // Success
    }}
}

/// Polls for the result of an async evaluation.
///
/// Dart calls this to check if an async eval has completed.
///
/// # Safety
///
/// Safe to call from FFI when pointers are valid.
///
/// # Arguments
///
/// * `eval_id` - The unique ID of the async eval
/// * `status_out` - Pointer to store status (0=in_progress, 1=success, 2=error)
/// * `result_out` - Pointer to store the result string
///
/// # Returns
///
/// 0 on success, -1 on error
#[no_mangle]
pub extern "C" fn rhai_eval_async_poll(
    eval_id: i64,
    status_out: *mut i32,
    result_out: *mut *mut c_char,
) -> i32 {
    catch_panic! {{
        clear_last_error();

        // Validate pointers
        if status_out.is_null() {
            set_last_error("Status output pointer is null");
            return -1;
        }

        if result_out.is_null() {
            set_last_error("Result output pointer is null");
            return -1;
        }

        // Look up the eval result
        let result = {
            let results = ASYNC_EVAL_RESULTS.lock().unwrap();
            match results.get(&eval_id) {
                Some(r) => r.clone(),
                None => {
                    set_last_error(&format!("Invalid eval ID: {}", eval_id));
                    return -1;
                }
            }
        };

        // Set status and result based on current state
        match result {
            AsyncEvalResult::InProgress => {
                unsafe {
                    *status_out = 0; // In progress
                    *result_out = std::ptr::null_mut();
                }
                0
            }
            AsyncEvalResult::Success(json) => {
                unsafe {
                    *status_out = 1; // Success
                    match CString::new(json) {
                        Ok(c_string) => {
                            *result_out = c_string.into_raw();
                        }
                        Err(e) => {
                            set_last_error(&format!("Failed to create C string: {}", e));
                            return -1;
                        }
                    }
                }

                // Clean up the registry entry
                let mut results = ASYNC_EVAL_RESULTS.lock().unwrap();
                results.remove(&eval_id);

                0
            }
            AsyncEvalResult::Error(error_msg) => {
                unsafe {
                    *status_out = 2; // Error
                    match CString::new(error_msg) {
                        Ok(c_string) => {
                            *result_out = c_string.into_raw();
                        }
                        Err(e) => {
                            set_last_error(&format!("Failed to create C string: {}", e));
                            return -1;
                        }
                    }
                }

                // Clean up the registry entry
                let mut results = ASYNC_EVAL_RESULTS.lock().unwrap();
                results.remove(&eval_id);

                0
            }
        }
    }}
}

/// Cancels an async evaluation.
///
/// This removes the eval from the registry. Note: doesn't actually stop
/// the background thread, just discards the result.
///
/// # Arguments
///
/// * `eval_id` - The unique ID of the async eval to cancel
///
/// # Returns
///
/// 0 on success, -1 if eval_id not found
#[no_mangle]
pub extern "C" fn rhai_eval_async_cancel(eval_id: i64) -> i32 {
    catch_panic! {{
        let mut results = ASYNC_EVAL_RESULTS.lock().unwrap();
        if results.remove(&eval_id).is_some() {
            0 // Success
        } else {
            set_last_error(&format!("Invalid eval ID: {}", eval_id));
            -1 // Not found
        }
    }}
}
