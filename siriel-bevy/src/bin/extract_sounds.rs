use std::env;
use siriel_bevy::dat_extractor::{DATExtractor, extract_siriel_sounds};

fn main() {
    let args: Vec<String> = env::args().collect();
    
    if args.len() > 1 && args[1] == "--help" {
        print_help();
        return;
    }
    
    println!("Siriel Sound Extractor");
    println!("=====================");
    println!();
    
    if args.len() > 1 {
        // Extract specific DAT file
        let dat_file = &args[1];
        println!("Extracting sounds from: {}", dat_file);
        
        match DATExtractor::new(dat_file) {
            Ok(mut extractor) => {
                extractor.list_resources();
                println!();
                
                let output_dir = format!("assets/audio/extracted/{}", 
                    std::path::Path::new(dat_file)
                        .file_stem()
                        .unwrap()
                        .to_string_lossy());
                
                match extractor.extract_all(&output_dir) {
                    Ok(_) => println!("Successfully extracted sounds to {}", output_dir),
                    Err(e) => eprintln!("Error extracting sounds: {}", e),
                }
            }
            Err(e) => {
                eprintln!("Failed to open DAT file '{}': {}", dat_file, e);
            }
        }
    } else {
        // Extract all DAT files
        println!("Extracting sounds from all available DAT files...");
        match extract_siriel_sounds() {
            Ok(_) => println!("Sound extraction completed successfully!"),
            Err(e) => eprintln!("Error during extraction: {}", e),
        }
    }
    
    println!();
    println!("Note: Extracted WAV files will be in assets/audio/extracted/");
    println!("You can convert them to OGG using: ffmpeg -i input.wav output.ogg");
}

fn print_help() {
    println!("Siriel Sound Extractor");
    println!("=====================");
    println!();
    println!("Usage:");
    println!("  extract_sounds                    - Extract all DAT files");
    println!("  extract_sounds <dat_file>         - Extract specific DAT file");
    println!("  extract_sounds --help             - Show this help");
    println!();
    println!("Examples:");
    println!("  extract_sounds");
    println!("  extract_sounds ../siriel-3.5-dos/BIN/MAIN.DAT");
    println!();
    println!("The extractor will:");
    println!("  1. Read DAT files and decrypt them using the original algorithm");
    println!("  2. Extract WAV files to assets/audio/extracted/");
    println!("  3. Organize sounds by their source DAT file");
}