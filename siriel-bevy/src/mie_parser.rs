use bevy::prelude::*;
use std::fs;

/// Parsed MIE level file data
#[derive(Debug, Clone)]
pub struct MIELevel {
    pub name: String,
    pub start_position: (i32, i32),
    pub start_sound: Option<String>,
    pub entities: Vec<MIEEntity>,
    pub tilemap: Vec<Vec<u8>>,
    pub width: usize,
    pub height: usize,
}

/// Entity definition from MIE file
#[derive(Debug, Clone)]
pub struct MIEEntity {
    pub entity_type: String,
    pub x: i32,
    pub y: i32,
    pub behavior_id: i32,
    pub param1: i32,
    pub param2: i32,
    pub param3: Option<i32>,
    pub param4: Option<i32>,
}

/// MIE file parser
pub struct MIEParser;

impl MIEParser {
    /// Parse a MIE level file
    pub fn parse_mie_file(file_path: &str) -> Result<MIELevel, Box<dyn std::error::Error>> {
        let content = fs::read(file_path)?;
        Self::parse_mie_binary(&content)
    }

    /// Parse MIE content from binary data
    pub fn parse_mie_binary(data: &[u8]) -> Result<MIELevel, Box<dyn std::error::Error>> {
        let mut level = MIELevel {
            name: String::new(),
            start_position: (0, 0),
            start_sound: None,
            entities: Vec::new(),
            tilemap: Vec::new(),
            width: 0,
            height: 0,
        };

        // Convert to string for header parsing
        let content = String::from_utf8_lossy(data);
        let lines: Vec<&str> = content.lines().collect();
        let mut i = 0;
        let mut map_start_pos = None;

        // Parse header section (text)
        while i < lines.len() {
            let line = lines[i].trim();

            if line.is_empty() {
                i += 1;
                continue;
            }

            // Check for map section start
            if line.starts_with("[MAP") {
                // Find the actual start of binary map data
                map_start_pos = Some(Self::find_map_start_position(data, i, &lines));
                break;
            }

            if line.starts_with('[') && line.contains(']') {
                // Parse command
                if let Some((key, value)) = Self::parse_command(line) {
                    match key.as_str() {
                        "MENO" => level.name = value,
                        "START" => {
                            if let Some((x, y)) = Self::parse_coordinates(&value) {
                                level.start_position = (x, y);
                            }
                        }
                        "SNDSTART" => level.start_sound = Some(value),
                        "ZNNA" | "ZNNB" | "ZNNC" | "ZANA" | "YNN~" | "YNNA" | "YASB" | "YASC" => {
                            if let Some(entity) = Self::parse_entity(&key, &value) {
                                level.entities.push(entity);
                            }
                        }
                        _ => {
                            // Handle other entity types and commands
                            if key.starts_with('Z') || key.starts_with('Y') {
                                if let Some(entity) = Self::parse_entity(&key, &value) {
                                    level.entities.push(entity);
                                }
                            } else {
                                info!("Unknown MIE command: {} = {}", key, value);
                            }
                        }
                    }
                }
            }

            i += 1;
        }

        // Parse binary map data if found
        if let Some(map_pos) = map_start_pos {
            level.tilemap = Self::parse_binary_tilemap(data, map_pos)?;
            level.height = level.tilemap.len();
            level.width = if !level.tilemap.is_empty() {
                level.tilemap[0].len()
            } else {
                0
            };
        }

        info!(
            "Parsed MIE level '{}': {}x{} map, {} entities, start at ({}, {})",
            level.name,
            level.width,
            level.height,
            level.entities.len(),
            level.start_position.0,
            level.start_position.1
        );

        Ok(level)
    }

    /// Parse a command line like [KEY]=value
    fn parse_command(line: &str) -> Option<(String, String)> {
        if let Some(eq_pos) = line.find('=') {
            let key_part = &line[..eq_pos];
            let value_part = &line[eq_pos + 1..];

            // Extract key from [KEY]
            if key_part.starts_with('[') && key_part.ends_with(']') {
                let key = key_part[1..key_part.len() - 1].to_string();
                return Some((key, value_part.to_string()));
            }
        }
        None
    }

    /// Parse coordinates like "88,88"
    fn parse_coordinates(value: &str) -> Option<(i32, i32)> {
        let parts: Vec<&str> = value.split(',').collect();
        if parts.len() == 2 {
            if let (Ok(x), Ok(y)) = (parts[0].parse::<i32>(), parts[1].parse::<i32>()) {
                return Some((x, y));
            }
        }
        None
    }

