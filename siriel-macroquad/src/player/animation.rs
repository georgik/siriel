// Siriel Macroquad - Character Animation State Machine

#![allow(dead_code)]

use crate::core::anim;
use crate::core::{Animation, LoopMode};
use macroquad::prelude::*;

/// Animation states for player character
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AnimStateType {
    Idle,
    Walking,
    Jumping,
    Falling,
}

/// Direction for directional animations
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

impl Direction {
    /// From velocity vector - simplified to 4 directions
    pub fn from_velocity(vx: f32, vy: f32) -> Self {
        let threshold = 0.1;

        if vx.abs() < threshold && vy < -threshold {
            Self::Up
        } else if vx.abs() < threshold && vy > threshold {
            Self::Down
        } else if vx < -threshold {
            Self::Left
        } else if vx > threshold {
            Self::Right
        } else {
            Self::Down // Default
        }
    }

    /// Check if facing left
    pub fn is_facing_left(self) -> bool {
        matches!(self, Self::Left)
    }

    /// Check if facing right
    pub fn is_facing_right(self) -> bool {
        matches!(self, Self::Right)
    }
}

/// Character animation state machine
#[derive(Clone, Debug)]
pub struct CharacterAnimation {
    /// Current animation state
    state: AnimStateType,
    /// Current direction
    direction: Direction,
    /// Current animation name
    current_anim: String,
    /// Current frame
    frame: i32,
    /// Animation timer
    timer: f32,
    /// Is animation playing
    playing: bool,
}

impl CharacterAnimation {
    /// Create new character animation
    pub fn new() -> Self {
        Self {
            state: AnimStateType::Idle,
            direction: Direction::Down,
            current_anim: anim::IDLE.to_string(),
            frame: 0,
            timer: 0.0,
            playing: true,
        }
    }

    /// Get current animation state type
    pub fn state(&self) -> AnimStateType {
        self.state
    }

    /// Get current direction
    pub fn direction(&self) -> Direction {
        self.direction
    }

    /// Get current animation name
    pub fn current_anim(&self) -> &str {
        &self.current_anim
    }

    /// Get current frame
    pub fn frame(&self) -> i32 {
        self.frame
    }

    /// Check if animation is playing
    pub fn is_playing(&self) -> bool {
        self.playing
    }

    /// Set animation state based on physics
    pub fn update_from_physics(&mut self, vx: f32, vy: f32, on_ground: bool) {
        // Determine new state
        let new_state = if !on_ground {
            if vy < 0.0 {
                AnimStateType::Jumping
            } else {
                AnimStateType::Falling
            }
        } else if vx.abs() > 0.1 {
            AnimStateType::Walking
        } else {
            AnimStateType::Idle
        };

        // Determine direction
        let new_direction = Direction::from_velocity(vx, vy);

        // Update if state or direction changed
        if new_state != self.state || new_direction != self.direction {
            self.state = new_state;
            self.direction = new_direction;
            self.update_animation_name();
        }
    }

    /// Update animation
    pub fn update(&mut self, animations: &[Animation], dt: f32) {
        if !self.playing {
            return;
        }

        // Find current animation
        let anim = match animations.iter().find(|a| a.name == self.current_anim) {
            Some(a) => a,
            None => return,
        };

        if anim.frame_count <= 1 {
            return;
        }

        // Update timer
        self.timer += dt;
        if self.timer >= anim.duration {
            self.timer = 0.0;

            match anim.loop_mode {
                LoopMode::Loop => {
                    self.frame = (self.frame + 1) % anim.frame_count;
                }
                LoopMode::Once => {
                    if self.frame < anim.frame_count - 1 {
                        self.frame += 1;
                    } else {
                        self.playing = false;
                    }
                }
                LoopMode::PingPong => {
                    self.frame = (self.frame + 1) % anim.frame_count;
                }
            }
        }
    }

    /// Update animation name based on state and direction
    fn update_animation_name(&mut self) {
        self.current_anim = match self.state {
            AnimStateType::Idle => anim::IDLE.to_string(),
            AnimStateType::Walking => match self.direction {
                Direction::Left => anim::WALK_LEFT.to_string(),
                Direction::Right => anim::WALK_RIGHT.to_string(),
                Direction::Up => anim::WALK_UP.to_string(),
                Direction::Down => anim::WALK_LEFT.to_string(), // Use walk_left for down (side view)
            },
            AnimStateType::Jumping => match self.direction {
                Direction::Up => anim::JUMP_UP.to_string(),
                Direction::Left => anim::JUMP_LEFT.to_string(),
                Direction::Right => anim::JUMP_RIGHT.to_string(),
                Direction::Down => anim::JUMP_UP.to_string(),
            },
            AnimStateType::Falling => anim::PARACHUTE.to_string(),
        };

        // Reset animation state
        self.frame = 0;
        self.timer = 0.0;
        self.playing = true;
    }

    /// Force set animation (for special cases)
    pub fn set_animation(&mut self, anim_name: &str) {
        if self.current_anim != anim_name {
            self.current_anim = anim_name.to_string();
            self.frame = 0;
            self.timer = 0.0;
            self.playing = true;
        }
    }
}

impl Default for CharacterAnimation {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_direction_from_velocity() {
        assert_eq!(Direction::from_velocity(0.0, -1.0), Direction::Up);
        assert_eq!(Direction::from_velocity(0.0, 1.0), Direction::Down);
        assert_eq!(Direction::from_velocity(-1.0, 0.0), Direction::Left);
        assert_eq!(Direction::from_velocity(1.0, 0.0), Direction::Right);
    }

    #[test]
    fn test_character_animation_creation() {
        let anim = CharacterAnimation::new();
        assert_eq!(anim.state(), AnimStateType::Idle);
        assert_eq!(anim.direction(), Direction::Down);
        assert_eq!(anim.current_anim(), anim::IDLE);
    }

    #[test]
    fn test_animation_update_from_physics() {
        let mut anim = CharacterAnimation::new();

        // Walking right
        anim.update_from_physics(1.0, 0.0, true);
        assert_eq!(anim.state(), AnimStateType::Walking);
        assert_eq!(anim.direction(), Direction::Right);
        assert_eq!(anim.current_anim(), anim::WALK_RIGHT);

        // Jumping
        anim.update_from_physics(0.0, -1.0, false);
        assert_eq!(anim.state(), AnimStateType::Jumping);
        assert_eq!(anim.direction(), Direction::Up);
    }
}
