# Setup Guide

This guide will walk you through setting up the rhai_dart library for development and usage.

## Table of Contents

- [System Requirements](#system-requirements)
- [Rust Toolchain Installation](#rust-toolchain-installation)
- [Dart SDK Installation](#dart-sdk-installation)
- [Platform-Specific Setup](#platform-specific-setup)
- [Project Setup](#project-setup)
- [Verifying Your Installation](#verifying-your-installation)
- [Troubleshooting](#troubleshooting)

## System Requirements

### Minimum Requirements

- **Dart SDK**: 3.10.1 or later
- **Rust Toolchain**: 1.83.0 (automatically pinned via `rust-toolchain.toml`)
- **Disk Space**: ~2 GB for Rust toolchain and dependencies
- **RAM**: 4 GB minimum (8 GB recommended for building)

### Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| macOS | ARM64 (Apple Silicon) | Supported |
| macOS | x64 (Intel) | Supported |
| Linux | x64 | Fully Tested |
| Linux | ARM64 | Supported |
| Windows | x64 | Supported |

**Note:** Only Linux x64 has been fully tested with hardware. Other platforms compile successfully but require native hardware for runtime verification.

## Rust Toolchain Installation

### Step 1: Install rustup

The recommended way to install Rust is through `rustup`, the official Rust toolchain installer.

#### macOS and Linux

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Follow the on-screen instructions. When asked, choose the default installation option (option 1).

#### Windows

Download and run the installer from: https://rustup.rs/

Alternatively, use the Visual Studio installer:
1. Download from https://visualstudio.microsoft.com/downloads/
2. Install "Desktop development with C++" workload

### Step 2: Verify Rust Installation

```bash
rustc --version
cargo --version
```

You should see output similar to:
```
rustc 1.83.0 (90b35a623 2024-11-26)
cargo 1.83.0 (5ffbef321 2024-10-29)
```

### Step 3: Install Required Rust Targets

The project's `rust-toolchain.toml` file automatically pins the Rust version and specifies required targets. However, you may need to manually install targets depending on your platform.

#### For macOS (ARM64 or x64)

```bash
# If you're on Apple Silicon (M1/M2/M3)
rustup target add aarch64-apple-darwin

# If you're on Intel Mac
rustup target add x86_64-apple-darwin

# Optional: Install both for universal compatibility
rustup target add aarch64-apple-darwin x86_64-apple-darwin
```

#### For Linux (x64 or ARM64)

```bash
# If you're on x64 Linux
rustup target add x86_64-unknown-linux-gnu

# If you're on ARM64 Linux (e.g., Raspberry Pi)
rustup target add aarch64-unknown-linux-gnu

# Optional: For cross-compilation to ARM64 from x64
rustup target add aarch64-unknown-linux-gnu
sudo apt-get install gcc-aarch64-linux-gnu
```

#### For Windows (x64)

```bash
# For x64 Windows
rustup target add x86_64-pc-windows-msvc
```

### Step 4: Install Rust Components (Optional)

```bash
# For code formatting
rustup component add rustfmt

# For linting
rustup component add clippy
```

## Dart SDK Installation

### macOS

Using Homebrew:
```bash
brew tap dart-lang/dart
brew install dart
```

Or download from: https://dart.dev/get-dart

### Linux

Using apt (Debian/Ubuntu):
```bash
sudo apt-get update
sudo apt-get install apt-transport-https
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list

sudo apt-get update
sudo apt-get install dart
```

Or download from: https://dart.dev/get-dart

### Windows

Using Chocolatey:
```powershell
choco install dart-sdk
```

Or download from: https://dart.dev/get-dart

### Verify Dart Installation

```bash
dart --version
```

You should see output similar to:
```
Dart SDK version: 3.10.1 (stable)
```

## Platform-Specific Setup

### macOS Setup

#### Install Xcode Command Line Tools

The Xcode Command Line Tools provide essential build tools like `clang` and the linker.

```bash
xcode-select --install
```

Verify installation:
```bash
xcode-select -p
# Should output: /Library/Developer/CommandLineTools
```

#### Common macOS Issues

**Issue:** `xcrun: error: unable to find utility`
**Solution:** Install Xcode Command Line Tools as shown above

**Issue:** `ld: framework not found`
**Solution:** Ensure you're using the correct target architecture:
- Apple Silicon: `aarch64-apple-darwin`
- Intel Mac: `x86_64-apple-darwin`

### Linux Setup

#### Install Build Essential Tools

```bash
sudo apt-get update
sudo apt-get install build-essential pkg-config
```

For cross-compilation to ARM64 (optional):
```bash
sudo apt-get install gcc-aarch64-linux-gnu
```

#### Verify Build Tools

```bash
gcc --version
make --version
```

#### Common Linux Issues

**Issue:** `error: linker 'cc' not found`
**Solution:** Install build-essential: `sudo apt-get install build-essential`

**Issue:** `cannot find -lgcc_s`
**Solution:** Install gcc multilib: `sudo apt-get install gcc-multilib`

**Issue:** Cross-compilation fails for ARM64
**Solution:** Install cross-compiler: `sudo apt-get install gcc-aarch64-linux-gnu`

### Windows Setup

#### Install Visual Studio Build Tools

You need the Microsoft Visual C++ (MSVC) compiler and linker.

**Option 1: Visual Studio 2019 or later (Recommended)**
1. Download from https://visualstudio.microsoft.com/downloads/
2. During installation, select "Desktop development with C++"
3. Ensure "MSVC v142" (or later) and "Windows 10 SDK" are checked

**Option 2: Build Tools for Visual Studio**
1. Download "Build Tools for Visual Studio" from the same link
2. Install the "C++ build tools" workload
3. This is lighter than full Visual Studio

#### Verify MSVC Installation

```powershell
# Open "Developer Command Prompt for VS" or "x64 Native Tools Command Prompt"
cl
link
```

You should see the Microsoft compiler and linker help messages.

#### Common Windows Issues

**Issue:** `error: linker 'link.exe' not found`
**Solution:** Install Visual Studio Build Tools as shown above

**Issue:** `LINK : fatal error LNK1181: cannot open input file 'msvcrt.lib'`
**Solution:** Ensure you're running from "Developer Command Prompt for VS"

**Issue:** `error: could not find native static library`
**Solution:** Rebuild with clean build: `cargo clean && cargo build --release`

## Project Setup

### 1. Clone or Create Your Project

If using rhai_dart as a dependency:

```bash
mkdir my_rhai_project
cd my_rhai_project
dart create .
```

### 2. Add rhai_dart Dependency

Edit your `pubspec.yaml`:

```yaml
name: my_rhai_project
description: A project using rhai_dart
version: 1.0.0

environment:
  sdk: ^3.10.1

dependencies:
  rhai_dart: ^0.1.0

# IMPORTANT: Enable native assets
native_assets:
  enabled: true

dev_dependencies:
  test: ^1.24.0
```

### 3. Get Dependencies

```bash
dart pub get
```

This command will:
1. Download the rhai_dart package
2. Trigger the native asset build hook
3. Compile the Rust library for your platform
4. Link the native library

**Note:** The first build may take 2-5 minutes as Rust compiles dependencies.

### 4. Verify Setup

Create a test file `test_setup.dart`:

```dart
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('Testing rhai_dart setup...');

  final engine = RhaiEngine.withDefaults();

  try {
    final result = engine.eval('2 + 2');
    print('✓ Rhai engine works! Result: $result');

    if (result == 4) {
      print('✓ All tests passed!');
    } else {
      print('✗ Unexpected result: expected 4, got $result');
    }
  } catch (e) {
    print('✗ Error: $e');
  } finally {
    engine.dispose();
  }
}
```

Run it:

```bash
dart run --enable-experiment=native-assets test_setup.dart
```

Expected output:
```
Testing rhai_dart setup...
✓ Rhai engine works! Result: 4
✓ All tests passed!
```

## Verifying Your Installation

### Run the Test Suite

The library includes comprehensive tests. Running them verifies your entire setup:

```bash
dart test --enable-experiment=native-assets
```

Expected output:
```
00:02 +102 -4: All tests passed!
```

**Note:** 4 tests are skipped due to documented async function limitations.

### Build the Library Manually (Optional)

If you want to verify the Rust build separately:

```bash
cd rust
cargo build --release
```

On success, you'll see the library in:
- macOS: `target/release/librhai_dart.dylib`
- Linux: `target/release/librhai_dart.so`
- Windows: `target/release/rhai_dart.dll`

### Check for Rust Warnings or Errors

```bash
cd rust
cargo check
cargo clippy
```

These should complete without errors.

## Troubleshooting

### Native Assets Issues

**Issue:** `Failed to load dynamic library`

**Solutions:**
1. Ensure native assets are enabled in `pubspec.yaml`:
   ```yaml
   native_assets:
     enabled: true
   ```

2. Run with the native assets flag:
   ```bash
   dart run --enable-experiment=native-assets your_script.dart
   ```

3. Rebuild the native library:
   ```bash
   cd rust
   cargo clean
   cargo build --release
   ```

### Rust Build Failures

**Issue:** `error: failed to run custom build command`

**Solutions:**
1. Check Rust version: `rustc --version` (should be 1.83.0)
2. Update Rust: `rustup update stable`
3. Clean and rebuild:
   ```bash
   cd rust
   cargo clean
   cargo build --release
   ```

**Issue:** `error: linking with 'cc' failed`

**Platform-specific solutions:**
- **macOS:** Install Xcode Command Line Tools: `xcode-select --install`
- **Linux:** Install build-essential: `sudo apt-get install build-essential`
- **Windows:** Install Visual Studio Build Tools

### Dart Build Failures

**Issue:** `Error: The native assets feature is disabled`

**Solution:** Add `--enable-experiment=native-assets` to your dart command:
```bash
dart run --enable-experiment=native-assets your_script.dart
```

**Issue:** `Target dart_native_toolchain:native_toolchain_rust not found`

**Solution:** Run `dart pub get` to ensure all dependencies are installed.

### Runtime Errors

**Issue:** `Unhandled exception: Invalid argument(s): Failed to load dynamic library`

**Solutions:**
1. Ensure library was built for correct architecture
2. Check that library file exists in expected location
3. On macOS, verify you're using the correct target:
   - Apple Silicon: `aarch64-apple-darwin`
   - Intel: `x86_64-apple-darwin`

**Issue:** `Symbol not found` or `Undefined symbol` errors

**Solutions:**
1. Rebuild with clean build: `cd rust && cargo clean && cargo build --release`
2. Ensure Rust version matches: `rustc --version` (should be 1.83.0)
3. Verify all Rust dependencies updated: `cd rust && cargo update`

### Memory or Performance Issues

**Issue:** High memory usage during build

**Solution:** Rust compilation can be memory-intensive. Close other applications or build with fewer parallel jobs:
```bash
cd rust
cargo build --release -j 2
```

**Issue:** Slow build times

**Solutions:**
1. First build is always slower (2-5 minutes) due to dependency compilation
2. Subsequent builds should be faster (10-30 seconds)
3. Consider using `cargo build` (debug) instead of `cargo build --release` for development

## Getting Help

If you encounter issues not covered in this guide:

1. **Check the main README:** [README.md](../README.md)
2. **Review existing issues:** Check the project's issue tracker
3. **Check Rhai documentation:** https://rhai.rs/
4. **Check Dart FFI documentation:** https://dart.dev/guides/libraries/c-interop

## Next Steps

After completing setup:

1. **Read the Architecture Guide:** [docs/architecture.md](architecture.md)
2. **Review Type Conversion:** [docs/type_conversion.md](type_conversion.md)
3. **Learn about Security:** [docs/security.md](security.md)
4. **Explore Examples:** [example/](../example/)
5. **Read API Documentation:** Generate with `dart doc` and open `doc/api/index.html`

## Development Tools (Optional)

### Recommended IDE Setup

**Visual Studio Code:**
- Install "Dart" extension
- Install "rust-analyzer" extension
- Install "Better TOML" extension

**IntelliJ IDEA / Android Studio:**
- Install "Dart" plugin
- Install "Rust" plugin

### Useful Cargo Commands

```bash
# Format Rust code
cargo fmt

# Lint Rust code
cargo clippy

# Run Rust tests (if any)
cargo test

# Clean build artifacts
cargo clean

# Update dependencies
cargo update

# Check for outdated dependencies
cargo outdated
```

### Useful Dart Commands

```bash
# Format Dart code
dart format .

# Analyze Dart code
dart analyze

# Generate documentation
dart doc

# Run specific test
dart test test/script_execution_test.dart --enable-experiment=native-assets

# Run with coverage
dart test --enable-experiment=native-assets --coverage
```

## Platform-Specific Performance Tuning

### macOS

For faster builds on Apple Silicon:
```bash
# Use native toolchain
export CARGO_BUILD_TARGET=aarch64-apple-darwin
```

### Linux

For faster linking with `lld` (LLVM linker):
```bash
sudo apt-get install lld
export RUSTFLAGS="-C link-arg=-fuse-ld=lld"
```

### Windows

For faster builds with multiple cores:
```powershell
# Set in PowerShell
$env:CARGO_BUILD_JOBS = "4"
```

## Summary

You should now have:
- ✓ Rust toolchain installed (1.83.0)
- ✓ Dart SDK installed (3.10.1+)
- ✓ Platform-specific build tools installed
- ✓ rhai_dart project set up
- ✓ Tests passing

Happy scripting with rhai_dart!
