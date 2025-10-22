use bevy::audio::{PlaybackMode, PlaybackSettings, Volume};
use bevy::prelude::*;
use std::collections::HashMap;

/// Audio resources and systems for Siriel
///
/// This module handles:
/// - Loading sound effects and music from OGG files
/// - Playing sounds based on game events
/// - Background music management
/// - Audio settings and volume control

/// Resource to hold all loaded audio assets
#[derive(Resource)]
pub struct AudioAssets {
    pub sound_effects: HashMap<String, Handle<AudioSource>>,
    pub music_tracks: HashMap<String, Handle<AudioSource>>,
}

/// Component to mark entities that should play sounds
#[derive(Component)]
pub struct SoundEmitter {
    pub sound_name: String,
}

/// Events for triggering sound playback
#[derive(Event, Message)]
pub enum SoundEvent {
    PlayEffect(String),
    PlayMusic(String),
    StopMusic,
}

/// Resource for audio settings
#[derive(Resource)]
pub struct AudioSettings {
    pub master_volume: f32,
    pub effects_volume: f32,
    pub music_volume: f32,
    pub current_music: Option<String>,
}

impl Default for AudioSettings {
    fn default() -> Self {
        Self {
            master_volume: 0.7,
            effects_volume: 0.8,
            music_volume: 0.6,
            current_music: None,
        }
    }
}

/// System to load all audio assets at startup
pub fn setup_audio(mut commands: Commands, asset_server: Res<AssetServer>) {
    let mut sound_effects = HashMap::new();
    let mut music_tracks = HashMap::new();

    // Load sound effects from the extracted/converted files
    let sound_names = [
        "zexplo", // explosion
        "ztuk",   // hit/thud
        "zkuk",   // pick/click
        "zlopta", // ball/sphere sound
        "zmucha", // fly sound
        "zfire",  // fire sound
        "zrum",   // rumble
        "zdrak",  // dragon sound
    ];

    for sound_name in sound_names.iter() {
        let handle: Handle<AudioSource> =
            asset_server.load(format!("audio/sounds/{}.ogg", sound_name));
        sound_effects.insert(sound_name.to_string(), handle);
    }

    // Load music tracks
    let music_names = ["m1", "m2", "m3", "m4", "m5"];

    for music_name in music_names.iter() {
        let handle: Handle<AudioSource> =
            asset_server.load(format!("audio/music/{}.ogg", music_name));
        music_tracks.insert(music_name.to_string(), handle);
    }

    commands.insert_resource(AudioAssets {
        sound_effects,
        music_tracks,
    });

    commands.insert_resource(AudioSettings::default());

    info!(
        "Audio system initialized with {} sound effects and {} music tracks",
        sound_names.len(),
        music_names.len()
    );
}

/// System to handle sound events
pub fn handle_sound_events(
    mut commands: Commands,
    mut sound_events: MessageReader<SoundEvent>,
    audio_assets: Res<AudioAssets>,
    audio_settings: Res<AudioSettings>,
) {
    for event in sound_events.read() {
        match event {
            SoundEvent::PlayEffect(sound_name) => {
                if let Some(handle) = audio_assets.sound_effects.get(sound_name) {
                    let volume = audio_settings.master_volume * audio_settings.effects_volume;
                    commands.spawn((
                        AudioPlayer::new(handle.clone()),
                        PlaybackSettings {
                            mode: PlaybackMode::Despawn,
                            volume: Volume::Linear(volume),
                            ..Default::default()
                        },
                    ));
                    debug!("Playing sound effect: {}", sound_name);
                }
            }
            SoundEvent::PlayMusic(music_name) => {
                if let Some(handle) = audio_assets.music_tracks.get(music_name) {
                    let volume = audio_settings.master_volume * audio_settings.music_volume;
                    commands.spawn((
                        AudioPlayer::new(handle.clone()),
                        PlaybackSettings {
                            mode: PlaybackMode::Despawn, // Play once, matching original engine behavior
                            volume: Volume::Linear(volume),
                            ..Default::default()
                        },
                    ));
                    info!("Playing music track: {}", music_name);
                }
            }
            SoundEvent::StopMusic => {
                // Note: In a more sophisticated system, we'd track music entities to stop them
                info!("Music stop requested (not yet implemented)");
            }
        }
    }
}

/// Plugin to add audio functionality
pub struct SirielAudioPlugin;

impl Plugin for SirielAudioPlugin {
    fn build(&self, app: &mut App) {
        app.add_message::<SoundEvent>()
            .add_systems(Startup, setup_audio)
            .add_systems(Update, handle_sound_events);
    }
}

/// Helper functions to trigger sounds from game systems
pub fn play_sound_effect(sound_events: &mut MessageWriter<SoundEvent>, sound_name: &str) {
    sound_events.write(SoundEvent::PlayEffect(sound_name.to_string()));
}

pub fn play_music(sound_events: &mut MessageWriter<SoundEvent>, music_name: &str) {
    sound_events.write(SoundEvent::PlayMusic(music_name.to_string()));
}

/// Map game events to sounds - this matches the original game's audio cues
pub mod sound_mappings {
    /// Sound effects mapped to game events
    pub const EXPLOSION: &str = "zexplo";
    pub const HIT: &str = "ztuk";
    pub const PICKUP: &str = "zkuk";
    pub const BALL: &str = "zlopta";
    pub const ENEMY_MOVE: &str = "zmucha";
    pub const FIRE: &str = "zfire";
    pub const RUMBLE: &str = "zrum";
    pub const DRAGON: &str = "zdrak";

    /// Background music tracks
    pub const MENU_MUSIC: &str = "m1";
    pub const LEVEL_MUSIC: &str = "m2";
    pub const BOSS_MUSIC: &str = "m3";
    pub const VICTORY_MUSIC: &str = "m4";
    pub const GAME_OVER_MUSIC: &str = "m5";
}
