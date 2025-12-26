import 'package:rhai_dart/rhai_dart.dart';

void main() async {
  print('Testing evalAsync with async functions...');

  final engine = RhaiEngine.withDefaults();

  // Test 1: Simple arithmetic (no functions)
  print('\n1. Testing simple arithmetic...');
  final result1 = await engine.evalAsync('2 + 2');
  print('   Result: $result1 (expected: 4)');
  assert(result1 == 4, 'Simple arithmetic failed');

  // Test 2: Sync function via evalAsync
  print('\n2. Testing sync function via evalAsync...');
  engine.registerFunction('syncFunc', () => 42);
  final result2 = await engine.evalAsync('syncFunc()');
  print('   Result: $result2 (expected: 42)');
  assert(result2 == 42, 'Sync function via evalAsync failed');

  // Test 3: Async function
  print('\n3. Testing async function...');
  engine.registerFunction('asyncFetch', () async {
    await Future.delayed(const Duration(milliseconds: 50));
    return 'data';
  });
  final result3 = await engine.evalAsync('asyncFetch()');
  print('   Result: $result3 (expected: data)');
  assert(result3 == 'data', 'Async function failed');

  // Test 4: Async function with map
  print('\n4. Testing async function returning map...');
  engine.registerFunction('asyncData', () async {
    await Future.delayed(const Duration(milliseconds: 30));
    return {'status': 'success', 'value': 123};
  });
  final result4 = await engine.evalAsync('asyncData()');
  print('   Result: $result4');
  assert(result4 is Map, 'Result is not a map');
  assert(result4['status'] == 'success', 'Map status incorrect');
  assert(result4['value'] == 123, 'Map value incorrect');

  engine.dispose();

  print('\n✅ All evalAsync tests passed!');
  print('The request/response pattern is working correctly.');
}
