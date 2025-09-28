use std::fs::File;
use std::io::{Read, Write, Seek, SeekFrom};
use std::collections::HashMap;

/// DAT file resource entry
#[derive(Debug, Clone)]
pub struct DATResource {
    pub key: [u8; 8],
    pub start: u64,
    pub size: u64,
}

/// DAT file decoder - implements the same logic as the original Pascal BLOCKX.PAS
pub struct DATExtractor {
    file: File,
    resources: HashMap<String, DATResource>,
}

impl DATExtractor {
    /// Open a DAT file and read its resource table
    pub fn new(file_path: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let mut file = File::open(file_path)?;
        let mut resources = HashMap::new();
        
        // Check if it's a valid DAT file (first two bytes should be special)
        let mut header = [0u8; 2];
        file.read_exact(&mut header)?;
        
        if header[1] != 0 {
            return Err("Invalid DAT file format".into());
        }
        
        file.seek(SeekFrom::Start(0))?;
        
        // Read number of sounds/resources
        let mut num_sounds_bytes = [0u8; 2];
        file.read_exact(&mut num_sounds_bytes)?;
        let num_sounds = u16::from_le_bytes(num_sounds_bytes);
        
        println!("Found {} resources in DAT file", num_sounds);
        
        // Read resource headers
        for i in 0..num_sounds {
            let mut key = [0u8; 8];
            let mut start_bytes = [0u8; 4];
            let mut size_bytes = [0u8; 4];
            
            file.read_exact(&mut key)?;
            file.read_exact(&mut start_bytes)?;
            file.read_exact(&mut size_bytes)?;
            
            let start = u32::from_le_bytes(start_bytes) as u64;
            let size = u32::from_le_bytes(size_bytes) as u64;
            
            // Convert key to string (null-terminated)
            let key_str = String::from_utf8_lossy(&key)
                .trim_end_matches('\0')
                .to_string();
            
            if !key_str.is_empty() {
                let resource = DATResource {
                    key,
                    start,
                    size,
                };
                
                resources.insert(key_str.clone(), resource);
                println!("Resource {}: '{}' at {} (size: {})", i, key_str, start, size);
            }
        }
        
        Ok(DATExtractor { file, resources })
    }
    
    /// Extract a specific resource by name
    pub fn extract_resource(&mut self, resource_name: &str, output_path: &str) -> Result<(), Box<dyn std::error::Error>> {
        let resource = self.resources.get(resource_name)
            .ok_or_else(|| format!("Resource '{}' not found", resource_name))?;
        
        // Seek to resource start
        self.file.seek(SeekFrom::Start(resource.start))?;
        
        // Read and decrypt data
        let mut encrypted_data = vec![0u8; resource.size as usize];
        self.file.read_exact(&mut encrypted_data)?;
        
        // Decrypt using the original algorithm
        let decrypted_data = self.decrypt_data(&encrypted_data);
        
        // For debugging: save raw decrypted data with .dat extension to check text files
        let raw_output_path = output_path.replace(".wav", ".dat");
        let mut raw_file = File::create(&raw_output_path)?;
        raw_file.write_all(&decrypted_data)?;
        
        // Create WAV file with header (8-bit mono PCM at 22050 Hz, matching original game)
        let wav_data = self.create_wav_file(&decrypted_data, 22050, 1, 8);
        
        // Write to output file
        let mut output_file = File::create(output_path)?;
        output_file.write_all(&wav_data)?;
        
        println!("Extracted '{}' to '{}'", resource_name, output_path);
        Ok(())
    }
    
    /// Extract all resources from the DAT file
    pub fn extract_all(&mut self, output_dir: &str) -> Result<(), Box<dyn std::error::Error>> {
        std::fs::create_dir_all(output_dir)?;
        
        for (name, _) in self.resources.clone() {
            let output_path = format!("{}/{}.wav", output_dir, name);
            if let Err(e) = self.extract_resource(&name, &output_path) {
                eprintln!("Failed to extract '{}': {}", name, e);
            }
        }
        
        Ok(())
    }
    
    /// List all available resources
    pub fn list_resources(&self) {
        println!("Available resources:");
        for (name, resource) in &self.resources {
            println!("  '{}' - {} bytes at offset {}", name, resource.size, resource.start);
        }
    }
    
    /// Decrypt data using the original koder algorithm
    /// Based on the Pascal KODER.PAS implementation
    fn decrypt_data(&self, encrypted_data: &[u8]) -> Vec<u8> {
        let mut decrypted = encrypted_data.to_vec();
        
        // Apply method 1 decryption (+2) to all non-zero bytes
        // This matches the pattern in LOAD235.PAS line 1987
        for byte in decrypted.iter_mut() {
            if *byte != 0 {
                *byte = self.dekoduj(1, *byte);
            }
        }
        
        decrypted
    }
    
