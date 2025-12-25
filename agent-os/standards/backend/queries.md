## Rust Async Operations Standards

This document outlines best practices for implementing async operations in Rust that are exposed via FFI to Dart/Flutter. The key pattern is using a thread-local Tokio runtime to bridge async Rust code with synchronous FFI calls.

### The Challenge: Async Rust + Synchronous FFI

**Problem:**
- Rust async functions return `Future<T>`, which cannot cross FFI boundaries
- Dart expects synchronous FFI calls (pointers, integers, etc.)
- Multiple Dart isolates may call the same FFI function concurrently
- Global shared runtime can cause deadlocks with `block_on`

**Solution:**
- Use thread-local Tokio runtime (one per Dart isolate/thread)
- Use `block_on` at FFI boundary to wait for async completion
- Wrap in `Future()` on Dart side for async API
- Rust handles async internally, Dart sees synchronous call

### Thread-Local Runtime Pattern

#### Implementation (src/runtime.rs)

```rust
use std::cell::OnceCell;
use tokio::runtime::Runtime;

thread_local! {
    /// Thread-local Tokio runtime for async operations.
    ///
    /// Each thread (including Dart isolate threads) gets its own dedicated runtime.
    /// This prevents deadlocks that occur when using `block_on` with a shared global runtime.
    ///
    /// # Why Thread-Local?
    ///
    /// When multiple threads call `block_on` on the same runtime:
    /// - Thread A blocks the runtime waiting for task completion
    /// - Thread B tries to block_on but runtime is already blocked
    /// - Deadlock occurs
    ///
    /// With thread-local runtimes:
    /// - Each thread has its own runtime
    /// - No contention between threads
    /// - Each isolate operates independently
    static RUNTIME: OnceCell<Runtime> = OnceCell::new();
}

/// Gets or creates the thread-local Tokio runtime.
///
/// # Safety
///
/// This is safe because:
/// - Each thread accesses only its own `OnceCell`
/// - The runtime is never moved or shared between threads
/// - The reference is valid for the lifetime of the thread
///
/// # Returns
///
/// A static reference to the thread-local runtime
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_runtime_creation() {
        let runtime = get_runtime();
        runtime.block_on(async {
            // Runtime works
            assert_eq!(2 + 2, 4);
        });
    }

    #[test]
    fn test_multiple_calls() {
        // Should return same runtime on same thread
        let runtime1 = get_runtime();
        let runtime2 = get_runtime();
        assert_eq!(runtime1 as *const _, runtime2 as *const _);
    }
}
```

**Key Design Decisions:**

1. **`new_current_thread()` vs `new_multi_thread()`**:
   - Use `new_current_thread()` - single-threaded runtime
   - More efficient for FFI use case
   - Each Dart isolate already runs on its own thread
   - No need for runtime's worker thread pool

2. **`enable_all()`**:
   - Enables I/O and timer drivers
   - Required for network operations, file I/O, sleep, timeouts

3. **`OnceCell` for lazy initialization**:
   - Runtime created on first use
   - Reused for subsequent calls on same thread
   - No synchronization overhead (thread-local)

### Using block_on at FFI Boundary

#### Basic Pattern

```rust
use std::ffi::{CStr, c_char};
use crate::runtime::get_runtime;
use crate::error::set_last_error;

/// Executes an async query synchronously via FFI
#[no_mangle]
pub extern "C" fn db_query_async(
    handle: *mut Database,
    sql: *const c_char,
) -> *mut QueryResponse {
    match panic::catch_unwind(|| {
        // 1. Validate inputs
        if handle.is_null() || sql.is_null() {
            set_last_error("Handle and SQL cannot be null");
            return std::ptr::null_mut();
        }

        // 2. Convert C string to Rust
        let sql_str = unsafe {
            match CStr::from_ptr(sql).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in SQL");
                    return std::ptr::null_mut();
                }
            }
        };

        // 3. Get mutable reference to database
        let db = unsafe { &mut *handle };

        // 4. Get thread-local runtime
        let runtime = get_runtime();

        // 5. Block on async operation
        match runtime.block_on(async {
            // This is async code - can use .await
            db.execute_query_async(sql_str).await
        }) {
            Ok(response) => {
                // 6. Transfer ownership to Dart
                Box::into_raw(Box::new(response))
            }
            Err(e) => {
                set_last_error(&format!("Query failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic in db_query_async");
            std::ptr::null_mut()
        }
    }
}
```

**Flow Diagram:**
```
Dart Thread → FFI Call → get_runtime() → block_on(async { ... })
                                              ↓
                                         Async Code Executes
                                              ↓
                                         Returns Result
                                              ↓
                                      Convert to C types
                                              ↓
                                      Return to Dart ✓
```

