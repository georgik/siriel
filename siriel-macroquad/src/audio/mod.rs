// Siriel Macroquad - Audio System

use macroquad::audio::{PlaySoundParams, Sound, load_sound, play_sound};
use macroquad::prelude::*;
use std::collections::HashMap;

/// Sound types
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum SoundType {
    Start,  // Level start sound
    Select, // UI selection sound
    Coin,   // Coin pickup
    Health, // Health pickup
    Hurt,   // Player hurt
    Land,   // Landing sound
}

/// Sound manager with real Macroquad audio
pub struct SoundManager {
    sounds: HashMap<SoundType, Option<Sound>>,
}

impl SoundManager {
    pub fn new() -> Self {
        Self {
            sounds: HashMap::new(),
        }
    }

    /// Load sound from file
    pub async fn load_sound(&mut self, sound_type: SoundType, path: &str) {
        match load_sound(path).await {
            Ok(sound) => {
                self.sounds.insert(sound_type.clone(), Some(sound));
                info!("Loaded sound: {:?} from {}", sound_type, path);
            }
            Err(e) => {
                warn!(
                    "Failed to load sound {:?} from {}: {:?}",
                    sound_type, path, e
                );
                self.sounds.insert(sound_type, None);
            }
        }
    }

    /// Play sound effect
    pub fn play(&self, sound_type: SoundType) {
        if let Some(Some(sound)) = self.sounds.get(&sound_type) {
            play_sound(
                sound,
                PlaySoundParams {
                    looped: false,
                    volume: 1.0,
                },
            );
        } else {
            warn!("Sound not loaded: {:?}", sound_type);
        }
    }

    /// Load all game sounds
    pub async fn load_all_sounds(&mut self) {
        info!("=== Loading Sounds ===");

        // Load the level start sound (ZINC.ogg - compressed format)
        self.load_sound(SoundType::Start, "assets/audio/ZINC.ogg")
            .await;

        // TODO: Load other sounds when converted
        // self.load_sound(SoundType::Select, "assets/audio/SELECT.ogg").await;
        // self.load_sound(SoundType::Coin, "assets/audio/COIN.ogg").await;
        // self.load_sound(SoundType::Health, "assets/audio/HEALTH.ogg").await;
        // self.load_sound(SoundType::Hurt, "assets/audio/HURT.ogg").await;
        // self.load_sound(SoundType::Land, "assets/audio/LAND.ogg").await;

        info!("=== Sound Loading Complete ===");
    }
}

impl Default for SoundManager {
    fn default() -> Self {
        Self::new()
    }
}
