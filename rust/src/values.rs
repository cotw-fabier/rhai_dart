//! Type conversion between Rhai Dynamic types and JSON
//!
//! This module provides utilities for converting between Rhai's Dynamic type
//! and JSON strings for passing across the FFI boundary.

use rhai::Dynamic;
use serde_json::{json, Value as JsonValue};

/// Converts a Rhai Dynamic value to a JSON string.
///
/// This function handles all common Rhai types:
/// - Primitives: i64, f64, bool, String, ()
/// - Arrays: Vec<Dynamic> (recursively converted)
/// - Maps: Map<String, Dynamic> (recursively converted)
/// - Special float values: Infinity, -Infinity, NaN
///
/// # Arguments
///
/// * `dynamic` - The Rhai Dynamic value to convert
///
/// # Returns
///
/// A JSON string representation of the value, or an error message if conversion fails.
///
/// # Examples
///
/// ```rust,ignore
/// use rhai::Dynamic;
/// let value = Dynamic::from(42_i64);
/// let json = rhai_dynamic_to_json(&value).unwrap();
/// assert_eq!(json, "42");
/// ```
pub fn rhai_dynamic_to_json(dynamic: &Dynamic) -> Result<String, String> {
    let json_value = dynamic_to_json_value(dynamic)?;
    serde_json::to_string(&json_value)
        .map_err(|e| format!("Failed to serialize to JSON: {}", e))
}

/// Converts a Rhai Dynamic to a serde_json::Value recursively.
///
/// This is an internal helper function used by `rhai_dynamic_to_json`.
fn dynamic_to_json_value(dynamic: &Dynamic) -> Result<JsonValue, String> {
    // Handle unit type (void/null)
    if dynamic.is_unit() {
        return Ok(JsonValue::Null);
    }

    // Handle boolean
    if dynamic.is_bool() {
        return Ok(json!(dynamic.as_bool().unwrap()));
    }

    // Handle integer
    if dynamic.is_int() {
        return Ok(json!(dynamic.as_int().unwrap()));
    }

    // Handle float with special value support
    #[cfg(not(feature = "no_float"))]
    if dynamic.is_float() {
        let float_val = dynamic.as_float().unwrap();

        // Handle special float values (Infinity, -Infinity, NaN)
        // JSON doesn't natively support these, so we encode them as special strings
        if float_val.is_infinite() {
            if float_val.is_sign_positive() {
                return Ok(json!("__INFINITY__"));
            } else {
                return Ok(json!("__NEG_INFINITY__"));
            }
        } else if float_val.is_nan() {
            return Ok(json!("__NAN__"));
        }

        return Ok(json!(float_val));
    }

    // Handle string
    if dynamic.is_string() {
        return Ok(json!(dynamic.clone().try_cast::<String>().unwrap()));
    }

    // Handle array
    if dynamic.is_array() {
        let arr = dynamic.clone().try_cast::<rhai::Array>().unwrap();
        let json_array: Result<Vec<JsonValue>, String> = arr
            .iter()
            .map(|item| dynamic_to_json_value(item))
            .collect();
        return Ok(json!(json_array?));
    }

    // Handle map
    if dynamic.is_map() {
        let map = dynamic.clone().try_cast::<rhai::Map>().unwrap();
        let mut json_map = serde_json::Map::new();
        for (key, value) in map.iter() {
            let json_value = dynamic_to_json_value(value)?;
            json_map.insert(key.to_string(), json_value);
        }
        return Ok(JsonValue::Object(json_map));
    }

    // If we can't convert it, return an error
    Err(format!("Unsupported Rhai type: {}", dynamic.type_name()))
}

