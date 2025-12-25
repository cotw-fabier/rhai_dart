## Thread-Local State Management Standards (Rust)

This document outlines best practices for managing per-thread state in Rust FFI applications. Thread-local state is essential for multi-isolate safety, error handling, and runtime management when working with Dart/Flutter.

### Why Thread-Local State?

**The Problem:**
- Multiple Dart isolates can call FFI functions concurrently
- Each isolate runs on its own thread
- Global shared state requires synchronization (locks, atomics)
- Locks add overhead and can cause contention
- Some state (like errors) should be per-isolate

**The Solution:**
- Use thread-local storage (TLS)
- Each thread gets its own independent state
- No synchronization needed
- Perfect for Dart isolates (one isolate = one thread)

### Thread-Local Error State Pattern

The most common use of thread-local state is error message storage:

#### Implementation (src/error.rs)

```rust
use std::cell::RefCell;
use std::ffi::{CString, c_char};

thread_local! {
    /// Thread-local storage for the last error message.
    ///
    /// Each thread (Dart isolate) has its own error state.
    /// This prevents race conditions when multiple isolates
    /// encounter errors simultaneously.
    static LAST_ERROR: RefCell<Option<String>> = const { RefCell::new(None) };
}

/// Stores an error message in thread-local storage.
///
/// This message can be retrieved by calling `get_last_error()`.
/// Only the most recent error is stored; calling this again
/// overwrites the previous error.
///
/// # Arguments
///
/// * `msg` - The error message to store
///
/// # Thread Safety
///
/// Thread-safe. Each thread has its own error state.
pub fn set_last_error(msg: &str) {
    LAST_ERROR.with(|last| {
        *last.borrow_mut() = Some(msg.to_string());
    });
}

/// Retrieves and clears the last error message.
///
/// # Memory Ownership
///
/// Returns a new C string owned by the caller.
/// Caller MUST call `free_string()` to prevent memory leaks.
///
/// # Returns
///
/// - Non-null C string containing the error message
/// - Null pointer if no error has been set
///
/// # Thread Safety
///
/// Thread-safe. Returns error for current thread only.
#[no_mangle]
pub extern "C" fn get_last_error() -> *mut c_char {
    LAST_ERROR.with(|last| {
        // Use .take() to consume the error (prevents repeated retrieval)
        match last.borrow_mut().take() {
            Some(err) => {
                match CString::new(err) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => {
                        // Error message contained null byte
                        std::ptr::null_mut()
                    }
                }
            }
            None => std::ptr::null_mut(),
        }
    })
}

/// Frees a string allocated by native code.
///
/// # Safety
///
/// - Must only be called on strings returned by FFI functions
/// - Safe to call with null pointer (no-op)
/// - Must only be called once per string
#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
            // String is dropped and freed here
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_storage() {
        set_last_error("Test error");

        let error_ptr = get_last_error();
        assert!(!error_ptr.is_null());

        let error_str = unsafe { CStr::from_ptr(error_ptr).to_str().unwrap() };
        assert_eq!(error_str, "Test error");

        free_string(error_ptr);
    }

    #[test]
    fn test_error_cleared_after_get() {
        set_last_error("Error 1");

        let _ = get_last_error();

        // Second call should return null (error was cleared)
        let error_ptr = get_last_error();
        assert_eq!(error_ptr, std::ptr::null_mut());
    }

    #[test]
    fn test_error_overwrite() {
        set_last_error("Error 1");
        set_last_error("Error 2");

        let error_ptr = get_last_error();
        let error_str = unsafe { CStr::from_ptr(error_ptr).to_str().unwrap() };

        // Should get most recent error
        assert_eq!(error_str, "Error 2");

        free_string(error_ptr);
    }
}
```

**Key Design Decisions:**

1. **`RefCell<Option<String>>`**:
   - `RefCell` provides interior mutability (needed for thread_local!)
   - `Option<String>` allows "no error" state (None)
   - `String` stores the actual error message

