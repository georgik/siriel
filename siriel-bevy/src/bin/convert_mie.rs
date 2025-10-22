#!/usr/bin/env cargo
//! MIE to RON Level Converter
//!
//! This tool converts original Siriel 3.5 DOS .MIE level files to modern RON format.
//!
//! Usage:
//!   cargo run --bin convert_mie -- <input_mie_file> [output_ron_file]
//!   cargo run --bin convert_mie -- --batch <mie_directory>
//!
//! Examples:
//!   cargo run --bin convert_mie -- ../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/1.MIE assets/levels/level1.ron
//!   cargo run --bin convert_mie -- --batch ../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/

use ron::ser::{to_string_pretty, PrettyConfig};
use std::env;
use std::fs;
use std::path::Path;

// Import our level parsing modules
use siriel_bevy::components::{BehaviorParams, BehaviorType};
use siriel_bevy::level::{
    AppearCondition, AppearMode, DangerLevel, EntityCodeProps, InteractionKind, LevelData,
    LevelEntity,
};
use siriel_bevy::mie_parser::{MIEEntity, MIELevel, MIEParser};

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
        "--batch-fmis" => {
            batch_convert_fmis();
        }
        "--batch-caul" => {
            batch_convert_caul();
        }
        "--batch-gball" => {
            batch_convert_gball();
        }
        "--help" | "-h" => {
            print_usage();
        }
        _ => {
            let input_file = &args[1];
            let output_file = if args.len() > 2 {
                args[2].clone()
            } else {
                generate_output_filename(input_file)
            };
            convert_single_file(input_file, &output_file);
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
    println!("OPTIONS:");
    println!("    --batch <dir>    Convert all .MIE files in directory");
    println!("    --batch-fmis     Convert all FMIS*.MIE files from ../siriel-levels");
    println!("    --batch-caul     Convert all CAUL*.MIE files from ../siriel-levels");
    println!("    --batch-gball    Convert all GBALL*.MIE files from ../siriel-levels");
    println!("    --help, -h       Show this help message");
    println!();
    println!("EXAMPLES:");
    println!("    cargo run --bin convert_mie -- ../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/1.MIE");
    println!("    cargo run --bin convert_mie -- ../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/1.MIE assets/levels/level1.ron");
    println!("    cargo run --bin convert_mie -- --batch ../siriel-3.5-dos/BIN/DISKY/FIRSTMIS/");
    println!("    cargo run --bin convert_mie -- --batch-fmis");
    println!("    cargo run --bin convert_mie -- --batch-gball");
}

