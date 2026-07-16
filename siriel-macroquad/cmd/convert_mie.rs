// Siriel Macroquad - MIE to RON Level Converter
// Converts original Siriel 3.5 DOS .MIE level files to modern RON format
// Usage: cargo run --bin convert_mie -- <input_mie_file> [output_ron_file]

use std::env;
use std::fs;
use std::path::Path;

/// Convert Latin-1/Windows-1250 bytes to UTF-8 string
fn bytes_to_string(bytes: &[u8]) -> String {
    bytes.iter().map(|&b| b as char).collect()
}

#[derive(Debug, Clone)]
struct MieEntity {
    code: String,
    sprite_id: i32,
    x: i32,
    y: i32,
    behavior_id: i32,
    params: Vec<i32>,
}

#[derive(Debug)]
struct MieLevel {
    name: String,
    start_x: i32,
    start_y: i32,
    sound: String,
    messages: Vec<String>,
    entities: Vec<MieEntity>,
    tiles: Vec<Vec<i32>>,
}

/// Normalize line endings (CRLF -> LF)
fn normalize_line_endings(text: &str) -> String {
    text.replace("\r\n", "\n").replace('\r', "\n")
}

fn parse_mie(content: &str) -> Result<MieLevel, String> {
    let mut level = MieLevel {
        name: "Unknown".to_string(),
        start_x: 88,
        start_y: 88,
        sound: String::new(),
        messages: Vec::new(),
        entities: Vec::new(),
        tiles: Vec::new(),
    };

    let mut in_map = false;
    let mut map_lines: Vec<String> = Vec::new();

    for line in content.lines() {
        let line = line.trim();

        if line.is_empty() && !in_map {
            continue;
        }

        // Check for map section start
        if line == "[MAPA]=" {
            in_map = true;
            continue;
        }

        if in_map {
            // Map data - convert ASCII to tile IDs
            // Keep all non-empty lines that aren't section headers
            if !line.is_empty() && !line.starts_with('[') {
                map_lines.push(line.to_string());
            }
        } else {
            // Parse sections
            if line.starts_with('[') && line.contains(']') {
                let bracket_pos = line.find(']').ok_or("Missing ]")?;
                let equals_pos = line.find('=').ok_or("Missing =")?;
                let key = &line[1..bracket_pos];
                let value = &line[equals_pos + 1..];

                match key {
                    "MENO" => {
                        level.name = value.to_string();
                    }
                    "START" => {
                        let parts: Vec<&str> = value.split(',').collect();
                        if parts.len() >= 2 {
                            level.start_x = parts[0].parse().unwrap_or(88);
                            level.start_y = parts[1].parse().unwrap_or(88);
                        }
                    }
                    "SNDSTART" => level.sound = value.to_string(),
                    "MSG1" => {
                        // Store all messages as-is (with ~SLO~ prefix)
                        level.messages.push(value.to_string());
                    }
                    _ => {
                        // Entity definition - any 4-char code starting with Z, Y, X, W, or V
                        if key.len() == 4 {
                            let first_char = key.chars().next().unwrap_or(' ');
                            if first_char == 'Z'
                                || first_char == 'Y'
                                || first_char == 'X'
                                || first_char == 'W'
                                || first_char == 'V'
                            {
                                if let Ok(entity) = parse_entity(key, value) {
                                    level.entities.push(entity);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Convert ASCII map to tile IDs
    level.tiles = convert_map(&map_lines)?;

    Ok(level)
}

fn parse_entity(code: &str, value: &str) -> Result<MieEntity, String> {
    let parts: Vec<&str> = value.split(',').collect();
    if parts.len() < 4 {
        return Err("Invalid entity format".to_string());
    }

    let sprite_id = parts[0].parse().unwrap_or(0);
    let x = parts[1].parse().unwrap_or(0);
    let y = parts[2].parse().unwrap_or(0);
    let behavior_id = parts[3].parse().unwrap_or(1);
    let params: Vec<i32> = parts[4..].iter().filter_map(|s| s.parse().ok()).collect();

    Ok(MieEntity {
        code: code.to_string(),
        sprite_id,
        x,
        y,
        behavior_id,
        params,
    })
}

fn convert_map(map_lines: &[String]) -> Result<Vec<Vec<i32>>, String> {
    let mut tiles = Vec::new();

    for line in map_lines {
        let row: Vec<i32> = line
            .chars()
            .map(|c| {
                // Original Siriel used ASCII values starting at 15 (0x0F = Control-O)
                // Offset to 0-based indices for spritesheet
                let tile = c as i32;
                tile - 15
            })
            .collect();
        tiles.push(row);
    }

    Ok(tiles)
}

fn entity_type_from_code(code: &str) -> &'static str {
    // Match first 3 chars for flexibility with 4th char being variable
    let prefix = if code.len() >= 3 { &code[..3] } else { code };

    match prefix {
        "ZNN" => "Collectible",
        "ZAN" => "Collectible",
        "YNN" => "Trigger",
        "YAS" => "Trigger",
        "XNN" => "Interactable",
        "WNN" => "UseObject",
        "VNN" => "Talk",
        _ => "Collectible",
    }
}

fn behavior_from_id(id: i32) -> &'static str {
    match id {
        1 => "Static",
        2 => "HorizontalOscillator",
        3 => "VerticalOscillator",
        4 => "PlatformWithGravity",
        5 => "EdgeWalking",
        12 => "RandomMovement",
        15 => "Fireball",
        16 => "Hunter",
        17 => "SoundTrigger",
        18 => "AdvancedProjectile",
        _ => "Static",
    }
}

/// Map sprite_id (row index) to sprite name from objects-fmis.ron
fn sprite_name_from_id(id: i32) -> &'static str {
    match id {
        0 => "teleport",
        1 => "pear",
        2 => "cherry",
        3 => "wheel",
        4 => "teleport2",
        5 => "water",
        6 => "coin",
        7 => "hearth",
        8 => "pacman",
        9 => "monster",
        10 => "exit",
        11 => "coin_static",
        12 => "lollipop",
        13 => "ice_cream",
        14 => "apple",
        15 => "orange",
        16 => "money",
        17 => "gold",
        18 => "switch",
        19 => "teleport3",
        _ => "coin_static", // Fallback
    }
}

fn group_from_char(code: &str) -> &'static str {
    if code.len() >= 4 {
        match code.chars().nth(3).unwrap() {
            'A' => "A",
            'B' => "B",
            'C' => "C",
            'D' => "D",
            'E' => "E",
            'F' => "F",
            'G' => "G",
            _ => "A",
        }
    } else {
        "A"
    }
}

fn is_dangerous(code: &str) -> bool {
    code.len() >= 3 && code.chars().nth(2) == Some('S')
}

fn convert_to_ron(level: &MieLevel) -> String {
    let mut ron = String::new();

    ron.push_str("// Siriel Macroquad Level - Converted from MIE\n");
    ron.push_str(&format!("// Original name: {}\n\n", level.name));

    ron.push_str("(\n");
    ron.push_str(&format!("    name: \"{}\",\n", level.name));
    ron.push_str(&format!("    music: \"{}\",\n", level.sound));
    ron.push_str(&format!(
        "    start_position: (x: {}, y: {}),\n",
        level.start_x, level.start_y
    ));

    // Map section
    ron.push_str("    map: (\n");
    ron.push_str(&format!(
        "        width: {},\n",
        level.tiles.first().map_or(0, |r| r.len())
    ));
    ron.push_str(&format!("        height: {},\n", level.tiles.len()));
    ron.push_str("        tiles: [\n");

    for row in &level.tiles {
        ron.push_str("            [");
        let row_str: Vec<String> = row.iter().map(|t| t.to_string()).collect();
        ron.push_str(&row_str.join(", "));
        ron.push_str("],\n");
    }

    ron.push_str("        ],\n");
    ron.push_str("    ),\n");

    // Entities section
    if !level.entities.is_empty() {
        ron.push_str("    entities: [\n");

        for (i, entity) in level.entities.iter().enumerate() {
            ron.push_str("        (\n");
            ron.push_str(&format!("            id: \"{}_{}\",\n", entity.code, i));
            ron.push_str(&format!(
                "            entity_type: {},\n",
                entity_type_from_code(&entity.code)
            ));
            ron.push_str(&format!(
                "            sprite_name: \"{}\",\n",
                sprite_name_from_id(entity.sprite_id)
            ));
            // Original MIE uses 8x8 grid, multiply by 8 for screen position
            ron.push_str(&format!(
                "            position: (x: {}, y: {}),\n",
                entity.x * 8, entity.y * 8
            ));
            ron.push_str(&format!(
                "            behavior: {},\n",
                behavior_from_id(entity.behavior_id)
            ));

            if !entity.params.is_empty() {
                ron.push_str("            params: [");
                let param_str: Vec<String> = entity.params.iter().map(|p| p.to_string()).collect();
                ron.push_str(&param_str.join(", "));
                ron.push_str("],\n");
            }

            ron.push_str(&format!(
                "            danger: {},\n",
                is_dangerous(&entity.code)
            ));
            ron.push_str(&format!(
                "            group: {},\n",
                group_from_char(&entity.code)
            ));

            ron.push_str("        ),\n");
        }

        ron.push_str("    ],\n");
    }

    // Messages section - localized format
    if !level.messages.is_empty() {
        ron.push_str("    messages: [\n");

        // Process messages in pairs (English first, then ~SLO~)
        let mut i = 0;
        while i < level.messages.len() {
            let english = &level.messages[i];

            // Check if next message is translation
            if i + 1 < level.messages.len() {
                let next = &level.messages[i + 1];
                if next.starts_with("~SLO~") {
                    let slovak = &next[5..]; // Skip ~SLO~
                    let en_escaped = english.replace('"', "\\\"");
                    let sk_escaped = slovak.replace('"', "\\\"");
                    ron.push_str(&format!(
                        "        LocalizedMessage(en: \"{}\", sk: Some(\"{}\")),\n",
                        en_escaped, sk_escaped
                    ));
                    i += 2;
                    continue;
                }
            }

            // Single message (English only)
            let escaped = english.replace('"', "\\\"");
            ron.push_str(&format!("        LocalizedMessage(en: \"{}\"),\n", escaped));
            i += 1;
        }

        ron.push_str("    ],\n");
    }

    ron.push_str(")\n");

    ron
}

fn convert_single_file(input_path: &str, output_path: &str) {
    println!("Converting {} to {}", input_path, output_path);

    if let Some(parent) = Path::new(output_path).parent() {
        if let Err(e) = fs::create_dir_all(parent) {
            eprintln!("Error creating output directory: {}", e);
            return;
        }
    }

    // Read input as bytes
    let bytes = match fs::read(&input_path) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("Error reading file {}: {}", input_path, e);
            return;
        }
    };

    // Convert from Latin-1/Windows-1250 to UTF-8
    let content = bytes_to_string(&bytes);

    // Normalize line endings
    let content = normalize_line_endings(&content);

    // Parse MIE
    let level = match parse_mie(&content) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Error parsing MIE: {}", e);
            return;
        }
    };

    println!("Converted level: {}", level.name);
    println!("  Entities: {}", level.entities.len());
    println!(
        "  Map size: {}x{}",
        level.tiles.first().map_or(0, |r| r.len()),
        level.tiles.len()
    );

    // Convert to RON
    let ron = convert_to_ron(&level);

    // Write output
    match fs::write(&output_path, ron) {
        Ok(_) => println!("Wrote: {}", output_path),
        Err(e) => {
            eprintln!("Error writing file {}: {}", output_path, e);
        }
    }
}