2. **`.take()` instead of `.clone()`**:
   - Consumes the error, clearing it after retrieval
   - Prevents accidental repeated error retrieval
   - Clear semantics: get error once, then it's gone

3. **`const` initializer**:
   - Required for thread_local! macro in modern Rust
   - `const { RefCell::new(None) }` is const-compatible

### Thread-Local Runtime Pattern

Already covered in detail in `queries.md`, but here's the summary:

```rust
use std::cell::OnceCell;
use tokio::runtime::Runtime;

thread_local! {
    static RUNTIME: OnceCell<Runtime> = OnceCell::new();
}

pub fn get_runtime() -> &'static Runtime {
    RUNTIME.with(|cell| {
        unsafe {
            let ptr = cell.get_or_init(|| {
                tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create Tokio runtime")
            }) as *const Runtime;
            &*ptr
        }
    })
}
```

**Why this works:**
- Each thread initializes its own runtime on first use
- `OnceCell` ensures initialization happens once per thread
- No synchronization needed (thread-local)

### Thread-Local Configuration

For per-thread configuration:

```rust
use std::cell::RefCell;

thread_local! {
    /// Thread-local configuration for logging.
    static LOG_CONFIG: RefCell<LogConfig> = RefCell::new(LogConfig::default());
}

#[derive(Debug, Clone)]
pub struct LogConfig {
    pub enabled: bool,
    pub level: LogLevel,
    pub output: LogOutput,
}

impl Default for LogConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            level: LogLevel::Info,
            output: LogOutput::Stderr,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogLevel {
    Debug,
    Info,
    Warning,
    Error,
}

#[derive(Debug, Clone, Copy)]
pub enum LogOutput {
    Stdout,
    Stderr,
    None,
}

/// Sets the log level for the current thread/isolate
#[no_mangle]
pub extern "C" fn set_log_level(level: i32) -> i32 {
    let log_level = match level {
        0 => LogLevel::Debug,
        1 => LogLevel::Info,
        2 => LogLevel::Warning,
        3 => LogLevel::Error,
        _ => {
            set_last_error("Invalid log level");
            return -1;
        }
    };

    LOG_CONFIG.with(|config| {
        config.borrow_mut().level = log_level;
    });

    0
}

/// Gets the current log level
#[no_mangle]
pub extern "C" fn get_log_level() -> i32 {
    LOG_CONFIG.with(|config| {
        match config.borrow().level {
            LogLevel::Debug => 0,
            LogLevel::Info => 1,
            LogLevel::Warning => 2,
            LogLevel::Error => 3,
        }
    })
}

/// Internal logging function that respects thread-local config
pub(crate) fn log(level: LogLevel, message: &str) {
    LOG_CONFIG.with(|config| {
        let cfg = config.borrow();

        if !cfg.enabled {
            return;
        }

        if level < cfg.level {
            return;
        }

        match cfg.output {
            LogOutput::Stdout => println!("[{:?}] {}", level, message),
            LogOutput::Stderr => eprintln!("[{:?}] {}", level, message),
            LogOutput::None => {},
        }
    });
}
```

### Thread-Local Cache

For per-isolate caching:

