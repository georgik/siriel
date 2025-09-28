use bevy::prelude::*;
use serde::{Deserialize, Serialize};

/// Player component - marks the player character entity
#[derive(Component)]
pub struct Player;

/// Position component - world coordinates
#[derive(Component, Clone, Copy, Debug)]
pub struct Position {
    pub x: f32,
    pub y: f32,
}

impl Default for Position {
    fn default() -> Self {
        Self { x: 0.0, y: 0.0 }
    }
}

/// Velocity component - movement speed per frame
#[derive(Component, Clone, Copy, Debug, Default)]
pub struct Velocity {
    pub x: f32,
    pub y: f32,
}

/// Collider component - defines collision bounds
#[derive(Component, Clone, Copy, Debug)]
pub struct Collider {
    pub width: f32,
    pub height: f32,
}

impl Default for Collider {
    fn default() -> Self {
        Self {
            width: 16.0,
            height: 16.0,
        }
    }
}

/// Sprite information component
#[derive(Component, Clone, Debug)]
pub struct SpriteInfo {
    pub texture_id: usize,
    pub frame: usize,
    pub facing_left: bool,
}

impl Default for SpriteInfo {
    fn default() -> Self {
        Self {
            texture_id: 0,
            frame: 0,
            facing_left: false,
        }
    }
}

/// Behavior component - stores the 18 different behavior types from original Siriel
#[derive(Component, Clone, Debug, Serialize, Deserialize)]
pub struct Behavior {
    pub behavior_type: BehaviorType,
    pub params: BehaviorParams,
    pub state: BehaviorState,
}

/// The 18 behavior types from the original Siriel engine
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum BehaviorType {
    Static = 1,           // No movement
    HorizontalOscillator = 2,  // Moves between two X coordinates
    VerticalOscillator = 3,    // Moves between two Y coordinates
    PlatformWithGravity = 4,   // Falls until hits solid ground
    EdgeWalkingPlatform = 5,   // Changes direction at edges
    RandomMovement = 12,       // Random direction changes, avoids walls
    Fireball = 15,            // Projectile that moves in straight line
    Hunter = 16,              // AI that chases player when activated
    SoundTrigger = 17,        // Plays sounds at timed intervals
    AdvancedProjectile = 18,  // Fireball with custom sounds
}

/// Parameters for entity behaviors (maps to inf1-inf7 from Pascal)
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BehaviorParams {
    pub inf1: u16,  // Speed or X1 coordinate
    pub inf2: u16,  // Timer or X2/Y2 coordinate  
    pub inf3: u16,  // Direction or active time
    pub inf4: u16,  // Animation frame or passive time
    pub inf5: u16,  // Counter or timer
    pub inf6: u16,  // State flag or counter
    pub inf7: u16,  // Direction or spare parameter
}

impl Default for BehaviorParams {
    fn default() -> Self {
        Self {
            inf1: 0, inf2: 0, inf3: 0, inf4: 0,
            inf5: 0, inf6: 0, inf7: 0,
        }
    }
}

/// Runtime state for behaviors
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct BehaviorState {
    pub timer: f32,
    pub active: bool,
    pub direction: i32,
    pub counter: u32,
}

/// Animation state component
#[derive(Component, Clone, Debug)]
pub struct AnimationState {
    pub current_frame: usize,
    pub timer: f32,
    pub frame_duration: f32,
    pub loop_animation: bool,
}

impl Default for AnimationState {
    fn default() -> Self {
        Self {
            current_frame: 0,
            timer: 0.0,
            frame_duration: 0.1, // 10 FPS default
            loop_animation: true,
        }
    }
}

/// Physics component - handles gravity and ground detection
#[derive(Component, Clone, Debug, Default)]
pub struct Physics {
    pub on_ground: bool,
    pub gravity_affected: bool,
    pub jump_force: f32,
    pub max_fall_speed: f32,
}

/// Room/Level component - which room/level this entity belongs to
#[derive(Component, Clone, Copy, Debug)]
pub struct Room {
    pub id: u8,
}

/// Pickup component - can be collected by player
#[derive(Component, Clone, Copy, Debug)]
pub struct Pickup {
    pub pickup_type: u16,
    pub value: u32,
}

/// Sound component - for entities that play sounds
#[derive(Component, Clone, Debug)]
pub struct SoundEmitter {
    pub sound_id1: Option<u8>,  // Maps to z1
    pub sound_id2: Option<u8>,  // Maps to z2
    pub triggered: bool,
}

/// Health/Damage component
#[derive(Component, Clone, Copy, Debug)]
pub struct Health {
    pub current: i32,
    pub max: i32,
    pub invulnerable: bool,
    pub invulnerability_timer: f32,
}