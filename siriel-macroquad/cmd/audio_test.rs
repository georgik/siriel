// Convert Z*.dat raw 8-bit audio to 16-bit WAV/OGG for Macroquad
// Usage: cargo run --bin audio_test --features audio-tools <input.dat> [output.wav|output.ogg]
//        cargo run --bin audio_test --features audio-tools --all-wav
//        cargo run --bin audio_test --features audio-tools --all-ogg

use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};

fn convert_raw_to_wav(
    samples: &[i16],
    output_path: &Path,
    sample_rate: u32,
) -> std::io::Result<()> {
    let mut wav = Vec::new();

    // RIFF header
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + samples.len() as u32 * 2).to_le_bytes());
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
    wav.extend_from_slice(&(samples.len() as u32 * 2).to_le_bytes());

    // Write 16-bit samples
    for sample in samples {
        wav.extend_from_slice(&sample.to_le_bytes());
    }

    let mut file = File::create(output_path)?;
    file.write_all(&wav)?;
    Ok(())
}

#[cfg(feature = "audio-tools")]
fn convert_raw_to_ogg(
    samples: &[i16],
    output_path: &Path,
    sample_rate: u32,
) -> std::io::Result<()> {
    use std::num::NonZeroU8;
    use std::num::NonZeroU32;
    use vorbis_rs::VorbisEncoderBuilder;

    // Convert i16 to f32 samples for Vorbis encoder (planar format)
    let samples_f32: Vec<f32> = samples.iter().map(|&s| s as f32 / 32768.0).collect();

    let mut output_ogg = Vec::new();

    // Create encoder with default quality
    let mut encoder = VorbisEncoderBuilder::new(
        NonZeroU32::new(sample_rate as u32).unwrap(),
        NonZeroU8::new(1).unwrap(), // mono
        &mut output_ogg,
    )
    .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, format!("{:?}", e)))?
    .build()
    .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, format!("{:?}", e)))?;

    // Encode in chunks of 1024 samples (optimal for Vorbis)
    let chunk_size = 1024;
    for chunk in samples_f32.chunks(chunk_size) {
        // Prepare planar format (Vec of Vecs, one per channel)
        let planar: Vec<Vec<f32>> = vec![chunk.to_vec()];
        encoder
            .encode_audio_block(&planar)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, format!("{:?}", e)))?;
    }

    // Flush remaining data
    encoder
        .finish()
        .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, format!("{:?}", e)))?;

    let mut file = File::create(output_path)?;
    file.write_all(&output_ogg)?;
    Ok(())
}

#[cfg(feature = "audio-tools")]
fn convert_raw(
    input_path: &Path,
    output_path: &Path,
    sample_rate: u32,
    format: &str,
) -> std::io::Result<()> {
    // Read raw 8-bit signed PCM data (original DOS format)
    let data = fs::read(input_path)?;

    // Convert signed 8-bit to signed 16-bit with volume reduction (75%)
    // Input: -128 to +127 (stored as u8 with two's complement)
    // Scale: 256 * 0.75 = 192 to prevent clipping
    let samples_16: Vec<i16> = data.iter().map(|&b| (b as i8 as i16) * 192).collect();

    match format {
        "wav" => convert_raw_to_wav(&samples_16, output_path, sample_rate),
        "ogg" => convert_raw_to_ogg(&samples_16, output_path, sample_rate),
        _ => Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "Unknown format",
        )),
    }
}

#[cfg(not(feature = "audio-tools"))]
fn convert_raw(
    input_path: &Path,
    output_path: &Path,
    sample_rate: u32,
    format: &str,
) -> std::io::Result<()> {
    if format == "ogg" {
        return Err(std::io::Error::new(
            std::io::ErrorKind::Unsupported,
            "OGG encoding requires --features audio-tools",
        ));
    }
    // Read raw 8-bit signed PCM data
    let data = fs::read(input_path)?;
    let samples_16: Vec<i16> = data.iter().map(|&b| (b as i8 as i16) * 192).collect();
    convert_raw_to_wav(&samples_16, output_path, sample_rate)
}

#[cfg(not(target_arch = "wasm32"))]
fn main() -> std::io::Result<()> {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage:");
        eprintln!(
            "  cargo run --bin audio_test --features audio-tools <input.dat> [output.wav|output.ogg]"
        );
        eprintln!("  cargo run --bin audio_test --features audio-tools --all-wav");
        eprintln!("  cargo run --bin audio_test --features audio-tools --all-ogg");
        std::process::exit(1);
    }

    let source_dir = Path::new("../siriel-modern/data");
    let output_dir = Path::new("assets/audio");
    fs::create_dir_all(output_dir)?;

    let dat_files = [
        "ZASTALA.dat",
        "ZCREDITS.dat",
        "ZDOINK.dat",
        "ZDUNE.dat",
        "ZFEELGO.dat",
        "ZINC.dat",
        "ZKUK.dat",
        "ZLOGTUNE.dat",
        "ZLOONEY.dat",
        "ZNAEC.dat",
        "ZPARA.dat",
        "ZPOP.dat",
        "ZRAD.dat",
        "ZROCK.dat",
        "ZSEEREAL.dat",
        "ZSCHUB.dat",
        "ZTUK.dat",
    ];

    match args[1].as_str() {
        "--all-wav" => {
            println!("Converting all Z*.dat files to WAV...");
            for filename in dat_files {
                let input_path = source_dir.join(filename);
                let name_base = filename.strip_suffix(".dat").unwrap_or(filename);
                let output_path = output_dir.join(format!("{}.wav", name_base));

                match convert_raw(&input_path, &output_path, 11025, "wav") {
                    Ok(_) => println!("  ✓ {} → {}.wav", filename, name_base),
                    Err(e) => eprintln!("  ✗ {}: {}", filename, e),
                }
            }
        }
        "--all-ogg" => {
            println!("Converting all Z*.dat files to OGG...");
            for filename in dat_files {
                let input_path = source_dir.join(filename);
                let name_base = filename.strip_suffix(".dat").unwrap_or(filename);
                let output_path = output_dir.join(format!("{}.ogg", name_base));

                match convert_raw(&input_path, &output_path, 11025, "ogg") {
                    Ok(_) => println!("  ✓ {} → {}.ogg", filename, name_base),
                    Err(e) => eprintln!("  ✗ {}: {}", filename, e),
                }
            }
        }
        input => {
            // Single file mode
            let input_path = Path::new(input);
            let output_path = if args.len() >= 3 {
                PathBuf::from(&args[2])
            } else {
                input_path.with_extension("wav")
            };

            let ext = output_path
                .extension()
                .and_then(|e| e.to_str())
                .unwrap_or("wav");

            convert_raw(input_path, &output_path, 11025, ext)?;
            println!(
                "Converted: {} → {}",
                input_path.display(),
                output_path.display()
            );
        }
    }

    println!("\nDone! Files in assets/audio/");
    Ok(())
}

#[cfg(target_arch = "wasm32")]
fn main() {
    panic!("audio_test is a native-only tool and cannot run on wasm");
}