```rust
use std::cell::RefCell;
use std::collections::HashMap;
use std::time::{Duration, Instant};

thread_local! {
    /// Thread-local query result cache.
    static QUERY_CACHE: RefCell<QueryCache> = RefCell::new(QueryCache::new(100));
}

pub struct QueryCache {
    entries: HashMap<String, CacheEntry>,
    max_size: usize,
}

struct CacheEntry {
    data: String,
    inserted_at: Instant,
    ttl: Duration,
}

impl QueryCache {
    fn new(max_size: usize) -> Self {
        Self {
            entries: HashMap::with_capacity(max_size),
            max_size,
        }
    }

    fn get(&self, key: &str) -> Option<String> {
        self.entries.get(key).and_then(|entry| {
            if entry.inserted_at.elapsed() < entry.ttl {
                Some(entry.data.clone())
            } else {
                None
            }
        })
    }

    fn insert(&mut self, key: String, data: String, ttl: Duration) {
        if self.entries.len() >= self.max_size {
            self.evict_oldest();
        }

        self.entries.insert(key, CacheEntry {
            data,
            inserted_at: Instant::now(),
            ttl,
        });
    }

    fn evict_oldest(&mut self) {
        // Simple eviction: remove first entry
        if let Some(key) = self.entries.keys().next().cloned() {
            self.entries.remove(&key);
        }
    }

    fn clear(&mut self) {
        self.entries.clear();
    }
}

/// Caches a query result (thread-local)
pub(crate) fn cache_query_result(key: &str, result: &str, ttl_secs: u64) {
    QUERY_CACHE.with(|cache| {
        cache.borrow_mut().insert(
            key.to_string(),
            result.to_string(),
            Duration::from_secs(ttl_secs),
        );
    });
}

/// Retrieves cached query result (thread-local)
pub(crate) fn get_cached_query_result(key: &str) -> Option<String> {
    QUERY_CACHE.with(|cache| {
        cache.borrow().get(key)
    })
}

/// Clears the query cache for current thread
#[no_mangle]
pub extern "C" fn clear_query_cache() {
    QUERY_CACHE.with(|cache| {
        cache.borrow_mut().clear();
    });
}
```

### Thread-Local Statistics

For per-isolate metrics:

```rust
use std::cell::RefCell;
use std::sync::atomic::{AtomicU64, Ordering};

thread_local! {
    /// Thread-local statistics for FFI operations.
    static STATS: RefCell<ThreadStats> = RefCell::new(ThreadStats::default());
}

#[derive(Default)]
pub struct ThreadStats {
    pub queries_executed: u64,
    pub errors_encountered: u64,
    pub total_execution_time_ms: u64,
    pub cache_hits: u64,
    pub cache_misses: u64,
}

impl ThreadStats {
    pub fn record_query(&mut self, execution_time_ms: u64) {
        self.queries_executed += 1;
        self.total_execution_time_ms += execution_time_ms;
    }

    pub fn record_error(&mut self) {
        self.errors_encountered += 1;
    }

    pub fn record_cache_hit(&mut self) {
        self.cache_hits += 1;
    }

    pub fn record_cache_miss(&mut self) {
        self.cache_misses += 1;
    }

    pub fn reset(&mut self) {
        *self = Self::default();
    }
}

/// Records a query execution (thread-local)
pub(crate) fn record_query_execution(execution_time_ms: u64) {
    STATS.with(|stats| {
        stats.borrow_mut().record_query(execution_time_ms);
    });
}

/// Gets query statistics for current thread
#[no_mangle]
pub extern "C" fn get_queries_executed() -> u64 {
    STATS.with(|stats| stats.borrow().queries_executed)
}

/// Gets error count for current thread
#[no_mangle]
pub extern "C" fn get_errors_encountered() -> u64 {
    STATS.with(|stats| stats.borrow().errors_encountered)
}

/// Resets statistics for current thread
#[no_mangle]
pub extern "C" fn reset_stats() {
    STATS.with(|stats| {
        stats.borrow_mut().reset();
    });
}
```

### Global State vs Thread-Local State

**When to use Global State:**
```rust
use std::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    /// Global configuration (shared across all threads)
    static ref GLOBAL_CONFIG: Mutex<GlobalConfig> = Mutex::new(GlobalConfig::default());
}

#[derive(Default)]
pub struct GlobalConfig {
    pub max_connections: u32,
    pub default_timeout: u64,
}

// Use global state for truly shared configuration
```

**When to use Thread-Local State:**
```rust
thread_local! {
    /// Per-thread state (isolated per Dart isolate)
    static THREAD_CONFIG: RefCell<ThreadConfig> = RefCell::new(ThreadConfig::default());
}

#[derive(Default)]
pub struct ThreadConfig {
    pub log_level: LogLevel,
    pub cache_enabled: bool,
}

// Use thread-local for per-isolate settings
```

