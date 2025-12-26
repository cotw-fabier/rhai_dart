//! Function registration and callback management
//!
//! This module provides FFI functions for registering Dart callbacks with the Rhai engine
//! and managing the callback invocation bridge.

use crate::types::CRhaiEngine;
use crate::error::clear_last_error;
use crate::{catch_panic};
use rhai::{Dynamic, Engine};
use std::ffi::{CString, CStr, c_char};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;

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
}

lazy_static::lazy_static! {
    /// Global registry of callback information.
    ///
    /// This maps function names to their callback information.
    /// We use Arc<Mutex<>> for thread-safe access since Rhai engine might be used
    /// from multiple threads.
    static ref CALLBACK_REGISTRY: Arc<Mutex<HashMap<String, CallbackInfo>>> =
        Arc::new(Mutex::new(HashMap::new()));
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
            crate::error::set_last_error("Engine pointer is null");
            return -1;
        }

        if name.is_null() {
            crate::error::set_last_error("Function name pointer is null");
            return -1;
        }

        // Get the engine (mutable reference needed to register functions)
        let engine_wrapper = unsafe { &mut *engine };

        // Convert function name to Rust string
        let func_name = unsafe {
            match CStr::from_ptr(name).to_str() {
                Ok(s) => s.to_string(),
                Err(e) => {
                    crate::error::set_last_error(&format!("Invalid UTF-8 in function name: {}", e));
                    return -1;
                }
            }
        };

        // Store callback info in registry
        let callback_info = CallbackInfo {
            callback_id,
            callback_ptr,
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
fn register_function_overloads(engine: &mut Engine, name: &str, info: CallbackInfo) {
    // Register 0-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move || {
            invoke_dart_callback_vec(&info, vec![])
        });
    }

    // Register 1-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1])
        });
    }

    // Register 2-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2])
        });
    }

    // Register 3-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3])
        });
    }

    // Register 4-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3, a4])
        });
    }

    // Register 5-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3, a4, a5])
        });
    }

    // Register 6-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3, a4, a5, a6])
        });
    }

    // Register 7-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3, a4, a5, a6, a7])
        });
    }

    // Register 8-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic, a8: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3, a4, a5, a6, a7, a8])
        });
    }

    // Register 9-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic, a8: Dynamic, a9: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3, a4, a5, a6, a7, a8, a9])
        });
    }

    // Register 10-parameter version
    {
        let info = info.clone();
        engine.register_fn(name, move |a1: Dynamic, a2: Dynamic, a3: Dynamic, a4: Dynamic, a5: Dynamic, a6: Dynamic, a7: Dynamic, a8: Dynamic, a9: Dynamic, a10: Dynamic| {
            invoke_dart_callback_vec(&info, vec![a1, a2, a3, a4, a5, a6, a7, a8, a9, a10])
        });
    }
}

/// Invokes a Dart callback with arguments as a Vec<Dynamic>.
///
/// This is a helper function that takes owned Dynamic values instead of mutable references.
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
/// JSON array string representation of the arguments
fn convert_args_to_json(args: &[Dynamic]) -> Result<String, String> {
    let mut json_values = Vec::new();

    for arg in args {
        let json_str = crate::values::rhai_dynamic_to_json(arg)?;
        let json_value: serde_json::Value = serde_json::from_str(&json_str)
            .map_err(|e| format!("Failed to parse arg as JSON: {}", e))?;
        json_values.push(json_value);
    }

    serde_json::to_string(&json_values)
        .map_err(|e| format!("Failed to serialize args array: {}", e))
}

#[cfg(test)]
mod tests {
    use super::*;

    // Mock Dart callback for testing
    extern "C" fn mock_dart_callback(_callback_id: i64, args_json: *const c_char) -> *mut c_char {
        // Parse args and return a simple result
        let _args_str = unsafe { CStr::from_ptr(args_json).to_str().unwrap() };

        // For testing, just echo back the first argument or return a fixed value
        let result = r#"{"success": true, "value": 42}"#;

        CString::new(result).unwrap().into_raw()
    }

    #[test]
    fn test_callback_registration() {
        let engine = crate::engine::rhai_engine_new(std::ptr::null());
        assert!(!engine.is_null());

        let func_name = CString::new("test_func").unwrap();
        let ret = rhai_register_function(
            engine,
            func_name.as_ptr(),
            1,
            mock_dart_callback,
        );

        assert_eq!(ret, 0);

        crate::engine::rhai_engine_free(engine);
    }

    #[test]
    fn test_convert_args_to_json() {
        let args = vec![
            Dynamic::from(42_i64),
            Dynamic::from("hello".to_string()),
            Dynamic::from(true),
        ];

        let json = convert_args_to_json(&args).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

        assert!(parsed.is_array());
        let arr = parsed.as_array().unwrap();
        assert_eq!(arr.len(), 3);
        assert_eq!(arr[0], 42);
        assert_eq!(arr[1], "hello");
        assert_eq!(arr[2], true);
    }
}
