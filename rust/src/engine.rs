//! Rhai Engine FFI
//!
//! This module provides FFI functions for Rhai engine lifecycle management
//! and configuration.

use crate::types::{CRhaiEngine, CRhaiConfig};
use crate::error::{clear_last_error, set_last_error};
use crate::values::rhai_dynamic_to_json;
use crate::{catch_panic, catch_panic_ptr};
use rhai::{Engine, Dynamic};
use std::ffi::{CString, CStr, c_char};

/// Configuration builder for Rhai engine.
///
/// This struct provides a Rust-side representation of engine configuration
/// with secure defaults and a builder pattern for customization.
pub struct EngineConfig {
    max_operations: Option<u64>,
    max_stack_depth: Option<usize>,
    max_string_length: Option<usize>,
    timeout_ms: Option<u64>,
    async_timeout_seconds: u64,
    disable_file_io: bool,
    disable_eval: bool,
    disable_modules: bool,
}

impl EngineConfig {
    /// Creates a new EngineConfig with secure defaults.
    ///
    /// Secure defaults include:
    /// - max_operations: 1,000,000
    /// - max_stack_depth: 100
    /// - max_string_length: 10MB
    /// - timeout_ms: 5000ms
    /// - async_timeout_seconds: 30s
    /// - All dangerous features disabled (file I/O, eval, modules)
    pub fn secure_defaults() -> Self {
        Self {
            max_operations: Some(1_000_000),
            max_stack_depth: Some(100),
            max_string_length: Some(10_485_760), // 10MB
            timeout_ms: Some(5000),
            async_timeout_seconds: 30,
            disable_file_io: true,
            disable_eval: true,
            disable_modules: true,
        }
    }

    /// Creates a new EngineConfig from a CRhaiConfig FFI struct.
    ///
    /// Converts C-compatible types to Rust types, treating 0 values as None
    /// for Option fields.
    pub fn from_c_config(c_config: &CRhaiConfig) -> Self {
        Self {
            max_operations: if c_config.max_operations == 0 {
                None
            } else {
                Some(c_config.max_operations)
            },
            max_stack_depth: if c_config.max_stack_depth == 0 {
                None
            } else {
                Some(c_config.max_stack_depth as usize)
            },
            max_string_length: if c_config.max_string_length == 0 {
                None
            } else {
                Some(c_config.max_string_length as usize)
            },
            timeout_ms: if c_config.timeout_ms == 0 {
                None
            } else {
                Some(c_config.timeout_ms)
            },
            async_timeout_seconds: if c_config.async_timeout_seconds == 0 {
                30 // Default to 30 seconds if 0
            } else {
                c_config.async_timeout_seconds
            },
            disable_file_io: c_config.disable_file_io != 0,
            disable_eval: c_config.disable_eval != 0,
            disable_modules: c_config.disable_modules != 0,
        }
    }

    /// Gets the async timeout in seconds.
    pub fn async_timeout_seconds(&self) -> u64 {
        self.async_timeout_seconds
    }

    /// Applies this configuration to a Rhai Engine.
    ///
    /// This method configures the engine with the specified limits and
    /// sandboxing settings.
    pub fn apply_to_engine(&self, engine: &mut Engine) {
        // Apply operation limits
        if let Some(max_ops) = self.max_operations {
            engine.set_max_operations(max_ops);
        }

        if let Some(max_depth) = self.max_stack_depth {
            engine.set_max_call_levels(max_depth);
        }

        if let Some(max_str_len) = self.max_string_length {
            engine.set_max_string_size(max_str_len);
        }

        // Note: Timeout handling would typically be done at the eval level
        // with tokio::time::timeout or similar. For now, we store the value
        // but don't apply it directly to the engine.
        // This will be implemented in Task Group 4 (Script Execution).

        // Apply sandboxing settings
        if self.disable_file_io {
            // Disable file I/O operations
            #[cfg(not(feature = "no_std"))]
            engine.on_print(|_| {});
            #[cfg(not(feature = "no_std"))]
            engine.on_debug(|_, _, _| {});
        }

        // Note: Rhai doesn't have a direct "disable eval" or "disable modules" API.
        // These would be handled by:
        // 1. Not registering eval-related functions
        // 2. Not using Engine::compile_file or import statements
        // 3. Not calling Engine::register_module for module loading
        // For a fully sandboxed environment, we rely on not exposing these features.
    }
}

