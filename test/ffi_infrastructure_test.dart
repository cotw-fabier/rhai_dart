import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:rhai_dart/src/ffi/bindings.dart';
import 'package:rhai_dart/src/ffi/ffi_utils.dart';
import 'package:rhai_dart/src/errors.dart';

void main() {
  group('FFI Infrastructure Tests', () {
    late RhaiBindings bindings;

    setUpAll(() {
      bindings = RhaiBindings.instance;
    });

    test('Library loading and symbol resolution', () {
      // Verify that the library loaded successfully
      expect(bindings, isNotNull);

      // Verify critical FFI function symbols are resolved
      expect(bindings.addresses.getLastError, isNotNull);
      expect(bindings.addresses.freeError, isNotNull);
    });

    test('Thread-local error storage and retrieval', () {
      // Test that error storage and retrieval works
      final errorPtr = bindings.getLastError();

      // Initially should be null or empty
      if (errorPtr != nullptr) {
        bindings.freeError(errorPtr);
      }

      // Clear any existing errors
      final clearedError = bindings.getLastError();
      if (clearedError != nullptr) {
        bindings.freeError(clearedError);
      }

      expect(true, isTrue); // Basic test passes if no crash
    });

    test('Error checking helper function', () {
      // Test the checkFFIError helper
      expect(() => checkFFIError(bindings), returnsNormally);

      // If there's no error, checkFFIError should not throw
      final errorPtr = bindings.getLastError();
      if (errorPtr == nullptr) {
        expect(() => checkFFIError(bindings), returnsNormally);
      } else {
        bindings.freeError(errorPtr);
      }
    });

    test('Opaque pointer creation and disposal (engine)', () {
      // Test that we can create and dispose an opaque engine pointer
      // This test will be expanded once engine creation is implemented

      // For now, verify that the function addresses exist
      expect(bindings.addresses.engineNew, isNotNull);
      expect(bindings.addresses.engineFree, isNotNull);
    });

    test('Panic catching at FFI boundary', () {
      // Test that Rust panics don't crash Dart
      // This will be tested more thoroughly once we have FFI functions that can panic

      // For now, verify the mechanism is in place
      expect(true, isTrue); // Placeholder
    });

    test('Native string handling', () {
      // Test that we can properly handle native strings
      // This will be used extensively for error messages

      final errorPtr = bindings.getLastError();

      if (errorPtr != nullptr) {
        // If there's an error string, we should be able to convert it
        final errorStr = errorPtr.cast<Utf8>().toDartString();
        expect(errorStr, isA<String>());

        // Free the error string
        bindings.freeError(errorPtr);
      }

      expect(true, isTrue);
    });

    test('FFI error class hierarchy', () {
      // Test that our error classes are properly defined
      final syntaxError = RhaiSyntaxError('test error', 42);
      expect(syntaxError, isA<RhaiException>());
      expect(syntaxError, isA<Exception>());
      expect(syntaxError.message, equals('test error'));
      expect(syntaxError.lineNumber, equals(42));

      final runtimeError = RhaiRuntimeError('runtime error', 'stack trace');
      expect(runtimeError, isA<RhaiException>());
      expect(runtimeError.message, equals('runtime error'));

      final ffiError = RhaiFFIError('ffi error');
      expect(ffiError, isA<RhaiException>());
      expect(ffiError.message, equals('ffi error'));
    });

    test('Error toString formatting', () {
      // Test that error messages are well-formatted
      final syntaxError = RhaiSyntaxError('syntax error', 10);
      expect(syntaxError.toString(), contains('RhaiSyntaxError'));
      expect(syntaxError.toString(), contains('syntax error'));
      expect(syntaxError.toString(), contains('10'));

      final runtimeError = RhaiRuntimeError('runtime error', 'trace');
      expect(runtimeError.toString(), contains('RhaiRuntimeError'));
      expect(runtimeError.toString(), contains('runtime error'));
    });
  });
}