/// Converts a JSON string to a Rhai Dynamic value.
///
/// This function parses a JSON string and converts it to the appropriate Rhai type:
/// - null -> ()
/// - boolean -> bool
/// - number -> i64 or f64
/// - string -> String (with support for special float encodings: __INFINITY__, __NEG_INFINITY__, __NAN__)
/// - array -> Vec<Dynamic>
/// - object -> Map<String, Dynamic>
///
/// # Arguments
///
/// * `json` - The JSON string to parse
///
/// # Returns
///
/// A Rhai Dynamic value, or an error message if parsing/conversion fails.
///
/// # Examples
///
/// ```rust,ignore
/// let dynamic = json_to_rhai_dynamic(r#"{"x": 42}"#).unwrap();
/// assert!(dynamic.is_map());
/// ```
pub fn json_to_rhai_dynamic(json: &str) -> Result<Dynamic, String> {
    let json_value: JsonValue = serde_json::from_str(json)
        .map_err(|e| format!("Failed to parse JSON: {}", e))?;

    json_value_to_dynamic(&json_value)
}

/// Converts a serde_json::Value to a Rhai Dynamic recursively.
///
/// This is an internal helper function used by `json_to_rhai_dynamic`.
fn json_value_to_dynamic(value: &JsonValue) -> Result<Dynamic, String> {
    match value {
        JsonValue::Null => Ok(Dynamic::UNIT),

        JsonValue::Bool(b) => Ok(Dynamic::from(*b)),

        JsonValue::Number(n) => {
            if let Some(i) = n.as_i64() {
                Ok(Dynamic::from(i))
            } else if let Some(f) = n.as_f64() {
                #[cfg(not(feature = "no_float"))]
                return Ok(Dynamic::from(f));

                #[cfg(feature = "no_float")]
                return Err("Float support is disabled".to_string());
            } else {
                Err(format!("Unsupported number format: {}", n))
            }
        }

        JsonValue::String(s) => {
            // Check for special float value encodings
            #[cfg(not(feature = "no_float"))]
            match s.as_str() {
                "__INFINITY__" => return Ok(Dynamic::from(f64::INFINITY)),
                "__NEG_INFINITY__" => return Ok(Dynamic::from(f64::NEG_INFINITY)),
                "__NAN__" => return Ok(Dynamic::from(f64::NAN)),
                _ => {}
            }

            Ok(Dynamic::from(s.clone()))
        }

        JsonValue::Array(arr) => {
            let dynamic_array: Result<Vec<Dynamic>, String> = arr
                .iter()
                .map(|item| json_value_to_dynamic(item))
                .collect();
            Ok(Dynamic::from(dynamic_array?))
        }

        JsonValue::Object(obj) => {
            let mut dynamic_map = rhai::Map::new();
            for (key, value) in obj.iter() {
                let dynamic_value = json_value_to_dynamic(value)?;
                dynamic_map.insert(key.clone().into(), dynamic_value);
            }
            Ok(Dynamic::from(dynamic_map))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rhai::{Dynamic, Map, Array};

    #[test]
    fn test_primitive_to_json() {
        // Test integer
        let int_val = Dynamic::from(42_i64);
        let json = rhai_dynamic_to_json(&int_val).unwrap();
        assert_eq!(json, "42");

        // Test float
        #[cfg(not(feature = "no_float"))]
        {
            let float_val = Dynamic::from(3.14_f64);
            let json = rhai_dynamic_to_json(&float_val).unwrap();
            assert!(json.contains("3.14"));
        }

        // Test boolean
        let bool_val = Dynamic::from(true);
        let json = rhai_dynamic_to_json(&bool_val).unwrap();
        assert_eq!(json, "true");

        // Test string
        let str_val = Dynamic::from("hello".to_string());
        let json = rhai_dynamic_to_json(&str_val).unwrap();
        assert_eq!(json, r#""hello""#);

        // Test unit
        let unit_val = Dynamic::UNIT;
        let json = rhai_dynamic_to_json(&unit_val).unwrap();
        assert_eq!(json, "null");
    }

    #[test]
    fn test_special_float_values() {
        #[cfg(not(feature = "no_float"))]
        {
            // Test infinity
            let inf_val = Dynamic::from(f64::INFINITY);
            let json = rhai_dynamic_to_json(&inf_val).unwrap();
            assert_eq!(json, r#""__INFINITY__""#);

            // Test negative infinity
            let neg_inf_val = Dynamic::from(f64::NEG_INFINITY);
            let json = rhai_dynamic_to_json(&neg_inf_val).unwrap();
            assert_eq!(json, r#""__NEG_INFINITY__""#);

            // Test NaN
            let nan_val = Dynamic::from(f64::NAN);
            let json = rhai_dynamic_to_json(&nan_val).unwrap();
            assert_eq!(json, r#""__NAN__""#);
        }
    }

    #[test]
    fn test_array_to_json() {
        let array: Array = vec![
            Dynamic::from(1_i64),
            Dynamic::from(2_i64),
            Dynamic::from(3_i64),
        ];
        let array_val = Dynamic::from(array);
        let json = rhai_dynamic_to_json(&array_val).unwrap();
        assert_eq!(json, "[1,2,3]");
    }

    #[test]
    fn test_map_to_json() {
        let mut map = Map::new();
        map.insert("name".into(), Dynamic::from("Alice".to_string()));
        map.insert("age".into(), Dynamic::from(30_i64));
        let map_val = Dynamic::from(map);
        let json = rhai_dynamic_to_json(&map_val).unwrap();

        // Parse to verify structure (order might vary)
        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed["name"], "Alice");
        assert_eq!(parsed["age"], 30);
    }

    #[test]
    fn test_nested_structures() {
        let mut inner_map = Map::new();
        inner_map.insert("x".into(), Dynamic::from(10_i64));

        let mut outer_map = Map::new();
        outer_map.insert("inner".into(), Dynamic::from(inner_map));
        outer_map.insert("values".into(), Dynamic::from(vec![
            Dynamic::from(1_i64),
            Dynamic::from(2_i64),
        ]));

        let nested_val = Dynamic::from(outer_map);
        let json = rhai_dynamic_to_json(&nested_val).unwrap();

        let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed["inner"]["x"], 10);
        assert_eq!(parsed["values"][0], 1);
        assert_eq!(parsed["values"][1], 2);
    }

    #[test]
    fn test_json_to_dynamic_primitives() {
        // Test integer
        let dynamic = json_to_rhai_dynamic("42").unwrap();
        assert_eq!(dynamic.as_int().unwrap(), 42);

        // Test float
        #[cfg(not(feature = "no_float"))]
        {
            let dynamic = json_to_rhai_dynamic("3.14").unwrap();
            assert!((dynamic.as_float().unwrap() - 3.14).abs() < 0.001);
        }

        // Test boolean
        let dynamic = json_to_rhai_dynamic("true").unwrap();
        assert_eq!(dynamic.as_bool().unwrap(), true);

        // Test string
        let dynamic = json_to_rhai_dynamic(r#""hello""#).unwrap();
        assert_eq!(dynamic.clone().try_cast::<String>().unwrap(), "hello");

        // Test null
        let dynamic = json_to_rhai_dynamic("null").unwrap();
        assert!(dynamic.is_unit());
    }

    #[test]
    fn test_json_to_dynamic_special_floats() {
        #[cfg(not(feature = "no_float"))]
        {
            // Test infinity
            let dynamic = json_to_rhai_dynamic(r#""__INFINITY__""#).unwrap();
            assert_eq!(dynamic.as_float().unwrap(), f64::INFINITY);

            // Test negative infinity
            let dynamic = json_to_rhai_dynamic(r#""__NEG_INFINITY__""#).unwrap();
            assert_eq!(dynamic.as_float().unwrap(), f64::NEG_INFINITY);

            // Test NaN
            let dynamic = json_to_rhai_dynamic(r#""__NAN__""#).unwrap();
            assert!(dynamic.as_float().unwrap().is_nan());
        }
    }

    #[test]
    fn test_json_to_dynamic_array() {
        let dynamic = json_to_rhai_dynamic("[1, 2, 3]").unwrap();
        assert!(dynamic.is_array());

        let array = dynamic.clone().try_cast::<rhai::Array>().unwrap();
        assert_eq!(array.len(), 3);
        assert_eq!(array[0].as_int().unwrap(), 1);
        assert_eq!(array[1].as_int().unwrap(), 2);
        assert_eq!(array[2].as_int().unwrap(), 3);
    }

    #[test]
    fn test_json_to_dynamic_map() {
        let dynamic = json_to_rhai_dynamic(r#"{"name": "Alice", "age": 30}"#).unwrap();
        assert!(dynamic.is_map());

        let map = dynamic.clone().try_cast::<rhai::Map>().unwrap();
        assert_eq!(map.get("name").unwrap().clone().try_cast::<String>().unwrap(), "Alice");
        assert_eq!(map.get("age").unwrap().as_int().unwrap(), 30);
    }

    #[test]
    fn test_json_to_dynamic_nested() {
        let json = r#"{"inner": {"x": 10}, "values": [1, 2]}"#;
        let dynamic = json_to_rhai_dynamic(json).unwrap();

        let map = dynamic.clone().try_cast::<rhai::Map>().unwrap();
        let inner = map.get("inner").unwrap().clone().try_cast::<rhai::Map>().unwrap();
        assert_eq!(inner.get("x").unwrap().as_int().unwrap(), 10);

        let values = map.get("values").unwrap().clone().try_cast::<rhai::Array>().unwrap();
        assert_eq!(values.len(), 2);
    }

    #[test]
    fn test_roundtrip_conversion() {
        // Create a complex structure
        let mut map = Map::new();
        map.insert("name".into(), Dynamic::from("Bob".to_string()));
        map.insert("age".into(), Dynamic::from(25_i64));
        map.insert("scores".into(), Dynamic::from(vec![
            Dynamic::from(90_i64),
            Dynamic::from(85_i64),
            Dynamic::from(95_i64),
        ]));

        let original = Dynamic::from(map);

        // Convert to JSON and back
        let json = rhai_dynamic_to_json(&original).unwrap();
        let restored = json_to_rhai_dynamic(&json).unwrap();

        // Verify structure is preserved
        let restored_map = restored.clone().try_cast::<rhai::Map>().unwrap();
        assert_eq!(restored_map.get("name").unwrap().clone().try_cast::<String>().unwrap(), "Bob");
        assert_eq!(restored_map.get("age").unwrap().as_int().unwrap(), 25);

        let scores = restored_map.get("scores").unwrap().clone().try_cast::<rhai::Array>().unwrap();
        assert_eq!(scores.len(), 3);
        assert_eq!(scores[0].as_int().unwrap(), 90);
    }

    #[test]
    fn test_roundtrip_special_floats() {
        #[cfg(not(feature = "no_float"))]
        {
            // Test infinity roundtrip
            let inf_val = Dynamic::from(f64::INFINITY);
            let json = rhai_dynamic_to_json(&inf_val).unwrap();
            let restored = json_to_rhai_dynamic(&json).unwrap();
            assert_eq!(restored.as_float().unwrap(), f64::INFINITY);

            // Test negative infinity roundtrip
            let neg_inf_val = Dynamic::from(f64::NEG_INFINITY);
            let json = rhai_dynamic_to_json(&neg_inf_val).unwrap();
            let restored = json_to_rhai_dynamic(&json).unwrap();
            assert_eq!(restored.as_float().unwrap(), f64::NEG_INFINITY);

            // Test NaN roundtrip
            let nan_val = Dynamic::from(f64::NAN);
            let json = rhai_dynamic_to_json(&nan_val).unwrap();
            let restored = json_to_rhai_dynamic(&json).unwrap();
            assert!(restored.as_float().unwrap().is_nan());
        }
    }

    #[test]
    fn test_invalid_json() {
        let result = json_to_rhai_dynamic("invalid json {");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Failed to parse JSON"));
    }
}
