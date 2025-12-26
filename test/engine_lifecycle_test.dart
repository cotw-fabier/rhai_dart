import 'dart:ffi';
import 'package:test/test.dart';
import 'package:rhai_dart/src/ffi/bindings.dart';
import 'package:rhai_dart/src/ffi/native_types.dart';
import 'package:ffi/ffi.dart';

void main() {
  group('Engine Lifecycle Tests', () {
    late RhaiBindings bindings;

    setUpAll(() {
      bindings = RhaiBindings.instance;
    });

    test('Engine creation with default config', () {
      // Create an engine with null config (uses defaults)
      final engine = bindings.engineNew(nullptr);

      // Verify engine was created successfully
      expect(engine, isNot(equals(nullptr)));
      expect(engine.address, isNot(equals(0)));

      // Clean up
      bindings.engineFree(engine);
    });

    test('Engine creation with custom config', () {
      // Allocate and configure a CRhaiConfig
      final config = calloc<CRhaiConfig>();
      config.ref.maxOperations = 500000;
      config.ref.maxStackDepth = 50;
      config.ref.maxStringLength = 5242880; // 5 MB
      config.ref.timeoutMs = 3000;
      config.ref.disableFileIo = 1;
      config.ref.disableEval = 1;
      config.ref.disableModules = 1;

      // Create engine with custom config
      final engine = bindings.engineNew(config);

      // Verify engine was created successfully
      expect(engine, isNot(equals(nullptr)));
      expect(engine.address, isNot(equals(0)));

      // Clean up
      bindings.engineFree(engine);
      calloc.free(config);
    });

    test('Engine creation with secure defaults config', () {
      // Allocate config with secure defaults
      final config = calloc<CRhaiConfig>();
      config.ref.maxOperations = 1000000;
      config.ref.maxStackDepth = 100;
      config.ref.maxStringLength = 10485760; // 10 MB
      config.ref.timeoutMs = 5000;
      config.ref.disableFileIo = 1;
      config.ref.disableEval = 1;
      config.ref.disableModules = 1;

      // Create engine
      final engine = bindings.engineNew(config);

      // Verify success
      expect(engine, isNot(equals(nullptr)));

      // Clean up
      bindings.engineFree(engine);
      calloc.free(config);
    });

    test('Engine disposal (manual)', () {
      // Create engine
      final engine = bindings.engineNew(nullptr);
      expect(engine, isNot(equals(nullptr)));

      // Dispose engine - should not crash
      expect(() => bindings.engineFree(engine), returnsNormally);
    });

    test('Engine disposal with null pointer', () {
      // Disposing a null pointer should not crash
      expect(() => bindings.engineFree(nullptr), returnsNormally);
    });

    test('Multiple engine creation and disposal', () {
      // Create multiple engines to test memory management
      final engines = <Pointer<CRhaiEngine>>[];

      for (var i = 0; i < 5; i++) {
        final engine = bindings.engineNew(nullptr);
        expect(engine, isNot(equals(nullptr)));
        engines.add(engine);
      }

      // Dispose all engines
      for (final engine in engines) {
        expect(() => bindings.engineFree(engine), returnsNormally);
      }
    });

    test('Configuration validation - non-zero values', () {
      // Test with various custom configurations to ensure they're accepted
      final config = calloc<CRhaiConfig>();

      // Test 1: Minimum reasonable limits
      config.ref.maxOperations = 1000;
      config.ref.maxStackDepth = 10;
      config.ref.maxStringLength = 1024;
      config.ref.timeoutMs = 100;
      config.ref.disableFileIo = 1;
      config.ref.disableEval = 1;
      config.ref.disableModules = 1;

      final engine1 = bindings.engineNew(config);
      expect(engine1, isNot(equals(nullptr)));
      bindings.engineFree(engine1);

      // Test 2: Large limits
      config.ref.maxOperations = 10000000;
      config.ref.maxStackDepth = 1000;
      config.ref.maxStringLength = 104857600; // 100 MB
      config.ref.timeoutMs = 60000;

      final engine2 = bindings.engineNew(config);
      expect(engine2, isNot(equals(nullptr)));
      bindings.engineFree(engine2);

      calloc.free(config);
    });

    test('Configuration validation - sandboxing options', () {
      // Test different sandboxing configurations
      final config = calloc<CRhaiConfig>();
      config.ref.maxOperations = 1000000;
      config.ref.maxStackDepth = 100;
      config.ref.maxStringLength = 10485760;
      config.ref.timeoutMs = 5000;

      // Test with all features disabled (most secure)
      config.ref.disableFileIo = 1;
      config.ref.disableEval = 1;
      config.ref.disableModules = 1;

      final engine1 = bindings.engineNew(config);
      expect(engine1, isNot(equals(nullptr)));
      bindings.engineFree(engine1);

      // Test with all features enabled (less secure, for testing)
      config.ref.disableFileIo = 0;
      config.ref.disableEval = 0;
      config.ref.disableModules = 0;

      final engine2 = bindings.engineNew(config);
      expect(engine2, isNot(equals(nullptr)));
      bindings.engineFree(engine2);

      calloc.free(config);
    });
  });
}
