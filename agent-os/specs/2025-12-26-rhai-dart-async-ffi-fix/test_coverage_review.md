# Test Coverage Review - Dual-Path Architecture

## Current Test Status (Task Group 6.1)

### Tests for Sync eval() Path
**File:** `test/function_registration_test.dart` (7 tests, 1 skipped)
- ✅ sync function registration and invocation
- ⏭️ async function registration and invocation (SKIPPED - old architecture test)
- ✅ function with multiple parameter types
- ✅ function error propagation to Rhai
- ✅ function return value conversion - primitives
- ✅ function return value conversion - collections
- ✅ function with list and map parameters
- ✅ multiple functions registered

**Coverage:** Good coverage for sync functions in sync eval() path

### Tests for evalAsync() Path
**File:** `test/eval_async_test.dart` (7 tests, all passing)
- ✅ evalAsync with sync functions works
- ✅ evalAsync with simple arithmetic
- ✅ evalAsync with async functions
- ✅ sync eval rejects async functions with helpful error
- ✅ evalAsync with async function returning map
- ✅ evalAsync error propagation
- ✅ concurrent evalAsync calls

**Coverage:** Good basic coverage for both sync and async functions in evalAsync() path

### Tests Needing Update/Removal
**File:** `test/async_callback_test.dart`
- Status: Uses old architecture (eval() with async functions)
- Action: Review and potentially remove or update

**File:** `test/async_function_test.dart` (26 failing tests)
- Status: All tests use old architecture assumptions
- Action: Remove or heavily refactor - most functionality now covered by eval_async_test.dart

### Coverage Gaps Identified

#### Sync eval() Edge Cases (Task 6.2)
- [ ] Sync function with multiple parameters (various arities 0-10)
- [ ] Sync function with complex return types (deeply nested structures)
- [ ] Sync function error handling (different error types)
- [ ] Multiple sync functions in one script
- [ ] Sync function performance characteristics

#### evalAsync() Comprehensive Tests (Task 6.3)
- [ ] Async function with delayed resolution (various delays)
- [ ] Async function with immediate resolution (Future.value)
- [ ] Async function with error after delay
- [ ] Async function with different Future types (Completer, Future.delayed, etc.)
- [ ] Nested async calls within scripts
- [ ] evalAsync timeout scenarios

#### Integration Tests (Task 6.4)
- [ ] Real HTTP request using package:http
- [ ] File I/O async operations
- [ ] Mixing sync and async functions in same script

#### Performance Tests (Task 6.5 - Optional)
- [ ] Benchmark sync eval() overhead
- [ ] Benchmark evalAsync() with various workloads
- [ ] Verify no regression in sync path

## Test Organization Strategy

1. Keep `eval_async_test.dart` for core dual-path tests (currently 7 tests)
2. Keep `function_registration_test.dart` for sync eval() tests (currently 7 tests)
3. Create `dual_path_edge_cases_test.dart` for edge case testing (new)
4. Create `integration_async_test.dart` for real-world async I/O (new)
5. Remove or archive `async_callback_test.dart` (old architecture)
6. Remove or archive `async_function_test.dart` (old architecture)

## Target Test Counts

- eval_async_test.dart: 7 existing + 6 new = 13 tests
- function_registration_test.dart: 7 existing + 5 new = 12 tests
- dual_path_edge_cases_test.dart: 8 new tests
- integration_async_test.dart: 3-5 new tests

**Total:** Approximately 36-38 tests (within 25-40 target range)
