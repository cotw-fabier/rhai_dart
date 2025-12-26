//! FFI Error Handling
//!
//! This module provides thread-local error storage for FFI boundary error propagation.
//! Follows the embedanythingindart pattern for safe error handling across the FFI boundary.

use std::cell::RefCell;
use std::ffi::{CString, c_char};

thread_local! {
    /// Thread-local storage for the last error that occurred.
    /// This allows FFI functions to return error codes while preserving error messages.
    static LAST_ERROR: RefCell<Option<String>> = const { RefCell::new(None) };
}

/// Sets the last error message in thread-local storage.
///
/// This function is used by FFI entry points to store error messages
/// when an operation fails.
///
/// # Arguments
///
/// * `error` - The error message to store
pub fn set_last_error(error: &str) {
    LAST_ERROR.with(|last| {
        *last.borrow_mut() = Some(error.to_string());
    });
}

/// Clears the last error message from thread-local storage.
///
/// This should be called at the beginning of FFI functions to ensure
/// error messages don't carry over from previous calls.
pub fn clear_last_error() {
    LAST_ERROR.with(|last| {
        *last.borrow_mut() = None;
    });
}

/// Retrieves the last error message as a C string.
///
/// # Safety
///
/// This function returns a pointer to a C string that must be freed by the caller
/// using `rhai_free_error()`. Returns null pointer if no error exists.
///
/// # Returns
///
/// A pointer to a null-terminated C string containing the error message,
/// or null if no error has been set.
#[no_mangle]
pub extern "C" fn rhai_get_last_error() -> *mut c_char {
    LAST_ERROR.with(|last| {
        match last.borrow().as_ref() {
            Some(error) => {
                match CString::new(error.as_str()) {
                    Ok(c_string) => c_string.into_raw(),
                    Err(_) => std::ptr::null_mut(),
                }
            }
            None => std::ptr::null_mut(),
        }
    })
}

/// Frees a C string that was allocated by Rust.
///
/// # Safety
///
/// This function must only be called with pointers that were returned from
/// Rust FFI functions. The pointer must not be null and must not have been
/// freed previously.
///
/// # Arguments
///
/// * `ptr` - A pointer to a C string to be freed
#[no_mangle]
pub extern "C" fn rhai_free_error(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            // Reclaim ownership and drop
            let _ = CString::from_raw(ptr);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_storage() {
        clear_last_error();

        let error_ptr = rhai_get_last_error();
        assert!(error_ptr.is_null());

        set_last_error("test error");

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        unsafe {
            let error_str = CString::from_raw(error_ptr).into_string().unwrap();
            assert_eq!(error_str, "test error");
        }

        clear_last_error();
        let error_ptr = rhai_get_last_error();
        assert!(error_ptr.is_null());
    }

    #[test]
    fn test_error_free() {
        set_last_error("test error");

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        // Free should not crash
        rhai_free_error(error_ptr);

        // Freeing null should not crash
        rhai_free_error(std::ptr::null_mut());
    }
}