fn batch_convert(directory: &str) {
    println!("Batch converting MIE files in: {}", directory);

    let dir_path = Path::new(directory);
    if !dir_path.is_dir() {
        eprintln!("Error: {} is not a directory", directory);
        return;
    }

    let output_dir = Path::new("assets/levels");
    if let Err(e) = fs::create_dir_all(output_dir) {
        eprintln!("Error creating output directory: {}", e);
        return;
    }

    match fs::read_dir(dir_path) {
        Ok(entries) => {
            let mut converted_count = 0;

            for entry in entries.flatten() {
                let path = entry.path();
                if let Some(extension) = path.extension() {
                    if extension.to_string_lossy().to_uppercase() == "MIE" {
                        let input_file = path.to_string_lossy().to_string();
                        let stem = path.file_stem().unwrap_or_default().to_string_lossy();
                        let output_file = format!("assets/levels/{}.ron", stem.to_lowercase());

                        println!(
                            "\n--- Converting {} ---",
                            path.file_name().unwrap().to_string_lossy()
                        );
                        convert_single_file(&input_file, &output_file);
                        converted_count += 1;
                    }
                }
            }

            println!("\nConverted {} files.", converted_count);
        }
        Err(e) => {
            eprintln!("Error reading directory: {}", e);
        }
    }
}

