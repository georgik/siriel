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
    /// TODO: Use texture_id for multi-atlas sprite lookups
    #[allow(dead_code)]
    pub texture_id: usize,
    pub frame: usize,
    /// TODO: Use facing_left for sprite flipping
    #[allow(dead_code)]
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

/// Behavior types from the original Siriel engine mapped to their functions
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum BehaviorType {
    Static,               // funk=1: No movement
    HorizontalOscillator, // funk=2: Moves between two X coordinates
    VerticalOscillator,   // funk=3: Moves between two Y coordinates
    PlatformWithGravity,  // funk=4: Falls until hits solid ground
    EdgeWalkingPlatform,  // funk=5: Changes direction at edges
    AnimatedCollectible,  // funk=6: Animated collectible (ZANA)
    RandomMovement,       // funk=12: Random direction changes, avoids walls
    Fireball,             // funk=15: Projectile that moves in straight line
    Hunter,               // funk=16: AI that chases player when activated
    SoundTrigger,         // funk=17: Plays sounds at timed intervals
    AdvancedProjectile,   // funk=18: Fireball with custom sounds
}

/// Named behavior parameters based on original Pascal code analysis
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum BehaviorParams {
    Static,
    HorizontalOscillator {
        left_bound: u16,  // inf1: left X boundary
        right_bound: u16, // inf2: right X boundary
        speed: u16,       // inf3: movement speed
    },
    VerticalOscillator {
        top_bound: u16,    // inf1: top Y boundary
        bottom_bound: u16, // inf2: bottom Y boundary
        speed: u16,        // inf3: movement speed
    },
    PlatformWithGravity {
        speed: u16,   // inf1: movement speed
        start_x: u16, // inf5: starting X position
        start_y: u16, // inf6: starting Y position
    },
    EdgeWalkingPlatform {
        speed: u16,   // inf1: movement speed
        start_x: u16, // inf5: starting X position
        start_y: u16, // inf6: starting Y position
    },
    AnimatedCollectible {
        animation_speed: u16, // inf1: animation speed
        timer_max: u16,       // inf2: animation timer max
        value: u16,           // inf3: pickup value
    },
    RandomMovement {
        boundary_mode: u16, // inf1: 0=screen bounds, 1=texture aware
        speed: u16,         // inf2: movement speed
        direction: u16,     // inf3: current direction (0-3)
        timer: u16,         // inf4: movement timer
        old_direction: u16, // inf5: previous direction
    },
    Fireball {
        direction: u16,   // inf1: 1=right, 2=left, 3=down, 4=up
        target_pos: u16,  // inf2: target X or Y coordinate
        speed: u16,       // inf3: movement speed
        reload_time: u16, // inf4: time between shots
        timer: u16,       // inf5: current timer
    },
    Hunter {
        speed: u16,            // inf1: movement speed
        passive_time: u16,     // inf2: time in passive mode
        active_time: u16,      // inf3: time in active mode
        alternate_sprite: u16, // inf4: sprite for active mode
        mode_timer: u16,       // inf6: current mode timer
    },
    SoundTrigger {
        sound1_id: u16,    // inf1: first sound ID
        sound1_delay: u16, // inf2: delay before first sound
        sound2_id: u16,    // inf3: second sound ID
        sound2_delay: u16, // inf4: delay before second sound
        timer: u16,        // inf5: current timer
        mode: u16,         // inf6: current sound mode
    },
    AdvancedProjectile {
        direction: u16,   // inf1: 1=right, 2=left, 3=down, 4=up
        target_pos: u16,  // inf2: target X or Y coordinate
        speed: u16,       // inf3: movement speed
        reload_time: u16, // inf4: time between shots
        timer: u16,       // inf5: current timer
                          // Uses z1, z2 for custom sounds instead of inf6, inf7
    },
}

impl Default for BehaviorParams {
    fn default() -> Self {
        Self::Static
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

/// Physics component - handles gravity and ground detection
#[derive(Component, Clone, Debug, Default)]
pub struct Physics {
    pub on_ground: bool,
    pub gravity_affected: bool,
    pub jump_force: f32,
    pub max_fall_speed: f32,
}

/// Pickup component - can be collected by player
#[derive(Component, Clone, Copy, Debug)]
pub struct Pickup {
    /// TODO: Use pickup_type to distinguish collectible categories
    #[allow(dead_code)]
    pub pickup_type: u16,
    #[allow(dead_code)]
    pub value: u32,
}

/// Health/Damage component
#[derive(Component, Clone, Copy, Debug)]
pub struct Health {
    pub current: i32,
    /// TODO: Use max for health bar rendering
    #[allow(dead_code)]
    pub max: i32,
    pub invulnerable: bool,
    pub invulnerability_timer: f32,
}

/// Animated entity component - for objects that use the animations atlas
#[derive(Component, Clone, Debug)]
pub struct AnimatedEntity {
    pub animation_name: String,
    pub current_frame_index: usize,
    pub timer: f32,
    /// TODO: Use duration_per_frame for animation timing
    #[allow(dead_code)]
    pub duration_per_frame: f32,
    /// TODO: Use total_frames for animation looping
    #[allow(dead_code)]
    pub total_frames: usize,
    /// TODO: Use base_sprite_id for animation frame calculation
    #[allow(dead_code)]
    pub base_sprite_id: u32, // Starting frame index in animations atlas
}

/// Avatar animation component - for player character animations
#[derive(Component, Clone, Debug)]
pub struct AvatarAnimation {
    pub current_animation: String,
    pub current_frame_index: usize,
    pub timer: f32,
    pub facing_left: bool,
}

impl Default for AvatarAnimation {
    fn default() -> Self {
        Self {
            current_animation: "idle".to_string(),
            current_frame_index: 0,
            timer: 0.0,
            facing_left: false,
        }
    }
}