    /// Parse entity definition like "1,8,17,1,3,10"
    fn parse_entity(entity_type: &str, value: &str) -> Option<MIEEntity> {
        let parts: Vec<&str> = value.split(',').collect();
        if parts.len() >= 5 {
            if let (Ok(behavior_id), Ok(x), Ok(y), Ok(param1), Ok(param2)) = (
                parts[0].parse::<i32>(),
                parts[1].parse::<i32>(),
                parts[2].parse::<i32>(),
                parts[3].parse::<i32>(),
                parts[4].parse::<i32>(),
            ) {
                let param3 = if parts.len() > 5 {
                    parts[5].parse::<i32>().ok()
                } else {
                    None
                };
                let param4 = if parts.len() > 6 {
                    parts[6].parse::<i32>().ok()
                } else {
                    None
                };

                return Some(MIEEntity {
                    entity_type: entity_type.to_string(),
                    x,
                    y,
                    behavior_id,
                    param1,
                    param2,
                    param3,
                    param4,
                });
            }
        }
        None
    }

    /// Find the byte position where binary map data starts
    fn find_map_start_position(data: &[u8], map_line_index: usize, lines: &[&str]) -> usize {
        // Find the byte position after the [MAPX]=N line
        let mut pos = 0;
        for (i, line) in lines.iter().enumerate() {
            if i == map_line_index {
                // Skip this line and the next newline to get to map data
                pos += line.len() + 2; // +2 for \r\n
                break;
            }
            pos += line.len() + 2; // +2 for \r\n
        }
        pos
    }

    /// Parse binary tilemap data from MIE file
    fn parse_binary_tilemap(
        data: &[u8],
        start_pos: usize,
    ) -> Result<Vec<Vec<u8>>, Box<dyn std::error::Error>> {
        let mut tilemap = Vec::new();
        let mut pos = start_pos;

        // Read until we hit the end of file or double newline
        while pos < data.len() {
            let mut row = Vec::new();

            // Read one row of tiles
            while pos < data.len() {
                let byte = data[pos];
                pos += 1;

                // Check for line ending
                if byte == 0x0D && pos < data.len() && data[pos] == 0x0A {
                    // Skip the \n
                    pos += 1;
                    break;
                } else if byte == 0x0A {
                    // Just \n
                    break;
                } else {
                    // This is a tile byte
                    row.push(byte);
                }
            }

            if row.is_empty() {
                // Empty row means end of map
                break;
            }

            tilemap.push(row);

            // Safety check - if we have too many rows, break
            if tilemap.len() > 100 {
                break;
            }
        }

        // Ensure all rows have the same width (pad with 0x0f if needed)
        if let Some(max_width) = tilemap.iter().map(|row| row.len()).max() {
            for row in &mut tilemap {
                while row.len() < max_width {
                    row.push(0x0f); // Empty tile
                }
            }
        }

        info!(
            "Parsed binary tilemap: {} rows, {} columns",
            tilemap.len(),
            tilemap.first().map(|r| r.len()).unwrap_or(0)
        );

        Ok(tilemap)
    }

    /// Convert MIE tile byte to tile ID
    /// 0x0f (15) = empty/walkable space (becomes tile 0 - transparent/walkable)
    /// 0x10 (16) = tile 1, 0x11 (17) = tile 2, etc.
    /// Maps to sequential 0-based atlas indices
    pub fn tile_byte_to_tile_id(tile_byte: u8) -> u32 {
        // Sequential mapping starting from 0x0f = 0
        // 0x0f -> 0, 0x10 -> 1, 0x11 -> 2, 0x12 -> 3, etc.
        if tile_byte >= 0x0f {
            (tile_byte - 0x0f) as u32
        } else {
            // Fallback for unexpected values
            0
        }
    }

    /// Get tile character for debugging
    pub fn tile_id_to_char(tile_id: u32) -> char {
        if tile_id == 0 {
            ' ' // Empty space
        } else {
            '#' // Solid tile
        }
    }
}

/// Debug function to print binary tilemap
pub fn debug_print_tilemap(tilemap: &[Vec<u8>]) {
    println!("Binary Tilemap ({} rows):", tilemap.len());
    for (i, row) in tilemap.iter().enumerate() {
        print!("{:2}: ", i);
        for &tile_byte in row {
            if tile_byte == 0x0f {
                print!(" "); // Empty space
            } else {
                print!("#"); // Solid tile
            }
        }
        print!(" | ");
        for &tile_byte in row {
            print!("{:02x} ", tile_byte);
        }
        println!();
    }
}
