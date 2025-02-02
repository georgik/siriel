use bevy::prelude::*;

/// Marker for the player and its lives.
#[derive(Component)]
pub struct Player {
    pub lives: u8,
}

/// Marker for background tiles.
#[derive(Component)]
pub struct Tile;

/// Marker for collectible items.
#[derive(Component)]
pub struct Collectible;

/// Marker for the exit object (to be spawned later).
#[derive(Component)]
pub struct Exit;

/// Marker for hazards (which reduce lives on collision).
#[derive(Component)]
pub struct Hazard;

/// Component for animated sprites.
/// It tracks the current frame, a timer, and the list of sprite indices that form the animation.
#[derive(Component)]
pub struct Animation {
    pub current_frame: usize,
    pub frame_timer: Timer,
    pub frames: Vec<usize>,
}

/// Resource holding HUD-related state (score, level password, etc.)
pub struct HudState {
    pub score: u32,
    pub level_password: Option<String>,
}
