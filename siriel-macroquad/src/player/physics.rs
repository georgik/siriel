// Siriel Macroquad - Player Physics

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

        if is_key_down(KeyCode::Left) {
            self.vx = -MOVE_SPEED;
            self.facing_left = true;
        } else if is_key_down(KeyCode::Right) {
            self.vx = MOVE_SPEED;
            self.facing_left = false;
        }

        // Jump
        if is_key_pressed(KeyCode::Space) && self.on_ground {
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

    /// Update physics with tilemap collision
    pub fn update_with_collision(&mut self, tilemap: &[Vec<i32>], _dt: f32) {
        // Apply gravity
        self.vy += GRAVITY;

        // Horizontal movement with collision
        let new_x = self.x + self.vx;
        if !self.check_collision(new_x, self.y, tilemap) {
            self.x = new_x;
        }

        // Vertical movement with collision
        let new_y = self.y + self.vy;
        if !self.check_collision(self.x, new_y, tilemap) {
            self.y = new_y;
            // Check if we're on ground
            self.on_ground = self.check_ground(self.y, tilemap);
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

    /// Check if position collides with solid tile
    fn check_collision(&self, x: f32, y: f32, tilemap: &[Vec<i32>]) -> bool {
        // Check all four corners of the player sprite
        let corners = [
            (x, y),               // Top-left
            (x + 15.0, y),        // Top-right
            (x, y + 15.0),        // Bottom-left
            (x + 15.0, y + 15.0), // Bottom-right
        ];

        for (cx, cy) in corners {
            let tile_x = (cx / TILE_SIZE as f32) as usize;
            let tile_y = (cy / TILE_SIZE as f32) as usize;

            if tile_y < tilemap.len() && tile_x < tilemap[tile_y].len() {
                let tile = tilemap[tile_y][tile_x];
                // Tiles 24+ are solid
                if tile >= 24 {
                    return true;
                }
            }
        }
        false
    }

    /// Check if standing on solid ground
    fn check_ground(&self, y: f32, tilemap: &[Vec<i32>]) -> bool {
        let bottom_y = y + 16.0;
        let tile_y = (bottom_y / TILE_SIZE as f32) as usize;

        if tile_y >= tilemap.len() {
            return false;
        }

        // Check center point of player's bottom
        let center_x = (self.x + 8.0) / TILE_SIZE as f32;
        let tile_x = center_x as usize;

        if tile_x < tilemap[tile_y].len() {
            let tile = tilemap[tile_y][tile_x];
            return tile >= 24;
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
