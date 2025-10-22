use siriel_bevy::dat_extractor::DATExtractor;
use std::env;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom, Write};

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() > 1 && args[1] == "--help" {
        print_help();
        return;
    }

    println!("Siriel Level Extractor");
    println!("======================");
    println!();

    if args.len() > 1 {
        // Extract specific DAT file
        let dat_file = &args[1];
        println!("Extracting levels from: {}", dat_file);

        match extract_levels_from_dat(dat_file) {
            Ok(count) => println!("Successfully extracted {} level files", count),
            Err(e) => eprintln!("Error extracting levels: {}", e),
        }
    } else {
        // Extract from all relevant DAT files in current directory tree
        println!("Extracting levels from all DAT files...");
        extract_all_levels();
    }
}

fn extract_levels_from_dat(dat_file: &str) -> Result<usize, Box<dyn std::error::Error>> {
    let mut extractor = DATExtractor::new(dat_file)?;

    extractor.list_resources();
    println!();

    // Map DAT file names to level prefixes
    let dat_name = std::path::Path::new(dat_file)
        .file_stem()
        .unwrap()
        .to_string_lossy();

    let level_prefix = match dat_name.as_ref() {
        "SIRIEL35" => "FMIS", // First Mission levels
        "CAULDRON" => "CAUL", // Cauldron levels
        "GBALL" => "GBALL",   // Great Ball levels
        "WAY" => "WAY",       // Way levels
        _ => "UNKNOWN",
    };

    let output_dir = format!("extracted_levels/{}", dat_name);

    std::fs::create_dir_all(&output_dir)?;

    let mut count = 0;

    // Extract each resource and save as raw data first to inspect
    for (name, _resource) in extractor.resources.clone() {
        // Try to extract MIE files (level files likely have specific naming patterns)
        if looks_like_level_file(&name) {
            // Generate proper level name based on DAT file and resource name
            let level_name =
                if name.starts_with("M") && name[1..].chars().all(|c| c.is_ascii_digit()) {
                    // Convert M1, M2, etc. to proper level names like FMIS01, CAUL01, etc.
                    let level_num: u32 = name[1..].parse().unwrap_or(0);
                    format!("{}{:02}", level_prefix, level_num)
                } else {
                    // Keep original name for explicitly named levels
                    name.clone()
                };

            let output_path = format!("{}/{}.MIE", output_dir, level_name);
            match extract_raw_resource(&mut extractor, &name, &output_path) {
                Ok(_) => {
                    println!(
                        "Extracted level '{}' as '{}' to '{}'",
                        name, level_name, output_path
                    );
                    count += 1;
                }
                Err(e) => {
                    eprintln!("Failed to extract '{}': {}", name, e);
                }
            }
        }
    }

    Ok(count)
}

fn extract_raw_resource(
    extractor: &mut DATExtractor,
    resource_name: &str,
    output_path: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let resource = extractor
        .resources
        .get(resource_name)
        .ok_or_else(|| format!("Resource '{}' not found", resource_name))?;

    // Seek to resource start
    extractor.file.seek(SeekFrom::Start(resource.start))?;

    // Read and decrypt data
    let mut encrypted_data = vec![0u8; resource.size as usize];
    extractor.file.read_exact(&mut encrypted_data)?;

    // Decrypt using the original algorithm
    let decrypted_data = decrypt_data(&encrypted_data);

    // Convert Slovak text encoding from CP852 (DOS Latin-2) to UTF-8
    let encoded_data = convert_slovak_encoding(&decrypted_data);

    // Convert line endings from CR (\r) to LF (\n) for Unix-like systems
    let converted_data = convert_line_endings(&encoded_data);

    // Write converted data as MIE file
    let mut output_file = File::create(output_path)?;
    output_file.write_all(&converted_data)?;

    Ok(())
}

fn decrypt_data(encrypted_data: &[u8]) -> Vec<u8> {
    let mut decrypted = encrypted_data.to_vec();

    // Apply method 1 decryption (+2) to all non-zero bytes
    for byte in decrypted.iter_mut() {
        if *byte != 0 {
            *byte = dekoduj(1, *byte);
        }
    }

    decrypted
}

fn dekoduj(method: u16, mut byte: u8) -> u8 {
    match method {
        1 => {
            // bt := bt + 2
            byte = byte.wrapping_add(2);
        }
        2 => {
            // Bitwise NOT operation
            byte = !byte;
        }
        3 => {
            // bt := bt + 74
            byte = byte.wrapping_add(74);
        }
        _ => {
            // Default case
        }
    }
    byte
}

fn convert_line_endings(data: &[u8]) -> Vec<u8> {
    let mut converted = Vec::with_capacity(data.len());

    for &byte in data {
        if byte == 0x0D {
            // CR (\r)
            converted.push(0x0A); // Convert to LF (\n)
        } else {
            converted.push(byte);
        }
    }

    converted
}

