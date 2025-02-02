use bevy::prelude::*;

/// Marker component for the player.
#[derive(Component)]
pub struct Player {
    pub lives: u8,
}

/// Marker component for background tiles.
#[derive(Component)]
pub struct Tile;

/// Marker component for collectible items.
#[derive(Component)]
pub struct Collectible;

/// Marker component for the exit object (to be spawned later).
#[derive(Component)]
pub struct Exit;

/// Marker component for hazards (that reduce lives on collision).
#[derive(Component)]
pub struct Hazard;

/// Component for sprite animation indices.
#[derive(Component)]
pub struct AnimationIndices {
    pub first: usize,
    pub last: usize,
}

/// Component for sprite animation timer.
#[derive(Component, Deref, DerefMut)]
pub struct AnimationTimer(pub Timer);

/// (Optional) Resource holding HUD-related state (currently disabled).
#[derive(Resource)]
pub struct HudState {
    pub score: u32,
    pub level_password: Option<String>,
}