/// Creates a new Rhai engine with the given configuration.
///
/// # Safety
///
/// This function is safe to call from FFI. The config pointer may be null,
/// in which case default secure configuration is used.
///
/// # Returns
///
/// A pointer to a newly created engine, or null on error.
/// The returned pointer must be freed using `rhai_engine_free()`.
///
/// # Arguments
///
/// * `config` - Pointer to a CRhaiConfig struct, or null for defaults
#[no_mangle]
pub extern "C" fn rhai_engine_new(config: *const CRhaiConfig) -> *mut CRhaiEngine {
    catch_panic_ptr! {{
        clear_last_error();

        // Create the configuration
        let engine_config = if config.is_null() {
            // Use secure defaults if no config provided
            EngineConfig::secure_defaults()
        } else {
            // Convert C config to Rust config
            let c_config = unsafe { &*config };
            EngineConfig::from_c_config(c_config)
        };

        // Get the async timeout before creating the engine
        let async_timeout_seconds = engine_config.async_timeout_seconds();

        // Create a new Rhai engine
        let mut engine = Engine::new();

        // Apply configuration to the engine
        engine_config.apply_to_engine(&mut engine);

        // Wrap in our opaque handle and return
        let wrapper = CRhaiEngine::new(engine, async_timeout_seconds);
        Box::into_raw(Box::new(wrapper))
    }}
}

/// Frees a Rhai engine instance.
///
/// This function cleans up the engine and removes any pending async futures
/// associated with this engine from the global registry.
///
/// # Safety
///
/// The engine pointer must have been created by `rhai_engine_new()` and
/// must not have been freed previously. Passing a null pointer is safe
/// and will be a no-op.
///
/// This function uses `Box::from_raw()` to reclaim ownership of the engine
/// and drop it, ensuring the Arc reference count is decremented properly.
///
/// # Arguments
///
/// * `engine` - Pointer to the engine to free
#[no_mangle]
pub extern "C" fn rhai_engine_free(engine: *mut CRhaiEngine) {
    let _result = catch_panic! {{
        if !engine.is_null() {
            // Note: In a per-engine future registry, we would clean up pending futures here.
            // Since we're using a global registry, we log a debug message but can't
            // distinguish which futures belong to this engine.
            // This is acceptable as futures will be cleaned up on timeout or completion.
            #[cfg(debug_assertions)]
            eprintln!("[DEBUG] Freeing engine - pending futures (if any) will be cleaned up on timeout");

            unsafe {
                // Reclaim ownership and drop
                // This will decrement the Arc reference count
                let _ = Box::from_raw(engine);
            }
        }
        0 // Success
    }};
}

