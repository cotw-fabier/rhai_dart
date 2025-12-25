# Async Programming Best Practices for Dart

Comprehensive guide for asynchronous programming in pure Dart CLI and backend applications, covering Futures, Streams, Isolates, and error handling.

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Future Patterns](#future-patterns)
3. [Stream Patterns](#stream-patterns)
4. [Isolates for Parallelism](#isolates-for-parallelism)
5. [Error Handling](#error-handling)
6. [Async Best Practices](#async-best-practices)

## Core Concepts

### When to Use Async

**Use async/await for:**
- File I/O operations
- Network requests
- Database queries
- Any blocking operation

**Don't use async for:**
- Pure computations
- Already synchronous operations
- Trivial operations

### Async vs Sync

**GOOD:**
```dart
// Async for I/O
Future<String> readFile(String path) async {
  final file = File(path);
  return await file.readAsString();
}

// Sync for computation
int calculateSum(List<int> numbers) {
  return numbers.reduce((a, b) => a + b);
}
```

**BAD:**
```dart
// Unnecessary async
Future<int> calculateSum(List<int> numbers) async {
  return numbers.reduce((a, b) => a + b); // No await needed!
}
```

## Future Patterns

### Basic Future Usage

```dart
/// Fetch weather from API
Future<Weather> getWeather(String city) async {
  final response = await httpClient.get(
    Uri.parse('https://api.weather.com/weather?city=$city'),
  );

  if (response.statusCode != 200) {
    throw WeatherException('Failed to fetch weather');
  }

  return Weather.fromJson(json.decode(response.body));
}

/// Usage
void main() async {
  try {
    final weather = await getWeather('Seattle');
    print(weather);
  } on WeatherException catch (e) {
    print('Error: ${e.message}');
  }
}
```

### Parallel Execution

**GOOD - Use Future.wait for parallel operations:**
```dart
Future<WeatherReport> getCompleteReport(String city) async {
  // Execute all requests in parallel
  final results = await Future.wait([
    getCurrentWeather(city),
    getForecast(city),
    getAirQuality(city),
  ]);

  return WeatherReport(
    current: results[0] as Weather,
    forecast: results[1] as List<Weather>,
    airQuality: results[2] as AirQuality,
  );
}
```

**BAD - Sequential when not needed:**
```dart
Future<WeatherReport> getCompleteReport(String city) async {
  // Each await waits for previous - SLOW!
  final current = await getCurrentWeather(city);
  final forecast = await getForecast(city);
  final airQuality = await getAirQuality(city);

  return WeatherReport(
    current: current,
    forecast: forecast,
    airQuality: airQuality,
  );
}
```

### Error Handling in Parallel

**Handle individual errors:**
```dart
Future<WeatherReport> getCompleteReport(String city) async {
  final results = await Future.wait([
    getCurrentWeather(city).catchError((e) => null),
    getForecast(city).catchError((e) => <Weather>[]),
    getAirQuality(city).catchError((e) => null),
  ]);

  return WeatherReport(
    current: results[0] as Weather?,
    forecast: results[1] as List<Weather>,
    airQuality: results[2] as AirQuality?,
  );
}
```

**Or use separate try-catch:**
```dart
Future<WeatherReport> getCompleteReport(String city) async {
  Weather? current;
  List<Weather> forecast = [];
  AirQuality? airQuality;

  await Future.wait([
    () async {
      try {
        current = await getCurrentWeather(city);
      } catch (e) {
        print('Failed to fetch current weather: $e');
      }
    }(),
    () async {
      try {
        forecast = await getForecast(city);
      } catch (e) {
        print('Failed to fetch forecast: $e');
      }
    }(),
    () async {
      try {
        airQuality = await getAirQuality(city);
      } catch (e) {
        print('Failed to fetch air quality: $e');
      }
    }(),
  ]);

  return WeatherReport(
    current: current,
    forecast: forecast,
    airQuality: airQuality,
  );
}
```

### Timeout Pattern

```dart
Future<Weather> getWeatherWithTimeout(String city) async {
  try {
    return await getWeather(city).timeout(
      Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Weather request timed out');
      },
    );
  } on TimeoutException {
    throw WeatherException('Request timed out after 10 seconds');
  }
}
```

### Retry Pattern

```dart
Future<T> retry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration delay = const Duration(seconds: 1),
}) async {
  var attempt = 0;

  while (true) {
    attempt++;

    try {
      return await operation();
    } catch (e) {
      if (attempt >= maxAttempts) {
        rethrow;
      }

      print('Attempt $attempt failed: $e. Retrying...');
      await Future.delayed(delay * attempt); // Exponential backoff
    }
  }
}

/// Usage
final weather = await retry(
  () => getWeather('Seattle'),
  maxAttempts: 3,
);
```

### Caching Pattern

```dart
class CachedWeatherService {
  final WeatherService _service;
  final Map<String, (Weather, DateTime)> _cache = {};
  final Duration _cacheDuration;

  CachedWeatherService(
    this._service, {
    Duration cacheDuration = const Duration(minutes: 10),
  }) : _cacheDuration = cacheDuration;

  Future<Weather> getWeather(String city) async {
    // Check cache
    final cached = _cache[city];
    if (cached != null) {
      final (weather, timestamp) = cached;
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        return weather;
      }
    }

    // Fetch fresh data
    final weather = await _service.getWeather(city);
    _cache[city] = (weather, DateTime.now());
    return weather;
  }

  void clearCache() {
    _cache.clear();
  }
}
```

## Stream Patterns

### Basic Stream Usage

```dart
/// Stream of temperature readings
Stream<double> temperatureReadings() async* {
  while (true) {
    final temp = await readTemperatureSensor();
    yield temp;
    await Future.delayed(Duration(seconds: 1));
  }
}

/// Usage
void main() async {
  await for (final temp in temperatureReadings()) {
    print('Temperature: ${temp}°C');
    
    if (temp > 100) {
      print('WARNING: High temperature!');
      break;
    }
  }
}
```

### StreamController

```dart
class MessageBus {
  final _controller = StreamController<Message>.broadcast();

  Stream<Message> get messages => _controller.stream;

  void send(Message message) {
    if (!_controller.isClosed) {
      _controller.add(message);
    }
  }

  void close() {
    _controller.close();
  }
}

/// Usage
void main() async {
  final bus = MessageBus();

  // Listen to messages
  final subscription = bus.messages.listen((message) {
    print('Received: ${message.content}');
  });

  // Send messages
  bus.send(Message('Hello'));
  bus.send(Message('World'));

  await Future.delayed(Duration(milliseconds: 100));

  // Cleanup
  await subscription.cancel();
  bus.close();
}
```

### Stream Transformations

```dart
Stream<Weather> weatherUpdates(String city) async* {
  while (true) {
    final weather = await getWeather(city);
    yield weather;
    await Future.delayed(Duration(minutes: 5));
  }
}

/// Transform stream
void main() async {
  final updates = weatherUpdates('Seattle')
      .where((w) => w.temperature > 70) // Filter
      .map((w) => '${w.temperature}°F') // Transform
      .take(10); // Limit

  await for (final temp in updates) {
    print('High temp: $temp');
  }
}
```

### Combining Streams

```dart
/// Merge multiple streams
Stream<T> merge<T>(List<Stream<T>> streams) async* {
  final controllers = streams.map((s) => StreamController<T>()).toList();

  for (var i = 0; i < streams.length; i++) {
    streams[i].listen(
      (data) => controllers[i].add(data),
      onError: (error) => controllers[i].addError(error),
      onDone: () => controllers[i].close(),
    );
  }

  await for (final controller in Stream.fromIterable(controllers)) {
    await for (final value in controller.stream) {
      yield value;
    }
  }
}
```

## Isolates for Parallelism

### Basic Isolate Usage

```dart
import 'dart:isolate';

/// CPU-intensive computation in isolate
Future<int> computeInIsolate(int n) async {
  final receivePort = ReceivePort();

  await Isolate.spawn(_computeIsolate, (receivePort.sendPort, n));

  return await receivePort.first as int;
}

void _computeIsolate((SendPort, int) args) {
  final (sendPort, n) = args;

  // Expensive computation
  var result = 0;
  for (var i = 0; i < n; i++) {
    result += i;
  }

  sendPort.send(result);
}

/// Usage
void main() async {
  final result = await computeInIsolate(1000000);
  print('Result: $result');
}
```

### Isolate with Multiple Messages

```dart
class IsolateWorker {
  late final SendPort _sendPort;
  final _responses = <int, Completer>{};
  var _nextId = 0;

  Future<void> start() async {
    final receivePort = ReceivePort();

    await Isolate.spawn(_worker, receivePort.sendPort);

    _sendPort = await receivePort.first as SendPort;

    receivePort.listen((message) {
      final (id, result) = message as (int, dynamic);
      _responses[id]?.complete(result);
      _responses.remove(id);
    });
  }

  Future<T> compute<T>(T Function() computation) async {
    final id = _nextId++;
    final completer = Completer<T>();
    _responses[id] = completer;

    _sendPort.send((id, computation));

    return await completer.future;
  }

  static void _worker(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      final (id, computation) = message as (int, Function);
      final result = computation();
      sendPort.send((id, result));
    });
  }
}
```

### Isolate Pool

```dart
class IsolatePool {
  final int size;
  final List<IsolateWorker> _workers = [];
  var _nextWorker = 0;

  IsolatePool(this.size);

  Future<void> start() async {
    for (var i = 0; i < size; i++) {
      final worker = IsolateWorker();
      await worker.start();
      _workers.add(worker);
    }
  }

  Future<T> compute<T>(T Function() computation) async {
    final worker = _workers[_nextWorker];
    _nextWorker = (_nextWorker + 1) % size;
    return await worker.compute(computation);
  }
}
```

## Error Handling

### Try-Catch Pattern

```dart
Future<Weather> getWeather(String city) async {
  try {
    final response = await httpClient.get(weatherUrl(city));

    if (response.statusCode != 200) {
      throw WeatherApiException(
        'API error: ${response.statusCode}',
        response.statusCode,
      );
    }

    return Weather.fromJson(json.decode(response.body));
  } on SocketException catch (e) {
    throw WeatherException('Network error', e);
  } on FormatException catch (e) {
    throw WeatherException('Invalid response format', e);
  } on TimeoutException catch (e) {
    throw WeatherException('Request timed out', e);
  } catch (e) {
    throw WeatherException('Unexpected error', e);
  }
}
```

### Error Recovery

```dart
Future<Weather?> getWeatherSafe(String city) async {
  try {
    return await getWeather(city);
  } catch (e) {
    print('Failed to fetch weather: $e');
    return null;
  }
}

Future<Weather> getWeatherWithFallback(String city) async {
  try {
    return await getWeather(city);
  } catch (e) {
    print('Primary source failed, trying backup...');
    return await getWeatherFromBackup(city);
  }
}
```

### Result Type for Error Handling

```dart
sealed class Result<T, E> {
  const Result();
}

class Success<T, E> extends Result<T, E> {
  const Success(this.value);
  final T value;
}

class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);
  final E error;
}

Future<Result<Weather, String>> getWeatherResult(String city) async {
  try {
    final weather = await getWeather(city);
    return Success(weather);
  } catch (e) {
    return Failure(e.toString());
  }
}

/// Usage
void main() async {
  final result = await getWeatherResult('Seattle');

  switch (result) {
    case Success(value: final weather):
      print('Weather: $weather');
    case Failure(error: final error):
      print('Error: $error');
  }
}
```

## Async Best Practices

### 1. Always Await or Return

**GOOD:**
```dart
Future<void> processData() async {
  await saveToDatabase(data); // Properly awaited
}

Future<Weather> getWeather(String city) {
  return weatherService.fetch(city); // Properly returned
}
```

**BAD:**
```dart
Future<void> processData() async {
  saveToDatabase(data); // Fire and forget - BAD!
}
```

### 2. Use async* for Generators

**GOOD:**
```dart
Stream<int> countDown(int n) async* {
  for (var i = n; i > 0; i--) {
    await Future.delayed(Duration(seconds: 1));
    yield i;
  }
}
```

**BAD:**
```dart
Stream<int> countDown(int n) {
  // Manual StreamController when async* would work
  final controller = StreamController<int>();
  // ... complex logic
  return controller.stream;
}
```

### 3. Handle Errors Appropriately

**GOOD:**
```dart
Future<void> process() async {
  try {
    await riskyOperation();
  } on SpecificException catch (e) {
    // Handle specific errors
    print('Specific error: $e');
  } catch (e, stackTrace) {
    // Handle unexpected errors
    print('Unexpected error: $e');
    print(stackTrace);
    rethrow; // Re-throw if can't handle
  }
}
```

### 4. Cancel Subscriptions

**GOOD:**
```dart
Future<void> listenForUpdates() async {
  final subscription = updates.listen((data) {
    process(data);
  });

  // Cleanup
  await Future.delayed(Duration(minutes: 5));
  await subscription.cancel();
}
```

### 5. Use Completer Sparingly

**GOOD - When bridging callback APIs:**
```dart
Future<String> readCallback() {
  final completer = Completer<String>();

  legacyApi.read((result) {
    completer.complete(result);
  }, (error) {
    completer.completeError(error);
  });

  return completer.future;
}
```

**BAD - When async/await would work:**
```dart
Future<String> fetchData() {
  final completer = Completer<String>();

  // Just use async/await!
  httpClient.get(url).then((response) {
    completer.complete(response.body);
  });

  return completer.future;
}
```

## Summary

This guide covers:

1. **Future Patterns** - Parallel execution, timeouts, retries
2. **Stream Patterns** - Generators, transformations, controllers
3. **Isolates** - CPU-intensive parallel processing
4. **Error Handling** - Try-catch, recovery, Result types
5. **Best Practices** - Common patterns and anti-patterns

Key principles:
- Use async for I/O, not computation
- Parallel execution with Future.wait
- Proper error handling
- Cancel subscriptions
- Isolates for CPU-intensive work

Follow these patterns for efficient, maintainable async code in Dart.
