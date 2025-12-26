/// Example 2: Synchronous Function Registration
///
/// This example demonstrates registering Dart functions that can be called from Rhai scripts:
/// - Registering zero-parameter functions
/// - Registering functions with multiple parameters
/// - Parameter type conversion (primitives, lists, maps)
/// - Return value conversion
/// - Error propagation from Dart to Rhai

import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('=== Example 2: Synchronous Function Registration ===\n');

  // Create an engine
  final engine = RhaiEngine.withDefaults();

  try {
    // Example 1: Register a simple function with no parameters
    print('Example 1: Zero-parameter function');
    engine.registerFunction('get_greeting', () {
      return 'Hello from Dart!';
    });

    final result1 = engine.eval('get_greeting()');
    print('Result: $result1\n');

    // Example 2: Register a function with parameters
    print('Example 2: Function with parameters');
    engine.registerFunction('add', (int a, int b) {
      return a + b;
    });

    final result2 = engine.eval('add(10, 20)');
    print('add(10, 20) = $result2\n');

    // Example 3: String manipulation function
    print('Example 3: String manipulation');
    engine.registerFunction('to_uppercase', (String text) {
      return text.toUpperCase();
    });

    final result3 = engine.eval('to_uppercase("hello world")');
    print('to_uppercase("hello world") = $result3\n');

    // Example 4: Function with multiple parameters of different types
    print('Example 4: Multiple parameter types');
    engine.registerFunction('format_message', (String name, int age, bool isActive) {
      return '$name is $age years old and is ${isActive ? "active" : "inactive"}';
    });

    final result4 = engine.eval('format_message("Alice", 30, true)');
    print('Result: $result4\n');

    // Example 5: Function returning a list
    print('Example 5: Returning a list');
    engine.registerFunction('create_range', (int start, int end) {
      return List.generate(end - start, (index) => start + index);
    });

    final result5 = engine.eval('create_range(1, 6)');
    print('create_range(1, 6) = $result5');
    print('Type: ${result5.runtimeType}\n');

    // Example 6: Function returning a map
    print('Example 6: Returning a map');
    engine.registerFunction('create_user', (String name, int age) {
      return {
        'name': name,
        'age': age,
        'created_at': DateTime.now().toIso8601String(),
      };
    });

    final result6 = engine.eval('create_user("Bob", 25)');
    print('create_user("Bob", 25) = $result6');
    print('Type: ${result6.runtimeType}\n');

    // Example 7: Function accepting a list parameter
    print('Example 7: Accepting a list parameter');
    engine.registerFunction('sum_list', (List<dynamic> numbers) {
      return numbers.fold<num>(0, (sum, n) => sum + (n as num));
    });

    final result7 = engine.eval('sum_list([1, 2, 3, 4, 5])');
    print('sum_list([1, 2, 3, 4, 5]) = $result7\n');

    // Example 8: Function accepting a map parameter
    print('Example 8: Accepting a map parameter');
    engine.registerFunction('get_user_info', (Map<String, dynamic> user) {
      return 'User: ${user['name']}, Age: ${user['age']}';
    });

    final result8 = engine.eval('get_user_info(#{name: "Charlie", age: 35})');
    print('Result: $result8\n');

    // Example 9: Error propagation - function throwing an error
    print('Example 9: Error propagation');
    engine.registerFunction('divide', (num a, num b) {
      if (b == 0) {
        throw Exception('Division by zero is not allowed');
      }
      return a / b;
    });

    print('Testing divide(10, 2):');
    final result9a = engine.eval('divide(10, 2)');
    print('Result: $result9a');

    print('\nTesting divide(10, 0):');
    try {
      engine.eval('divide(10, 0)');
    } on RhaiRuntimeError catch (e) {
      print('Caught error from Dart function: ${e.message}');
    }

    // Example 10: Using registered functions in complex scripts
    print('\nExample 10: Complex script with multiple registered functions');
    final result10 = engine.eval('''
      let nums = create_range(1, 11);
      let total = sum_list(nums);
      let user = create_user("Alice", 30);
      format_message(user.name, user.age, true) + " - Total: " + total
    ''');
    print('Complex script result: $result10\n');

    print('=== All examples completed successfully! ===');
  } finally {
    // Clean up
    engine.dispose();
    print('\nEngine disposed.');
  }
}
