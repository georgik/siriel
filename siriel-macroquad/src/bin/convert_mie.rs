// MIE to RON Converter for Siriel Macroquad
// Converts original Siriel 3.5 MIE files to modern RON format

use std::env;
use std::fs;
use std::path::Path;

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

        if line.is_empty() {
            continue;
        }

        // Check for map section start
        if line == "[MAPA]=" {
            in_map = true;
            continue;
        }

        if in_map {
            // Map data - convert ASCII to tile IDs
            if !line.starts_with('[') {
                map_lines.push(line.to_string());
            }
        } else {
            // Parse sections
            if line.starts_with('[') && line.contains(']') {
                let equals_pos = line.find('=').ok_or("Missing =")?;
                let key = &line[1..equals_pos];
                let value = &line[equals_pos + 1..];

                match key {
                    "MENO" => level.name = value.to_string(),
                    "START" => {
                        let parts: Vec<&str> = value.split(',').collect();
                        if parts.len() >= 2 {
                            level.start_x = parts[0].parse().unwrap_or(88);
                            level.start_y = parts[1].parse().unwrap_or(88);
                        }
                    }
                    "SNDSTART" => level.sound = value.to_string(),
                    "MSG1" => level.messages.push(value.to_string()),
                    _ => {
                        // Entity definition
                        if key.len() == 4 {
                            if let Ok(entity) = parse_entity(key, value) {
                                level.entities.push(entity);
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
    let params: Vec<i32> = parts[4..]
        .iter()
        .filter_map(|s| s.parse().ok())
        .collect();

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
    match code {
        "ZNNA" | "ZANA" => "Collectible",
        "YNN~" | "YNN" => "Trigger",
        "XNNA" => "Interactable",
        "WNNA" => "UseObject",
        "VNNC" => "Talk",
        _ => "Collectible",
    }
}

fn behavior_from_id(id: i32) -> &'static str {
    match id {
        0 => "Static",
        1 => "Teleport",
        2 => "HorizontalOscillator",
        3 => "VerticalOscillator",
        4 => "PlatformWithGravity",
        5 => "EdgeWalking",
        6 => "TextureChange",
        7 => "ShowGroup",
        8 => "HideGroup",
        9 => "LevelComplete",
        10 => "AddLife",
        12 => "RandomMovement",
        13 => "SwapRoomVisibility",
        14 => "TransferToStage",
        15 => "Fireball",
        16 => "Hunter",
        17 => "SoundTrigger",
        18 => "AdvancedProjectile",
        19 => "TextureChange",
        _ => "Static",
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

fn is_animated(code: &str) -> bool {
    code.len() >= 2 && code.chars().nth(1) == Some('A')
}

fn is_dangerous(code: &str) -> bool {
    code.len() >= 3 && code.chars().nth(2) == Some('S')
}

fn convert_to_ron(level: &MieLevel) -> String {
    let mut ron = String::new();

    ron.push_str("(\n");
    ron.push_str(&format!("    name: \"{}\",\n", level.name));
    ron.push_str(&format!("    start_position: (x: {}, y: {}),\n", level.start_x, level.start_y));

    // Map section
    ron.push_str("    map: (\n");
    ron.push_str(&format!("        width: {},\n", level.tiles.first().map_or(0, |r| r.len())));
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
    ron.push_str("    entities: [\n");

    for (i, entity) in level.entities.iter().enumerate() {
        ron.push_str("        (\n");
        ron.push_str(&format!("            id: \"{}_{}\",\n", entity.code, i));
        ron.push_str(&format!("            entity_type: {},\n", entity_type_from_code(&entity.code)));
        ron.push_str(&format!("            sprite_id: {},\n", entity.sprite_id));
        ron.push_str(&format!("            position: (x: {}, y: {}),\n", entity.x, entity.y));
        ron.push_str(&format!("            behavior: {},\n", behavior_from_id(entity.behavior_id)));

        if !entity.params.is_empty() {
            ron.push_str("            params: [");
            let param_str: Vec<String> = entity.params.iter().map(|p| p.to_string()).collect();
            ron.push_str(&param_str.join(", "));
            ron.push_str("],\n");
        }

        ron.push_str(&format!("            animated: {},\n", is_animated(&entity.code)));
        ron.push_str(&format!("            danger: {},\n", is_dangerous(&entity.code)));
        ron.push_str(&format!("            group: {},\n", group_from_char(&entity.code)));

        ron.push_str("        ),\n");
    }

    ron.push_str("    ],\n");

    // Messages section
    if !level.messages.is_empty() {
        ron.push_str("    messages: [\n");
        for msg in &level.messages {
            // Escape quotes in messages
            let escaped = msg.replace('"', "\\\"");
            ron.push_str(&format!("        \"{}\",\n", escaped));
        }
        ron.push_str("    ],\n");
    }

    ron.push_str(")\n");

    ron
}

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 3 {
        warn!("Usage: {} <input.mie> <output.ron>", args[0]);
        warn!("Example: {} FMIS01.MIE fmis01.ron", args[0]);
        std::process::exit(1);
    }

    let input_path = Path::new(&args[1]);
    let output_path = Path::new(&args[2]);

    // Read input
    let content = match fs::read_to_string(&input_path) {
        Ok(c) => c,
        Err(e) => {
            warn!("Error reading file {}: {}", input_path.display(), e);
            std::process::exit(1);
        }
    };

    // Parse MIE
    let level = match parse_mie(&content) {
        Ok(l) => l,
        Err(e) => {
            warn!("Error parsing MIE: {}", e);
            std::process::exit(1);
        }
    };

    info!("Converted level: {}", level.name);
    info!("  Entities: {}", level.entities.len());
    info!("  Map size: {}x{}", level.tiles.first().map_or(0, |r| r.len()), level.tiles.len());

    // Convert to RON
    let ron = convert_to_ron(&level);

    // Write output
    if let Some(parent) = output_path.parent() {
        if let Err(e) = fs::create_dir_all(parent) {
            warn!("Error creating directory: {}", e);
            std::process::exit(1);
        }
    }

    match fs::write(&output_path, ron) {
        Ok(_) => info!("Wrote: {}", output_path.display()),
        Err(e) => {
            warn!("Error writing file {}: {}", output_path.display(), e);
            std::process::exit(1);
        }
    }
}
