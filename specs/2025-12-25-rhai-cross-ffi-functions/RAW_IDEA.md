# Cross-FFI Functions for Rhai Script Execution - Raw Idea

## Overview
Building cross-FFI functions for creating and running Rhai scripts with Dart integration.

## Core Features
- Build cross FFI functions for creating and running Rhai scripts
- Use ~/Documents/code/embedanythingindart/ as an example project for setting up native_toolchain_rust
- Functions like eval_rhai and analyze_rhai
- Way for Rhai scripts to call back to Dart functions (possibly pass functions in an array to eval_rhai)
- Bootstrap the library, ensure Rhai is properly working and building, and setup FFI boundaries

## Scope
This combines FFI foundation, native assets build integration, and Dart-to-Rhai callbacks.
