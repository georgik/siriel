use bevy::prelude::*;

/// Global game state resource
#[derive(Resource, Default)]
pub struct GameState {
    pub score: u32,
    pub lives: i32,
    pub level: u32,
    pub timer: f32,
    pub paused: bool,
    pub player_invulnerable: bool,
    pub freeze_time: f32,
    pub god_mode_time: f32,
}

/// Physics configuration
#[derive(Resource)]
pub struct PhysicsConfig {
    pub gravity: f32,
    pub jump_force: f32,
    pub max_fall_speed: f32,
    pub ground_friction: f32,
    pub air_friction: f32,
}

impl Default for PhysicsConfig {
    fn default() -> Self {
        Self {
            gravity: 980.0, // pixels per second squared
            jump_force: 400.0,
            max_fall_speed: 600.0,
            ground_friction: 0.8,
            air_friction: 0.95,
        }
    }
}

/// Input state resource
#[derive(Resource, Default)]
pub struct InputState {
    pub move_left: bool,
    pub move_right: bool,
    pub move_up: bool,
    pub move_down: bool,
    pub jump: bool,
    pub jump_pressed: bool,
    pub action: bool,
    pub pause: bool,
    pub menu: bool,
    pub quit: bool,
}

/// Level data resource
#[derive(Resource, Default)]
pub struct LevelData {
    pub width: u32,
    pub height: u32,
    pub tiles: Vec<Vec<u8>>,
    pub spawn_point: (f32, f32),
    pub entities: Vec<EntityData>,
}

/// Entity data for loading from files
#[derive(Clone, Debug)]
pub struct EntityData {
    pub name: String,
    pub x: f32,
    pub y: f32,
    pub behavior_type: u8,
    pub params: [u16; 7],
    pub sprite_id: u16,
    pub room: u8,
    pub take_type: u16,
}

/// Animation frame data
#[derive(Clone, Debug)]
pub struct AnimationFrame {
    pub sprite_id: usize,
    pub duration: f32,
}

/// Texture atlas resource for managing sprites
#[derive(Resource, Default)]
pub struct SpriteAtlas {
    pub textures: Vec<Handle<Image>>,
    pub sprite_size: f32,
    pub player_texture: Option<Handle<Image>>,
    pub objects_texture: Option<Handle<Image>>,
    pub tiles_texture: Option<Handle<Image>>,
    pub animations_texture: Option<Handle<Image>>,
    pub loaded: bool,
}

/// Audio resources
#[derive(Resource, Default)]
pub struct AudioResources {
    pub sound_effects: Vec<Handle<AudioSource>>,
    pub music: Vec<Handle<AudioSource>>,
}

/// Game configuration
#[derive(Resource)]
pub struct GameConfig {
    pub screen_width: f32,
    pub screen_height: f32,
    pub sprite_size: f32,
    pub target_fps: f32,
    pub debug_mode: bool,
}

impl Default for GameConfig {
    fn default() -> Self {
        Self {
            screen_width: 640.0,
            screen_height: 480.0,
            sprite_size: 16.0,
            target_fps: 60.0,
            debug_mode: true,
        }
    }
}
