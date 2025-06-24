use bevy::prelude::*;

/// Player character (Siriel) component
#[derive(Component)]
pub struct Player {
    pub lives: u8,
    pub score: u32,
    pub on_ground: bool,
    pub jump_speed: f32,
    pub move_speed: f32,
    pub state: PlayerState,
    pub direction: PlayerDirection,
}

/// Player animation state
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum PlayerState {
    Idle,
    Walking,
    Jumping,
    Falling,
    Parachuting,
}

/// Player facing direction
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum PlayerDirection {
    Down,
    Left,
    Right,
    Up,
}

/// Player animation component that tracks which sprite to use
#[derive(Component)]
pub struct PlayerAnimation {
    pub current_frame: usize,
    pub frame_timer: f32,
    pub frame_duration: f32,
}

/// Physics component for entities affected by gravity
#[derive(Component)]
pub struct Physics {
    pub velocity: Vec2,
    pub on_ground: bool,
    pub gravity: f32,
    pub max_fall_speed: f32,
}

/// Solid tile component for collision detection
#[derive(Component)]
pub struct SolidTile;

/// Background tile component (non-collidable)
#[derive(Component)]
pub struct BackgroundTile;

/// Collectible items component
#[derive(Component)]
pub struct Collectible {
    pub value: u32,
    pub collected: bool,
}

/// Exit/Door component
#[derive(Component)]
pub struct Exit {
    pub requires_all_collected: bool,
    pub next_level: Option<String>,
}

/// Hazard component (spikes, enemies, etc.)
#[derive(Component)]
pub struct Hazard {
    pub damage: u8,
}

/// Moving platform component
#[derive(Component)]
pub struct MovingPlatform {
    pub start_pos: Vec2,
    pub end_pos: Vec2,
    pub speed: f32,
    pub direction: i8, // 1 or -1
}

/// Component for sprite animation indices
#[derive(Component)]
pub struct AnimationIndices {
    pub first: usize,
    pub last: usize,
}

/// Component for sprite animation timer
#[derive(Component, Deref, DerefMut)]
pub struct AnimationTimer(pub Timer);

/// Game state resource
#[derive(Resource)]
pub struct GameState {
    pub score: u32,
    pub lives: u8,
    pub level: u32,
    pub collectibles_remaining: u32,
    pub game_over: bool,
    pub level_complete: bool,
}

impl Default for GameState {
    fn default() -> Self {
        Self {
            score: 0,
            lives: 3,
            level: 1,
            collectibles_remaining: 0,
            game_over: false,
            level_complete: false,
        }
    }
}

/// Camera follow component
#[derive(Component)]
pub struct CameraTarget;

/// Tile collision types from original game
#[derive(Component)]
pub struct TileType {
    pub tile_id: u32,
    pub solid: bool,
    pub deadly: bool,
}
