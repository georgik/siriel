// Siriel Macroquad - Level Loader

#![allow(dead_code)]

use super::types::*;
use macroquad::prelude::*;
use serde::Deserialize;
use std::path::Path;

/// Load level from embedded level definition (compile-time)
pub fn load_embedded<L: LevelDef>() -> Level {
    L::to_level()
}

/// Parse simple tilemap format from string
/// Format: Rust-like 2D array syntax
pub fn parse_tilemap(source: &str) -> Result<Vec<Vec<i32>>, String> {
    let source = source.trim();

    if !source.starts_with('[') || !source.ends_with(']') {
        return Err("Tilemap must be wrapped in brackets".to_string());
    }

    let mut result = Vec::new();
    let mut current_row = Vec::new();
    let mut current_num = String::new();
    let mut in_row = false;

    let chars: Vec<char> = source.chars().collect();
    let mut i = 1; // Skip opening bracket

    while i < chars.len() - 1 {
        // Skip closing bracket
        match chars[i] {
            '[' => {
                in_row = true;
                i += 1;
            }
            ']' => {
                if in_row && !current_num.is_empty() {
                    if let Ok(num) = current_num.trim().parse::<i32>() {
                        current_row.push(num);
                    }
                    current_num.clear();
                }
                if in_row && !current_row.is_empty() {
                    result.push(current_row.clone());
                    current_row.clear();
                }
                in_row = false;
                i += 1;
            }
            ',' => {
                if !current_num.is_empty() {
                    if let Ok(num) = current_num.trim().parse::<i32>() {
                        current_row.push(num);
                    }
                    current_num.clear();
                }
                i += 1;
            }
            c if c.is_whitespace() => {
                i += 1;
            }
            c => {
                current_num.push(c);
                i += 1;
            }
        }
    }

    Ok(result)
}

/// Parse level from .rs file content
pub fn parse_level_file(content: &str) -> Result<Level, String> {
    let mut meta = LevelMeta::default();
    let mut player_start = (88, 88);
    let mut tiles: Option<Vec<Vec<i32>>> = None;

    // Simple parser for level .rs files
    for line in content.lines() {
        let line = line.trim();

        // Skip empty lines and comments
        if line.is_empty() || line.starts_with("//") {
            continue;
        }

        // Parse metadata
        if line.contains("name:") {
            if let Some(rest) = line.split("name:").nth(1) {
                let value = rest.trim().trim_matches('"').trim();
                meta.name = value.to_string();
            }
        } else if line.contains("author:") {
            if let Some(rest) = line.split("author:").nth(1) {
                let value = rest.trim().trim_matches('"').trim();
                meta.author = value.to_string();
            }
        } else if line.contains("player_start:") {
            if let Some(rest) = line.split("player_start:").nth(1) {
                let coords = rest.trim().trim_matches('(').trim_matches(')').trim();
                let parts: Vec<&str> = coords.split(',').collect();
                if parts.len() == 2 {
                    if let (Ok(x), Ok(y)) = (
                        parts[0].trim().parse::<i32>(),
                        parts[1].trim().parse::<i32>(),
                    ) {
                        player_start = (x, y);
                    }
                }
            }
        } else if line.contains("tiles:") {
            // Extract array after "tiles:"
            if let Some(rest) = line.split("tiles:").nth(1) {
                let array_str = rest.trim();
                if let Ok(parsed) = parse_tilemap(array_str) {
                    meta.width = parsed.first().map_or(0, |row| row.len());
                    meta.height = parsed.len();
                    tiles = Some(parsed);
                }
            }
        }
    }

    let tiles = tiles.ok_or("No tiles found in level file".to_string())?;

    Ok(Level::from_data(meta, tiles, player_start))
}

/// Load level from file path (runtime)
pub fn load_from_file(path: &Path) -> Result<Level, String> {
    let content =
        std::fs::read_to_string(path).map_err(|e| format!("Failed to read file: {}", e))?;
    parse_level_file(&content)
}

/// Load level from RON file (primary level format)
/// RON is Rust-native format that matches LevelData struct exactly
pub fn load_from_ron(path: &Path) -> Result<Level, String> {
    let content =
        std::fs::read_to_string(path).map_err(|e| format!("Failed to read RON file: {}", e))?;

    // Parse RON format
    let mut parser =
        ron::Deserializer::from_str(&content).map_err(|e| format!("RON parse error: {}", e))?;

    let level_data =
        LevelData::deserialize(&mut parser).map_err(|e| format!("Deserialize error: {}", e))?;

    // Convert to legacy format
    Ok(level_data.to_legacy())
}

/// Load level from RON file asynchronously (WASM-compatible)
/// Uses macroquad's load_string instead of std::fs
pub async fn load_from_ron_async(path: &str) -> Result<Level, String> {
    let content = load_string(path)
        .await
        .map_err(|e| format!("Failed to load RON: {:?}", e))?;

    let mut parser =
        ron::Deserializer::from_str(&content).map_err(|e| format!("RON parse error: {}", e))?;

    let level_data =
        LevelData::deserialize(&mut parser).map_err(|e| format!("Deserialize error: {}", e))?;

    Ok(level_data.to_legacy())
}

/// Load level with format detection
/// Note: Only RON format is supported. Use convert_mie.rs to convert MIE files.
pub fn load_level_auto(path: &Path) -> Result<Level, String> {
    let extension = path.extension().and_then(|e| e.to_str()).unwrap_or("");

    match extension {
        "ron" => load_from_ron(path),
        _ => Err(format!(
            "Unsupported level format: '{}'. Only .ron files supported. \
                Use 'cargo run --bin convert_mie -- <input_mie_file>' to convert MIE files.",
            extension
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_tilemap() {
        let input = "[[1, 2, 3], [4, 5, 6]]";
        let result = parse_tilemap(input).unwrap();
        assert_eq!(result, vec![vec![1, 2, 3], vec![4, 5, 6]]);
    }

    #[test]
    fn test_parse_level() {
        let input = r#"
// Test level
name: "Test Level"
author: "Test Author"
player_start: (100, 100)
tiles: [[1, 2], [3, 4]]
"#;
        let level = parse_level_file(input).unwrap();
        assert_eq!(level.meta.name, "Test Level");
        assert_eq!(level.meta.author, "Test Author");
        assert_eq!(level.player_start, (100, 100));
        assert_eq!(level.tiles, vec![vec![1, 2], vec![3, 4]]);
    }

    #[test]
    fn test_load_fmis01() {
        let result = load_from_ron(Path::new("assets/levels/fmis01.ron"));
        if let Err(e) = &result {
            eprintln!("Error loading RON: {}", e);
        }
        assert!(result.is_ok(), "Failed to load RON: {:?}", result);

        let level = result.unwrap();
        assert_eq!(level.meta.name, "START");
        assert_eq!(level.meta.width, 39);
        assert_eq!(level.meta.height, 27);
    }
}
