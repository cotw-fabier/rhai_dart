/// Example 3: Async Function Registration
///
/// This example demonstrates the RECOMMENDED approach for handling async data
/// in Rhai scripts.
///
/// IMPORTANT NOTE: Due to fundamental limitations in Dart's FFI callback system,
/// async functions that depend on the event loop (like Future.delayed, HTTP requests,
/// or file I/O) cannot reliably complete when called from within FFI callbacks.
///
/// The Dart event loop cannot run while inside a synchronous FFI callback,
/// preventing Futures from completing. This is a known limitation documented
/// in docs/ASYNC_FUNCTIONS.md.
///
/// CURRENT RECOMMENDATION:
/// Use synchronous functions for all registered callbacks. Pre-fetch any async
/// data before calling eval() and provide it via sync functions.
///
/// This example demonstrates WORKING patterns for handling async data.

import 'dart:async';
import 'package:rhai_dart/rhai_dart.dart';

void main() async {
  print('=== Example 3: Async Data Handling (Best Practices) ===\n');

  print('This example demonstrates the RECOMMENDED approach for async data:');
  print('- Pre-fetch async data BEFORE creating the engine');
  print('- Register synchronous functions that use the pre-fetched data');
  print('- Use closures to capture async data');
  print('See docs/ASYNC_FUNCTIONS.md for technical details.\n');

  final engine = RhaiEngine.withDefaults();

  try {
    // Example 1: Pre-fetch async data and use in sync function
    print('Example 1: Pre-fetching async data');
    print('----------------------------------------');

    // Fetch data asynchronously BEFORE registering functions
    final userData = await fetchUserData();
    print('Pre-fetched user data: $userData');

    // Register a synchronous function that uses the pre-fetched data
    engine.registerFunction('get_user_data', () {
      return userData;
    });

    // Now use it in a script - works perfectly!
    final result1 = engine.eval('get_user_data()');
    print('Script result: $result1');
    print('User name: ${(result1 as Map)['name']}\n');

    // Example 2: Multiple async sources
    print('Example 2: Multiple async data sources');
    print('----------------------------------------');

    // Pre-fetch all async data
    final weatherData = await fetchWeatherData();
    final stockData = await fetchStockData();

    print('Pre-fetched weather: $weatherData');
    print('Pre-fetched stocks: $stockData');

    // Register sync functions that use pre-fetched data
    engine.registerFunction('get_weather', () => weatherData);
    engine.registerFunction('get_stock_price', (String symbol) {
      return stockData[symbol] ?? 0.0;
    });

    // Use in Rhai script
    final result2 = engine.eval('''
      let weather = get_weather();
      let stock = get_stock_price("AAPL");
      #{
        temperature: weather.temp,
        condition: weather.condition,
        stock_price: stock,
        summary: "Weather: " + weather.condition + ", AAPL: " + stock
      }
    ''');
    print('Complex result: $result2\n');

    // Example 3: Using closures to capture async data
    print('Example 3: Closures with cached data');
    print('----------------------------------------');

    final cachedResponse = await simulateHttpRequest();
    print('Cached HTTP response: $cachedResponse');

    // The closure captures the cached response
    engine.registerFunction('get_cached_response', () {
      return cachedResponse;
    });

    final result3 = engine.eval('get_cached_response()');
    print('Result: $result3\n');

    // Example 4: Dynamic data provider pattern
    print('Example 4: Data provider pattern');
    print('----------------------------------------');

    // Pre-fetch configuration
    final config = await fetchConfiguration();
    print('Configuration loaded: $config');

    // Create a data provider that uses the config
    engine.registerFunction('get_config', (String key) {
      return config[key] ?? 'default';
    });

    final result4 = engine.eval('''
      let api_url = get_config("api_url");
      let timeout = get_config("timeout");
      #{url: api_url, timeout: timeout}
    ''');
    print('Config access: $result4\n');

    // Example 5: Real-world pattern - data pipeline
    print('Example 5: Real-world data pipeline');
    print('----------------------------------------');

    // Step 1: Fetch all required data
    print('Fetching data from multiple sources...');
    final users = await fetchUserList();
    final permissions = await fetchPermissions();
    final settings = await fetchSettings();

    print('  Users loaded: ${users.length}');
    print('  Permissions loaded: ${permissions.length}');
    print('  Settings loaded: ${settings.length}');

    // Step 2: Register data access functions
    engine.registerFunction('get_user', (int id) {
      return users.firstWhere(
        (u) => u['id'] == id,
        orElse: () => {'error': 'User not found'},
      );
    });

    engine.registerFunction('has_permission', (int userId, String permission) {
      final userPermissions = permissions[userId] ?? [];
      return userPermissions.contains(permission);
    });

    engine.registerFunction('get_setting', (String key) {
      return settings[key] ?? 'default';
    });

    // Step 3: Use in complex business logic
    final result5 = engine.eval('''
      let user_id = 1;
      let user = get_user(user_id);

      let can_edit = has_permission(user_id, "edit");
      let can_delete = has_permission(user_id, "delete");
      let theme = get_setting("theme");

      #{
        user: user.name,
        permissions: #{edit: can_edit, delete: can_delete},
        theme: theme,
        access_level: if can_delete { "admin" } else if can_edit { "editor" } else { "viewer" }
      }
    ''');

    print('Business logic result: $result5\n');

    // Example 6: Refresh pattern
    print('Example 6: Data refresh pattern');
    print('----------------------------------------');

    // Initial data
    var currentData = await fetchLiveData();
    print('Initial data: $currentData');

    engine.registerFunction('get_live_data', () {
      return currentData;
    });

    print('First eval:');
    final firstResult = engine.eval('get_live_data()');
    print('  Result: $firstResult');

    // Simulate data refresh
    print('\nRefreshing data...');
    currentData = await fetchLiveData();
    print('Refreshed data: $currentData');

    // Re-register with new data (or the closure will capture the updated value)
    engine.registerFunction('get_live_data', () {
      return currentData;
    });

    print('Second eval:');
    final secondResult = engine.eval('get_live_data()');
    print('  Result: $secondResult\n');

    print('=== All examples completed successfully! ===');
    print('\nKEY TAKEAWAYS:');
    print('1. Pre-fetch all async data BEFORE registering functions');
    print('2. Use synchronous functions that return pre-fetched data');
    print('3. Use closures to capture async data');
    print('4. Refresh data between eval() calls if needed');
    print('5. This pattern works perfectly for HTTP, database, file I/O, etc.');
  } finally {
    engine.dispose();
    print('\nEngine disposed.');
  }
}

