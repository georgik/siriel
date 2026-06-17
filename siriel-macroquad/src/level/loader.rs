// Siriel Macroquad - Level Loader

#![allow(dead_code)]

use super::types::*;
use crate::entities::Creature;
use std::collections::HashMap;
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

/// TOML level structure for deserialization
#[derive(Debug, serde::Deserialize)]
struct TomlLevel {
    level: TomlLevelData,
}

#[derive(Debug, serde::Deserialize)]
struct TomlLevelData {
    name: String,
    width: usize,
    height: usize,
    start_x: i32,
    start_y: i32,
    #[serde(default)]
    start_sound: Option<String>,
    #[serde(default)]
    messages: Vec<String>,
    #[serde(default)]
    tilemap: HashMap<String, Vec<i32>>,
    #[serde(default)]
    entities: Vec<TomlEntity>,
}

#[derive(Debug, Clone, serde::Deserialize)]
struct TomlEntity {
    #[serde(rename = "type")]
    entity_type: String,
    sprite_id: i32,
    x: i32,
    y: i32,
    #[serde(default)]
    behavior: i32,
    #[serde(default)]
    param1: i32,
    #[serde(default)]
    param2: i32,
    #[serde(default)]
    param3: Option<i32>,
    #[serde(default)]
    param4: Option<i32>,
}

/// Load level from TOML file (converted from MIE)
pub fn load_from_toml(path: &Path) -> Result<Level, String> {
    let content =
        std::fs::read_to_string(path).map_err(|e| format!("Failed to read TOML file: {}", e))?;

    let toml_level: TomlLevel =
        toml::from_str(&content).map_err(|e| format!("Failed to parse TOML: {}", e))?;

    let data = toml_level.level;

    // Parse tilemap from row_0, row_1, etc.
    let mut tiles = Vec::new();
    let mut i = 0;
    while let Some(row) = data.tilemap.get(&format!("row_{}", i)) {
        tiles.push(row.clone());
        i += 1;
    }

    if tiles.is_empty() {
        // Create default empty tilemap
        tiles = vec![vec![0; data.width]; data.height];
    }

    // Create metadata
    let meta = LevelMeta {
        name: data.name.clone(),
        author: "Converted from MIE".to_string(),
        version: "1.0".to_string(),
        width: data.width,
        height: data.height,
        music: data.start_sound.clone(),
    };

    let player_start = (data.start_x, data.start_y);

    let mut level = Level::from_data(meta, tiles, player_start);

    // Add messages
    level.messages = data.messages;

    // Convert entities to Creatures
    for entity in &data.entities {
        let param3 = entity.param3.unwrap_or(0);
        let param4 = entity.param4.unwrap_or(0);

        if let Some(creature) = Creature::from_toml(
            &entity.entity_type,
            entity.sprite_id,
            entity.x,
            entity.y,
            entity.behavior as u32,
            entity.param1,
            entity.param2,
            param3,
            param4,
        ) {
            level.add_creature(creature);
        }
    }

    Ok(level)
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
}
