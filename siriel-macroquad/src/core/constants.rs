// Siriel Macroquad - Core Constants

#![allow(dead_code)]

use macroquad::prelude::Color;

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
// rolling=30 frames jump duration, gravity calculated from config
pub const GRAVITY: f32 = 0.5;
pub const MOVE_SPEED: f32 = 2.0; // Original DOS: ~2 pixels per frame
pub const JUMP_FORCE: f32 = -6.0; // Middle value between -4 and -8

// Frame rate
pub const TARGET_FPS: i32 = 60;

// Map dimensions
pub const MAP_WIDTH: usize = 42;
pub const MAP_HEIGHT: usize = 26;

// === UI Colors (unified style) ===
/// Background color for all game modes (neutral gray)
pub const BG_COLOR: Color = Color::new(0.3, 0.3, 0.35, 1.0);

/// Menu background color (lighter gray for menu boxes)
pub const MENU_BG_COLOR: Color = Color::new(0.5, 0.5, 0.55, 1.0);

/// Primary text color (light, readable on gray backgrounds)
pub const TEXT_PRIMARY: Color = Color::new(0.95, 0.95, 0.95, 1.0);

/// Secondary text color (slightly darker)
pub const TEXT_SECONDARY: Color = Color::new(0.8, 0.8, 0.85, 1.0);

/// Accent/highlight color (for selection, UI elements)
pub const ACCENT_COLOR: Color = Color::new(0.4, 0.6, 1.0, 1.0);