**Decision Matrix:**

| State Type | Global (Mutex) | Thread-Local (RefCell) |
|------------|----------------|------------------------|
| **Error messages** | ❌ Race conditions | ✅ Isolated per isolate |
| **Runtime** | ❌ Deadlock risk | ✅ Independent per thread |
| **Cache** | ⚠️ Contention | ✅ Fast, no locks |
| **Statistics** | ⚠️ Atomic overhead | ✅ No synchronization |
| **Shared config** | ✅ Single source | ❌ Can diverge |
| **Connection pools** | ✅ Resource sharing | ❌ Wasteful |

### Best Practices

#### 1. Use const Initializers

```rust
// ✅ GOOD: const initializer
thread_local! {
    static STATE: RefCell<MyState> = const { RefCell::new(MyState::new()) };
}

// ❌ BAD: non-const initializer (may not compile in newer Rust)
thread_local! {
    static STATE: RefCell<MyState> = RefCell::new(MyState::new());
}
```

#### 2. Clear State Appropriately

```rust
// ✅ GOOD: Take error (clears it)
let error = LAST_ERROR.with(|e| e.borrow_mut().take());

// ❌ BAD: Clone error (doesn't clear it)
let error = LAST_ERROR.with(|e| e.borrow().clone());
```

#### 3. Handle Panics in thread_local! Access

```rust
// ✅ GOOD: Handle potential panic
let result = std::panic::catch_unwind(|| {
    STATS.with(|stats| {
        stats.borrow_mut().record_query(100);
    });
});

// In practice, thread_local! with is very unlikely to panic
// unless you've already panicked and are unwinding
```

#### 4. Document Thread Safety

```rust
/// Records an error in thread-local storage.
///
/// # Thread Safety
///
/// Thread-safe. Each thread has independent error state.
/// Multiple threads can call this concurrently without contention.
pub fn set_last_error(msg: &str) {
    LAST_ERROR.with(|last| {
        *last.borrow_mut() = Some(msg.to_string());
    });
}
```

#### 5. Provide Clear/Reset Functions

```rust
/// Clears the error for the current thread
#[no_mangle]
pub extern "C" fn clear_last_error() {
    LAST_ERROR.with(|last| {
        *last.borrow_mut() = None;
    });
}

/// Resets thread-local cache
#[no_mangle]
pub extern "C" fn reset_cache() {
    CACHE.with(|cache| {
        cache.borrow_mut().clear();
    });
}
```

### Testing Thread-Local State

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn test_thread_local_isolation() {
        // Set error in main thread
        set_last_error("Main thread error");

        // Spawn new thread
        let handle = thread::spawn(|| {
            // New thread should not see main thread's error
            let error = get_last_error();
            assert_eq!(error, std::ptr::null_mut());

            // Set error in this thread
            set_last_error("Spawned thread error");

            // Should be able to retrieve it
            let error = get_last_error();
            assert!(!error.is_null());
            free_string(error);
        });

        handle.join().unwrap();

        // Main thread's error should still be there
        let error = get_last_error();
        assert!(!error.is_null());

        let error_str = unsafe { CStr::from_ptr(error).to_str().unwrap() };
        assert_eq!(error_str, "Main thread error");

        free_string(error);
    }

    #[test]
    fn test_concurrent_access() {
        let handles: Vec<_> = (0..10)
            .map(|i| {
                thread::spawn(move || {
                    // Each thread sets its own error
                    set_last_error(&format!("Error {}", i));

                    // Each thread should get its own error back
                    let error = get_last_error();
                    let error_str = unsafe { CStr::from_ptr(error).to_str().unwrap() };
                    assert_eq!(error_str, format!("Error {}", i));

                    free_string(error);
                })
            })
            .collect();

        for handle in handles {
            handle.join().unwrap();
        }
    }

    #[test]
    fn test_stats_isolation() {
        record_query_execution(100);
        assert_eq!(get_queries_executed(), 1);

        let handle = thread::spawn(|| {
            // New thread starts with 0
            assert_eq!(get_queries_executed(), 0);

            record_query_execution(50);
            assert_eq!(get_queries_executed(), 1);
        });

        handle.join().unwrap();

        // Main thread still has 1
        assert_eq!(get_queries_executed(), 1);
    }
}
```

### Dart Integration

From Dart's perspective, thread-local state is transparent:

```dart
// Each Dart isolate automatically gets its own thread-local state