fn convert_single_file(input_path: &str, output_path: &str) {
    println!("Converting {} to {}", input_path, output_path);

    // Ensure output directory exists
    if let Some(parent) = Path::new(output_path).parent() {
        if let Err(e) = fs::create_dir_all(parent) {
            eprintln!("Error creating output directory: {}", e);
            return;
        }
    }

    // Load and convert the MIE file
    match load_mie_level(input_path) {
        Ok(mie_level) => {
            println!("Successfully loaded MIE level: {}", mie_level.name);
            print_mie_info(&mie_level);

            // Convert to modern format
            let level_data = convert_mie_to_level_data(mie_level);

            // Save as RON file
            match save_level_data(&level_data, output_path) {
                Ok(()) => {
                    println!("✓ Successfully converted and saved to {}", output_path);
                    print_level_summary(&level_data);
                }
                Err(e) => {
                    eprintln!("Error saving converted level: {}", e);
                }
            }
        }
        Err(e) => {
            eprintln!("Error loading MIE file: {}", e);
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

    // Create output directory
    let output_dir = Path::new("assets/levels");
    if let Err(e) = fs::create_dir_all(output_dir) {
        eprintln!("Error creating output directory: {}", e);
        return;
    }

    // Find all .MIE files
    match fs::read_dir(dir_path) {
        Ok(entries) => {
            let mut converted_count = 0;

            for entry in entries {
                if let Ok(entry) = entry {
                    let path = entry.path();
                    if let Some(extension) = path.extension() {
                        if extension.to_string_lossy().to_uppercase() == "MIE" {
                            let input_file = path.to_string_lossy();
                            let output_file = generate_batch_output_filename(&path);

                            println!(
                                "\n--- Converting {} ---",
                                path.file_name().unwrap().to_string_lossy()
                            );
                            convert_single_file(&input_file, &output_file);
                            converted_count += 1;
                        }
                    }
                }
            }

            println!(
                "\n🎉 Batch conversion complete! Converted {} files.",
                converted_count
            );
        }
        Err(e) => {
            eprintln!("Error reading directory: {}", e);
        }
    }
}

fn generate_output_filename(input_path: &str) -> String {
    let path = Path::new(input_path);
    let stem = path.file_stem().unwrap_or_default().to_string_lossy();
    format!("assets/levels/{}.ron", stem)
}

fn generate_batch_output_filename(input_path: &Path) -> String {
    let stem = input_path.file_stem().unwrap_or_default().to_string_lossy();
    format!("assets/levels/{}.ron", stem)
}

fn save_level_data(level: &LevelData, filename: &str) -> Result<(), Box<dyn std::error::Error>> {
    // Custom formatting approach for better tilemap readability
    // Since RON's pretty printer can't format nested arrays the way we want,
    // we'll create a custom formatted string

    let mut output = String::new();
    output.push_str("(\n");
    output.push_str(&format!("    name: \"{}\",\n", level.name));
    output.push_str(&format!("    width: {},\n", level.width));
    output.push_str(&format!("    height: {},\n", level.height));
    output.push_str(&format!(
        "    spawn_point: ({}, {}),\n",
        level.spawn_point.0, level.spawn_point.1
    ));
    output.push_str("    background_image: None,\n");

    // Custom tilemap formatting - each row on its own line with padded numbers
    output.push_str("    tilemap: [\n");
    for (i, row) in level.tilemap.iter().enumerate() {
        output.push_str("        [");
        for (j, &tile) in row.iter().enumerate() {
            if j > 0 {
                output.push_str(", ");
            }
            // Pad numbers to 2 digits for better visual alignment
            output.push_str(&format!("{:2}", tile));
        }
        output.push_str("]");
        if i < level.tilemap.len() - 1 {
            output.push_str(",");
        }
        output.push_str("\n");
    }
    output.push_str("    ],\n");

    // Use standard RON formatting for entities and other complex structures
    let config = PrettyConfig::new()
        .depth_limit(4)
        .separate_tuple_members(true)
        .enumerate_arrays(false)
        .compact_arrays(false)
        .new_line("\n".to_string())
        .indentor("    ".to_string());

    // Serialize just the entities, transitions, scripts, messages parts
    let entities_ron = to_string_pretty(&level.entities, config.clone())?;
    let transitions_ron = to_string_pretty(&level.transitions, config.clone())?;
    let scripts_ron = to_string_pretty(&level.scripts, config.clone())?;
    let messages_ron = to_string_pretty(&level.messages, config.clone())?;

    output.push_str(&format!("    entities: {},\n", entities_ron));
    output.push_str(&format!("    transitions: {},\n", transitions_ron));
    output.push_str(&format!("    scripts: {},\n", scripts_ron));
    output.push_str(&format!("    messages: {},\n", messages_ron));

    if let Some(ref music) = level.music {
        output.push_str(&format!("    music: Some(\"{}\"),\n", music));
    } else {
        output.push_str("    music: None,\n");
    }

    if let Some(time_limit) = level.time_limit {
        output.push_str(&format!("    time_limit: Some({}),\n", time_limit));
    } else {
        output.push_str("    time_limit: None,\n");
    }

    output.push_str(")");

    fs::write(filename, output)?;
    Ok(())
}

fn print_mie_info(mie_level: &MIELevel) {
    println!("📋 MIE Level Information:");
    println!("   Name: {}", mie_level.name);
    println!("   Dimensions: {}x{}", mie_level.width, mie_level.height);
    println!(
        "   Start Position: ({}, {})",
        mie_level.start_position.0, mie_level.start_position.1
    );
    if let Some(ref start_sound) = mie_level.start_sound {
        println!("   Start Sound: {}", start_sound);
    }
    println!("   Entities: {}", mie_level.entities.len());
    println!("   Messages: {}", mie_level.messages.len());

    // Show messages if any
    for (i, message) in mie_level.messages.iter().enumerate() {
        println!("     MSG{}: {}", i + 1, message);
    }

    // Group entities by type
    let mut entity_counts = std::collections::HashMap::new();
    for entity in &mie_level.entities {
        *entity_counts.entry(entity.entity_type.clone()).or_insert(0) += 1;
    }

    for (entity_type, count) in entity_counts {
        println!("     {}: {} instances", entity_type, count);
    }
}

fn print_level_summary(level: &LevelData) {
    println!("📋 Converted Level Summary:");
    println!("   Name: {}", level.name);
    println!("   Dimensions: {}x{}", level.width, level.height);
    println!(
        "   Spawn Point: ({:.1}, {:.1})",
        level.spawn_point.0, level.spawn_point.1
    );
    println!("   Entities: {}", level.entities.len());
    println!("   Transitions: {}", level.transitions.len());
    println!("   Scripts: {}", level.scripts.len());
    println!("   Messages: {}", level.messages.len());
    if let Some(time_limit) = level.time_limit {
        println!("   Time Limit: {:.0} seconds", time_limit);
    }

    // Count non-empty tiles
    let mut tile_count = 0;
    for row in &level.tilemap {
        for &tile in row {
            if tile > 0 {
                tile_count += 1;
            }
        }
    }
    println!("   Non-empty tiles: {}", tile_count);
}

/// Load MIE level file
fn load_mie_level(file_path: &str) -> Result<MIELevel, Box<dyn std::error::Error>> {
    MIEParser::parse_mie_file(file_path)
}

/// Convert MIE level data to modern LevelData format
fn convert_mie_to_level_data(mie_level: MIELevel) -> LevelData {
    // Convert tilemap
    let tilemap = convert_mie_tilemap(&mie_level.tilemap);

    // Convert entities with Y-coordinate flipping
    let entities = convert_mie_entities(&mie_level.entities, mie_level.height as f32);

    // Convert spawn point with proper coordinate system transformation
    // Original DOS coordinates: (0,0) at top-left, MIE coordinates are in 8x8 grid units
    // Convert to pixels, then center for Bevy coordinate system (0,0 at center)
    let spawn_x_pixels = mie_level.start_position.0 as f32 * 8.0;
    let spawn_y_pixels = mie_level.start_position.1 as f32 * 8.0;
    let spawn_x_centered = spawn_x_pixels - 320.0; // Center X (screen width / 2)
    let spawn_y_centered = 240.0 - spawn_y_pixels; // Flip Y and center (screen height / 2)

    LevelData {
        name: mie_level.name.clone(),
        width: mie_level.width as u32,
        height: mie_level.height as u32,
        spawn_point: (spawn_x_centered, spawn_y_centered),
        background_image: None,
        tilemap,
        entities,
        transitions: Vec::new(),
        scripts: Vec::new(),
        messages: mie_level.messages,
        music: None,
        time_limit: Some(300.0), // Default 5 minutes
    }
}

/// Convert MIE binary tilemap to tile IDs with proper collision mapping
fn convert_mie_tilemap(binary_map: &[Vec<u8>]) -> Vec<Vec<u16>> {
    let mut tilemap = Vec::new();

    for row in binary_map {
        let mut tile_row = Vec::new();
        for &tile_byte in row {
            // Convert tile byte to proper tile ID
            // 0x0f (15) -> 0 (empty/walkable)
            // Other values -> 1+ (solid tiles)
            let tile_id = MIEParser::tile_byte_to_tile_id(tile_byte);
            tile_row.push(tile_id as u16);
        }
        tilemap.push(tile_row);
    }

    // Ensure minimum size
    if tilemap.is_empty() {
        // Create a basic empty level
        tilemap = vec![vec![0u16; 40]; 30]; // 0 = empty/walkable tile
    }

    tilemap
}

/// Decode the 4-character entity code into structured properties
fn decode_entity_code(entity_type: &str) -> Option<EntityCodeProps> {
    let chars: Vec<char> = entity_type.chars().collect();
    if chars.len() != 4 {
        return None;
    }

    // Position 1: Interaction Type
    let interaction_kind = match chars[0] {
        'Z' => InteractionKind::PickupWalk,
        'Y' => InteractionKind::SpecialTouch,
        'X' => InteractionKind::SpecialEnter,
        'W' => InteractionKind::Use,
        'V' => InteractionKind::Talk,
        _ => return None, // Invalid interaction type
    };

    // Position 2: Animation
    let animated = match chars[1] {
        'A' => true,
        'N' => false,
        _ => return None, // Invalid animation flag
    };

    // Position 3: Danger Level
    let danger = match chars[2] {
        'N' => DangerLevel::None,
        'S' => DangerLevel::Mortal,
        'D' => DangerLevel::NoGod,
        _ => return None, // Invalid danger level
    };

    // Position 4: Visibility/Activation Group
    let appear = match chars[3] {
        'A' => AppearCondition {
            mode: AppearMode::Immediate,
            group_char: None,
        },
        '~' => AppearCondition {
            mode: AppearMode::ExitOnAllCollected,
            group_char: None,
        },
        group_char => AppearCondition {
            mode: AppearMode::Group,
            group_char: Some(group_char),
        },
    };

    Some(EntityCodeProps {
        interaction_kind,
        animated,
        danger,
        appear,
    })
}

/// Convert numeric behavior ID to BehaviorType enum
fn map_behavior_type_from_id(behavior_id: u8) -> BehaviorType {
    match behavior_id {
        1 => BehaviorType::Static,
        2 => BehaviorType::HorizontalOscillator,
        3 => BehaviorType::VerticalOscillator,
        4 => BehaviorType::PlatformWithGravity,
        5 => BehaviorType::EdgeWalkingPlatform,
        6 => BehaviorType::AnimatedCollectible,
        7 => BehaviorType::RandomMovement, // Additional random movement variant
        8 => BehaviorType::RandomMovement, // Additional random movement variant
        9 => BehaviorType::RandomMovement, // Additional random movement variant
        10 => BehaviorType::RandomMovement, // Additional random movement variant
        11 => BehaviorType::RandomMovement, // Additional random movement variant
        12 => BehaviorType::RandomMovement,
        13 => BehaviorType::Static, // Static variant (likely unused/special case)
        14 => BehaviorType::Static, // Static variant (likely unused/special case)
        15 => BehaviorType::Fireball,
        16 => BehaviorType::Hunter,
        17 => BehaviorType::SoundTrigger,
        18 => BehaviorType::AdvancedProjectile,
        _ => {
            println!(
                "Warning: Unknown behavior ID {}, defaulting to Static",
                behavior_id
            );
            BehaviorType::Static
        }
    }
}

/// Convert numeric behavior parameters array to BehaviorParams enum
fn map_behavior_params_from_array(behavior_type: BehaviorType, params: [u16; 4]) -> BehaviorParams {
    match behavior_type {
        BehaviorType::Static => BehaviorParams::Static,
        BehaviorType::HorizontalOscillator => BehaviorParams::HorizontalOscillator {
            left_bound: params[0],
            right_bound: params[1],
            speed: params[2],
        },
        BehaviorType::VerticalOscillator => BehaviorParams::VerticalOscillator {
            top_bound: params[0],
            bottom_bound: params[1],
            speed: params[2],
        },
        BehaviorType::PlatformWithGravity => BehaviorParams::PlatformWithGravity {
            speed: params[0],
            start_x: 0, // Will be set from entity position
            start_y: 0, // Will be set from entity position
        },
        BehaviorType::EdgeWalkingPlatform => BehaviorParams::EdgeWalkingPlatform {
            speed: params[0],
            start_x: 0, // Will be set from entity position
            start_y: 0, // Will be set from entity position
        },
        BehaviorType::AnimatedCollectible => BehaviorParams::AnimatedCollectible {
            animation_speed: params[0],
            timer_max: params[1],
            value: params[2],
        },
        BehaviorType::RandomMovement => BehaviorParams::RandomMovement {
            boundary_mode: params[0],
            speed: params[1],
            direction: params[2],
            timer: params[3],
            old_direction: 0,
        },
        BehaviorType::Fireball => BehaviorParams::Fireball {
            direction: params[0],
            target_pos: params[1],
            speed: params[2],
            reload_time: params[3],
            timer: 0,
        },
        BehaviorType::Hunter => BehaviorParams::Hunter {
            speed: params[0],
            passive_time: params[1],
            active_time: params[2],
            alternate_sprite: params[3],
            mode_timer: 0,
        },
        BehaviorType::SoundTrigger => BehaviorParams::SoundTrigger {
            sound1_id: params[0],
            sound1_delay: params[1],
            sound2_id: params[2],
            sound2_delay: params[3],
            timer: 0,
            mode: 0,
        },
        BehaviorType::AdvancedProjectile => BehaviorParams::AdvancedProjectile {
            direction: params[0],
            target_pos: params[1],
            speed: params[2],
            reload_time: params[3],
            timer: 0,
        },
    }
}

/// Convert MIE entities to modern LevelEntity format
fn convert_mie_entities(mie_entities: &[MIEEntity], _level_height: f32) -> Vec<LevelEntity> {
    mie_entities
        .iter()
        .enumerate()
        .map(|(i, entity)| {
            // Decode the 4-letter entity code into properties
            let props_opt = decode_entity_code(&entity.entity_type);

            // Use sprite_id directly from MIE data (first parameter)
            // The original Pascal engine stores sprite IDs in the first parameter of entity definitions
            let sprite_id: u16 = entity.sprite_id as u16;

            // Use decoded interaction properties for pickup flags (no more hardcoded categories)
            let (pickupable, pickup_value) = if let Some(ref props) = props_opt {
                match props.interaction_kind {
                    InteractionKind::PickupWalk => (true, entity.param1 as u32), // Value from param1 (inf1 in editor)
                    InteractionKind::SpecialEnter
                    | InteractionKind::Use
                    | InteractionKind::Talk
                    | InteractionKind::SpecialTouch => (false, 0),
                }
            } else {
                // Fallback: assume not pickupable if we can't decode
                (false, 0)
            };

            // Convert entity coordinates from DOS coordinate system to Bevy coordinates
            // DOS: (0,0) at top-left, MIE coordinates are in 8x8 grid units
            // Convert to pixels, then center for Bevy coordinate system (0,0 at center)
            let entity_x_pixels = entity.x as f32 * 8.0;
            let entity_y_pixels = entity.y as f32 * 8.0;
            let entity_x_centered = entity_x_pixels - 320.0; // Center X (screen width / 2)
            let entity_y_centered = 240.0 - entity_y_pixels; // Flip Y and center (screen height / 2)

            // Convert behavior to new system
            let behavior_type = map_behavior_type_from_id(entity.behavior_id as u8);
            let behavior_params = map_behavior_params_from_array(
                behavior_type,
                [
                    entity.param1 as u16,
                    entity.param2 as u16,
                    entity.param3.unwrap_or(0) as u16,
                    entity.param4.unwrap_or(0) as u16,
                ],
            );

            LevelEntity {
                id: format!("{}_{}", entity.entity_type, i),
                entity_type: entity.entity_type.clone(),
                position: (entity_x_centered, entity_y_centered),
                sprite_id,
                behavior_type,
                behavior_params,
                // room/group: mirror editor behavior
                // Immediate ('A') and Exit ('~') => room = 1
                // Group letter => room = ord(letter)
                room: if let Some(ref p) = props_opt {
                    match p.appear.mode {
                        AppearMode::Immediate | AppearMode::ExitOnAllCollected => 1,
                        AppearMode::Group => p.appear.group_char.map(|c| c as u8).unwrap_or(1),
                    }
                } else {
                    1
                },
                pickupable,
                pickup_value,
                sound_effects: None,
                entity_props: props_opt,
            }
        })
        .collect()
}

fn batch_convert_fmis() {
    println!("Batch converting all FMIS*.MIE files from ../siriel-levels");
    batch_convert_pattern("../siriel-levels", "FMIS*.MIE");
}

fn batch_convert_caul() {
    println!("Batch converting all CAUL*.MIE files from ../siriel-levels");
    batch_convert_pattern("../siriel-levels", "CAUL*.MIE");
}

fn batch_convert_gball() {
    println!("Batch converting all GBALL*.MIE files from ../siriel-levels");
    batch_convert_pattern("../siriel-levels", "GBALL*.MIE");
}

fn batch_convert_pattern(directory: &str, pattern: &str) {
    let dir_path = Path::new(directory);
    if !dir_path.is_dir() {
        eprintln!("Error: {} is not a directory or does not exist", directory);
        eprintln!("Make sure the siriel-levels directory exists with the original MIE files.");
        return;
    }

    // Create output directory
    let output_dir = Path::new("assets/levels");
    if let Err(e) = fs::create_dir_all(output_dir) {
        eprintln!("Error creating output directory: {}", e);
        return;
    }

    // Extract prefix from pattern (e.g., "FMIS" from "FMIS*.MIE")
    let prefix = pattern.split('*').next().unwrap_or("");

    // Find all matching .MIE files
    match fs::read_dir(dir_path) {
        Ok(entries) => {
            let mut converted_count = 0;

            for entry in entries {
                if let Ok(entry) = entry {
                    let path = entry.path();
                    if let Some(file_name) = path.file_name() {
                        let file_name_str = file_name.to_string_lossy();
                        let file_name_upper = file_name_str.to_uppercase();

                        // Check if filename matches the pattern
                        if file_name_upper.starts_with(prefix) && file_name_upper.ends_with(".MIE")
                        {
                            let input_file = path.to_string_lossy();
                            let output_file = generate_batch_output_filename(&path);

                            println!("\n--- Converting {} ---", file_name_str);
                            convert_single_file(&input_file, &output_file);
                            converted_count += 1;
                        }
                    }
                }
            }

            if converted_count == 0 {
                println!(
                    "\n⚠️  No files matching pattern '{}' found in {}",
                    pattern, directory
                );
                println!("   Make sure the directory contains the expected MIE files.");
            } else {
                println!(
                    "\n🎉 Batch conversion complete! Converted {} files matching '{}'.",
                    converted_count, pattern
                );
            }
        }
        Err(e) => {
            eprintln!("Error reading directory: {}", e);
        }
    }
}
