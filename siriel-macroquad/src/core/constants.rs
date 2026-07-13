// Siriel Macroquad - Core Constants

#![allow(dead_code)]

// Screen dimensions
pub const SCREEN_WIDTH: i32 = 1280;
pub const SCREEN_HEIGHT: i32 = 960;

// Game area (actual play field)
pub const GAME_WIDTH: i32 = 640;
pub const GAME_HEIGHT: i32 = 480;

// Tile/sprite sizes (all 16px - original DOS scale)
pub const TILE_SIZE: i32 = 16;
pub const SPRITE_SIZE: i32 = 16;

// Physics constants (from original DOS)
pub const GRAVITY: f32 = 0.5;
pub const MOVE_SPEED: f32 = 1.0;
pub const JUMP_FORCE: f32 = -6.0;

// Frame rate
pub const TARGET_FPS: i32 = 60;

// Map dimensions
pub const MAP_WIDTH: usize = 42;
pub const MAP_HEIGHT: usize = 26;