### Async Database Operations

#### Database Connection

```rust
pub struct Database {
    endpoint: String,
    connection: Option<AsyncConnection>,
}

impl Database {
    pub(crate) fn new(endpoint: &str) -> Self {
        Self {
            endpoint: endpoint.to_string(),
            connection: None,
        }
    }

    /// Connects to database asynchronously
    pub(crate) async fn connect_async(&mut self) -> Result<(), DatabaseError> {
        let conn = AsyncConnection::connect(&self.endpoint).await?;
        self.connection = Some(conn);
        Ok(())
    }

    /// Executes a query asynchronously
    pub(crate) async fn execute_query_async(
        &mut self,
        sql: &str,
    ) -> Result<QueryResponse, DatabaseError> {
        let conn = self.connection.as_mut()
            .ok_or(DatabaseError::NotConnected)?;

        // Async query execution
        let rows = conn.query(sql).await?;

        Ok(QueryResponse {
            results: rows,
            affected_rows: 0,
            execution_time_ms: 0,
        })
    }

    /// Closes connection asynchronously
    pub(crate) async fn close_async(&mut self) {
        if let Some(mut conn) = self.connection.take() {
            let _ = conn.close().await;
        }
    }
}
```

#### FFI Wrapper for Connection

```rust
/// Connects to database (async operation, synchronous FFI)
#[no_mangle]
pub extern "C" fn db_connect_async(handle: *mut Database) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return ERROR_NULL_POINTER;
        }

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        match runtime.block_on(async {
            db.connect_async().await
        }) {
            Ok(_) => SUCCESS,
            Err(e) => {
                set_last_error(&format!("Connection failed: {}", e));
                ERROR_CONNECTION_FAILED
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic in db_connect_async");
            ERROR_PANIC
        }
    }
}
```

### Async HTTP Requests

```rust
use reqwest;

pub struct HttpClient {
    client: reqwest::Client,
}

impl HttpClient {
    pub(crate) fn new() -> Self {
        Self {
            client: reqwest::Client::new(),
        }
    }

    /// Performs async HTTP GET request
    pub(crate) async fn get(&self, url: &str) -> Result<String, HttpError> {
        let response = self.client
            .get(url)
            .send()
            .await?;

        let status = response.status();

        if !status.is_success() {
            return Err(HttpError::RequestFailed(status.as_u16()));
        }

        let body = response.text().await?;
        Ok(body)
    }

    /// Performs async HTTP POST request with JSON
    pub(crate) async fn post_json(
        &self,
        url: &str,
        json_body: &str,
    ) -> Result<String, HttpError> {
        let response = self.client
            .post(url)
            .header("Content-Type", "application/json")
            .body(json_body.to_string())
            .send()
            .await?;

        let status = response.status();

        if !status.is_success() {
            return Err(HttpError::RequestFailed(status.as_u16()));
        }

        let body = response.text().await?;
        Ok(body)
    }
}

/// HTTP GET request via FFI
#[no_mangle]
pub extern "C" fn http_get(
    client: *mut HttpClient,
    url: *const c_char,
) -> *mut c_char {
    match panic::catch_unwind(|| {
        if client.is_null() || url.is_null() {
            set_last_error("Client and URL cannot be null");
            return std::ptr::null_mut();
        }

        let url_str = unsafe {
            match CStr::from_ptr(url).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in URL");
                    return std::ptr::null_mut();
                }
            }
        };

        let http_client = unsafe { &*client };
        let runtime = get_runtime();

        match runtime.block_on(async {
            http_client.get(url_str).await
        }) {
            Ok(body) => {
                match CString::new(body) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => {
                        set_last_error("Failed to create C string");
                        std::ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("HTTP request failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic in http_get");
            std::ptr::null_mut()
        }
    }
}
```

### Async File Operations

```rust
use tokio::fs;
use tokio::io::AsyncWriteExt;

pub struct FileManager;

impl FileManager {
    /// Reads file asynchronously
    pub(crate) async fn read_file(path: &str) -> Result<String, FileError> {
        let contents = fs::read_to_string(path).await?;
        Ok(contents)
    }

    /// Writes file asynchronously
    pub(crate) async fn write_file(path: &str, contents: &str) -> Result<(), FileError> {
        let mut file = fs::File::create(path).await?;
        file.write_all(contents.as_bytes()).await?;
        file.flush().await?;
        Ok(())
    }

    /// Deletes file asynchronously
    pub(crate) async fn delete_file(path: &str) -> Result<(), FileError> {
        fs::remove_file(path).await?;
        Ok(())
    }
}

/// Reads file via FFI
#[no_mangle]
pub extern "C" fn file_read(path: *const c_char) -> *mut c_char {
    match panic::catch_unwind(|| {
        if path.is_null() {
            set_last_error("Path cannot be null");
            return std::ptr::null_mut();
        }

        let path_str = unsafe {
            match CStr::from_ptr(path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in path");
                    return std::ptr::null_mut();
                }
            }
        };

        let runtime = get_runtime();

        match runtime.block_on(async {
            FileManager::read_file(path_str).await
        }) {
            Ok(contents) => {
                match CString::new(contents) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => {
                        set_last_error("File contains null bytes");
                        std::ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Failed to read file: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic in file_read");
            std::ptr::null_mut()
        }
    }
}
```