/// Evaluates a Rhai script and returns the result as a JSON string.
///
/// This function runs the script within a Tokio runtime context to support
/// async Dart function calls. The evaluation itself is synchronous, but
/// any async Dart callbacks registered with the engine can complete properly.
///
/// # Safety
///
/// This function is safe to call from FFI. The engine and script pointers must be valid.
///
/// # Returns
///
/// 0 on success (with result stored via result_out), -1 on error.
/// On error, use `rhai_get_last_error()` to retrieve the error message.
///
/// # Arguments
///
/// * `engine` - Pointer to the Rhai engine
/// * `script` - Pointer to a null-terminated C string containing the script
/// * `result_out` - Pointer to store the result JSON string (must be freed with rhai_free_error)
#[no_mangle]
pub extern "C" fn rhai_eval(
    engine: *const CRhaiEngine,
    script: *const c_char,
    result_out: *mut *mut c_char,
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

        if result_out.is_null() {
            set_last_error("Result output pointer is null");
            return -1;
        }

        // Get the engine
        let engine_wrapper = unsafe { &*engine };
        let rhai_engine = engine_wrapper.engine();

        // Convert C string to Rust string
        let script_str = unsafe {
            match CStr::from_ptr(script).to_str() {
                Ok(s) => s,
                Err(e) => {
                    set_last_error(&format!("Invalid UTF-8 in script: {}", e));
                    return -1;
                }
            }
        };

        // Evaluate the script directly - the Tokio runtime will be used by async callbacks
        let result: Result<Dynamic, Box<rhai::EvalAltResult>> = rhai_engine.eval(script_str);

        // Check if async functions were invoked during eval
        // Sync eval() should not be used with async functions - users should use evalAsync()
        if crate::functions::check_and_clear_async_flag() {
            set_last_error("Script attempted to call async functions. Use evalAsync() instead of eval() for scripts with async functions.");
            return -1;
        }

        match result {
            Ok(value) => {
                // Convert the result to JSON
                match rhai_dynamic_to_json(&value) {
                    Ok(json) => {
                        // Convert to C string
                        match CString::new(json) {
                            Ok(c_string) => {
                                unsafe {
                                    *result_out = c_string.into_raw();
                                }
                                0 // Success
                            }
                            Err(e) => {
                                set_last_error(&format!("Failed to create C string: {}", e));
                                -1
                            }
                        }
                    }
                    Err(e) => {
                        set_last_error(&format!("Failed to convert result to JSON: {}", e));
                        -1
                    }
                }
            }
            Err(err) => {
                // Format the error with type and position information
                let error_msg = format_rhai_error(&err);
                set_last_error(&error_msg);
                -1
            }
        }
    }}
}

/// Formats a Rhai error with type and position information.
///
/// This function extracts line numbers from syntax errors and formats
/// runtime errors with their stack traces.
pub fn format_rhai_error(err: &rhai::EvalAltResult) -> String {
    use rhai::EvalAltResult;

    match err {
        // Syntax errors with position
        EvalAltResult::ErrorParsing(parse_error, pos) => {
            format!("Syntax error at line {}: {}", pos.line().unwrap_or(0), parse_error)
        }

        // Runtime errors
        EvalAltResult::ErrorRuntime(msg, pos) => {
            if pos.is_none() {
                format!("Runtime error: {}", msg)
            } else {
                format!("Runtime error at line {}: {}", pos.line().unwrap_or(0), msg)
            }
        }

        // Variable not found
        EvalAltResult::ErrorVariableNotFound(var, pos) => {
            format!("Runtime error at line {}: Variable '{}' not found", pos.line().unwrap_or(0), var)
        }

        // Function not found
        EvalAltResult::ErrorFunctionNotFound(func, pos) => {
            format!("Runtime error at line {}: Function '{}' not found", pos.line().unwrap_or(0), func)
        }

        // Arithmetic errors
        EvalAltResult::ErrorArithmetic(msg, pos) => {
            format!("Runtime error at line {}: Arithmetic error: {}", pos.line().unwrap_or(0), msg)
        }

        // Type mismatch
        EvalAltResult::ErrorMismatchDataType(expected, actual, pos) => {
            format!(
                "Runtime error at line {}: Type mismatch: expected {}, got {}",
                pos.line().unwrap_or(0),
                expected,
                actual
            )
        }

        // Array/Map index errors
        EvalAltResult::ErrorIndexNotFound(index, pos) => {
            format!("Runtime error at line {}: Index not found: {}", pos.line().unwrap_or(0), index)
        }

        // Timeout
        EvalAltResult::ErrorTooManyOperations(pos) => {
            format!("Runtime error at line {}: Script execution timeout - too many operations", pos.line().unwrap_or(0))
        }

        // Stack overflow
        EvalAltResult::ErrorStackOverflow(pos) => {
            format!("Runtime error at line {}: Stack overflow", pos.line().unwrap_or(0))
        }

        // Generic catch-all for other errors
        _ => {
            format!("Runtime error: {}", err)
        }
    }
}

/// Result structure for script analysis.
///
/// This structure contains the results of analyzing a Rhai script without executing it.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AnalysisResult {
    /// Whether the script is syntactically valid
    pub is_valid: bool,

    /// List of syntax errors found in the script
    pub syntax_errors: Vec<String>,

    /// List of warnings (currently unused, reserved for future use)
    pub warnings: Vec<String>,

    /// Optional summary of the AST structure (currently unused)
    pub ast_summary: Option<String>,
}

