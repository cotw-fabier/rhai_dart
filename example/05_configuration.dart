/// Example 5: Engine Configuration
///
/// This example demonstrates all aspects of engine configuration:
/// - Default secure configuration
/// - Custom configuration with timeout and operation limits
/// - Timeout enforcement
/// - Operation limit enforcement
/// - String length limit enforcement
/// - Stack depth limit enforcement
/// - Sandboxing in action

import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('=== Example 5: Engine Configuration ===\n');

  // Example 1: Default Secure Configuration
  print('Example 1: Default Secure Configuration');
  print('----------------------------------------');

  final defaultConfig = RhaiConfig.secureDefaults();
  print('Default config:');
  print(defaultConfig);

  final defaultEngine = RhaiEngine.withDefaults();
  print('\nEngine created with defaults: $defaultEngine');

  // Test with a simple script
  final result1 = defaultEngine.eval('2 + 2');
  print('Result: $result1');
  defaultEngine.dispose();
  print('Engine disposed.\n');

  // Example 2: Custom Configuration
  print('\nExample 2: Custom Configuration');
  print('----------------------------------------');

  final customConfig = RhaiConfig.custom(
    maxOperations: 500000,     // Half the default
    maxStackDepth: 50,         // Half the default
    maxStringLength: 5000000,  // ~5 MB
    timeoutMs: 3000,           // 3 seconds
    disableFileIo: true,
    disableEval: true,
    disableModules: true,
  );

  print('Custom config:');
  print(customConfig);

  final customEngine = RhaiEngine.withConfig(customConfig);
  print('\nEngine created with custom config: $customEngine');

  final result2 = customEngine.eval('10 * 5');
  print('Result: $result2');
  customEngine.dispose();
  print('Engine disposed.\n');

  // Example 3: Timeout Enforcement
  print('\nExample 3: Timeout Enforcement');
  print('----------------------------------------');

  // Create engine with short timeout
  final timeoutConfig = RhaiConfig.custom(
    timeoutMs: 1000, // 1 second timeout
    maxOperations: 0, // Unlimited operations to test timeout specifically
  );

  final timeoutEngine = RhaiEngine.withConfig(timeoutConfig);
  print('Created engine with 1 second timeout');

  // Test with a quick script (should succeed)
  print('\nTesting quick script (should succeed):');
  try {
    final result = timeoutEngine.eval('let sum = 0; for i in 0..100 { sum += i; } sum');
    print('Success! Result: $result');
  } on RhaiRuntimeError catch (e) {
    print('Error: ${e.message}');
  }

  // Test with a slow script (should timeout)
  print('\nTesting slow script (should timeout):');
  try {
    // This script is intentionally slow due to large iteration count
    timeoutEngine.eval('''
      let sum = 0;
      for i in 0..1000000000 {
        sum += i;
      }
      sum
    ''');
    print('This should not print - script should timeout');
  } on RhaiRuntimeError catch (e) {
    print('Caught timeout error!');
    print('  Message: ${e.message}');
  }

  timeoutEngine.dispose();

  // Example 4: Operation Limit Enforcement
  print('\n\nExample 4: Operation Limit Enforcement');
  print('----------------------------------------');

  final operationConfig = RhaiConfig.custom(
    maxOperations: 10000, // Very low limit for demonstration
    timeoutMs: 0,         // No timeout to test operation limit specifically
  );

  final operationEngine = RhaiEngine.withConfig(operationConfig);
  print('Created engine with 10,000 operation limit');

  // Test with script that stays within limit
  print('\nTesting script within limit (should succeed):');
  try {
    final result = operationEngine.eval('''
      let sum = 0;
      for i in 0..50 {
        sum += i;
      }
      sum
    ''');
    print('Success! Result: $result');
  } on RhaiRuntimeError catch (e) {
    print('Error: ${e.message}');
  }

  // Test with script that exceeds limit
  print('\nTesting script exceeding operation limit (should fail):');
  try {
    operationEngine.eval('''
      let sum = 0;
      for i in 0..100000 {
        sum += i;
      }
      sum
    ''');
    print('This should not print - should hit operation limit');
  } on RhaiRuntimeError catch (e) {
    print('Caught operation limit error!');
    print('  Message: ${e.message}');
  }

  operationEngine.dispose();

  // Example 5: Stack Depth Limit Enforcement
  print('\n\nExample 5: Stack Depth Limit Enforcement');
  print('----------------------------------------');

  final stackConfig = RhaiConfig.custom(
    maxStackDepth: 20, // Very low for demonstration
    maxOperations: 0,  // Unlimited operations
    timeoutMs: 0,      // No timeout
  );

  final stackEngine = RhaiEngine.withConfig(stackConfig);
  print('Created engine with stack depth limit of 20');

  // Test with shallow recursion (should succeed)
  print('\nTesting shallow recursion (should succeed):');
  try {
    final result = stackEngine.eval('''
      fn factorial(n) {
        if n <= 1 {
          1
        } else {
          n * factorial(n - 1)
        }
      }
      factorial(5)
    ''');
    print('Success! Result: $result');
  } on RhaiRuntimeError catch (e) {
    print('Error: ${e.message}');
  }

  // Test with deep recursion (should fail)
  print('\nTesting deep recursion (should fail):');
  try {
    stackEngine.eval('''
      fn deep_recursion(n) {
        if n <= 0 {
          0
        } else {
          deep_recursion(n - 1) + 1
        }
      }
      deep_recursion(100)
    ''');
    print('This should not print - should hit stack depth limit');
  } on RhaiRuntimeError catch (e) {
    print('Caught stack overflow error!');
    print('  Message: ${e.message}');
  }

  stackEngine.dispose();

  // Example 6: String Length Limit Enforcement
  print('\n\nExample 6: String Length Limit Enforcement');
  print('----------------------------------------');

  final stringConfig = RhaiConfig.custom(
    maxStringLength: 1000, // 1 KB limit
    maxOperations: 0,
    timeoutMs: 0,
  );

  final stringEngine = RhaiEngine.withConfig(stringConfig);
  print('Created engine with 1 KB string length limit');

  // Test with small string (should succeed)
  print('\nTesting small string (should succeed):');
  try {
    final result = stringEngine.eval('"Hello, World!"');
    print('Success! Result: $result');
  } on RhaiRuntimeError catch (e) {
    print('Error: ${e.message}');
  }

  // Test with large string (should fail)
  print('\nTesting large string creation (should fail):');
  try {
    stringEngine.eval('''
      let s = "";
      for i in 0..100 {
        s += "This is a long string that will exceed the limit. ";
      }
      s
    ''');
    print('This should not print - should hit string length limit');
  } on RhaiRuntimeError catch (e) {
    print('Caught string length limit error!');
    print('  Message: ${e.message}');
  }

  stringEngine.dispose();

  // Example 7: Sandboxing in Action
  print('\n\nExample 7: Sandboxing in Action');
  print('----------------------------------------');

  // Default config has sandboxing enabled
  final sandboxEngine = RhaiEngine.withDefaults();
  print('Created engine with default sandboxing');

  // Rhai doesn't have file I/O or eval by default, so we just verify
  // the engine is configured securely
  print('\nSandboxing features:');
  print('- File I/O: disabled');
  print('- eval(): disabled');
  print('- Modules: disabled');
  print('- Operation limits: enabled');
  print('- Timeout: enabled');

  // Test a safe script
  print('\nTesting safe script:');
  final result7 = sandboxEngine.eval('''
    let data = #{
      name: "Alice",
      scores: [85, 90, 95],
    };

    let avg = 0;
    for score in data.scores {
      avg += score;
    }
    avg = avg / data.scores.len();

    data.name + "'s average: " + avg
  ''');
  print('Result: $result7');

  sandboxEngine.dispose();

  // Example 8: Unlimited Configuration (Dangerous!)
  print('\n\nExample 8: Unlimited Configuration (For Testing Only)');
  print('----------------------------------------');

  final unlimitedConfig = RhaiConfig.unlimited();
  print('Unlimited config (WARNING: Not for production!):');
  print(unlimitedConfig);

  final unlimitedEngine = RhaiEngine.withConfig(unlimitedConfig);
  print('\nEngine created with unlimited config');

  // This engine has no limits - use only for trusted scripts
  final result8 = unlimitedEngine.eval('''
    let sum = 0;
    for i in 0..1000 {
      sum += i;
    }
    sum
  ''');
  print('Result: $result8');

  unlimitedEngine.dispose();

  // Example 9: Configuration Comparison
  print('\n\nExample 9: Configuration Comparison');
  print('----------------------------------------');

  print('Secure defaults:');
  print(RhaiConfig.secureDefaults());

  print('\nCustom for production (high limits):');
  final productionConfig = RhaiConfig.custom(
    maxOperations: 10000000,
    maxStackDepth: 200,
    timeoutMs: 30000,
  );
  print(productionConfig);

  print('\nDevelopment config (no limits):');
  print(RhaiConfig.unlimited());

  print('\n=== All configuration examples completed! ===');
}
