//! Rhai-Dart FFI Bridge
//!
//! This library provides a Foreign Function Interface (FFI) bridge between
//! Dart and the Rhai scripting engine, enabling safe and efficient script
//! execution with bidirectional function calling.
//!
//! # Architecture
//!
//! The library uses an opaque pointer pattern to safely pass Rhai engine instances
//! across the FFI boundary. All FFI entry points are protected with panic catching
//! to prevent Rust panics from crashing the Dart application.
//!
//! # Error Handling
//!
//! Errors are propagated using a thread-local storage pattern. When an FFI function
//! fails, it stores the error message in thread-local storage and returns an error
//! code (-1 for integer returns, null for pointer returns). The Dart side can then
//! retrieve the error message using `rhai_get_last_error()`.
//!
//! # Safety
//!
//! All FFI functions are carefully designed to be safe when called from Dart:
//! - Null pointer checks are performed before dereferencing
//! - Panics are caught and converted to error codes
//! - Memory is properly managed with clear ownership semantics
//! - Pointers returned to Dart must be freed using the corresponding free functions
//!
//! # Module Structure
//!
//! - `error`: Thread-local error storage and retrieval
//! - `types`: C-compatible type definitions for FFI
//! - `macros`: Macros for panic catching and error handling
//! - `engine`: Engine lifecycle management
//! - `values`: Type conversion between Rhai and Dart
//! - `functions`: Function registration and callback management

// Re-export macros at crate root for easier use
#[macro_use]
pub mod macros;

pub mod error;
pub mod types;
pub mod engine;
pub mod values;
pub mod functions;
pub mod async_eval;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_handling() {
        use error::{clear_last_error, set_last_error, rhai_get_last_error, rhai_free_error};

        clear_last_error();

        let error_ptr = rhai_get_last_error();
        assert!(error_ptr.is_null());

        set_last_error("test error");

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        rhai_free_error(error_ptr);
    }

    #[test]
    fn test_panic_catching() {
        use error::{clear_last_error, rhai_get_last_error, rhai_free_error};

        clear_last_error();

        let result = catch_panic! {{
            panic!("test panic");
        }};

        assert_eq!(result, -1);

        let error_ptr = rhai_get_last_error();
        assert!(!error_ptr.is_null());

        rhai_free_error(error_ptr);
    }
}
