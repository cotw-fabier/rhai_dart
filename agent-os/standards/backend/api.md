# Dart CLI/Backend API Design Standards

This document outlines comprehensive best practices for building CLI commands, backend services, and APIs in pure Dart without Flutter dependencies. Based on production patterns from kvetchbot and Effective Dart guidelines.

## Table of Contents

1. [Core Principles](#core-principles)
2. [CLI Command Patterns](#cli-command-patterns)
3. [Service Layer Architecture](#service-layer-architecture)
4. [API Design Principles](#api-design-principles)
5. [Error Handling](#error-handling)
6. [Dependency Injection](#dependency-injection)
7. [Testing CLI Applications](#testing-cli-applications)
8. [Best Practices](#best-practices)

## Core Principles

### 1. Separation of Concerns

Organize your CLI/backend application into clear layers:

```
lib/
├── commands/           # CLI command handlers
│   ├── weather.dart
│   ├── bible.dart
│   └── dice.dart
├── services/          # Business logic
│   ├── weather_service.dart
│   ├── bible_service.dart
│   └── ai_service.dart
├── providers/         # Riverpod providers for DI
│   ├── envprovider.dart
│   ├── ollamaclient.dart
│   └── bibleprovider.dart
├── models/            # Data models
│   ├── weather_data.dart
│   ├── bible_verse.dart
│   └── ai_response.dart
├── functions/         # Utility functions
│   ├── parsemessage.dart
│   ├── homedirectory.dart
│   └── upperlowercase.dart
└── repositories/      # Data access layer
    ├── api_client.dart
    └── database_repository.dart
```

### 2. Pure Functions Where Possible

**GOOD:**
```dart
// Pure function - deterministic, no side effects
String formatWeatherReport(Weather weather) {
  return 'Temperature: ${weather.temperature}°F\n'
         'Conditions: ${weather.condition}';
}

// Pure transformation
List<String> parseVerseReferences(String input) {
  return input
      .split(',')
      .map((ref) => ref.trim())
      .where((ref) => ref.isNotEmpty)
      .toList();
}
```

**BAD:**
```dart
// Impure - relies on external state
String formatWeatherReport(Weather weather) {
  final apiKey = Platform.environment['API_KEY']; // External state
  return 'Temperature: ${weather.temperature}°F';
}

// Mutates input
void parseVerseReferences(List<String> refs, String input) {
  refs.addAll(input.split(',')); // Side effect
}
```

### 3. Explicit Dependencies

Make dependencies explicit via constructor injection:

**GOOD:**
```dart
class WeatherService {
  WeatherService({
    required this.apiClient,
    required this.logger,
  });

  final ApiClient apiClient;
  final Logger logger;

  Future<Weather> getWeather(String city) async {
    logger.info('Fetching weather for $city');
    return await apiClient.fetchWeather(city);
  }
}
```

**BAD:**
```dart
class WeatherService {
  // Hidden dependencies
  Future<Weather> getWeather(String city) async {
    final client = ApiClient(); // Hidden instantiation
    final logger = Logger.global; // Global state
    return await client.fetchWeather(city);
  }
}
```

## CLI Command Patterns

### Using args Package

**Basic Command Structure:**

```dart
import 'package:args/args.dart';
import 'package:riverpod/riverpod.dart';

/// Weather command - fetches and displays weather information
Future<void> weatherCommand(
  List<String> arguments,
  ProviderContainer container,
) async {
  // 1. Define argument parser
  final parser = ArgParser()
    ..addOption('city', abbr: 'c', mandatory: true, help: 'City name')
    ..addOption('country', abbr: 'C', defaultsTo: 'us', help: 'Country code')
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  // 2. Parse arguments
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (e) {
    print('Error: ${e.message}');
    print('\n${parser.usage}');
    return;
  }

  // 3. Handle help flag
  if (results['help'] as bool) {
    print('Weather Command');
    print(parser.usage);
    return;
  }

  // 4. Extract arguments
  final city = results['city'] as String;
  final country = results['country'] as String;
  final verbose = results['verbose'] as bool;

  // 5. Execute command logic
  try {
    final weatherService = container.read(weatherServiceProvider);
    final weather = await weatherService.getWeather(city, country);

    if (verbose) {
      print(weather.toDetailedString());
    } else {
      print(weather.toString());
    }
  } on WeatherException catch (e) {
    print('Weather error: ${e.message}');
    exit(1);
  } catch (e) {
    print('Unexpected error: $e');
    exit(1);
  }
}
```

### Complex Command Pattern (from kvetchbot)

**Example: Bible Verse Lookup**

```dart
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:riverpod/riverpod.dart';

/// Bible command - looks up verses by reference
ChatCommand bible(Ref ref) => ChatCommand(
  'bible',
  'Request a bible verse or series of verses',
  id('bible', (
    ChatContext context,
    String reference,
  ) async {
    // 1. Input validation and parsing
    ParsedReference referenceParsed;
    try {
      referenceParsed = parseReference(reference)!;
    } on ParseException catch (e) {
      await context.respond(MessageBuilder(
        content: "Couldn't parse reference: ${e.message}",
      ));
      return;
    }

    // 2. Fetch data from provider
    final books = await ref.read(bibleNotifierProvider.future);

    // 3. Find requested book (case-insensitive)
    final bookObj = books.firstWhere(
      (b) => (b['name'] as String).toLowerCase() ==
             referenceParsed.book.toLowerCase(),
      orElse: () => {},
    );

    if (bookObj.isEmpty) {
      await context.respond(MessageBuilder(
        content: 'Book "${referenceParsed.book}" not found',
      ));
      return;
    }

    // 4. Extract verses
    final results = _extractVerses(bookObj, referenceParsed);

    // 5. Format and respond
    final formatted = results
        .map((verse) => '${verse['chapter']}:${verse['verse']} ${verse['text']}')
        .join('\n\n');

    await context.respond(
      await pagination.split(formatted, maxLength: 2000),
    );
  }),
);

/// Helper function to extract verses from book data
List<Map<String, dynamic>> _extractVerses(
  Map<String, dynamic> bookObj,
  ParsedReference ref,
) {
  final chapters = bookObj['chapters'] as List<dynamic>;
  final results = <Map<String, dynamic>>[];

  final startChapter = ref.startChapter;
  final endChapter = ref.endChapter ?? startChapter;

  for (int chapterIndex = startChapter;
       chapterIndex <= endChapter;
       chapterIndex++) {
    final chIndex = chapterIndex - 1;
    if (chIndex < 0 || chIndex >= chapters.length) continue;

    final chapterData = chapters[chIndex];
    final verses = chapterData['verses'] as List<dynamic>;

    final isFirstChapter = (chapterIndex == startChapter);
    final isLastChapter = (chapterIndex == endChapter);

    final startVerse = (isFirstChapter && ref.startVerse != null)
        ? ref.startVerse!
        : 1;
    final endVerse = (isLastChapter && ref.endVerse != null)
        ? ref.endVerse!
        : verses.length;

    for (int verseNum = startVerse; verseNum <= endVerse; verseNum++) {
      final vIndex = verseNum - 1;
      if (vIndex < 0 || vIndex >= verses.length) continue;

      final verseData = verses[vIndex];
      results.add({
        'book': bookObj['name'],
        'chapter': chapterIndex,
        'verse': verseData['num'],
        'text': verseData['text'],
      });
    }
  }

  return results;
}
```

### Command Registration Pattern

**Main Entry Point:**

```dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:riverpod/riverpod.dart';

void main(List<String> arguments) async {
  // Initialize dependency container
  final container = ProviderContainer();

  // Create command runner
  final runner = CommandRunner<void>(
    'myapp',
    'A powerful CLI application',
  )
    ..addCommand(WeatherCommand(container))
    ..addCommand(BibleCommand(container))
    ..addCommand(ConfigCommand(container));

  // Run command
  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    print(e);
    exit(64); // Exit code for usage error
  } catch (e, stackTrace) {
    print('Error: $e');
    if (verbose) print(stackTrace);
    exit(1);
  } finally {
    container.dispose();
  }
}

/// Weather command implementation
class WeatherCommand extends Command<void> {
  WeatherCommand(this.container) {
    argParser
      ..addOption('city', abbr: 'c', mandatory: true)
      ..addOption('country', defaultsTo: 'us')
      ..addFlag('verbose', abbr: 'v');
  }

  final ProviderContainer container;

  @override
  String get name => 'weather';

  @override
  String get description => 'Get weather information';

  @override
  Future<void> run() async {
    final city = argResults!['city'] as String;
    final country = argResults!['country'] as String;
    final verbose = argResults!['verbose'] as bool;

    final service = container.read(weatherServiceProvider);
    final weather = await service.getWeather(city, country);

    print(verbose ? weather.toDetailedString() : weather.toString());
  }
}
```

## Service Layer Architecture

### Service Interface Pattern

**Define clear service interfaces:**

```dart
/// Weather service interface
abstract class WeatherService {
  /// Fetches current weather for a city
  Future<Weather> getCurrentWeather(String city, [String country = 'us']);

  /// Fetches 5-day forecast
  Future<List<Weather>> getFiveDayForecast(String city, [String country = 'us']);

  /// Checks if weather data is available
  Future<bool> isAvailable();
}

/// Implementation
class WeatherServiceImpl implements WeatherService {
  WeatherServiceImpl({
    required this.apiKey,
    required this.httpClient,
    required this.cache,
  });

  final String apiKey;
  final http.Client httpClient;
  final Cache cache;

  @override
  Future<Weather> getCurrentWeather(String city, [String country = 'us']) async {
    // Check cache first
    final cacheKey = 'weather:$city:$country';
    final cached = cache.get<Weather>(cacheKey);
    if (cached != null) return cached;

    // Fetch from API
    final url = Uri.parse(
      'https://api.weather.com/v1/current?city=$city&country=$country',
    );

    final response = await httpClient.get(
      url,
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode != 200) {
      throw WeatherException('Failed to fetch weather: ${response.statusCode}');
    }

    final weather = Weather.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );

    // Cache for 10 minutes
    cache.set(cacheKey, weather, duration: Duration(minutes: 10));

    return weather;
  }

  @override
  Future<List<Weather>> getFiveDayForecast(
    String city,
    [String country = 'us'],
  ) async {
    final url = Uri.parse(
      'https://api.weather.com/v1/forecast?city=$city&country=$country&days=5',
    );

    final response = await httpClient.get(
      url,
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode != 200) {
      throw WeatherException('Failed to fetch forecast: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final forecasts = data['forecasts'] as List<dynamic>;

    return forecasts
        .map((f) => Weather.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await httpClient
          .get(Uri.parse('https://api.weather.com/health'))
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
```

### Repository Pattern

**Separate data access from business logic:**

```dart
/// Bible repository interface
abstract class BibleRepository {
  Future<List<Book>> getBooks();
  Future<Book?> getBook(String name);
  Future<List<Verse>> getVerses(ParsedReference reference);
}

/// File-based implementation
class FileBibleRepository implements BibleRepository {
  FileBibleRepository({required this.filePath});

  final String filePath;
  List<Book>? _cachedBooks;

  @override
  Future<List<Book>> getBooks() async {
    if (_cachedBooks != null) return _cachedBooks!;

    final file = File(filePath);
    if (!file.existsSync()) {
      throw BibleException('Bible file not found: $filePath');
    }

    final content = await file.readAsString();
    final data = json.decode(content) as Map<String, dynamic>;
    final booksData = data['books'] as List<dynamic>;

    _cachedBooks = booksData
        .map((b) => Book.fromJson(b as Map<String, dynamic>))
        .toList();

    return _cachedBooks!;
  }

  @override
  Future<Book?> getBook(String name) async {
    final books = await getBooks();
    try {
      return books.firstWhere(
        (b) => b.name.toLowerCase() == name.toLowerCase(),
      );
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<Verse>> getVerses(ParsedReference reference) async {
    final book = await getBook(reference.book);
    if (book == null) {
      throw BibleException('Book not found: ${reference.book}');
    }

    final results = <Verse>[];
    final startChapter = reference.startChapter;
    final endChapter = reference.endChapter ?? startChapter;

    for (int chapterIndex = startChapter;
         chapterIndex <= endChapter;
         chapterIndex++) {
      final chapter = book.chapters[chapterIndex - 1];

      final isFirstChapter = (chapterIndex == startChapter);
      final isLastChapter = (chapterIndex == endChapter);

      final startVerse = (isFirstChapter && reference.startVerse != null)
          ? reference.startVerse!
          : 1;
      final endVerse = (isLastChapter && reference.endVerse != null)
          ? reference.endVerse!
          : chapter.verses.length;

      for (int verseNum = startVerse; verseNum <= endVerse; verseNum++) {
        results.add(chapter.verses[verseNum - 1]);
      }
    }

    return results;
  }
}
```

### Service Composition Pattern

**Compose multiple services for complex operations:**

```dart
/// AI-enhanced weather service
class AiWeatherService {
  AiWeatherService({
    required this.weatherService,
    required this.aiService,
    required this.messageHistory,
  });

  final WeatherService weatherService;
  final AiService aiService;
  final MessageHistory messageHistory;

  /// Generates AI commentary on weather
  Future<String> getWeatherWithCommentary({
    required String city,
    String? question,
  }) async {
    // 1. Fetch weather data
    final currentWeather = await weatherService.getCurrentWeather(city);
    final forecast = await weatherService.getFiveDayForecast(city);

    // 2. Format weather information
    final weatherReport = _formatWeatherReport(currentWeather, forecast);

    // 3. Get conversation context
    final context = messageHistory.getRecent(10);
    final contextText = context.map((m) => m.toString()).join('\n\n');

    // 4. Build AI prompt
    final prompt = question != null
        ? _buildQuestionPrompt(weatherReport, question, contextText)
        : _buildReportPrompt(weatherReport, city, contextText);

    // 5. Generate AI response
    final aiResponse = await aiService.generateResponse(
      system: 'You are a sassy weatherman. Deliver weather in detail '
              'with humor and interesting conversation.',
      prompt: prompt,
    );

    return '$aiResponse\n\n---\n\n$weatherReport';
  }

  String _formatWeatherReport(Weather current, List<Weather> forecast) {
    final buffer = StringBuffer();

    buffer.writeln('Current Weather:');
    buffer.writeln('---');
    buffer.writeln(_formatWeather(current, isCurrent: true));
    buffer.writeln();

    buffer.writeln('Five Day Forecast:');
    buffer.writeln('---');
    for (final weather in forecast) {
      buffer.writeln(_formatWeather(weather));
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _formatWeather(Weather weather, {bool isCurrent = false}) {
    final willBe = isCurrent ? 'is currently' : 'will be';
    final date = weather.date;

    return '''
Weather for ${_formatDate(date)}:
Temperature High: ${weather.tempMax}°F Low: ${weather.tempMin}°F
${isCurrent ? 'Currently: ${weather.temperature}°F (feels like ${weather.feelsLike}°F)' : ''}
Wind: ${weather.windSpeed} mph with gusts up to ${weather.windGust} mph
Conditions $willBe: ${weather.condition}
${weather.rainVolume > 0 ? 'Rain: ${weather.rainVolume} inches' : ''}
${weather.snowVolume > 0 ? 'Snow: ${weather.snowVolume} inches' : ''}
'''.trim();
  }

  String _buildQuestionPrompt(
    String weatherReport,
    String question,
    String context,
  ) {
    return '''
Here is the channel history:
$context

---

Today is: ${_formatDate(DateTime.now())}

$weatherReport

---

Answer the user's question about the weather using the above information:

$question
''';
  }

  String _buildReportPrompt(
    String weatherReport,
    String city,
    String context,
  ) {
    final today = DateTime.now();
    return '''
Here is the channel history:
$context

---

Today is: ${_formatDate(today)}

$weatherReport

---

Please give a detailed and sassy writeup of the weather for $city.
Give details of the current weather starting today: ${_weekdayName(today)},
then summarize tomorrow, the following day, and the outlook for the rest
of the week. Include temperature and precipitation predictions.
''';
  }

  String _formatDate(DateTime date) {
    return '${_weekdayName(date)} ${date.month}/${date.day}/${date.year}';
  }

  String _weekdayName(DateTime date) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return days[date.weekday - 1];
  }
}
```

## API Design Principles

### 1. Design for Testability

**Make services easy to mock and test:**

```dart
// Good: Interface-based design
abstract class ApiClient {
  Future<Map<String, dynamic>> get(String path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}

class HttpApiClient implements ApiClient {
  HttpApiClient({required this.baseUrl, required this.httpClient});

  final String baseUrl;
  final http.Client httpClient;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    final response = await httpClient.get(Uri.parse('$baseUrl$path'));
    return json.decode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    return json.decode(response.body) as Map<String, dynamic>;
  }
}

// Easy to mock in tests
class MockApiClient implements ApiClient {
  @override
  Future<Map<String, dynamic>> get(String path) async {
    return {'status': 'ok', 'data': []};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return {'status': 'ok', 'id': '123'};
  }
}
```

### 2. Use DTOs for API Boundaries

**Separate internal models from API contracts:**

```dart
/// API DTO (Data Transfer Object)
class WeatherApiResponse {
  WeatherApiResponse({
    required this.temp,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
  });

  factory WeatherApiResponse.fromJson(Map<String, dynamic> json) {
    return WeatherApiResponse(
      temp: (json['main']['temp'] as num).toDouble(),
      tempMin: (json['main']['temp_min'] as num).toDouble(),
      tempMax: (json['main']['temp_max'] as num).toDouble(),
      condition: json['weather'][0]['description'] as String,
    );
  }

  final double temp;
  final double tempMin;
  final double tempMax;
  final String condition;

  /// Convert to domain model
  Weather toDomain() {
    return Weather(
      temperature: temp,
      tempMin: tempMin,
      tempMax: tempMax,
      condition: condition,
      date: DateTime.now(),
    );
  }
}

/// Domain model
class Weather {
  const Weather({
    required this.temperature,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
    required this.date,
  });

  final double temperature;
  final double tempMin;
  final double tempMax;
  final String condition;
  final DateTime date;
}
```

### 3. Validate at Boundaries

**Validate all external input:**

```dart
/// Reference parser with validation
class ReferenceParser {
  /// Parses a Bible reference
  ///
  /// Throws [ParseException] if reference is invalid
  ParsedReference parse(String reference) {
    if (reference.trim().isEmpty) {
      throw ParseException('Reference cannot be empty');
    }

    // Normalize whitespace
    reference = reference.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Find first digit to separate book from chapter:verse
    final match = RegExp(r'\d').firstMatch(reference);
    if (match == null) {
      throw ParseException(
        'Reference must include chapter number: "$reference"',
      );
    }

    final firstDigitIndex = match.start;
    final bookName = reference.substring(0, firstDigitIndex).trim();
    final remainder = reference.substring(firstDigitIndex).trim();

    if (bookName.isEmpty) {
      throw ParseException('Book name cannot be empty');
    }

    // Parse chapter:verse parts
    final dashSplit = remainder.split(RegExp(r'-')).map((p) => p.trim()).toList();

    if (dashSplit.length == 1) {
      return _parseSingleReference(bookName, dashSplit[0]);
    } else if (dashSplit.length == 2) {
      return _parseRangeReference(bookName, dashSplit[0], dashSplit[1]);
    } else {
      throw ParseException(
        'Invalid reference format: too many dashes in "$reference"',
      );
    }
  }

  ParsedReference _parseSingleReference(String book, String ref) {
    if (ref.contains(':')) {
      final parts = ref.split(':');
      final chapter = int.tryParse(parts[0]);
      final verse = int.tryParse(parts[1]);

      if (chapter == null || verse == null) {
        throw ParseException('Invalid chapter or verse number');
      }

      if (chapter < 1 || verse < 1) {
        throw ParseException('Chapter and verse must be positive numbers');
      }

      return ParsedReference(
        book: book,
        startChapter: chapter,
        startVerse: verse,
        endChapter: chapter,
        endVerse: verse,
      );
    } else {
      final chapter = int.tryParse(ref);
      if (chapter == null) {
        throw ParseException('Invalid chapter number');
      }

      if (chapter < 1) {
        throw ParseException('Chapter must be a positive number');
      }

      return ParsedReference(book: book, startChapter: chapter);
    }
  }

  ParsedReference _parseRangeReference(
    String book,
    String startRef,
    String endRef,
  ) {
    // Implementation details...
    throw UnimplementedError();
  }
}

/// Custom exception for parse errors
class ParseException implements Exception {
  ParseException(this.message);

  final String message;

  @override
  String toString() => 'ParseException: $message';
}
```

## Error Handling

### Exception Hierarchy

**Define clear exception types:**

```dart
/// Base exception for weather service
class WeatherException implements Exception {
  WeatherException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    final causeText = cause != null ? ' (caused by: $cause)' : '';
    return 'WeatherException: $message$causeText';
  }
}

/// Specific exception types
class WeatherApiException extends WeatherException {
  WeatherApiException(super.message, this.statusCode, [super.cause]);

  final int statusCode;

  @override
  String toString() => 'WeatherApiException [$statusCode]: $message';
}

class WeatherNotFoundException extends WeatherException {
  WeatherNotFoundException(String city)
      : super('Weather data not found for city: $city');
}

class WeatherTimeoutException extends WeatherException {
  WeatherTimeoutException() : super('Weather API request timed out');
}
```

### Error Handling Patterns

**Handle errors at the right level:**

```dart
/// Service level - convert errors to domain exceptions
class WeatherServiceImpl implements WeatherService {
  @override
  Future<Weather> getCurrentWeather(String city, [String country = 'us']) async {
    try {
      final response = await httpClient
          .get(
            Uri.parse('$baseUrl/weather?city=$city&country=$country'),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 404) {
        throw WeatherNotFoundException(city);
      }

      if (response.statusCode != 200) {
        throw WeatherApiException(
          'Failed to fetch weather',
          response.statusCode,
        );
      }

      return Weather.fromJson(
        json.decode(response.body) as Map<String, dynamic>,
      );
    } on TimeoutException catch (e) {
      throw WeatherTimeoutException();
    } on SocketException catch (e) {
      throw WeatherException('Network error', e);
    } on FormatException catch (e) {
      throw WeatherException('Invalid response format', e);
    }
  }
}

/// Command level - handle and display errors
class WeatherCommand extends Command<void> {
  @override
  Future<void> run() async {
    final city = argResults!['city'] as String;

    try {
      final service = container.read(weatherServiceProvider);
      final weather = await service.getCurrentWeather(city);
      print(weather);
    } on WeatherNotFoundException catch (e) {
      stderr.writeln('Error: ${e.message}');
      stderr.writeln('Please check the city name and try again.');
      exit(1);
    } on WeatherTimeoutException catch (e) {
      stderr.writeln('Error: Request timed out');
      stderr.writeln('Please try again later.');
      exit(1);
    } on WeatherApiException catch (e) {
      stderr.writeln('Error: ${e.message} (Status: ${e.statusCode})');
      exit(1);
    } on WeatherException catch (e) {
      stderr.writeln('Weather error: ${e.message}');
      if (e.cause != null && verbose) {
        stderr.writeln('Caused by: ${e.cause}');
      }
      exit(1);
    } catch (e, stackTrace) {
      stderr.writeln('Unexpected error: $e');
      if (verbose) {
        stderr.writeln(stackTrace);
      }
      exit(1);
    }
  }
}
```

### Result Type Pattern

**Use Result type for expected failures:**

```dart
/// Result type for operations that may fail
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

/// Extension methods for Result
extension ResultExtensions<T, E> on Result<T, E> {
  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get valueOrNull => this is Success<T, E>
      ? (this as Success<T, E>).value
      : null;

  E? get errorOrNull => this is Failure<T, E>
      ? (this as Failure<T, E>).error
      : null;

  T getOrElse(T Function() defaultValue) {
    return this is Success<T, E>
        ? (this as Success<T, E>).value
        : defaultValue();
  }

  Result<R, E> map<R>(R Function(T) transform) {
    return this is Success<T, E>
        ? Success(transform((this as Success<T, E>).value))
        : Failure((this as Failure<T, E>).error);
  }

  Result<R, E> flatMap<R>(Result<R, E> Function(T) transform) {
    return this is Success<T, E>
        ? transform((this as Success<T, E>).value)
        : Failure((this as Failure<T, E>).error);
  }
}

/// Usage example
class UserService {
  Result<User, String> validateAndCreate(String username, String email) {
    // Validation
    if (username.isEmpty) {
      return Failure('Username cannot be empty');
    }

    if (!email.contains('@')) {
      return Failure('Invalid email format');
    }

    // Creation
    return Success(User(username: username, email: email));
  }
}

void main() {
  final service = UserService();

  final result = service.validateAndCreate('john', 'john@example.com');

  // Pattern matching
  switch (result) {
    case Success(:final value):
      print('Created user: ${value.username}');
    case Failure(:final error):
      print('Error: $error');
  }

  // Using extensions
  final user = result.getOrElse(() => User.guest());
  final greeting = result.map((u) => 'Hello, ${u.username}!');
}
```

## Dependency Injection

### Riverpod Provider Patterns

**Environment Provider (from kvetchbot):**

```dart
import 'package:dotenv/dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'envprovider.g.dart';

/// Environment configuration provider
///
/// Loads .env file and provides access to environment variables
@riverpod
DotEnv envNotifier(EnvNotifierRef ref) {
  return DotEnv(includePlatformEnvironment: true)..load();
}

/// Usage in other providers
@riverpod
String weatherApiKey(WeatherApiKeyRef ref) {
  final env = ref.read(envNotifierProvider);
  final key = env['WEATHER_API_KEY'];

  if (key == null || key.isEmpty) {
    throw StateError('WEATHER_API_KEY not configured in .env file');
  }

  return key;
}
```

**Client Provider:**

```dart
import 'package:ollama_dart/ollama_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollamaclient.g.dart';

/// Ollama AI client provider
@riverpod
class OllamaClientNotifier extends _$OllamaClientNotifier {
  @override
  OllamaClient build() {
    final env = ref.read(envNotifierProvider);

    // Client is created and cached
    final client = OllamaClient(
      baseUrl: env['OLLAMA_URL'] ?? 'http://localhost:11434',
    );

    // Cleanup on dispose
    ref.onDispose(() {
      client.close();
    });

    return client;
  }

  /// Generate AI response
  Future<String> generateResponse({
    String model = '',
    String system = '',
    String prompt = '',
    RequestOptions? options,
    List<String>? images,
  }) async {
    final env = ref.read(envNotifierProvider);

    final modelName = model.isEmpty ? env['MODEL'] ?? 'llama2' : model;

    print('Generating response with model: $modelName');
    print('Prompt: <system>$system</system> <user>$prompt</user>');

    final client = state;

    final generated = await client.generateCompletion(
      request: GenerateCompletionRequest(
        model: modelName,
        system: system,
        prompt: prompt,
        options: options,
      ),
    );

    // Remove thinking tags
    final thinkTagPattern = RegExp(r'<think>(.*?)</think>', dotAll: true);
    final cleaned = generated.response?.replaceAll(thinkTagPattern, '')
        ?? 'No response from AI';

    print('Model response: $cleaned');
    return cleaned;
  }
}
```

**Data Provider with Async:**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bibleprovider.g.dart';

/// Bible data provider
///
/// Loads bible JSON file and caches data
@Riverpod(keepAlive: true)
class BibleNotifier extends _$BibleNotifier {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final file = File('../bibles/NKJV.bible.json');

    if (!file.existsSync()) {
      // Fail gracefully if file doesn't exist
      return [];
    }

    final bibleString = await file.readAsString();
    final bibleData = json.decode(bibleString) as Map<String, dynamic>;

    return (bibleData['books'] as List)
        .cast<Map<String, dynamic>>();
  }
}

/// Usage
void main() async {
  final container = ProviderContainer();

  // Read async provider
  final books = await container.read(bibleNotifierProvider.future);
  print('Loaded ${books.length} books');

  container.dispose();
}
```

**Stateful Provider:**

```dart
import 'package:nyxx/nyxx.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'messagehistory.g.dart';

/// Message history provider with state management
@Riverpod(keepAlive: true)
class MessageHistoryNotifier extends _$MessageHistoryNotifier {
  @override
  List<Message> build(String server, String channel) {
    return [];
  }

  void addMessage(Message message) {
    print('Added message: ${message.content}');

    var history = state;
    history.add(message);

    // Trim to last 500 messages
    if (history.length > 500) {
      history = history.sublist(history.length - 500);
    }

    state = history;
  }

  List<Message> pullMessages(int count) {
    final messages = state;
    final howFarBack = messages.length < count ? messages.length : count;

    print('${messages.length} - $count - $howFarBack');

    return messages
        .sublist(messages.length - howFarBack)
        .reversed
        .toList();
  }

  void clear() {
    state = [];
  }
}
```

### Provider Dependencies

**Compose providers:**

```dart
/// HTTP client provider
@riverpod
http.Client httpClient(HttpClientRef ref) {
  final client = http.Client();
  ref.onDispose(() => client.close());
  return client;
}

/// Weather service provider (depends on multiple providers)
@riverpod
WeatherService weatherService(WeatherServiceRef ref) {
  final apiKey = ref.watch(weatherApiKeyProvider);
  final httpClient = ref.watch(httpClientProvider);
  final cache = ref.watch(cacheProvider);

  return WeatherServiceImpl(
    apiKey: apiKey,
    httpClient: httpClient,
    cache: cache,
  );
}

/// AI weather service (composes multiple services)
@riverpod
AiWeatherService aiWeatherService(AiWeatherServiceRef ref) {
  return AiWeatherService(
    weatherService: ref.watch(weatherServiceProvider),
    aiService: ref.watch(aiServiceProvider),
    messageHistory: ref.watch(messageHistoryProvider),
  );
}
```

## Testing CLI Applications

### Unit Testing Services

```dart
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockCache extends Mock implements Cache {}

void main() {
  group('WeatherService', () {
    late MockApiClient apiClient;
    late MockCache cache;
    late WeatherServiceImpl service;

    setUp(() {
      apiClient = MockApiClient();
      cache = MockCache();
      service = WeatherServiceImpl(
        apiKey: 'test-key',
        httpClient: apiClient,
        cache: cache,
      );
    });

    test('getCurrentWeather returns cached data if available', () async {
      // Arrange
      final cachedWeather = Weather(
        temperature: 72.0,
        tempMin: 65.0,
        tempMax: 78.0,
        condition: 'Sunny',
        date: DateTime.now(),
      );

      when(() => cache.get<Weather>('weather:Seattle:us'))
          .thenReturn(cachedWeather);

      // Act
      final result = await service.getCurrentWeather('Seattle');

      // Assert
      expect(result, equals(cachedWeather));
      verify(() => cache.get<Weather>('weather:Seattle:us')).called(1);
      verifyNever(() => apiClient.get(any()));
    });

    test('getCurrentWeather fetches from API if not cached', () async {
      // Arrange
      when(() => cache.get<Weather>(any())).thenReturn(null);
      when(() => apiClient.get(any())).thenAnswer((_) async => {
        'main': {
          'temp': 72.0,
          'temp_min': 65.0,
          'temp_max': 78.0,
        },
        'weather': [
          {'description': 'Sunny'}
        ],
      });
      when(() => cache.set<Weather>(any(), any(), duration: any(named: 'duration')))
          .thenReturn(null);

      // Act
      final result = await service.getCurrentWeather('Seattle');

      // Assert
      expect(result.temperature, equals(72.0));
      verify(() => apiClient.get(any())).called(1);
      verify(() => cache.set(any(), any(), duration: any(named: 'duration'))).called(1);
    });

    test('getCurrentWeather throws on API error', () async {
      // Arrange
      when(() => cache.get<Weather>(any())).thenReturn(null);
      when(() => apiClient.get(any()))
          .thenThrow(SocketException('Network error'));

      // Act & Assert
      expect(
        () => service.getCurrentWeather('Seattle'),
        throwsA(isA<WeatherException>()),
      );
    });
  });
}
```

### Testing Commands

```dart
void main() {
  group('WeatherCommand', () {
    late ProviderContainer container;
    late MockWeatherService mockService;

    setUp(() {
      mockService = MockWeatherService();

      container = ProviderContainer(
        overrides: [
          weatherServiceProvider.overrideWith((ref) => mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('displays weather when successful', () async {
      // Arrange
      final weather = Weather(
        temperature: 72.0,
        tempMin: 65.0,
        tempMax: 78.0,
        condition: 'Sunny',
        date: DateTime.now(),
      );

      when(() => mockService.getCurrentWeather('Seattle', 'us'))
          .thenAnswer((_) async => weather);

      // Capture output
      final output = <String>[];
      runZoned(
        () async {
          final command = WeatherCommand(container);
          await command.run(['--city', 'Seattle']);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, message) {
            output.add(message);
          },
        ),
      );

      // Assert
      expect(output, contains(contains('72.0')));
      expect(output, contains(contains('Sunny')));
    });

    test('displays error when service fails', () async {
      // Arrange
      when(() => mockService.getCurrentWeather(any(), any()))
          .thenThrow(WeatherNotFoundException('Seattle'));

      // Act & Assert
      expect(
        () => WeatherCommand(container).run(['--city', 'Seattle']),
        throwsA(isA<WeatherNotFoundException>()),
      );
    });
  });
}
```

### Integration Testing

```dart
void main() {
  group('Bible command integration', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('fetches Genesis 1:1', () async {
      final ref = container.read;

      // This tests the full stack
      final books = await ref(bibleNotifierProvider.future);
      expect(books, isNotEmpty);

      final parser = ReferenceParser();
      final reference = parser.parse('Genesis 1:1');

      final repository = FileBibleRepository(
        filePath: '../bibles/NKJV.bible.json',
      );

      final verses = await repository.getVerses(reference);

      expect(verses, hasLength(1));
      expect(verses.first.text, contains('In the beginning'));
    });
  });
}
```

## Best Practices

### 1. Command Organization

**DO:**
- Keep commands thin - delegate to services
- Validate input at command level
- Handle errors at command level
- Use clear, descriptive command names
- Provide helpful error messages

**DON'T:**
- Put business logic in commands
- Mix concerns (UI, business logic, data access)
- Ignore error handling
- Use abbreviated, unclear names

### 2. Service Design

**DO:**
- Define clear interfaces
- Make dependencies explicit
- Return domain models, not DTOs
- Throw specific exceptions
- Log important operations

**DON'T:**
- Use global state
- Depend on concrete implementations
- Return null for errors (throw or use Result)
- Swallow exceptions
- Mix unrelated responsibilities

### 3. Error Handling

**DO:**
- Create exception hierarchy
- Provide context in error messages
- Handle errors at appropriate level
- Log errors before re-throwing
- Use Result type for expected failures

**DON'T:**
- Catch and ignore exceptions
- Use exceptions for flow control
- Return error codes (use exceptions)
- Lose error context when wrapping
- Show stack traces to end users

### 4. Dependency Injection

**DO:**
- Use Riverpod for DI
- Keep providers simple and focused
- Dispose resources in onDispose
- Use code generation
- Test with provider overrides

**DON'T:**
- Use service locators
- Create providers with side effects
- Forget to dispose resources
- Use global singletons
- Mix provider types inappropriately

### 5. Testing

**DO:**
- Test services independently
- Use mocks for external dependencies
- Test error paths
- Write integration tests
- Test CLI argument parsing

**DON'T:**
- Test implementation details
- Forget edge cases
- Skip error scenarios
- Make tests depend on external services
- Write tests that require manual setup

### 6. Code Organization

**DO:**
- Organize by feature
- Keep files focused and small
- Use clear naming conventions
- Export public APIs explicitly
- Document public interfaces

**DON'T:**
- Create god classes
- Mix concerns in same file
- Use unclear abbreviations
- Expose implementation details
- Leave code undocumented

## Summary

This guide covers:

1. **CLI Command Patterns** - Using args package and command runner
2. **Service Layer** - Interfaces, repositories, composition
3. **API Design** - DTOs, validation, boundaries
4. **Error Handling** - Exception hierarchy, Result type
5. **Dependency Injection** - Riverpod patterns
6. **Testing** - Unit, integration, mocking

Key principles:
- Separation of concerns
- Explicit dependencies
- Clear error handling
- Testability first
- Pure functions where possible

Follow these patterns for maintainable, testable CLI and backend applications in pure Dart.
