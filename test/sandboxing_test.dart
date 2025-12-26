/// Tests for Rhai engine sandboxing and security features.
///
/// This test suite verifies that:
/// 1. Operation limits are enforced (max_operations)
/// 2. Stack depth limits are enforced (max_stack_depth)
/// 3. String length limits are enforced (max_string_length)
/// 4. File I/O is disabled in default config
/// 5. Eval is disabled in default config (Rhai doesn't have built-in eval by default)
/// 6. Module loading is disabled in default config
library;

import 'package:test/test.dart';
import 'package:rhai_dart/rhai_dart.dart';

void main() {
  group('Sandboxing Tests', () {
    test('operation limit enforcement - infinite loop', () {
      // Create engine with very low operation limit to simulate timeout
      final config = RhaiConfig.custom(
        maxOperations: 100,
        maxStackDepth: 100,
        maxStringLength: 10485760,
        timeoutMs: 5000,
      );
      final engine = RhaiEngine.withConfig(config);

      // This loop should exceed the operation limit
      expect(
        () => engine.eval('let x = 0; loop { x += 1; }'),
        throwsA(
          isA<RhaiRuntimeError>().having(
            (e) => e.message.toLowerCase(),
            'message',
            anyOf(
              contains('timeout'),
              contains('too many operations'),
              contains('operation'),
            ),
          ),
        ),
      );

      engine.dispose();
    });

    test('stack depth limit enforcement - deep recursion', () {
      // Create engine with low stack depth limit
      final config = RhaiConfig.custom(
        maxOperations: 1000000,
        maxStackDepth: 10, // Very low to trigger quickly
        maxStringLength: 10485760,
        timeoutMs: 5000,
      );
      final engine = RhaiEngine.withConfig(config);

      // This recursion should exceed the stack depth limit
      final script = '''
        fn recursive(n) {
          if n > 0 {
            recursive(n - 1);
          }
        }
        recursive(100);
      ''';

      expect(
        () => engine.eval(script),
        throwsA(
          isA<RhaiRuntimeError>().having(
            (e) => e.message.toLowerCase(),
            'message',
            anyOf(
              contains('stack overflow'),
              contains('stack'),
              contains('recursion'),
            ),
          ),
        ),
      );

      engine.dispose();
    });

    test('string length limit enforcement', () {
      // Create engine with very low string length limit
      final config = RhaiConfig.custom(
        maxOperations: 1000000,
        maxStackDepth: 100,
        maxStringLength: 100, // Very low limit (100 bytes)
        timeoutMs: 5000,
      );
      final engine = RhaiEngine.withConfig(config);

      // Try to create a string longer than the limit
      // Build a string by concatenation that exceeds 100 bytes
      final script = '''
        let s = "";
        for i in 0..50 {
          s += "ABCDEFGHIJ"; // 10 chars each iteration
        }
        s
      ''';

      expect(
        () => engine.eval(script),
        throwsA(
          isA<RhaiRuntimeError>().having(
            (e) => e.message.toLowerCase(),
            'message',
            anyOf(
              contains('string'),
              contains('length'),
              contains('too large'),
              contains('too long'),
            ),
          ),
        ),
      );

      engine.dispose();
    });

    test('default config has sandboxing enabled', () {
      // Verify that default config has all sandboxing features enabled
      final config = RhaiConfig.secureDefaults();

      expect(config.disableFileIo, isTrue);
      expect(config.disableEval, isTrue);
      expect(config.disableModules, isTrue);
      expect(config.maxOperations, equals(1000000));
      expect(config.maxStackDepth, equals(100));
      expect(config.maxStringLength, equals(10485760));
    });

    test('operation limit can be disabled with unlimited config', () {
      // Note: This test verifies that we CAN disable limits,
      // but in production you should use secure defaults
      final config = RhaiConfig.unlimited();

      expect(config.maxOperations, equals(0)); // 0 means unlimited
      expect(config.maxStackDepth, equals(0)); // 0 means unlimited
      expect(config.maxStringLength, equals(0)); // 0 means unlimited
      expect(config.disableFileIo, isFalse);
      expect(config.disableEval, isFalse);
      expect(config.disableModules, isFalse);
    });

    test('sandboxing prevents harmful operations - secure by default', () {
      // Create engine with default (secure) config
      final engine = RhaiEngine.withDefaults();

      // Verify basic operations still work with sandboxing enabled
      final result = engine.eval('2 + 2');
      expect(result, equals(4));

      // Verify that potentially harmful operations are limited
      // Note: Rhai doesn't expose file I/O or eval by default,
      // but we verify that operation limits work
      expect(
        () => engine.eval('let x = 0; loop { x += 1; }'),
        throwsA(isA<RhaiRuntimeError>()),
        reason: 'Infinite loop should be caught by operation limit',
      );

      engine.dispose();
    });
  });
}
