//! FFI Safety Macros
//!
//! This module provides macros for safe FFI entry points that catch panics
//! and convert them to error codes.

/// Catches panics and converts them to FFI error codes.
///
/// This macro wraps FFI entry points to ensure that Rust panics don't
/// propagate across the FFI boundary and crash the Dart application.
///
/// # Usage
///
/// ```rust,ignore
/// #[no_mangle]
/// pub extern "C" fn my_ffi_function() -> i32 {
///     catch_panic! {{
///         // Your code here
///         0 // Return 0 on success
///     }}
/// }
/// ```
///
/// # Behavior
///
/// - On success: Returns the value from the block
/// - On panic: Sets the error message in thread-local storage and returns -1
/// - On error: The caller should check the return code and retrieve the error via `rhai_get_last_error()`
#[macro_export]
macro_rules! catch_panic {
    ({$($body:tt)*}) => {{
        use std::panic::{catch_unwind, AssertUnwindSafe};
        use $crate::error::set_last_error;

        match catch_unwind(AssertUnwindSafe(|| {
            $($body)*
        })) {
            Ok(result) => result,
            Err(panic_info) => {
                let panic_msg = if let Some(s) = panic_info.downcast_ref::<&str>() {
                    s.to_string()
                } else if let Some(s) = panic_info.downcast_ref::<String>() {
                    s.clone()
                } else {
                    "Unknown panic occurred".to_string()
                };

                set_last_error(&format!("Panic in FFI call: {}", panic_msg));
                -1
            }
        }
    }};
}

/// Catches panics in FFI functions that return pointers.
///
/// Similar to `catch_panic!` but returns a null pointer on error instead of -1.
///
/// # Usage
///
/// ```rust,ignore
/// #[no_mangle]
/// pub extern "C" fn my_ffi_function() -> *mut SomeType {
///     catch_panic_ptr! {{
///         // Your code here
///         Box::into_raw(Box::new(some_value))
///     }}
/// }
/// ```
#[macro_export]
macro_rules! catch_panic_ptr {
    ({$($body:tt)*}) => {{
        use std::panic::{catch_unwind, AssertUnwindSafe};
        use $crate::error::set_last_error;

        match catch_unwind(AssertUnwindSafe(|| {
            $($body)*
        })) {
            Ok(result) => result,
            Err(panic_info) => {
                let panic_msg = if let Some(s) = panic_info.downcast_ref::<&str>() {
                    s.to_string()
                } else if let Some(s) = panic_info.downcast_ref::<String>() {
                    s.clone()
                } else {
                    "Unknown panic occurred".to_string()
                };

                set_last_error(&format!("Panic in FFI call: {}", panic_msg));
                std::ptr::null_mut()
            }
        }
    }};
}

#[cfg(test)]
mod tests {
    use crate::error::{clear_last_error, rhai_get_last_error, rhai_free_error};
    use std::ffi::CString;

    #[test]
    fn test_catch_panic_success() {
        clear_last_error();

        let result = catch_panic! {{
            42
        }};

        assert_eq!(result, 42);

        let error_ptr = rhai_get_last_error();
        assert!(error_ptr.is_null());
    }

    #[test]
    fn test_catch_panic_on_panic() {
        clear_last_error();

        let result = catch_panic! {{
            panic!("test panic");
        }};

        assert_eq!(result, -1);

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        unsafe {
            let error_str = CString::from_raw(error_ptr).into_string().unwrap();
            assert!(error_str.contains("Panic in FFI call"));
            assert!(error_str.contains("test panic"));
        }
    }

    #[test]
    fn test_catch_panic_ptr_success() {
        clear_last_error();

        let result = catch_panic_ptr! {{
            Box::into_raw(Box::new(42))
        }};

        assert!(!result.is_null());

        unsafe {
            let _ = Box::from_raw(result);
        }

        let error_ptr = rhai_get_last_error();
        assert!(error_ptr.is_null());
    }

    #[test]
    fn test_catch_panic_ptr_on_panic() {
        clear_last_error();

        let result: *mut i32 = catch_panic_ptr! {{
            panic!("test panic");
        }};

        assert!(result.is_null());

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        rhai_free_error(error_ptr);
    }
}
