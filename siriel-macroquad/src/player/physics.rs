// Siriel Macroquad - Player Physics
// Implements pixel-perfect collision matching original Siriel 3.5

use crate::assets::Tileset;
use crate::core::anim;
use crate::core::{GRAVITY, JUMP_FORCE, MOVE_SPEED, TARGET_FPS, TILE_SIZE};
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
    // Parachute mechanics
    fall_start_y: f32,
    parachute_active: bool,
    was_on_ground: bool,
}

/// Minimum fall distance to trigger parachute (2 tiles = 32px)
const PARACHUTE_TRIGGER_DISTANCE: f32 = 32.0;
/// Glide speed when parachute is open (slower than normal gravity fall)
const PARACHUTE_GLIDE_SPEED: f32 = 1.5;

impl PhysicsState {
    pub fn new(x: f32, y: f32) -> Self {
        Self {
            x,
            y,
            vx: 0.0,
            vy: 0.0,
            on_ground: false,
            facing_left: false,
            fall_start_y: y,
            parachute_active: false,
            was_on_ground: true,
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

    /// Handle input from virtual touch buttons
    pub fn handle_touch_input(&mut self, left: bool, right: bool, jump: bool) {
        self.vx = 0.0;

        if left {
            self.vx = -MOVE_SPEED;
            self.facing_left = true;
        } else if right {
            self.vx = MOVE_SPEED;
            self.facing_left = false;
        }

        if jump && self.on_ground {
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
    /// Matches original SI35.PAS movement with automatic wall sliding
    /// dt: delta time in seconds (scales movement to be framerate-independent)
    pub fn update_with_collision(&mut self, tilemap: &[Vec<i32>], tileset: &Tileset, dt: f32) {
        // Scale factor: 1.0 at 60 FPS, adjusts for actual framerate
        // Original DOS values are per-frame at 60 FPS
        let time_scale = dt * TARGET_FPS as f32;
        // Track ground state transitions for parachute logic
        if self.was_on_ground && !self.on_ground {
            // Just left ground - start tracking fall
            self.fall_start_y = self.y;
            self.parachute_active = false;
        } else if !self.was_on_ground && self.on_ground {
            // Just landed - reset parachute state
            self.parachute_active = false;
        }
        self.was_on_ground = self.on_ground;

        // Check if should deploy parachute (falling more than 2 tiles)
        if !self.on_ground && self.vy > 0.0 && !self.parachute_active {
            let fall_distance = self.y - self.fall_start_y;
            if fall_distance >= PARACHUTE_TRIGGER_DISTANCE {
                self.parachute_active = true;
            }
        }

        // Apply gravity (or cap at glide speed if parachute active)
        // Scale by time_scale for framerate independence
        let gravity_this_frame = GRAVITY * time_scale;
        if self.parachute_active {
            // Glide mode: cap fall speed
            if self.vy < PARACHUTE_GLIDE_SPEED {
                self.vy += gravity_this_frame;
                if self.vy > PARACHUTE_GLIDE_SPEED {
                    self.vy = PARACHUTE_GLIDE_SPEED;
                }
            }
        } else {
            // Normal gravity
            self.vy += gravity_this_frame;
        }

        // Horizontal movement with collision (scaled by time_scale)
        let horizontal_move = self.vx * time_scale;
        let new_x = self.x + horizontal_move;
        if !self.check_collision(new_x, self.y, tilemap, tileset) {
            self.x = new_x;
        } else {
            // Original auto wall-slide: if blocked, check if opposite shoulder is clear
            // GAME.INC lines 195-196: po3(si.x-5,si.y-12) and po3(si.x+6,si.y-12)
            // Slide amount also scaled
            let slide_amount = 1.0 * time_scale;
            if self.vx > 0.0 {
                // Moving right, blocked - check left shoulder
                if !self.check_shoulder(-5.0, tilemap, tileset) {
                    // Left shoulder clear, slide left
                    self.x -= slide_amount;
                }
            } else if self.vx < 0.0 {
                // Moving left, blocked - check right shoulder
                if !self.check_shoulder(6.0, tilemap, tileset) {
                    // Right shoulder clear, slide right
                    self.x += slide_amount;
                }
            }
        }

        // Vertical movement with collision (scaled by time_scale)
        let vertical_move = self.vy * time_scale;
        let new_y = self.y + vertical_move;
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

    /// Check shoulder point for collision (y-12 offset from position)
    /// Matches original GAME.INC lines 195-196: po3(si.x±5, si.y-12)
    fn check_shoulder(&self, x_offset: f32, tilemap: &[Vec<i32>], tileset: &Tileset) -> bool {
        let px = self.x + x_offset;
        let py = self.y - 12.0;

        let tile_x = (px / TILE_SIZE as f32) as usize;
        let tile_y = (py / TILE_SIZE as f32) as usize;

        if tile_y < tilemap.len() && tile_x < tilemap[tile_y].len() {
            let tile_id = tilemap[tile_y][tile_x] as usize;
            if tile_id < tileset.collision_masks.len() {
                let pixel_x = (px as i32 % TILE_SIZE) as usize;
                let pixel_y = (py as i32 % TILE_SIZE) as usize;
                return tileset.is_pixel_solid(tile_id as i32, pixel_x, pixel_y);
            }
        }
        false
    }

    /// Check if position collides with solid pixels
    /// Uses 4 points matching original smeruj() from SI35.PAS:
    /// - Upper points at y+6 (allows 45° slope climbing)
    /// - Lower points at y+16 (feet level)
    /// - X offset shifted +6 (fixed for sprite alignment)
    fn check_collision(&self, x: f32, y: f32, tilemap: &[Vec<i32>], tileset: &Tileset) -> bool {
        // Fixed X offset +6: x, x+12 | y+6, y+16
        let points = [
            (x, y + 6.0),         // Left-shoulder (6px down from top)
            (x + 12.0, y + 6.0),  // Right-shoulder
            (x, y + 16.0),        // Left-foot
            (x + 12.0, y + 16.0), // Right-foot
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

    /// Check if parachute is currently active
    pub fn parachute_active(&self) -> bool {
        self.parachute_active
    }

    /// Get animation name based on state
    pub fn get_animation(&self) -> &str {
        if !self.on_ground {
            if self.vy < 0.0 {
                return anim::JUMP_UP;
            } else {
                // Falling: use directional walk sprites, parachute drawn separately
                return if self.facing_left {
                    anim::WALK_LEFT
                } else {
                    anim::WALK_RIGHT
                };
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
