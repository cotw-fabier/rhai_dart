# Technology Stack

## Language & Runtime

### Dart
- **Version:** 3.10.1+
- **Purpose:** Primary language for library API and host application integration
- **Features:** Null safety, FFI support, native_assets system
- **Why:** Provides type safety, excellent async support, and first-class FFI capabilities

### Rust
- **Version:** 1.90.0 (via rust-toolchain.toml)
- **Purpose:** Native library implementation and Rhai engine embedding
- **Features:** Memory safety, zero-cost abstractions, C FFI compatibility
- **Why:** Enables safe and performant FFI layer with guaranteed memory safety

## Core Dependencies

### Dart Packages

#### ffi (^2.1.0)
- **Purpose:** Foreign Function Interface for calling Rust code from Dart
- **Use Cases:** Low-level bindings to Rust functions, memory management, pointer operations

#### native_toolchain_rust (^1.0.0)
- **Purpose:** Build automation for Rust native assets
- **Use Cases:** Automatic Rust compilation during `dart run`, cross-platform builds

#### hooks (^1.0.0)
- **Purpose:** Native Assets build hooks
- **Use Cases:** Custom build.dart scripts that compile Rust before Dart runs

### Rust Crates

#### rhai
- **Purpose:** Embedded scripting engine
- **Features:** Lightweight (~250KB), JavaScript-like syntax, safe sandboxing
- **Why:** Designed specifically for embedding with minimal overhead

#### tokio (with features: rt, rt-multi-thread)
- **Purpose:** Async runtime for Rust
- **Use Cases:** Handling async operations in Rhai scripts, future FFI async support

#### once_cell
- **Purpose:** Lazy static initialization
- **Use Cases:** Global runtime initialization, thread-safe singletons

#### anyhow
- **Purpose:** Flexible error handling
- **Use Cases:** Error propagation in Rust FFI layer

## Development Tools

### Dart Development

#### lints (^6.0.0)
- **Purpose:** Official Dart linter rules
- **Configuration:** Based on package:lints/recommended.yaml

#### test (^1.25.6)
- **Purpose:** Unit and integration testing framework
- **Use Cases:** Testing FFI bindings, type conversions, error handling

#### dart format
- **Purpose:** Code formatting
- **Command:** `dart format .`

#### dart analyze
- **Purpose:** Static analysis
- **Command:** `dart analyze`

### Rust Development

#### cargo
- **Purpose:** Rust build system and package manager
- **Commands:**
  - `cargo build --release` - Release build
  - `cargo clippy` - Rust linter
  - `cargo clean` - Clean build artifacts

#### rustup
- **Purpose:** Rust toolchain manager
- **Commands:**
  - `rustup show` - Install targets from rust-toolchain.toml
  - `rustup target add <target>` - Add platform target

## FFI Architecture

### Rust FFI Layer (rust/src/lib.rs)

#### Memory Management
- **Pattern:** Transfer ownership from Rust to Dart, Dart frees via FFI calls
- **Safety:** All FFI functions use `#[no_mangle]` and `extern "C"`
- **Error Handling:** Thread-local error storage, never panic across FFI boundary

#### Key Components
- Opaque handle types (e.g., CRhaiEngine wrapping Arc<Engine>)
- C-compatible structs for data transfer
- Free functions for Dart to call when disposing resources
- Panic catching via `std::panic::catch_unwind()`

### Dart FFI Layer (lib/src/ffi/)

#### Structure
- **native_types.dart:** Opaque types and FFI structs
- **bindings.dart:** @Native function declarations with assetId
- **ffi_utils.dart:** String conversion, error retrieval utilities
- **finalizers.dart:** NativeFinalizer for automatic cleanup

#### Asset Name Convention
- **Cargo.toml:** `name = "rhai_dart"`
- **hook/build.dart:** `assetName: 'rhai_dart'`
- **bindings.dart:** `assetId: 'package:rhai_dart/rhai_dart'`

### High-Level Dart API (lib/src/)

- **rhai_engine.dart:** Main user-facing API class
- **script_result.dart:** Typed result wrappers
- **exceptions.dart:** Dart exception classes for script errors
- **types.dart:** Type conversion utilities

## Build System

### Native Assets (Experimental)
- **Flag Required:** `--enable-experiment=native-assets`
- **Build Hook:** hook/build.dart using native_toolchain_rust
- **Process:** Rust library auto-compiled during `dart run` or `flutter run`
- **Output:** Platform-specific shared library (.dylib, .so, .dll)