### Concurrent Operations with join! and select!

```rust
use tokio::join;
use tokio::select;
use tokio::time::{sleep, Duration};

/// Performs multiple queries concurrently
pub(crate) async fn fetch_dashboard_data(
    db: &mut Database,
) -> Result<DashboardData, DatabaseError> {
    // Execute queries concurrently
    let (users_result, posts_result, stats_result) = join!(
        db.query_async("SELECT COUNT(*) FROM users"),
        db.query_async("SELECT COUNT(*) FROM posts"),
        db.query_async("SELECT * FROM stats LIMIT 1"),
    );

    Ok(DashboardData {
        user_count: users_result?,
        post_count: posts_result?,
        stats: stats_result?,
    })
}

/// Query with timeout
pub(crate) async fn query_with_timeout(
    db: &mut Database,
    sql: &str,
    timeout_secs: u64,
) -> Result<QueryResponse, DatabaseError> {
    let timeout = sleep(Duration::from_secs(timeout_secs));

    select! {
        result = db.execute_query_async(sql) => {
            result
        }
        _ = timeout => {
            Err(DatabaseError::Timeout)
        }
    }
}

/// FFI wrapper with timeout
#[no_mangle]
pub extern "C" fn db_query_with_timeout(
    handle: *mut Database,
    sql: *const c_char,
    timeout_secs: u64,
) -> *mut QueryResponse {
    match panic::catch_unwind(|| {
        if handle.is_null() || sql.is_null() {
            set_last_error("Handle and SQL cannot be null");
            return std::ptr::null_mut();
        }

        let sql_str = unsafe {
            match CStr::from_ptr(sql).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in SQL");
                    return std::ptr::null_mut();
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        match runtime.block_on(async {
            query_with_timeout(db, sql_str, timeout_secs).await
        }) {
            Ok(response) => Box::into_raw(Box::new(response)),
            Err(e) => {
                set_last_error(&format!("Query failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic in db_query_with_timeout");
            std::ptr::null_mut()
        }
    }
}
```

### Streaming Data

For large result sets, consider streaming:

```rust
use tokio::sync::mpsc;
use futures::stream::StreamExt;

/// Streams large result set
pub(crate) async fn stream_large_query(
    db: &mut Database,
    sql: &str,
) -> Result<Vec<Row>, DatabaseError> {
    let conn = db.connection.as_mut()
        .ok_or(DatabaseError::NotConnected)?;

    // Get async stream of rows
    let mut row_stream = conn.query_stream(sql).await?;

    let mut all_rows = Vec::new();

    // Process stream
    while let Some(row_result) = row_stream.next().await {
        let row = row_result?;
        all_rows.push(row);

        // Could batch results here to limit memory
        if all_rows.len() >= 1000 {
            // Process batch or yield to caller
        }
    }

    Ok(all_rows)
}
```

### Error Handling in Async Code

```rust
use std::fmt;

#[derive(Debug)]
pub enum AsyncError {
    Database(DatabaseError),
    Http(reqwest::Error),
    Io(tokio::io::Error),
    Timeout,
    Cancelled,
}

impl fmt::Display for AsyncError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            AsyncError::Database(e) => write!(f, "Database error: {}", e),
            AsyncError::Http(e) => write!(f, "HTTP error: {}", e),
            AsyncError::Io(e) => write!(f, "IO error: {}", e),
            AsyncError::Timeout => write!(f, "Operation timed out"),
            AsyncError::Cancelled => write!(f, "Operation cancelled"),
        }
    }
}

impl From<DatabaseError> for AsyncError {
    fn from(e: DatabaseError) -> Self {
        AsyncError::Database(e)
    }
}

impl From<reqwest::Error> for AsyncError {
    fn from(e: reqwest::Error) -> Self {
        AsyncError::Http(e)
    }
}

impl From<tokio::io::Error> for AsyncError {
    fn from(e: tokio::io::Error) -> Self {
        AsyncError::Io(e)
    }
}
```

### Dart Side: Async API

On the Dart side, wrap FFI calls in `Future()`:

