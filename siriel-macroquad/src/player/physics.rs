// Siriel Macroquad - Player Physics
// Implements pixel-perfect collision matching original Siriel 3.5

use crate::assets::Tileset;
use crate::core::anim;
use crate::core::{GRAVITY, JUMP_FORCE, MOVE_SPEED, TILE_SIZE};
use macroquad::prelude::*;

/// Player physics state
#[derive(Clone, Debug)]
pub struct PhysicsState {
    pub x: f32,
    pub y: f32,
    pub vx: f32,
    pub vy: f32,
    pub on_ground: bool,
    pub facing_left: bool,
}

impl PhysicsState {
    pub fn new(x: f32, y: f32) -> Self {
        Self {
            x,
            y,
            vx: 0.0,
            vy: 0.0,
            on_ground: false,
            facing_left: false,
        }
    }

    /// Handle input and return desired movement
    pub fn handle_input(&mut self) {
        self.vx = 0.0;

        let moving_left = is_key_down(KeyCode::Left) || is_key_down(KeyCode::A);
        let moving_right = is_key_down(KeyCode::Right) || is_key_down(KeyCode::D);

        if moving_left {
            self.vx = -MOVE_SPEED;
            self.facing_left = true;
        } else if moving_right {
            self.vx = MOVE_SPEED;
            self.facing_left = false;
        }

        // Jump (arcade: Up arrow, W, or Space)
        let jump_pressed = is_key_pressed(KeyCode::Up)
            || is_key_pressed(KeyCode::W)
            || is_key_pressed(KeyCode::Space);

        if jump_pressed && self.on_ground {
            self.vy = JUMP_FORCE;
            self.on_ground = false;
        }
    }

    /// Update physics (simple version without collision)
    #[allow(dead_code)]
    pub fn update(&mut self, _dt: f32) {
        // Apply gravity
        self.vy += GRAVITY;

        // Update position
        self.x += self.vx;
        self.y += self.vy;

        // Simple ground check for demo
        if self.y > 400.0 {
            self.y = 400.0;
            self.vy = 0.0;
            self.on_ground = true;
        }
    }

    /// Update physics with tilemap collision using pixel-perfect masks
    pub fn update_with_collision(&mut self, tilemap: &[Vec<i32>], tileset: &Tileset, _dt: f32) {
        // Apply gravity
        self.vy += GRAVITY;

        // Horizontal movement with collision
        let new_x = self.x + self.vx;
        if !self.check_collision(new_x, self.y, tilemap, tileset) {
            self.x = new_x;
        }

        // Vertical movement with collision
        let new_y = self.y + self.vy;
        if !self.check_collision(self.x, new_y, tilemap, tileset) {
            self.y = new_y;
            // Check if we're on ground using asymmetric foot check
            self.on_ground = self.check_ground(new_y, tilemap, tileset);
        } else {
            // Collision occurred
            if self.vy > 0.0 {
                // Landed on ground
                self.on_ground = true;
            }
            self.vy = 0.0;
        }

        // Boundary checks
        self.x = self.x.clamp(0.0, (42 * TILE_SIZE - 16) as f32);
        self.y = self.y.clamp(0.0, (26 * TILE_SIZE - 16) as f32);
    }

    /// Check if position collides with solid pixels
    /// Uses 4 points at ±6 offset from center (matches original smeruj())
    fn check_collision(&self, x: f32, y: f32, tilemap: &[Vec<i32>], tileset: &Tileset) -> bool {
        // 4 points at ±6 from center (matches original smeruj())
        let points = [
            (x - 6.0, y),        // Left
            (x + 6.0, y),        // Right
            (x - 6.0, y + 16.0), // Bottom-left
            (x + 6.0, y + 16.0), // Bottom-right
        ];

        for (px, py) in points {
            let tile_x = (px / TILE_SIZE as f32) as usize;
            let tile_y = (py / TILE_SIZE as f32) as usize;

            if tile_y < tilemap.len() && tile_x < tilemap[tile_y].len() {
                let tile_id = tilemap[tile_y][tile_x] as usize;

                // Skip invalid tiles
                if tile_id >= tileset.collision_masks.len() {
                    continue;
                }

                // Check pixel-level transparency
                let pixel_x = (px as i32 % TILE_SIZE) as usize;
                let pixel_y = (py as i32 % TILE_SIZE) as usize;

                if tileset.is_pixel_solid(tile_id as i32, pixel_x, pixel_y) {
                    return true; // Collision detected
                }
            }
        }
        false // No collision at any point
    }

    /// Check if standing on solid ground using asymmetric foot check
    /// Matches original gravitacia() - checks (x-12, y) and (x+4, y)
    fn check_ground(&self, y: f32, tilemap: &[Vec<i32>], tileset: &Tileset) -> bool {
        // Asymmetric foot check like original gravitacia()
        let feet_points = [
            (self.x - 12.0, y + 16.0), // Left foot
            (self.x + 4.0, y + 16.0),  // Right foot
        ];

        for (px, py) in feet_points {
            let tile_x = (px / TILE_SIZE as f32) as usize;
            let tile_y = (py / TILE_SIZE as f32) as usize;

            if tile_y < tilemap.len() && tile_x < tilemap[tile_y].len() {
                let tile_id = tilemap[tile_y][tile_x] as usize;
                if tile_id < tileset.collision_masks.len() {
                    let pixel_x = (px as i32 % TILE_SIZE) as usize;
                    let pixel_y = (py as i32 % TILE_SIZE) as usize;
                    if tileset.is_pixel_solid(tile_id as i32, pixel_x, pixel_y) {
                        return true; // Standing on solid ground
                    }
                }
            }
        }
        false
    }

    /// Get current position
    pub fn position(&self) -> Vec2 {
        vec2(self.x, self.y)
    }

    /// Get animation name based on state
    pub fn get_animation(&self) -> &str {
        if !self.on_ground {
            if self.vy < 0.0 {
                return anim::JUMP_UP;
            } else {
                return anim::PARACHUTE;
            }
        }

        if self.vx != 0.0 {
            if self.facing_left {
                return anim::WALK_LEFT;
            } else {
                return anim::WALK_RIGHT;
            }
        }

        anim::IDLE
    }
}
