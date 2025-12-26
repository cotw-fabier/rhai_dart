/// Type conversion utilities for Rhai-Dart FFI
///
/// This module provides utilities for converting between Dart types and JSON
/// for passing across the FFI boundary.
library;

import 'dart:convert';

/// Converts a JSON string to a Dart value.
///
/// This function parses a JSON string and converts it to the appropriate Dart type:
/// - null -> null
/// - boolean -> bool
/// - number -> int or double
/// - string -> String (with support for special float encodings)
/// - array -> List<dynamic>
/// - object -> Map<String, dynamic>
///
/// Special float values are encoded as strings:
/// - "__INFINITY__" -> double.infinity
/// - "__NEG_INFINITY__" -> double.negativeInfinity
/// - "__NAN__" -> double.nan
///
/// The conversion is recursive, so nested structures are handled correctly.
///
/// Example:
/// ```dart
/// final value = jsonToRhaiValue('{"x": 42}');
/// print(value); // {x: 42}
/// ```
dynamic jsonToRhaiValue(String json) {
  final decoded = jsonDecode(json);
  return _decodeSpecialValues(decoded);
}

/// Recursively decodes special float values in a data structure
dynamic _decodeSpecialValues(dynamic value) {
  // Handle special float value strings
  if (value is String) {
    switch (value) {
      case '__INFINITY__':
        return double.infinity;
      case '__NEG_INFINITY__':
        return double.negativeInfinity;
      case '__NAN__':
        return double.nan;
      default:
        return value;
    }
  }

  // Recursively handle lists
  if (value is List) {
    return value.map((item) => _decodeSpecialValues(item)).toList();
  }

  // Recursively handle maps - ensure we return Map<String, dynamic>
  if (value is Map) {
    final Map<String, dynamic> result = {};
    value.forEach((key, val) {
      result[key.toString()] = _decodeSpecialValues(val);
    });
    return result;
  }

  // Return other values as-is
  return value;
}

/// Converts a Dart value to a JSON string.
///
/// This function converts a Dart value to a JSON string for passing across
/// the FFI boundary.
///
/// Supported types:
/// - null
/// - bool
/// - int
/// - double (including Infinity, -Infinity, NaN)
/// - String
/// - List<dynamic>
/// - Map<String, dynamic>
///
/// Special float values are encoded as strings:
/// - double.infinity -> "__INFINITY__"
/// - double.negativeInfinity -> "__NEG_INFINITY__"
/// - double.nan -> "__NAN__"
///
/// Example:
/// ```dart
/// final json = rhaiValueToJson({'x': 42});
/// print(json); // {"x":42}
/// ```
String rhaiValueToJson(dynamic value) {
  final encoded = _encodeSpecialValues(value);
  return jsonEncode(encoded);
}

/// Recursively encodes special float values in a data structure
dynamic _encodeSpecialValues(dynamic value) {
  // Handle special float values
  if (value is double) {
    if (value.isInfinite) {
      return value.isNegative ? '__NEG_INFINITY__' : '__INFINITY__';
    }
    if (value.isNaN) {
      return '__NAN__';
    }
    return value;
  }

  // Recursively handle lists
  if (value is List) {
    return value.map((item) => _encodeSpecialValues(item)).toList();
  }

  // Recursively handle maps
  if (value is Map) {
    final Map<String, dynamic> result = {};
    value.forEach((key, val) {
      result[key.toString()] = _encodeSpecialValues(val);
    });
    return result;
  }

  // Return other values as-is
  return value;
}
