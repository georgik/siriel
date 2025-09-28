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

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use ron::ser::{to_string_pretty, PrettyConfig};

// Import our level parsing modules
use siriel_bevy::level::{LevelData, LevelEntity};
use siriel_bevy::mie_parser::{MIELevel, MIEEntity, MIEParser};

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
                            
                            println!("\n--- Converting {} ---", path.file_name().unwrap().to_string_lossy());
                            convert_single_file(&input_file, &output_file);
                            converted_count += 1;
                        }
                    }
                }
            }
            
            println!("\n🎉 Batch conversion complete! Converted {} files.", converted_count);
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
    output.push_str(&format!("    spawn_point: ({}, {}),\n", level.spawn_point.0, level.spawn_point.1));
    output.push_str("    background_image: None,\n");
    
    // Custom tilemap formatting - each row on its own line with padded numbers
    output.push_str("    tilemap: [\n");
    for (i, row) in level.tilemap.iter().enumerate() {
        output.push_str("        [");
        for (j, &tile) in row.iter().enumerate() {
            if j > 0 { output.push_str(", "); }
            // Pad numbers to 2 digits for better visual alignment
            output.push_str(&format!("{:2}", tile));
        }
        output.push_str("]");
        if i < level.tilemap.len() - 1 { output.push_str(","); }
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
    
    // Serialize just the entities, transitions, scripts parts
    let entities_ron = to_string_pretty(&level.entities, config.clone())?;
    let transitions_ron = to_string_pretty(&level.transitions, config.clone())?;
    let scripts_ron = to_string_pretty(&level.scripts, config.clone())?;
    
    output.push_str(&format!("    entities: {},\n", entities_ron));
    output.push_str(&format!("    transitions: {},\n", transitions_ron));
    output.push_str(&format!("    scripts: {},\n", scripts_ron));
    
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
    println!("   Start Position: ({}, {})", mie_level.start_position.0, mie_level.start_position.1);
    if let Some(ref start_sound) = mie_level.start_sound {
        println!("   Start Sound: {}", start_sound);
    }
    println!("   Entities: {}", mie_level.entities.len());
    
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
    println!("   Spawn Point: ({:.1}, {:.1})", level.spawn_point.0, level.spawn_point.1);
    println!("   Entities: {}", level.entities.len());
    println!("   Transitions: {}", level.transitions.len());
    println!("   Scripts: {}", level.scripts.len());
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
    
    // Convert spawn point with Y-coordinate flipping 
    let spawn_y_flipped = (mie_level.height as f32 * 16.0) - mie_level.start_position.1 as f32;
    
    LevelData {
        name: mie_level.name.clone(),
        width: mie_level.width as u32,
        height: mie_level.height as u32,
        spawn_point: (mie_level.start_position.0 as f32, spawn_y_flipped),
        background_image: None,
        tilemap,
        entities,
        transitions: Vec::new(),
        scripts: Vec::new(),
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

/// Convert MIE entities to modern LevelEntity format
fn convert_mie_entities(mie_entities: &[MIEEntity], level_height: f32) -> Vec<LevelEntity> {
    mie_entities
        .iter()
        .enumerate()
        .map(|(i, entity)| {
            // Map entity types to sprite IDs and behaviors
            let (sprite_id, behavior_type, pickupable) = match entity.entity_type.as_str() {
                "ZNNA" => (1, entity.behavior_id as u8, false), // Normal enemy
                "ZANA" => (2, entity.behavior_id as u8, false), // Special enemy
                "YNN~" => (5, 1, true),  // Pickup item
                _ => (0, 1, false),
            };
            
            // Flip Y coordinate for Bevy's coordinate system
            let flipped_y = (level_height * 16.0) - entity.y as f32;
            
            LevelEntity {
                id: format!("{}_{}", entity.entity_type, i),
                entity_type: entity.entity_type.clone(),
                position: (entity.x as f32, flipped_y),
                sprite_id,
                behavior_type,
                behavior_params: [
                    entity.param1 as u16,
                    entity.param2 as u16,
                    entity.param3.unwrap_or(0) as u16,
                    entity.param4.unwrap_or(0) as u16,
                    0, 0, 0
                ],
                room: 1,
                pickupable,
                pickup_value: if pickupable { 100 } else { 0 },
                sound_effects: None,
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
                        if file_name_upper.starts_with(prefix) && file_name_upper.ends_with(".MIE") {
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
                println!("\n⚠️  No files matching pattern '{}' found in {}", pattern, directory);
                println!("   Make sure the directory contains the expected MIE files.");
            } else {
                println!("\n🎉 Batch conversion complete! Converted {} files matching '{}'.", converted_count, pattern);
            }
        }
        Err(e) => {
            eprintln!("Error reading directory: {}", e);
        }
    }
}