### Cargo Configuration

#### Library Type (Cargo.toml)
```toml
[lib]
crate-type = ["staticlib", "cdylib"]
```
- **staticlib:** For iOS and static linking scenarios
- **cdylib:** For dynamic linking on macOS, Linux, Windows, Android

#### Rust Toolchain (rust-toolchain.toml)
- **Channel:** Stable 1.90.0
- **Targets:** Platform-specific (aarch64-apple-darwin, x86_64-unknown-linux-gnu, etc.)
- **Auto-install:** `rustup show` reads and installs required targets

## Platform Support

### Desktop Platforms
- **macOS:** aarch64-apple-darwin (Apple Silicon), x86_64-apple-darwin (Intel)
- **Linux:** x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu
- **Windows:** x86_64-pc-windows-msvc

### Future Platforms
- **iOS:** aarch64-apple-ios, aarch64-apple-ios-sim
- **Android:** aarch64-linux-android, armv7-linux-androideabi, x86_64-linux-android

## Memory Management

### Ownership Model
1. Rust allocates data on heap
2. Transfers ownership to Dart via raw pointer
3. Dart copies data to native Dart types
4. Dart calls Rust free function to deallocate original
5. NativeFinalizer ensures automatic cleanup on GC

### Finalizer Pattern
```dart
final _finalizer = NativeFinalizer(bindings.addresses.rhaiEngineFree);

class RhaiEngine {
  final Pointer<CRhaiEngine> _handle;

  RhaiEngine._(this._handle) {
    _finalizer.attach(this, _handle.cast());
  }

  void dispose() {
    bindings.rhaiEngineFree(_handle);
  }
}
```

## Error Handling Strategy

### Rust Side
- **Thread-local storage:** Errors stored per-thread, retrieved via `get_last_error()`
- **Panic safety:** All FFI entry points wrapped in `catch_unwind()`
- **Error types:** Anyhow for internal errors, C strings for FFI transfer

### Dart Side
- **Exception hierarchy:** ScriptException, ScriptSyntaxError, ScriptRuntimeError
- **Error propagation:** Check Rust error after FFI calls, throw Dart exception
- **Stack traces:** Preserve Rhai script line numbers and call stacks

## Testing Strategy

### Unit Tests
- Test individual FFI bindings for correctness
- Test type conversions in isolation
- Test error handling edge cases
- Test memory management (no leaks, proper cleanup)

### Integration Tests
- Test complete script execution workflows
- Test bidirectional function calling
- Test module loading and imports
- Test sandboxing and security controls

### Platform Tests
- Test on all supported platforms (macOS, Linux, Windows)
- Test both debug and release builds
- Test with different Rust toolchain configurations

## Performance Considerations

### Compilation Strategy
- **Development:** Debug builds for fast iteration
- **Production:** Release builds with optimizations (`--release`)

### FFI Overhead
- Minimize FFI boundary crossings (batch operations when possible)
- Use zero-copy strategies for large data transfers
- Cache compiled scripts to avoid re-parsing

### Memory Efficiency
- Immediate cleanup via dispose() for short-lived engines
- NativeFinalizer for automatic cleanup of long-lived objects
- Avoid unnecessary data copies across FFI boundary

## Development Workflow

### Initial Setup
```bash
# Install Rust targets
cd rust && rustup show

# Get Dart dependencies
dart pub get
```

### Development Iteration
```bash
# Run with native assets
dart run --enable-experiment=native-assets example/example.dart

# Run tests
dart test --enable-experiment=native-assets

# Analyze code
dart analyze

# Format code
dart format .
```

### Clean Build
```bash
# Clean Dart artifacts
dart clean

# Clean Rust artifacts
cd rust && cargo clean

# Rebuild from scratch
dart run --enable-experiment=native-assets
```

## Version Compatibility

### Minimum Versions
- **Dart SDK:** 3.10.1+
- **Rust:** 1.90.0
- **ffi:** 2.1.0+
- **native_toolchain_rust:** 1.0.0+

### Experimental Features
- **native_assets:** Required for build system

## References

- [Rhai Documentation](https://rhai.rs/book/)
- [Dart FFI Documentation](https://dart.dev/guides/libraries/c-interop)
- [Native Assets Documentation](https://github.com/dart-lang/native/tree/main/pkgs/native_assets_cli)
- [EmbedAnythingInDart Reference](~/Documents/code/embedanythingindart/)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
