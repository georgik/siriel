// Siriel Macroquad - Character Animation State Machine
// Phase 12: Enhanced animation system

#![allow(dead_code)]

use crate::core::{Animation, LoopMode};
use macroquad::prelude::*;

/// Animation states for player character
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AnimStateType {
    Idle,
    Walking,
    Jumping,
    Falling,
    Landing,
}

/// Direction for directional animations
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
}

impl Direction {
    /// From velocity vector
    pub fn from_velocity(vx: f32, vy: f32) -> Self {
        let threshold = 0.1;

        if vx.abs() < threshold && vy < -threshold {
            Self::Up
        } else if vx.abs() < threshold && vy > threshold {
            Self::Down
        } else if vx < -threshold && vy.abs() < threshold {
            Self::Left
        } else if vx > threshold && vy.abs() < threshold {
            Self::Right
        } else if vx < -threshold && vy < -threshold {
            Self::UpLeft
        } else if vx > threshold && vy < -threshold {
            Self::UpRight
        } else if vx < -threshold && vy > threshold {
            Self::DownLeft
        } else if vx > threshold && vy > threshold {
            Self::DownRight
        } else {
            Self::Down // Default
        }
    }

    /// Check if facing left
    pub fn is_facing_left(self) -> bool {
        matches!(self, Self::Left | Self::UpLeft | Self::DownLeft)
    }

    /// Check if facing right
    pub fn is_facing_right(self) -> bool {
        matches!(self, Self::Right | Self::UpRight | Self::DownRight)
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
    /// Previous state (for transitions)
    prev_state: Option<AnimStateType>,
    /// Transition timer
    transition_timer: f32,
}

impl CharacterAnimation {
    /// Create new character animation
    pub fn new() -> Self {
        Self {
            state: AnimStateType::Idle,
            direction: Direction::Down,
            current_anim: "idle_down".to_string(),
            frame: 0,
            timer: 0.0,
            playing: true,
            prev_state: None,
            transition_timer: 0.0,
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
            self.prev_state = Some(self.state);
            self.state = new_state;
            self.direction = new_direction;
            self.transition_timer = 0.1; // Short transition
            self.update_animation_name();
        }
    }

    /// Update animation
    pub fn update(&mut self, animations: &[Animation], dt: f32) {
        if !self.playing {
            return;
        }

        // Update transition timer
        if self.transition_timer > 0.0 {
            self.transition_timer -= dt;
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
                        // Once animation done, switch to idle
                        if matches!(self.state, AnimStateType::Landing) {
                            self.state = AnimStateType::Idle;
                            self.update_animation_name();
                        }
                        self.playing = false;
                    }
                }
                LoopMode::PingPong => {
                    // TODO: Implement ping-pong
                    self.frame = (self.frame + 1) % anim.frame_count;
                }
            }
        }
    }

    /// Update animation name based on state and direction
    fn update_animation_name(&mut self) {
        self.current_anim = match self.state {
            AnimStateType::Idle => match self.direction {
                Direction::Up => "idle_up",
                Direction::Down => "idle_down",
                Direction::Left | Direction::UpLeft | Direction::DownLeft => "idle_left",
                Direction::Right | Direction::UpRight | Direction::DownRight => "idle_right",
            },
            AnimStateType::Walking => match self.direction {
                Direction::Up => "walk_up",
                Direction::Down => "walk_down",
                Direction::Left | Direction::UpLeft | Direction::DownLeft => "walk_left",
                Direction::Right | Direction::UpRight | Direction::DownRight => "walk_right",
            },
            AnimStateType::Jumping => match self.direction {
                Direction::Up => "jump_up",
                Direction::Left => "jump_left",
                Direction::Right => "jump_right",
                _ => "jump_up",
            },
            AnimStateType::Falling => "parachute",
            AnimStateType::Landing => "landing",
        }
        .to_string();

        // Reset animation state
        self.frame = 0;
        self.timer = 0.0;
        self.playing = true;
    }

    /// Trigger landing animation
    pub fn trigger_landing(&mut self) {
        self.prev_state = Some(self.state);
        self.state = AnimStateType::Landing;
        self.update_animation_name();
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

/// Animation controller with frame timing
#[derive(Clone, Debug)]
pub struct AnimationController {
    /// Frame rate (frames per second)
    frame_rate: f32,
    /// Frame time accumulator
    frame_accum: f32,
}

impl AnimationController {
    /// Create new controller with target FPS
    pub fn new(fps: f32) -> Self {
        Self {
            frame_rate: fps,
            frame_accum: 0.0,
        }
    }

    /// Create controller with default 15 FPS
    pub fn default() -> Self {
        Self::new(15.0)
    }

    /// Update and return true if frame should advance
    pub fn update(&mut self, dt: f32) -> bool {
        self.frame_accum += dt;

        let frame_time = 1.0 / self.frame_rate;

        if self.frame_accum >= frame_time {
            self.frame_accum -= frame_time;
            true
        } else {
            false
        }
    }

    /// Set frame rate
    pub fn set_frame_rate(&mut self, fps: f32) {
        self.frame_rate = fps;
    }

    /// Reset accumulator
    pub fn reset(&mut self) {
        self.frame_accum = 0.0;
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
        assert_eq!(Direction::from_velocity(-0.5, -0.5), Direction::UpLeft);
        assert_eq!(Direction::from_velocity(0.5, -0.5), Direction::UpRight);
        assert_eq!(Direction::from_velocity(-0.5, 0.5), Direction::DownLeft);
        assert_eq!(Direction::from_velocity(0.5, 0.5), Direction::DownRight);
    }

    #[test]
    fn test_character_animation_creation() {
        let anim = CharacterAnimation::new();
        assert_eq!(anim.state(), AnimStateType::Idle);
        assert_eq!(anim.direction(), Direction::Down);
        assert_eq!(anim.current_anim(), "idle_down");
    }

    #[test]
    fn test_animation_update_from_physics() {
        let mut anim = CharacterAnimation::new();

        // Walking right
        anim.update_from_physics(1.0, 0.0, true);
        assert_eq!(anim.state(), AnimStateType::Walking);
        assert_eq!(anim.direction(), Direction::Right);
        assert_eq!(anim.current_anim(), "walk_right");

        // Jumping
        anim.update_from_physics(0.0, -1.0, false);
        assert_eq!(anim.state(), AnimStateType::Jumping);
        assert_eq!(anim.direction(), Direction::Up);
    }

    #[test]
    fn test_animation_controller() {
        let mut controller = AnimationController::new(10.0);

        // 10 FPS = 0.1s per frame
        assert!(!controller.update(0.05)); // Not enough time
        assert!(controller.update(0.05)); // Frame advances
        assert!(!controller.update(0.05)); // Reset
        assert!(controller.update(0.1)); // Exactly one frame time
    }

    #[test]
    fn test_direction_is_facing() {
        assert!(Direction::Left.is_facing_left());
        assert!(Direction::UpLeft.is_facing_left());
        assert!(Direction::DownLeft.is_facing_left());
        assert!(!Direction::Right.is_facing_left());

        assert!(Direction::Right.is_facing_right());
        assert!(Direction::UpRight.is_facing_right());
        assert!(Direction::DownRight.is_facing_right());
        assert!(!Direction::Left.is_facing_right());
    }
}