fn print_usage() {
    println!("MIE to RON Level Converter");
    println!("Converts original Siriel 3.5 DOS .MIE level files to modern RON format.");
    println!();
    println!("USAGE:");
    println!("    cargo run --bin convert_mie -- <input_mie_file> [output_ron_file]");
    println!("    cargo run --bin convert_mie -- --batch <mie_directory>");
    println!();
    println!("EXAMPLES:");
    println!("    cargo run --bin convert_mie -- ../siriel-levels/FMIS01.MIE");
    println!(
        "    cargo run --bin convert_mie -- ../siriel-levels/FMIS01.MIE assets/levels/fmis01.ron"
    );
    println!("    cargo run --bin convert_mie -- --batch ../siriel-levels/");
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        print_usage();
        return;
    }

    match args[1].as_str() {
        "--batch" => {
            if args.len() < 3 {
                eprintln!("Error: --batch requires a directory path");
                print_usage();
                return;
            }
            batch_convert(&args[2]);
        }
        "--help" | "-h" => {
            print_usage();
        }
        _ => {
            let input_file = &args[1];
            let output_file = if args.len() > 2 {
                args[2].clone()
            } else {
                let path = Path::new(input_file);
                let stem = path.file_stem().unwrap_or_default().to_string_lossy();
                format!("assets/levels/{}.ron", stem.to_lowercase())
            };
            convert_single_file(input_file, &output_file);
        }
    }
}