    /// Implement the dekoduj function from KODER.PAS
    fn dekoduj(&self, method: u16, mut byte: u8) -> u8 {
        match method {
            1 => {
                // bt := bt + 2
                byte = byte.wrapping_add(2);
            },
            2 => {
                // Bitwise NOT operation
                byte = !byte;
            },
            3 => {
                // bt := bt + 74
                byte = byte.wrapping_add(74);
            },
            _ => {
                // Default case
            }
        }
        byte
    }
    
    /// Generate WAV header and combine with raw PCM data
    fn create_wav_file(&self, pcm_data: &[u8], sample_rate: u32, channels: u16, bits_per_sample: u16) -> Vec<u8> {
        let data_size = pcm_data.len() as u32;
        let mut wav_data = Vec::with_capacity(44 + pcm_data.len());
        
        // RIFF header
        wav_data.extend_from_slice(b"RIFF");
        wav_data.extend_from_slice(&(36 + data_size).to_le_bytes());
        wav_data.extend_from_slice(b"WAVE");
        
        // fmt chunk
        wav_data.extend_from_slice(b"fmt ");
        wav_data.extend_from_slice(&16u32.to_le_bytes()); // chunk size
        wav_data.extend_from_slice(&1u16.to_le_bytes()); // audio format (PCM)
        wav_data.extend_from_slice(&channels.to_le_bytes());
        wav_data.extend_from_slice(&sample_rate.to_le_bytes());
        
        let byte_rate = sample_rate * channels as u32 * bits_per_sample as u32 / 8;
        let block_align = channels * bits_per_sample / 8;
        
        wav_data.extend_from_slice(&byte_rate.to_le_bytes());
        wav_data.extend_from_slice(&block_align.to_le_bytes());
        wav_data.extend_from_slice(&bits_per_sample.to_le_bytes());
        
        // data chunk
        wav_data.extend_from_slice(b"data");
        wav_data.extend_from_slice(&data_size.to_le_bytes());
        
        // Add the actual audio data
        wav_data.extend_from_slice(pcm_data);
        
        wav_data
    }
    
    /// Check if the extracted file looks like a valid WAV file
    pub fn is_wav_file(file_path: &str) -> Result<bool, Box<dyn std::error::Error>> {
        let mut file = File::open(file_path)?;
        let mut header = [0u8; 4];
        file.read_exact(&mut header)?;
        
        // Check for "RIFF" header
        Ok(header == b"RIFF"[..])
    }
}

/// Main function to extract all sounds from DAT files
pub fn extract_siriel_sounds() -> Result<(), Box<dyn std::error::Error>> {
    let dat_files = [
        "../siriel-3.5-dos/BIN/MAIN.DAT",
        "../siriel-3.5-dos/BIN/GBALL.DAT",
        "../siriel-3.5-dos/BIN/CAULDRON.DAT",
        "../siriel-3.5-dos/BIN/WAY.DAT",
    ];
    
    std::fs::create_dir_all("assets/audio/extracted")?;
    
    for dat_file in &dat_files {
        println!("\n=== Processing {} ===", dat_file);
        
        if let Ok(mut extractor) = DATExtractor::new(dat_file) {
            extractor.list_resources();
            
            let output_dir = format!("assets/audio/extracted/{}", 
                std::path::Path::new(dat_file)
                    .file_stem()
                    .unwrap()
                    .to_string_lossy());
            
            if let Err(e) = extractor.extract_all(&output_dir) {
                eprintln!("Failed to extract from {}: {}", dat_file, e);
            }
        } else {
            eprintln!("Failed to open DAT file: {}", dat_file);
        }
    }
    
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_dekoduj() {
        let extractor = DATExtractor {
            file: File::open("/dev/null").unwrap(), // Dummy file for testing
            resources: HashMap::new(),
        };
        
        // Test method 1: +2
        assert_eq!(extractor.dekoduj(1, 10), 12);
        assert_eq!(extractor.dekoduj(1, 254), 0); // Test overflow
        
        // Test method 2: NOT
        assert_eq!(extractor.dekoduj(2, 0), 255);
        assert_eq!(extractor.dekoduj(2, 255), 0);
        
        // Test method 3: +74
        assert_eq!(extractor.dekoduj(3, 10), 84);
        assert_eq!(extractor.dekoduj(3, 200), 18); // Test overflow
    }
}