// Convert working 8-bit 11025Hz to 16-bit 11025Hz for Macroquad compatibility
use std::fs::File;
use std::io::Write;

fn convert_8bit_to_16bit(path: &str, samples: &[u8], sample_rate: u32) -> std::io::Result<()> {
    let mut wav = Vec::new();

    // Convert 8-bit unsigned (128 = center) to 16-bit signed
    let samples_16: Vec<i16> = samples.iter().map(|&b| (b as i16 - 128) * 256).collect();

    // RIFF header
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + samples_16.len() as u32 * 2).to_le_bytes());
    wav.extend_from_slice(b"WAVE");

    // fmt chunk - 16-bit PCM
    wav.extend_from_slice(b"fmt ");
    wav.extend_from_slice(&16u32.to_le_bytes());
    wav.extend_from_slice(&1u16.to_le_bytes()); // PCM
    wav.extend_from_slice(&1u16.to_le_bytes()); // mono
    wav.extend_from_slice(&sample_rate.to_le_bytes());
    wav.extend_from_slice(&(sample_rate * 2).to_le_bytes()); // byte rate
    wav.extend_from_slice(&2u16.to_le_bytes()); // block align
    wav.extend_from_slice(&16u16.to_le_bytes()); // 16-bit

    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&(samples_16.len() as u32 * 2).to_le_bytes());

    // Write 16-bit samples
    for sample in samples_16 {
        wav.extend_from_slice(&sample.to_le_bytes());
    }

    let mut file = File::create(path)?;
    file.write_all(&wav)?;
    Ok(())
}

#[cfg(not(target_arch = "wasm32"))]
fn main() -> std::io::Result<()> {
    let working = "assets/audio/ZINC_signed2unsigned_11025Hz.wav";
    let output =
        "assets/audio/ZINC.wav";

    // Read working WAV and extract PCM data
    let data = std::fs::read(working)?;

    // Skip WAV header (44 bytes) to get raw PCM
    let pcm_data = &data[44..];

    // Convert to 16-bit at same 11025 Hz
    convert_8bit_to_16bit(output, pcm_data, 11025)?;

    println!("Converted to 16-bit 11025Hz: {}", output);
    println!("Test: afplay {}", output);

    Ok(())
}

#[cfg(target_arch = "wasm32")]
fn main() {
    panic!("audio_test is a native-only tool and cannot run on wasm");
}
