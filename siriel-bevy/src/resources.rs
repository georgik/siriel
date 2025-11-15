use bevy::prelude::*;

/// Game state enumeration
#[derive(States, Default, Debug, Clone, PartialEq, Eq, Hash)]
pub enum AppState {
    #[default]
    IntroScreen,
    Menu,
    InGame,
    /// TODO: Implement pause menu
    #[allow(dead_code)]
    Paused,
}

/// Global game state resource
#[derive(Resource, Default)]
pub struct GameState {
    pub score: u32,
    pub lives: i32,
    pub level: u32,
    pub timer: f32,
    /// TODO: Implement pause functionality
    #[allow(dead_code)]
    pub paused: bool,
    #[allow(dead_code)]
    pub player_invulnerable: bool,
    /// TODO: Implement freeze time power-up from original game
    #[allow(dead_code)]
    pub freeze_time: f32,
    #[allow(dead_code)]
    pub god_mode_time: f32,
}

/// Level selection menu resource
#[derive(Resource)]
pub struct LevelMenu {
    pub available_levels: Vec<LevelInfo>,
    pub selected_index: usize,
    pub scroll_offset: usize,
    pub max_visible: usize,
}

#[derive(Clone, Debug)]
pub struct LevelInfo {
    pub name: String,
    pub display_name: String,
    pub file_path: String,
    pub description: Option<String>,
}

impl Default for LevelMenu {
    fn default() -> Self {
        Self {
            available_levels: Vec::new(),
            selected_index: 0,
            scroll_offset: 0,
            max_visible: 20, // How many levels to show at once (increased for 380px height)
        }
    }
}

/// Physics configuration
#[derive(Resource)]
pub struct PhysicsConfig {
    pub gravity: f32,
    /// Stored in config for reference, actual jump force on Physics component
    #[allow(dead_code)]
    pub jump_force: f32,
    #[allow(dead_code)]
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

/// Collision debugging state
#[derive(Resource)]
pub struct CollisionDebug {
    pub enabled: bool,
    pub show_tile_grid: bool,
    pub show_collision_points: bool,
    pub show_tile_boundaries: bool,
    pub show_coordinate_info: bool,
}

impl Default for CollisionDebug {
    fn default() -> Self {
        Self {
            enabled: false,
            show_tile_grid: true,
            show_collision_points: true,
            show_tile_boundaries: true,
            show_coordinate_info: true,
        }
    }
}

/// Texture atlas resource for managing sprites used by runtime systems
#[derive(Resource, Default)]
pub struct SpriteAtlas {
    pub sprite_size: f32,
    pub player_texture: Option<Handle<Image>>,
    pub objects_texture: Option<Handle<Image>>,
    pub tiles_texture: Option<Handle<Image>>,
    pub animations_texture: Option<Handle<Image>>,
    pub loaded: bool,
}
