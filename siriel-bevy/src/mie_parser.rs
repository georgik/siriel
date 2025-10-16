use bevy::prelude::*;
use std::fs;

/// Parsed MIE level file data
#[derive(Debug, Clone)]
pub struct MIELevel {
    pub name: String,
    pub start_position: (i32, i32),
    pub start_sound: Option<String>,
    pub entities: Vec<MIEEntity>,
    pub messages: Vec<String>, // MSG1-MSG5 from MIE files
    pub tilemap: Vec<Vec<u8>>,
    pub width: usize,
    pub height: usize,
}

/// Entity definition from MIE file
#[derive(Debug, Clone)]
pub struct MIEEntity {
    pub entity_type: String,
    pub sprite_id: i32,      // First parameter - sprite ID for rendering
    pub x: i32,              // Second parameter - X coordinate
    pub y: i32,              // Third parameter - Y coordinate
    pub behavior_id: i32,    // Fourth parameter - Behavior type ID
    pub param1: i32,         // Fifth parameter - First behavior parameter
    pub param2: i32,         // Sixth parameter - Second behavior parameter
    pub param3: Option<i32>, // Seventh parameter - Third behavior parameter (optional)
    pub param4: Option<i32>, // Eighth parameter - Fourth behavior parameter (optional)
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
            messages: Vec::new(),
            tilemap: Vec::new(),
            width: 0,
            height: 0,
        };

        // Find where binary data begins by looking for [MAPA] or [MAP
        let mut header_end = data.len();
        let mut map_start_pos = None;

        // Look for [MAPA]= pattern specifically
        for i in 0..data.len() - 7 {
            if data[i] == b'['
                && data[i + 1] == b'M'
                && data[i + 2] == b'A'
                && data[i + 3] == b'P'
                && data[i + 4] == b'A'
                && data[i + 5] == b']'
                && data[i + 6] == b'='
            {
                // Found [MAPA]= - the header ends at the start of this line
                // Find the beginning of this line
                let mut line_start = i;
                while line_start > 0 && data[line_start - 1] != 0x0A {
                    line_start -= 1;
                }

                header_end = line_start;

                // Find the end of the [MAP] line to start binary data
                let mut line_end = i;
                while line_end < data.len() && data[line_end] != 0x0D && data[line_end] != 0x0A {
                    line_end += 1;
                }
                // Skip past line ending
                while line_end < data.len() && (data[line_end] == 0x0D || data[line_end] == 0x0A) {
                    line_end += 1;
                }
                map_start_pos = Some(line_end);
                break;
            }
        }

        // Parse only the header section as text
        let header_data = &data[0..header_end];
        let content = String::from_utf8_lossy(header_data);
        let lines: Vec<&str> = content.lines().collect();

        // Parse header section (text)
        for line in lines {
            let line = line.trim();

            if line.is_empty() {
                continue;
            }

            // Skip MAP lines as they're handled separately
            if line.starts_with("[MAP") {
                continue;
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
                        "MSG1" | "MSG2" | "MSG3" | "MSG4" | "MSG5" => {
                            // Process language-specific messages
                            let processed_message = Self::process_language_message(&value);
                            level.messages.push(processed_message);
                        }
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

    /// Parse entity definition like "2,8,17,1,1,3" (sprite_id,x,y,behavior_id,param1,param2)
    fn parse_entity(entity_type: &str, value: &str) -> Option<MIEEntity> {
        let parts: Vec<&str> = value.split(',').collect();
        if parts.len() >= 5 {
            if let (Ok(sprite_id), Ok(x), Ok(y), Ok(behavior_id), Ok(param1)) = (
                parts[0].parse::<i32>(), // sprite_id - first parameter
                parts[1].parse::<i32>(), // x coordinate
                parts[2].parse::<i32>(), // y coordinate
                parts[3].parse::<i32>(), // behavior_id - fourth parameter
                parts[4].parse::<i32>(), // param1
            ) {
                let param2 = if parts.len() > 5 {
                    parts[5].parse::<i32>().ok().unwrap_or(0)
                } else {
                    0
                };
                let param3 = if parts.len() > 6 {
                    parts[6].parse::<i32>().ok()
                } else {
                    None
                };
                let param4 = if parts.len() > 7 {
                    parts[7].parse::<i32>().ok()
                } else {
                    None
                };

                return Some(MIEEntity {
                    entity_type: entity_type.to_string(),
                    sprite_id,
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
        let line_ending_len = Self::detect_line_ending(data);

        for (i, line) in lines.iter().enumerate() {
            if i == map_line_index {
                // Skip this line and the next newline to get to map data
                pos += line.len() + line_ending_len;
                break;
            }
            pos += line.len() + line_ending_len;
        }
        pos
    }

    /// Detect line ending type in the data
    fn detect_line_ending(data: &[u8]) -> usize {
        // Look for first line ending to determine type
        for i in 0..(data.len() - 1) {
            if data[i] == 0x0D {
                if data[i + 1] == 0x0A {
                    return 2; // \r\n (Windows)
                } else {
                    return 1; // \r (Mac classic)
                }
            } else if data[i] == 0x0A {
                return 1; // \n (Unix)
            }
        }
        1 // Default fallback
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
                if byte == 0x0D {
                    // CR - could be \r or \r\n
                    if pos < data.len() && data[pos] == 0x0A {
                        // Skip the \n for \r\n
                        pos += 1;
                    }
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

    /// Process language-specific messages (mimics Pascal check_lan function)
    /// Handles ~SLO~ markers and strips them to return just the message text
    fn process_language_message(message: &str) -> String {
        // Check if message starts with language marker like ~SLO~
        if message.starts_with('~') && message.len() >= 5 {
            // Extract language code (positions 1-3: ~SLO~)
            let lang_marker = &message[1..4];

            // For now, we'll prefer Slovak (SLO) messages, but also accept English
            // In the original game, this would check against current language setting
            if lang_marker == "SLO" || lang_marker == "ENG" {
                // Find the end of the language marker (~SLO~)
                if let Some(marker_end) = message
                    .find("~")
                    .and_then(|start| message[start + 1..].find("~").map(|end| start + end + 2))
                {
                    // Return the message after the language marker
                    return message[marker_end..].to_string();
                }
            }
        }

        // If no language marker or unsupported language, return as-is
        message.to_string()
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
