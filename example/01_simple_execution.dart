/// Example 1: Simple Script Execution
///
/// This example demonstrates the basics of executing Rhai scripts:
/// - Creating an engine with default secure configuration
/// - Executing simple arithmetic scripts
/// - Printing results
/// - Handling errors with try-catch
/// - Proper resource cleanup

import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('=== Example 1: Simple Script Execution ===\n');

  // Step 1: Create an engine with default secure configuration
  // This provides safe defaults for running untrusted scripts
  print('Step 1: Creating Rhai engine with secure defaults...');
  final engine = RhaiEngine.withDefaults();
  print('Engine created: $engine\n');

  try {
    // Step 2: Execute a simple arithmetic script
    print('Step 2: Evaluating simple arithmetic expression...');
    final result1 = engine.eval('2 + 2');
    print('Result of "2 + 2": $result1');
    print('Result type: ${result1.runtimeType}\n');

    // Step 3: Execute more complex arithmetic
    print('Step 3: Evaluating complex expression...');
    final result2 = engine.eval('(10 + 5) * 2 - 8');
    print('Result of "(10 + 5) * 2 - 8": $result2');
    print('Result type: ${result2.runtimeType}\n');

    // Step 4: Execute script with variables
    print('Step 4: Evaluating script with variables...');
    final result3 = engine.eval('''
      let x = 10;
      let y = 20;
      x + y
    ''');
    print('Result of script with variables: $result3\n');

    // Step 5: Execute script returning different types
    print('Step 5: Testing different return types...');

    // Integer
    final intResult = engine.eval('42');
    print('Integer: $intResult (type: ${intResult.runtimeType})');

    // Float
    final floatResult = engine.eval('3.14159');
    print('Float: $floatResult (type: ${floatResult.runtimeType})');

    // String
    final stringResult = engine.eval('"Hello, Rhai!"');
    print('String: $stringResult (type: ${stringResult.runtimeType})');

    // Boolean
    final boolResult = engine.eval('true');
    print('Boolean: $boolResult (type: ${boolResult.runtimeType})');

    // Array
    final arrayResult = engine.eval('[1, 2, 3, 4, 5]');
    print('Array: $arrayResult (type: ${arrayResult.runtimeType})');

    // Object/Map
    final mapResult = engine.eval('#{name: "Alice", age: 30}');
    print('Map: $mapResult (type: ${mapResult.runtimeType})\n');

    // Step 6: Demonstrate error handling - syntax error
    print('Step 6: Testing error handling...');
    print('Testing syntax error:');
    try {
      engine.eval('let x = '); // Incomplete statement
    } on RhaiSyntaxError catch (e) {
      print('Caught syntax error at line ${e.lineNumber}: ${e.message}');
    }

    // Step 7: Demonstrate error handling - runtime error
    print('\nTesting runtime error:');
    try {
      engine.eval('let x = 10; x + y'); // 'y' is undefined
    } on RhaiRuntimeError catch (e) {
      print('Caught runtime error: ${e.message}');
    }

    // Step 8: Demonstrate error handling - generic catch
    print('\nTesting generic error handling:');
    try {
      engine.eval('1 / 0'); // Division by zero
    } on RhaiException catch (e) {
      print('Caught Rhai exception: ${e.message}');
    }

    print('\n=== All examples completed successfully! ===');
  } finally {
    // Step 9: Clean up resources
    // This ensures the native engine is properly disposed even if an error occurs
    print('\nCleaning up resources...');
    engine.dispose();
    print('Engine disposed: $engine');
    print('isDisposed: ${engine.isDisposed}');
  }

  // Note: Even without calling dispose(), the engine will be automatically
  // cleaned up when it goes out of scope via the NativeFinalizer.
  // However, calling dispose() explicitly is recommended for deterministic cleanup.
}