// Main isolate
Future<void> mainIsolate() async {
  final db = await Database.connect(endpoint: 'test://');

  try {
    await db.query('INVALID SQL');
  } catch (e) {
    // Gets error from main isolate's thread-local storage
    print(e);
  }
}

// Spawned isolate
Future<void> workerIsolate() async {
  final db = await Database.connect(endpoint: 'test://');

  try {
    await db.query('ALSO INVALID');
  } catch (e) {
    // Gets error from THIS isolate's thread-local storage
    // Completely independent from main isolate
    print(e);
  }
}
```

### Common Patterns

#### Pattern 1: Error Context Stack

For nested error contexts:

```rust
thread_local! {
    static ERROR_CONTEXT: RefCell<Vec<String>> = const { RefCell::new(Vec::new()) };
}

pub fn push_error_context(context: &str) {
    ERROR_CONTEXT.with(|ctx| {
        ctx.borrow_mut().push(context.to_string());
    });
}

pub fn pop_error_context() {
    ERROR_CONTEXT.with(|ctx| {
        ctx.borrow_mut().pop();
    });
}

pub fn get_error_context() -> String {
    ERROR_CONTEXT.with(|ctx| {
        ctx.borrow().join(" -> ")
    })
}

// Usage
pub(crate) fn complex_operation() -> Result<(), Error> {
    push_error_context("complex_operation");

    let result = inner_operation();

    pop_error_context();
    result
}
```

#### Pattern 2: Request ID Tracking

For tracing requests across FFI calls:

```rust
use uuid::Uuid;

thread_local! {
    static REQUEST_ID: RefCell<Option<Uuid>> = const { RefCell::new(None) };
}

#[no_mangle]
pub extern "C" fn set_request_id(id: *const c_char) -> i32 {
    if id.is_null() {
        return -1;
    }

    let id_str = unsafe {
        match CStr::from_ptr(id).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        }
    };

    match Uuid::parse_str(id_str) {
        Ok(uuid) => {
            REQUEST_ID.with(|rid| {
                *rid.borrow_mut() = Some(uuid);
            });
            0
        }
        Err(_) => -1,
    }
}

pub(crate) fn get_current_request_id() -> Option<Uuid> {
    REQUEST_ID.with(|rid| *rid.borrow())
}
```

### Best Practices Summary

**Do:**
- [ ] Use thread-local for per-isolate state
- [ ] Use `RefCell` for interior mutability
- [ ] Use `const` initializers
- [ ] Clear state with `.take()` when appropriate
- [ ] Document thread safety guarantees
- [ ] Test thread isolation
- [ ] Provide reset/clear functions

**Don't:**
- [ ] Share mutable state across threads without synchronization
- [ ] Use global state for errors or per-request data
- [ ] Forget that each thread has independent state
- [ ] Clone when you should take
- [ ] Leave stale state between requests
- [ ] Assume thread-local state persists across FFI calls (it does, per thread)

### Performance Considerations

Thread-local access is:
- **Very fast**: No locks, no atomics
- **Cache-friendly**: Thread-local data stays in CPU cache
- **Scalable**: No contention between threads

Overhead:
- **Memory**: ~Small overhead per thread (KB, not MB)
- **Access time**: Nanoseconds (similar to local variable)
- **Initialization**: One-time per thread

Perfect for FFI because:
- Dart isolates are long-lived (thread-local amortized)
- No synchronization overhead
- Natural fit for isolate model
