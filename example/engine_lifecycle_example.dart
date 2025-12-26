import 'package:rhai_dart/rhai_dart.dart';

void main() {
  print('=== Rhai Engine Lifecycle Example ===\n');

  // Example 1: Create engine with default configuration
  print('Example 1: Default Configuration');
  final engine1 = RhaiEngine.withDefaults();
  print('Created engine: $engine1');
  engine1.dispose();
  print('Disposed engine: $engine1\n');

  // Example 2: Create engine with custom configuration
  print('Example 2: Custom Configuration');
  final customConfig = RhaiConfig.custom(
    maxOperations: 500000,
    maxStackDepth: 50,
    timeoutMs: 3000,
  );
  print('Config: $customConfig');
  final engine2 = RhaiEngine.withConfig(customConfig);
  print('Created engine: $engine2');
  engine2.dispose();
  print('Disposed engine: $engine2\n');

  // Example 3: Multiple engines
  print('Example 3: Multiple Engines');
  final engines = <RhaiEngine>[];
  for (var i = 0; i < 3; i++) {
    final engine = RhaiEngine.withDefaults();
    print('Created engine $i: $engine');
    engines.add(engine);
  }
  print('Disposing all engines...');
  for (var i = 0; i < engines.length; i++) {
    engines[i].dispose();
    print('Disposed engine $i: ${engines[i]}');
  }
  print('');

  // Example 4: Config comparison
  print('Example 4: Configuration Options');
  final secureConfig = RhaiConfig.secureDefaults();
  print('Secure defaults: $secureConfig');

  final unlimitedConfig = RhaiConfig.unlimited();
  print('\nUnlimited config (dangerous!): $unlimitedConfig');

  // Example 5: Config validation
  print('\nExample 5: Configuration Validation');
  try {
    final invalidConfig = RhaiConfig.custom(
      maxOperations: -1, // Invalid!
    );
    print('This should not print: $invalidConfig');
  } catch (e) {
    print('Caught expected error: $e');
  }

  // Example 6: Automatic cleanup via finalizer
  print('\nExample 6: Automatic Cleanup');
  print('Creating engine without manual disposal...');
  {
    final tempEngine = RhaiEngine.withDefaults();
    print('Created: $tempEngine');
    // No dispose() call - will be cleaned up by finalizer
  }
  print('Engine went out of scope - will be cleaned up by GC\n');

  print('=== All examples completed successfully! ===');
}