/// Simulates fetching user data asynchronously
Future<Map<String, dynamic>> fetchUserData() async {
  await Future.delayed(Duration(milliseconds: 50));
  return {
    'name': 'Alice',
    'age': 30,
    'email': 'alice@example.com',
  };
}

/// Simulates HTTP request
Future<String> simulateHttpRequest() async {
  await Future.delayed(Duration(milliseconds: 30));
  return 'HTTP response data';
}

/// Simulates fetching weather data
Future<Map<String, dynamic>> fetchWeatherData() async {
  await Future.delayed(Duration(milliseconds: 40));
  return {
    'temp': 72,
    'condition': 'Sunny',
  };
}

/// Simulates fetching stock data
Future<Map<String, double>> fetchStockData() async {
  await Future.delayed(Duration(milliseconds: 35));
  return {
    'AAPL': 178.25,
    'GOOGL': 142.50,
    'MSFT': 415.30,
  };
}

/// Simulates fetching configuration
Future<Map<String, dynamic>> fetchConfiguration() async {
  await Future.delayed(Duration(milliseconds: 25));
  return {
    'api_url': 'https://api.example.com',
    'timeout': 5000,
    'debug': false,
  };
}

/// Simulates fetching user list
Future<List<Map<String, dynamic>>> fetchUserList() async {
  await Future.delayed(Duration(milliseconds: 45));
  return [
    {'id': 1, 'name': 'Alice', 'role': 'admin'},
    {'id': 2, 'name': 'Bob', 'role': 'editor'},
    {'id': 3, 'name': 'Charlie', 'role': 'viewer'},
  ];
}

/// Simulates fetching permissions
Future<Map<int, List<String>>> fetchPermissions() async {
  await Future.delayed(Duration(milliseconds: 40));
  return {
    1: ['read', 'write', 'edit', 'delete'],
    2: ['read', 'write', 'edit'],
    3: ['read'],
  };
}

/// Simulates fetching settings
Future<Map<String, dynamic>> fetchSettings() async {
  await Future.delayed(Duration(milliseconds: 30));
  return {
    'theme': 'dark',
    'language': 'en',
    'notifications': true,
  };
}

/// Simulates fetching live data
Future<Map<String, dynamic>> fetchLiveData() async {
  await Future.delayed(Duration(milliseconds: 20));
  return {
    'timestamp': DateTime.now().toIso8601String(),
    'value': DateTime.now().millisecondsSinceEpoch % 1000,
  };
}
