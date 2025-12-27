/// Example 7: Variables and Constants
///
/// This example demonstrates how to pass data from Dart into Rhai scripts
/// using setVar and setConstant:
/// - Setting mutable variables that scripts can modify
/// - Setting immutable constants that scripts cannot modify
/// - Passing complex types (lists, maps)
/// - Clearing the scope

import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('=== Example 7: Variables and Constants ===\n');

  final engine = RhaiEngine.withDefaults();

  try {
    // Step 1: Set a mutable variable
    print('Step 1: Setting mutable variables...');
    engine.setVar('name', 'Alice');
    engine.setVar('age', 30);
    engine.setVar('active', true);

    // Use variables in script
    final greeting = engine.eval('name + " is " + age + " years old"');
    print('Greeting: $greeting');

    // Modify variable in script
    engine.eval('age = 31');
    final newAge = engine.eval('age');
    print('Age after modification: $newAge\n');

    // Step 2: Set immutable constants
    print('Step 2: Setting immutable constants...');
    engine.setConstant('PI', 3.14159);
    engine.setConstant('APP_NAME', 'MyApp');

    // Use constants in script
    final circumference = engine.eval('2.0 * PI * 5.0');
    print('Circumference of circle with radius 5: $circumference');

    // Try to modify constant (will fail)
    print('Attempting to modify constant PI...');
    try {
      engine.eval('PI = 3'); // This will throw!
    } on RhaiRuntimeError catch (e) {
      print('Caught expected error: Cannot modify constant\n');
    }

    // Step 3: Pass complex types
    print('Step 3: Passing complex types...');
    engine.setVar('config', {
      'debug': true,
      'maxRetries': 3,
      'timeout': 5000,
    });
    engine.setVar('items', [1, 2, 3, 4, 5]);

    final debugMode = engine.eval('config.debug');
    print('Debug mode: $debugMode');

    final itemCount = engine.eval('items.len()');
    print('Item count: $itemCount');

    final sum = engine.eval('items.reduce(|a, b| a + b)');
    print('Sum of items: $sum\n');

    // Step 4: Clear scope
    print('Step 4: Clearing scope...');
    engine.clearScope();

    // Variables are no longer available
    try {
      engine.eval('name');
    } on RhaiRuntimeError {
      print('Variables cleared - "name" is no longer defined');
    }

    // Step 5: Set new variables after clear
    print('\nStep 5: Setting new variables after clear...');
    engine.setVar('message', 'Hello from Dart!');
    final msg = engine.eval('message');
    print('Message: $msg');

    print('\n=== Example completed successfully! ===');
  } finally {
    engine.dispose();
    print('Engine disposed.');
  }
}
