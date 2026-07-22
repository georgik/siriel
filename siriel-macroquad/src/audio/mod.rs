// Siriel Macroquad - Audio System

use macroquad::audio::{PlaySoundParams, Sound, load_sound, play_sound};
use macroquad::prelude::*;
use std::collections::HashMap;

/// Sound types
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum SoundType {
    Jump,
    Land,
    Coin,
    Health,
    Hurt,
    EnemyHit,
    Explosion,
    Pause,
    Select,
    Complete,
    Start, // Level start sound
}

/// Music tracks
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum MusicTrack {
    Theme,
    Level1,
    Level2,
    Boss,
    Victory,
    GameOver,
}

/// Sound manager with real Macroquad audio
pub struct SoundManager {
    sounds: HashMap<SoundType, Option<Sound>>,
    music: HashMap<MusicTrack, Option<Sound>>,
    sfx_volume: f32,
    music_volume: f32,
    current_music: Option<MusicTrack>,
}

impl SoundManager {
    pub fn new() -> Self {
        Self {
            sounds: HashMap::new(),
            music: HashMap::new(),
            sfx_volume: 0.7,
            music_volume: 0.5,
            current_music: None,
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

    /// Load music from file
    pub async fn load_music(&mut self, track: MusicTrack, path: &str) {
        match load_sound(path).await {
            Ok(sound) => {
                self.music.insert(track.clone(), Some(sound));
                info!("Loaded music: {:?} from {}", track, path);
            }
            Err(e) => {
                warn!("Failed to load music {:?} from {}: {:?}", track, path, e);
                self.music.insert(track, None);
            }
        }
    }

    /// Play sound effect
    pub fn play(&self, sound_type: SoundType) {
        info!("Attempting to play sound: {:?}", sound_type);
        if let Some(Some(sound)) = self.sounds.get(&sound_type) {
            info!(
                "Playing sound: {:?} with volume {}",
                sound_type, self.sfx_volume
            );
            play_sound(
                sound,
                PlaySoundParams {
                    looped: false,
                    volume: self.sfx_volume,
                },
            );
        } else {
            warn!("Sound not loaded: {:?}", sound_type);
        }
    }

    /// Play music track
    pub fn play_music(&mut self, track: MusicTrack) {
        if self.current_music != Some(track.clone()) {
            if let Some(Some(sound)) = self.music.get(&track) {
                play_sound(
                    sound,
                    PlaySoundParams {
                        looped: true,
                        volume: self.music_volume,
                    },
                );
                self.current_music = Some(track);
            }
        }
    }

    /// Stop current music
    pub fn stop_music(&mut self) {
        self.current_music = None;
        // Note: Macroquad doesn't have stop_sound, so we just track state
    }

    /// Set SFX volume
    pub fn set_sfx_volume(&mut self, volume: f32) {
        self.sfx_volume = volume.clamp(0.0, 1.0);
    }

    /// Set music volume
    pub fn set_music_volume(&mut self, volume: f32) {
        self.music_volume = volume.clamp(0.0, 1.0);
    }

    /// Get SFX volume
    pub fn sfx_volume(&self) -> f32 {
        self.sfx_volume
    }

    /// Get music volume
    pub fn music_volume(&self) -> f32 {
        self.music_volume
    }

    /// Get current music track
    pub fn current_music(&self) -> Option<MusicTrack> {
        self.current_music.clone()
    }

    /// Load all game sounds
    pub async fn load_all_sounds(&mut self) {
        info!("=== Loading Sounds ===");

        // Load the level start sound (ZINC.wav - already converted)
        self.load_sound(SoundType::Start, "assets/audio/ZINC.wav")
            .await;

        // TODO: Load other sounds when converted
        // self.load_sound(SoundType::Jump, "assets/audio/JUMP.wav").await;
        // self.load_sound(SoundType::Coin, "assets/audio/COIN.wav").await;

        info!("=== Sound Loading Complete ===");
    }
}

impl Default for SoundManager {
    fn default() -> Self {
        Self::new()
    }
}