```dart
class Database {
  Pointer<NativeDatabase> _handle;

  /// Connects to database
  Future<void> connect() async {
    return Future(() {
      final result = bindings.dbConnectAsync(_handle);
      validateSuccess(result, 'Database connection');
    });
  }

  /// Executes async query (Rust handles async, Dart sees sync FFI)
  Future<List<Map<String, dynamic>>> query(String sql) async {
    return Future(() {
      final sqlPtr = sql.toNativeUtf8();

      try {
        final responsePtr = bindings.dbQueryAsync(_handle, sqlPtr);

        if (responsePtr == nullptr) {
          throw QueryException('Query returned null');
        }

        return _parseResponse(responsePtr);
      } finally {
        malloc.free(sqlPtr);
      }
    });
  }

  /// Query with timeout
  Future<List<Map<String, dynamic>>> queryWithTimeout(
    String sql,
    Duration timeout,
  ) async {
    return Future(() {
      final sqlPtr = sql.toNativeUtf8();

      try {
        final responsePtr = bindings.dbQueryWithTimeout(
          _handle,
          sqlPtr,
          timeout.inSeconds,
        );

        if (responsePtr == nullptr) {
          throw QueryException('Query timed out or failed');
        }

        return _parseResponse(responsePtr);
      } finally {
        malloc.free(sqlPtr);
      }
    });
  }
}
```

### Performance Considerations

#### When to Use block_on

**✅ Good Use Cases:**
- Database queries (I/O-bound)
- HTTP requests (I/O-bound)
- File operations (I/O-bound)
- Network operations (I/O-bound)
- Operations < 100ms

**❌ Avoid block_on For:**
- CPU-intensive computations
- Operations > 1 second
- Situations where UI must stay responsive
- Parallel processing of many tasks

For CPU-intensive or long-running operations, use Dart isolates instead.

#### Runtime Overhead

Thread-local runtime overhead:
- **Memory**: ~2-4 MB per thread
- **Initialization**: One-time cost per thread
- **Performance**: No synchronization overhead

This is acceptable for FFI use case because:
- Each Dart isolate already has its own thread
- Runtime is reused for all operations on that thread
- Alternative (isolates for async) has higher overhead

### Testing Async FFI Functions

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn test_async_query() {
        let db = db_new(CString::new("test://").unwrap().as_ptr());
        assert!(!db.is_null());

        let result = db_connect_async(db);
        assert_eq!(result, SUCCESS);

        let sql = CString::new("SELECT 1").unwrap();
        let response = db_query_async(db, sql.as_ptr());
        assert!(!response.is_null());

        response_free(response);
        db_free(db);
    }

    #[test]
    fn test_concurrent_queries() {
        let db = db_new(CString::new("test://").unwrap().as_ptr());
        db_connect_async(db);

        // Multiple queries should work fine with thread-local runtime
        for _ in 0..10 {
            let sql = CString::new("SELECT 1").unwrap();
            let response = db_query_async(db, sql.as_ptr());
            assert!(!response.is_null());
            response_free(response);
        }

        db_free(db);
    }

    #[test]
    fn test_timeout() {
        let db = db_new(CString::new("test://").unwrap().as_ptr());
        db_connect_async(db);

        let sql = CString::new("SELECT SLEEP(10)").unwrap();
        let response = db_query_with_timeout(db, sql.as_ptr(), 1);

        // Should timeout and return null
        assert_eq!(response, std::ptr::null_mut());

        db_free(db);
    }
}
```

### Best Practices Summary

**Runtime Management:**
- [ ] Use thread-local runtime (not global)
- [ ] Use `new_current_thread()` builder
- [ ] Call `get_runtime()` at FFI boundary
- [ ] Cache runtime reference (OnceCell)

**Async Operations:**
- [ ] Keep async logic in Rust business layer
- [ ] Use `block_on` only at FFI boundary
- [ ] Handle errors from async operations
- [ ] Set reasonable timeouts

**Error Handling:**
- [ ] Convert async errors to error codes
- [ ] Store error messages in thread-local
- [ ] Provide descriptive error context
- [ ] Clean up resources on error

**Dart Integration:**
- [ ] Wrap FFI calls in `Future()`
- [ ] Provide async API to Dart callers
- [ ] Handle exceptions appropriately
- [ ] Clean up pointers in finally blocks

**Performance:**
- [ ] Use for I/O-bound operations only
- [ ] Consider Dart isolates for CPU-bound work
- [ ] Implement timeouts for long operations
- [ ] Profile and measure actual performance

**Testing:**
- [ ] Test async operations in Rust
- [ ] Test timeout behavior
- [ ] Test error conditions
- [ ] Test concurrent access from multiple threads
