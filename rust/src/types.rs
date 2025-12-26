//! Native C Types for FFI
//!
//! This module defines C-compatible types for passing data across the FFI boundary.
//! All structs use #[repr(C)] to ensure consistent memory layout.

use std::sync::Arc;
use rhai::Engine;
use std::ffi::c_char;

/// Opaque handle for a Rhai engine instance.
///
/// This wraps an Arc<Engine> to provide thread-safe reference counting
/// while exposing an opaque pointer to Dart.
///
/// # Safety
///
/// This type is only accessed via FFI functions and should never be
/// directly constructed or accessed from Rust code outside this crate.
#[repr(C)]
pub struct CRhaiEngine {
    /// The wrapped Rhai engine
    pub(crate) inner: Arc<Engine>,
}

impl CRhaiEngine {
    /// Creates a new CRhaiEngine wrapping the given engine
    pub(crate) fn new(engine: Engine) -> Self {
        Self {
            inner: Arc::new(engine),
        }
    }

    /// Gets a reference to the inner engine
    pub(crate) fn engine(&self) -> &Engine {
        &self.inner
    }
}

/// Configuration for creating a Rhai engine.
///
/// This struct is passed across the FFI boundary to configure engine creation.
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct CRhaiConfig {
    /// Maximum number of operations before script execution is aborted (0 = unlimited)
    pub max_operations: u64,

    /// Maximum call stack depth (0 = unlimited)
    pub max_stack_depth: u64,

    /// Maximum string length in bytes (0 = unlimited)
    pub max_string_length: u64,

    /// Script execution timeout in milliseconds (0 = no timeout)
    pub timeout_ms: u64,

    /// Whether to disable file I/O operations
    pub disable_file_io: u8, // bool as u8 for C compatibility

    /// Whether to disable eval() function
    pub disable_eval: u8,

    /// Whether to disable module loading
    pub disable_modules: u8,
}

impl Default for CRhaiConfig {
    fn default() -> Self {
        Self::secure_defaults()
    }
}

impl CRhaiConfig {
    /// Returns a secure default configuration.
    ///
    /// This configuration enables all sandboxing features and sets
    /// reasonable limits for safe script execution.
    pub const fn secure_defaults() -> Self {
        Self {
            max_operations: 1_000_000,
            max_stack_depth: 100,
            max_string_length: 10_485_760, // 10 MB
            timeout_ms: 5000,
            disable_file_io: 1,
            disable_eval: 1,
            disable_modules: 1,
        }
    }
}

/// Represents a Rhai value for passing across the FFI boundary.
///
/// Uses JSON serialization for complex types to avoid FFI alignment issues.
#[repr(C)]
pub struct CRhaiValue {
    /// JSON-serialized value
    pub json_data: *mut c_char,

    /// Type tag for the value
    /// 0 = null, 1 = bool, 2 = int, 3 = float, 4 = string, 5 = array, 6 = map
    pub type_tag: u8,
}

/// Structured error information for detailed error reporting.
///
/// This provides more context than a simple error message string.
#[repr(C)]
pub struct CRhaiError {
    /// Error message
    pub message: *mut c_char,

    /// Error type: 0 = syntax, 1 = runtime, 2 = ffi
    pub error_type: u8,

    /// Line number where error occurred (0 if not applicable)
    pub line_number: u64,

    /// Stack trace (may be null)
    pub stack_trace: *mut c_char,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_defaults() {
        let config = CRhaiConfig::default();
        assert_eq!(config.max_operations, 1_000_000);
        assert_eq!(config.max_stack_depth, 100);
        assert_eq!(config.disable_file_io, 1);
        assert_eq!(config.disable_eval, 1);
        assert_eq!(config.disable_modules, 1);
    }

    #[test]
    fn test_config_secure_defaults() {
        let config = CRhaiConfig::secure_defaults();
        assert_eq!(config.max_operations, 1_000_000);
        assert_eq!(config.timeout_ms, 5000);
        assert_eq!(config.disable_file_io, 1);
    }

    #[test]
    fn test_engine_wrapper() {
        let engine = Engine::new();
        let wrapper = CRhaiEngine::new(engine);
        assert!(!Arc::as_ptr(&wrapper.inner).is_null());
    }
}