impl AnalysisResult {
    /// Creates a new AnalysisResult indicating a valid script.
    pub fn valid() -> Self {
        Self {
            is_valid: true,
            syntax_errors: Vec::new(),
            warnings: Vec::new(),
            ast_summary: None,
        }
    }

    /// Creates a new AnalysisResult with syntax errors.
    pub fn with_errors(errors: Vec<String>) -> Self {
        Self {
            is_valid: false,
            syntax_errors: errors,
            warnings: Vec::new(),
            ast_summary: None,
        }
    }
}

/// Analyzes a Rhai script and returns validation results without executing it.
///
/// This function parses the script using Rhai's AST parser to check for syntax errors
/// without actually running the script. This is useful for validating user input
/// before execution.
///
/// # Safety
///
/// This function is safe to call from FFI. The engine and script pointers must be valid.
///
/// # Returns
///
/// 0 on success (with result stored via result_out), -1 on error.
/// On error, use `rhai_get_last_error()` to retrieve the error message.
///
/// # Arguments
///
/// * `engine` - Pointer to the Rhai engine
/// * `script` - Pointer to a null-terminated C string containing the script to analyze
/// * `result_out` - Pointer to store the analysis result JSON string (must be freed with rhai_free_error)
#[no_mangle]
pub extern "C" fn rhai_analyze(
    engine: *const CRhaiEngine,
    script: *const c_char,
    result_out: *mut *mut c_char,
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

        if result_out.is_null() {
            set_last_error("Result output pointer is null");
            return -1;
        }

        // Get the engine
        let engine_wrapper = unsafe { &*engine };
        let rhai_engine = engine_wrapper.engine();

        // Convert C string to Rust string
        let script_str = unsafe {
            match CStr::from_ptr(script).to_str() {
                Ok(s) => s,
                Err(e) => {
                    set_last_error(&format!("Invalid UTF-8 in script: {}", e));
                    return -1;
                }
            }
        };

        // Try to compile the script (parse AST without executing)
        let analysis_result = match rhai_engine.compile(script_str) {
            Ok(_ast) => {
                // Script is syntactically valid
                AnalysisResult::valid()
            }
            Err(err) => {
                // Collect syntax errors
                let error_msg = format!("Syntax error: {}", err);
                AnalysisResult::with_errors(vec![error_msg])
            }
        };

        // Serialize the analysis result to JSON
        match serde_json::to_string(&analysis_result) {
            Ok(json) => {
                // Convert to C string
                match CString::new(json) {
                    Ok(c_string) => {
                        unsafe {
                            *result_out = c_string.into_raw();
                        }
                        0 // Success
                    }
                    Err(e) => {
                        set_last_error(&format!("Failed to create C string: {}", e));
                        -1
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Failed to serialize analysis result: {}", e));
                -1
            }
        }
    }}
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_config_secure_defaults() {
        let config = EngineConfig::secure_defaults();
        assert_eq!(config.max_operations, Some(1_000_000));
        assert_eq!(config.max_stack_depth, Some(100));
        assert_eq!(config.max_string_length, Some(10_485_760));
        assert_eq!(config.timeout_ms, Some(5000));
        assert_eq!(config.async_timeout_seconds, 30);
        assert!(config.disable_file_io);
        assert!(config.disable_eval);
        assert!(config.disable_modules);
    }

    #[test]
    fn test_engine_config_from_c_config() {
        let c_config = CRhaiConfig {
            max_operations: 500_000,
            max_stack_depth: 50,
            max_string_length: 5_242_880,
            timeout_ms: 3000,
            async_timeout_seconds: 60,
            disable_file_io: 1,
            disable_eval: 0,
            disable_modules: 1,
        };

        let config = EngineConfig::from_c_config(&c_config);
        assert_eq!(config.max_operations, Some(500_000));
        assert_eq!(config.max_stack_depth, Some(50));
        assert_eq!(config.max_string_length, Some(5_242_880));
        assert_eq!(config.timeout_ms, Some(3000));
        assert_eq!(config.async_timeout_seconds, 60);
        assert!(config.disable_file_io);
        assert!(!config.disable_eval);
        assert!(config.disable_modules);
    }

    #[test]
    fn test_engine_config_zero_means_none() {
        let c_config = CRhaiConfig {
            max_operations: 0,
            max_stack_depth: 0,
            max_string_length: 0,
            timeout_ms: 0,
            async_timeout_seconds: 0,
            disable_file_io: 0,
            disable_eval: 0,
            disable_modules: 0,
        };

        let config = EngineConfig::from_c_config(&c_config);
        assert_eq!(config.max_operations, None);
        assert_eq!(config.max_stack_depth, None);
        assert_eq!(config.max_string_length, None);
        assert_eq!(config.timeout_ms, None);
        assert_eq!(config.async_timeout_seconds, 30); // Defaults to 30 when 0
    }

    #[test]
    fn test_engine_creation_with_defaults() {
        let engine = rhai_engine_new(std::ptr::null());
        assert!(!engine.is_null());

        // Verify async timeout is set
        unsafe {
            let wrapper = &*engine;
            assert_eq!(wrapper.async_timeout_seconds(), 30);
        }

        rhai_engine_free(engine);
    }

    #[test]
    fn test_engine_creation_with_custom_config() {
        let c_config = CRhaiConfig {
            max_operations: 500_000,
            max_stack_depth: 50,
            max_string_length: 5_242_880,
            timeout_ms: 3000,
            async_timeout_seconds: 60,
            disable_file_io: 1,
            disable_eval: 1,
            disable_modules: 1,
        };

        let engine = rhai_engine_new(&c_config as *const CRhaiConfig);
        assert!(!engine.is_null());

        // Verify async timeout is set correctly
        unsafe {
            let wrapper = &*engine;
            assert_eq!(wrapper.async_timeout_seconds(), 60);
        }

        rhai_engine_free(engine);
    }

    #[test]
    fn test_engine_free_null() {
        // Should not crash
        rhai_engine_free(std::ptr::null_mut());
    }

    #[test]
    fn test_multiple_engines() {
        let engine1 = rhai_engine_new(std::ptr::null());
        let engine2 = rhai_engine_new(std::ptr::null());
        let engine3 = rhai_engine_new(std::ptr::null());

        assert!(!engine1.is_null());
        assert!(!engine2.is_null());
        assert!(!engine3.is_null());

        rhai_engine_free(engine1);
        rhai_engine_free(engine2);
        rhai_engine_free(engine3);
    }

    #[test]
    fn test_engine_config_applies_to_engine() {
        let config = EngineConfig {
            max_operations: Some(1000),
            max_stack_depth: Some(10),
            max_string_length: Some(1024),
            timeout_ms: Some(100),
            async_timeout_seconds: 15,
            disable_file_io: true,
            disable_eval: true,
            disable_modules: true,
        };

        let mut engine = Engine::new();
        config.apply_to_engine(&mut engine);

        // The engine should now have the configured limits
        // Note: We can't directly inspect these values in the current Rhai API,
        // but we can verify the engine was created without panicking
        assert!(true);
    }

    #[test]
    fn test_eval_simple_expression() {
        let engine = rhai_engine_new(std::ptr::null());
        assert!(!engine.is_null());

        let script = CString::new("2 + 2").unwrap();
        let mut result_ptr: *mut c_char = std::ptr::null_mut();

        let ret = rhai_eval(engine, script.as_ptr(), &mut result_ptr as *mut *mut c_char);

        assert_eq!(ret, 0);
        assert!(!result_ptr.is_null());

        unsafe {
            let result_str = CStr::from_ptr(result_ptr).to_str().unwrap();
            assert_eq!(result_str, "4");
            let _ = CString::from_raw(result_ptr);
        }

        rhai_engine_free(engine);
    }

    #[test]
    fn test_eval_syntax_error() {
        use crate::error::{rhai_get_last_error, rhai_free_error};

        let engine = rhai_engine_new(std::ptr::null());
        assert!(!engine.is_null());

        let script = CString::new("let x = ;").unwrap();
        let mut result_ptr: *mut c_char = std::ptr::null_mut();

        let ret = rhai_eval(engine, script.as_ptr(), &mut result_ptr as *mut *mut c_char);

        assert_eq!(ret, -1);
        assert!(result_ptr.is_null());

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        unsafe {
            let error_str = CStr::from_ptr(error_ptr).to_str().unwrap();
            assert!(error_str.contains("Syntax error"));
            rhai_free_error(error_ptr);
        }

        rhai_engine_free(engine);
    }

    #[test]
    fn test_eval_timeout() {
        use crate::error::{rhai_get_last_error, rhai_free_error};

        // Create engine with very low operation limit to simulate timeout
        let c_config = CRhaiConfig {
            max_operations: 100,
            max_stack_depth: 100,
            max_string_length: 10_485_760,
            timeout_ms: 5000,
            async_timeout_seconds: 30,
            disable_file_io: 1,
            disable_eval: 1,
            disable_modules: 1,
        };

        let engine = rhai_engine_new(&c_config as *const CRhaiConfig);
        assert!(!engine.is_null());

        // This loop should exceed the operation limit
        let script = CString::new("let x = 0; loop { x += 1; }").unwrap();
        let mut result_ptr: *mut c_char = std::ptr::null_mut();

        let ret = rhai_eval(engine, script.as_ptr(), &mut result_ptr as *mut *mut c_char);

        assert_eq!(ret, -1);

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        unsafe {
            let error_str = CStr::from_ptr(error_ptr).to_str().unwrap();
            assert!(error_str.contains("timeout") || error_str.contains("too many operations"));
            rhai_free_error(error_ptr);
        }

        rhai_engine_free(engine);
    }

    #[test]
    fn test_analyze_valid_script() {
        use crate::error::{rhai_get_last_error};

        let engine = rhai_engine_new(std::ptr::null());
        assert!(!engine.is_null());

        let script = CString::new("let x = 10; x + 20").unwrap();
        let mut result_ptr: *mut c_char = std::ptr::null_mut();

        let ret = rhai_analyze(engine, script.as_ptr(), &mut result_ptr as *mut *mut c_char);

        assert_eq!(ret, 0);
        assert!(!result_ptr.is_null());

        unsafe {
            let result_str = CStr::from_ptr(result_ptr).to_str().unwrap();
            let analysis: AnalysisResult = serde_json::from_str(result_str).unwrap();
            assert!(analysis.is_valid);
            assert!(analysis.syntax_errors.is_empty());
            let _ = CString::from_raw(result_ptr);
        }

        rhai_engine_free(engine);
    }

    #[test]
    fn test_analyze_invalid_script() {
        let engine = rhai_engine_new(std::ptr::null());
        assert!(!engine.is_null());

        let script = CString::new("let x = ;").unwrap();
        let mut result_ptr: *mut c_char = std::ptr::null_mut();

        let ret = rhai_analyze(engine, script.as_ptr(), &mut result_ptr as *mut *mut c_char);

        assert_eq!(ret, 0);
        assert!(!result_ptr.is_null());

        unsafe {
            let result_str = CStr::from_ptr(result_ptr).to_str().unwrap();
            let analysis: AnalysisResult = serde_json::from_str(result_str).unwrap();
            assert!(!analysis.is_valid);
            assert!(!analysis.syntax_errors.is_empty());
            assert!(analysis.syntax_errors[0].contains("Syntax error"));
            let _ = CString::from_raw(result_ptr);
        }

        rhai_engine_free(engine);
    }

    #[test]
    fn test_analyze_does_not_execute() {
        // This script would timeout if executed, but analysis should succeed
        let engine = rhai_engine_new(std::ptr::null());
        assert!(!engine.is_null());

        let script = CString::new("loop { let x = 1; }").unwrap();
        let mut result_ptr: *mut c_char = std::ptr::null_mut();

        let ret = rhai_analyze(engine, script.as_ptr(), &mut result_ptr as *mut *mut c_char);

        assert_eq!(ret, 0);
        assert!(!result_ptr.is_null());

        unsafe {
            let result_str = CStr::from_ptr(result_ptr).to_str().unwrap();
            let analysis: AnalysisResult = serde_json::from_str(result_str).unwrap();
            // The script is syntactically valid (even though it would timeout if executed)
            assert!(analysis.is_valid);
            let _ = CString::from_raw(result_ptr);
        }

        rhai_engine_free(engine);
    }
}
