/// Example 4: Comprehensive Error Handling
///
/// This example demonstrates all aspects of error handling in Rhai-Dart:
/// - Catching syntax errors with line numbers
/// - Catching runtime errors
/// - Pattern matching on exception types
/// - Extracting error details (line numbers, stack traces, messages)
/// - Proper resource disposal with try-finally blocks
/// - Error propagation from Dart functions to Rhai

import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('=== Example 4: Comprehensive Error Handling ===\n');

  // Example 1: Catching syntax errors with line numbers
  print('Example 1: Syntax Errors with Line Numbers');
  print('----------------------------------------');
  final engine = RhaiEngine.withDefaults();

  try {
    // Missing closing brace
    print('Testing: Missing closing brace...');
    try {
      engine.eval('''
        if true {
          let x = 10;
      ''');
    } on RhaiSyntaxError catch (e) {
      print('Caught syntax error!');
      print('  Line number: ${e.lineNumber}');
      print('  Message: ${e.message}');
      print('  toString(): $e');
    }

    // Invalid syntax
    print('\nTesting: Incomplete statement...');
    try {
      engine.eval('let x = ');
    } on RhaiSyntaxError catch (e) {
      print('Caught syntax error!');
      print('  Line number: ${e.lineNumber}');
      print('  Message: ${e.message}');
    }

    // Multiple line script with error
    print('\nTesting: Multi-line script with syntax error...');
    try {
      engine.eval('''
        let x = 10;
        let y = 20;
        let z = x + y
        let w = z * 2;
      '''); // Missing semicolon on line 3
    } on RhaiSyntaxError catch (e) {
      print('Caught syntax error!');
      print('  Line number: ${e.lineNumber ?? "unknown"}');
      print('  Message: ${e.message}');
    }

    // Example 2: Catching runtime errors
    print('\n\nExample 2: Runtime Errors');
    print('----------------------------------------');

    // Undefined variable
    print('Testing: Undefined variable...');
    try {
      engine.eval('''
        let x = 10;
        x + y
      '''); // 'y' is undefined
    } on RhaiRuntimeError catch (e) {
      print('Caught runtime error!');
      print('  Message: ${e.message}');
      print('  Stack trace: ${e.stackTrace ?? "not available"}');
    }

    // Type mismatch
    print('\nTesting: Type mismatch...');
    try {
      engine.eval('let x = "hello"; let y = 42; x + y'); // Type mismatch
    } on RhaiRuntimeError catch (e) {
      print('Caught runtime error!');
      print('  Message: ${e.message}');
    }

    // Array index out of bounds
    print('\nTesting: Array index out of bounds...');
    try {
      engine.eval('''
        let arr = [1, 2, 3];
        arr[10]
      ''');
    } on RhaiRuntimeError catch (e) {
      print('Caught runtime error!');
      print('  Message: ${e.message}');
    }

    // Example 3: Pattern matching on exception types
    print('\n\nExample 3: Pattern Matching on Exception Types');
    print('----------------------------------------');

    final testScripts = [
      ('let x =', 'Syntax error'),
      ('let x = 10; x + y', 'Runtime error'),
      ('1 + 1', 'Success'),
    ];

    for (final (script, description) in testScripts) {
      print('\nTesting: $description');
      print('Script: "$script"');

      try {
        final result = engine.eval(script);
        print('Success! Result: $result');
      } on RhaiSyntaxError catch (e) {
        print('Syntax error at line ${e.lineNumber}: ${e.message}');
      } on RhaiRuntimeError catch (e) {
        print('Runtime error: ${e.message}');
      } on RhaiFFIError catch (e) {
        print('FFI error: ${e.message}');
      } on RhaiException catch (e) {
        print('Generic Rhai error: ${e.message}');
      }
    }

    // Example 4: Using switch expressions (Dart 3.0+)
    print('\n\nExample 4: Modern Pattern Matching with Switch');
    print('----------------------------------------');

    try {
      engine.eval('let x =');
    } catch (e) {
      final errorType = switch (e) {
        RhaiSyntaxError() => 'Syntax Error',
        RhaiRuntimeError() => 'Runtime Error',
        RhaiFFIError() => 'FFI Error',
        _ => 'Unknown Error',
      };
      print('Error type: $errorType');
      print('Details: $e');
    }

    // Example 5: Error propagation from Dart functions
    print('\n\nExample 5: Error Propagation from Dart Functions');
    print('----------------------------------------');

    // Register a function that can throw errors
    engine.registerFunction('safe_divide', (num a, num b) {
      if (b == 0) {
        throw Exception('Division by zero is not allowed');
      }
      return a / b;
    });

    // Test successful call
    print('Testing: safe_divide(10, 2)');
    try {
      final result = engine.eval('safe_divide(10, 2)');
      print('Success! Result: $result');
    } on RhaiRuntimeError catch (e) {
      print('Error: ${e.message}');
    }

    // Test error propagation
    print('\nTesting: safe_divide(10, 0)');
    try {
      engine.eval('safe_divide(10, 0)');
    } on RhaiRuntimeError catch (e) {
      print('Caught error propagated from Dart function!');
      print('  Message: ${e.message}');
    }

    // Register another function with validation
    engine.registerFunction('validate_age', (int age) {
      if (age < 0) {
        throw ArgumentError('Age cannot be negative');
      }
      if (age > 150) {
        throw ArgumentError('Age cannot exceed 150');
      }
      return 'Valid age: $age';
    });

    print('\nTesting: validate_age(25)');
    try {
      final result = engine.eval('validate_age(25)');
      print('Success! Result: $result');
    } on RhaiRuntimeError catch (e) {
      print('Error: ${e.message}');
    }

    print('\nTesting: validate_age(-5)');
    try {
      engine.eval('validate_age(-5)');
    } on RhaiRuntimeError catch (e) {
      print('Caught validation error!');
      print('  Message: ${e.message}');
    }

    // Example 6: Proper disposal in finally blocks
    print('\n\nExample 6: Proper Resource Cleanup with Finally');
    print('----------------------------------------');

    RhaiEngine? tempEngine;
    try {
      print('Creating temporary engine...');
      tempEngine = RhaiEngine.withDefaults();
      print('Engine created: $tempEngine');

      print('Executing script that will fail...');
      tempEngine.eval('let x ='); // This will throw

      print('This line will not be reached');
    } on RhaiSyntaxError catch (e) {
      print('Caught error: ${e.message}');
      print('But cleanup will still happen in finally block...');
    } finally {
      print('Finally block: Disposing engine...');
      tempEngine?.dispose();
      print('Engine disposed: ${tempEngine?.isDisposed ?? false}');
    }

    // Example 7: Nested error handling
    print('\n\nExample 7: Nested Error Handling');
    print('----------------------------------------');

    engine.registerFunction('risky_operation', (int value) {
      if (value < 0) {
        throw Exception('Negative values not allowed');
      }
      return value * 2;
    });

    try {
      print('Testing nested operations...');
      final result = engine.eval('''
        let x = risky_operation(10);
        let y = risky_operation(-5);
        x + y
      ''');
      print('Result: $result');
    } on RhaiRuntimeError catch (e) {
      print('Caught error from nested operation!');
      print('  Message: ${e.message}');

      // You can handle the error and continue
      print('  Continuing execution after error...');
    }

    print('\n=== All error handling examples completed! ===');
  } finally {
    // Always dispose the engine, even if errors occurred
    print('\nFinal cleanup: Disposing main engine...');
    engine.dispose();
    print('Engine disposed: ${engine.isDisposed}');
  }
}
