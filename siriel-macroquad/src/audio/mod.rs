// Siriel Macroquad - Audio System

#![allow(dead_code)]

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

/// Stub sound handle (placeholder for actual Macroquad Sound type)
#[derive(Debug, Clone)]
pub struct SoundHandle;

/// Sound manager
pub struct SoundManager {
    sounds: HashMap<SoundType, bool>,
    music: HashMap<MusicTrack, bool>,
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

    /// Load sound from file (stub for now - returns empty sound)
    pub async fn load_sound(&mut self, sound_type: SoundType, _path: &str) {
        // Stub: In real implementation, would load from path
        // For now, we just mark it as loaded
        self.sounds.insert(sound_type, true);
    }

    /// Load music from file (stub for now)
    pub async fn load_music(&mut self, track: MusicTrack, _path: &str) {
        // Stub: In real implementation, would load from path
        self.music.insert(track, true);
    }

    /// Play sound effect
    pub fn play(&self, sound_type: SoundType) {
        // Stub: In real implementation, would play the sound
        let _ = sound_type;
    }

    /// Play music track
    pub fn play_music(&mut self, track: MusicTrack) {
        // Stub: In real implementation, would play the music
        if self.current_music != Some(track.clone()) {
            self.current_music = Some(track);
        }
    }

    /// Stop current music
    pub fn stop_music(&mut self) {
        if let Some(_) = self.current_music {
            // In real implementation, would stop the sound
            self.current_music = None;
        }
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
}

impl Default for SoundManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_manager_creation() {
        let manager = SoundManager::new();
        assert_eq!(manager.sfx_volume(), 0.7);
        assert_eq!(manager.music_volume(), 0.5);
        assert!(manager.current_music().is_none());
    }

    #[test]
    fn test_set_sfx_volume() {
        let mut manager = SoundManager::new();
        manager.set_sfx_volume(0.5);
        assert_eq!(manager.sfx_volume(), 0.5);
    }

    #[test]
    fn test_set_music_volume() {
        let mut manager = SoundManager::new();
        manager.set_music_volume(0.3);
        assert_eq!(manager.music_volume(), 0.3);
    }

    #[test]
    fn test_volume_clamping() {
        let mut manager = SoundManager::new();
        manager.set_sfx_volume(1.5);
        assert_eq!(manager.sfx_volume(), 1.0);

        manager.set_sfx_volume(-0.5);
        assert_eq!(manager.sfx_volume(), 0.0);
    }

    #[test]
    fn test_play_does_not_crash() {
        let manager = SoundManager::new();
        // Should not crash even without loaded sounds
        manager.play(SoundType::Jump);
    }

    #[test]
    fn test_play_music_does_not_crash() {
        let mut manager = SoundManager::new();
        // Should not crash even without loaded music
        manager.play_music(MusicTrack::Theme);
    }
}