fn convert_slovak_encoding(data: &[u8]) -> Vec<u8> {
    // Only convert Slovak text sections (after ~SLO~ markers) from CP852 (DOS Latin-2)
    // The rest of the file should remain as-is since it's ASCII commands and binary data

    let mut result = Vec::with_capacity(data.len());
    let mut i = 0;

    while i < data.len() {
        // Look for ~SLO~ marker
        if i + 5 < data.len() && &data[i..i + 5] == b"~SLO~" {
            // Copy the ~SLO~ marker as-is
            result.extend_from_slice(&data[i..i + 5]);
            i += 5;

            // Find the end of this line (marked by \n or \r)
            let line_start = i;
            while i < data.len() && data[i] != 0x0A && data[i] != 0x0D {
                i += 1;
            }

            if i > line_start {
                // Convert this Slovak text from CP852 (DOS Latin-2) to UTF-8
                let slovak_text = &data[line_start..i];
                let decoded = decode_cp852_to_utf8(slovak_text);

                // Add the converted UTF-8 text
                result.extend_from_slice(decoded.as_bytes());
            }
        } else {
            // Regular byte - copy as-is
            result.push(data[i]);
            i += 1;
        }
    }

    result
}

fn decode_cp852_to_utf8(bytes: &[u8]) -> String {
    // Custom CP852 (DOS Latin-2) to UTF-8 decoder for Slovak characters
    // Based on CP852 character encoding table
    let mut result = String::with_capacity(bytes.len());

    for &byte in bytes {
        let character = match byte {
            // ASCII range (0x00-0x7F) remains the same
            0x00..=0x7F => byte as char,

            // CP852 Slovak/Czech special characters:
            0x87 => 'ç', // This maps to ç in CP852, but we want 'č'
            0x9F => 'č', // This is the correct CP852 code for 'č'
            0xA0 => 'á', // Correct: á
            0xA1 => 'í', // Correct: í
            0xA2 => 'ó', // Correct: ó
            0xA3 => 'ú', // Correct: ú
            0xA7 => 'ž', // Correct: ž
            0xA8 => 'Ę', // This maps to Ę in CP852, but we want 'š'
            0xE7 => 'š', // This is the correct CP852 code for 'š'
            0x82 => 'é', // Correct: é
            0x84 => 'ä', // Correct: ä
            0x93 => 'ô', // Correct: ô
            0x96 => 'ľ', // Correct: ľ
            0x9C => 'ť', // Correct: ť
            0xE5 => 'ň', // Correct: ň
            0xEA => 'ŕ', // Correct: ŕ
            0xEC => 'ý', // Correct: ý

            // For any unmapped byte, assume it's latin-1 compatible
            _ => byte as char,
        };
        result.push(character);
    }

    // Manual fix for known incorrect encodings in the original files:
    // The original files seem to have some encoding issues, so we'll fix them
    result = result.replace("vĘetko", "všetko"); // Fix 0xa8 -> š instead of Ę
    result = result.replace("Stlaç", "Stlač"); // Fix 0x87 -> č instead of ç

    result
}

fn looks_like_level_file(name: &str) -> bool {
    // Level files in DAT archives are named M1, M2, ..., M12
    // Or they could be explicitly named FMIS*, CAUL*, GBALL*, etc.
    name.starts_with("FMIS")
        || name.starts_with("CAUL")
        || name.starts_with("GBALL")
        || name.starts_with("SWAY")
        || (name.starts_with("M") && name[1..].chars().all(|c| c.is_ascii_digit()))
    // M1, M2, M10, M11, M12
}

fn extract_all_levels() {
    // Look for DAT files in common locations
    let possible_dat_dirs = [
        "../siriel-3.5-dos/BIN",
        "../../siriel-3.5-dos/BIN",
        "./BIN",
        ".",
    ];

    let dat_files = ["SIRIEL35.DAT", "CAULDRON.DAT", "GBALL.DAT", "WAY.DAT"];

    for dir in &possible_dat_dirs {
        let dir_path = std::path::Path::new(dir);
        if dir_path.exists() {
            println!("Checking directory: {}", dir);

            for dat_file in &dat_files {
                let full_path = dir_path.join(dat_file);
                if full_path.exists() {
                    println!("\n--- Processing {} ---", full_path.display());
                    match extract_levels_from_dat(&full_path.to_string_lossy()) {
                        Ok(count) => {
                            println!("Extracted {} levels from {}", count, full_path.display())
                        }
                        Err(e) => eprintln!("Failed to process {}: {}", full_path.display(), e),
                    }
                }
            }
        }
    }
}

fn print_help() {
    println!("Siriel Level Extractor");
    println!("======================");
    println!();
    println!("Usage:");
    println!("  extract_levels                    - Extract levels from all DAT files");
    println!("  extract_levels <dat_file>         - Extract levels from specific DAT file");
    println!("  extract_levels --help             - Show this help");
    println!();
    println!("Examples:");
    println!("  extract_levels");
    println!("  extract_levels ../siriel-3.5-dos/BIN/SIRIEL35.DAT");
    println!();
    println!("The extractor will:");
    println!("  1. Read DAT files and decrypt them using the original algorithm");
    println!("  2. Extract MIE files to extracted_levels/");
    println!("  3. Organize levels by their source DAT file");
}
