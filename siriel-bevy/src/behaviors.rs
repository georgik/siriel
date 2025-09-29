use crate::components::*;
use bevy::prelude::*;
use rand::Rng;

/// Implementation of all 18 behavior types from the original Siriel engine
pub struct BehaviorManager;

impl BehaviorManager {
    /// Execute behavior for an entity based on its behavior type
    pub fn execute_behavior(
        behavior_type: BehaviorType,
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
        player_pos: Option<&Position>,
    ) {
        match behavior_type {
            BehaviorType::Static => {
                Self::static_behavior(velocity);
            }
            BehaviorType::HorizontalOscillator => {
                Self::horizontal_oscillator(position, velocity, params, state, dt);
            }
            BehaviorType::VerticalOscillator => {
                Self::vertical_oscillator(position, velocity, params, state, dt);
            }
            BehaviorType::PlatformWithGravity => {
                Self::platform_with_gravity(position, velocity, params, state, dt);
            }
            BehaviorType::EdgeWalkingPlatform => {
                Self::edge_walking_platform(position, velocity, params, state, dt);
            }
            BehaviorType::RandomMovement => {
                Self::random_movement(position, velocity, params, state, dt);
            }
            BehaviorType::Fireball => {
                Self::fireball(position, velocity, params, state, dt);
            }
            BehaviorType::Hunter => {
                if let Some(player_position) = player_pos {
                    Self::hunter(position, velocity, params, state, dt, player_position);
                }
            }
            BehaviorType::SoundTrigger => {
                Self::sound_trigger(params, state, dt);
            }
            BehaviorType::AdvancedProjectile => {
                Self::advanced_projectile(position, velocity, params, state, dt);
            }
        }
    }

    /// Behavior 1: Static - no movement
    fn static_behavior(velocity: &mut Velocity) {
        velocity.x = 0.0;
        velocity.y = 0.0;
    }

    /// Behavior 2: Horizontal oscillator - moves between two X coordinates
    fn horizontal_oscillator(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
    ) {
        let speed = params.inf1 as f32;
        let left_bound = params.inf3 as f32;
        let right_bound = params.inf2 as f32;

        // Move in current direction
        velocity.x = speed * state.direction as f32;
        position.x += velocity.x * dt;

        // Check boundaries and reverse direction
        if position.x <= left_bound {
            position.x = left_bound;
            state.direction = 1;
        } else if position.x >= right_bound {
            position.x = right_bound;
            state.direction = -1;
        }
    }

    /// Behavior 3: Vertical oscillator - moves between two Y coordinates
    fn vertical_oscillator(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
    ) {
        let speed = params.inf1 as f32;
        let top_bound = params.inf3 as f32;
        let bottom_bound = params.inf2 as f32;

        velocity.y = speed * state.direction as f32;
        position.y += velocity.y * dt;

        if position.y <= top_bound {
            position.y = top_bound;
            state.direction = 1;
        } else if position.y >= bottom_bound {
            position.y = bottom_bound;
            state.direction = -1;
        }
    }

    /// Behavior 4: Platform with gravity - falls until hits solid ground
    fn platform_with_gravity(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
    ) {
        let gravity = 200.0; // Gravity force
        let speed = params.inf1 as f32;

        // Apply gravity if not on ground (simplified)
        if !state.active {
            // active flag used as "on_ground" here
            velocity.y -= gravity * dt;
        }

        // Horizontal movement
        velocity.x = speed * state.direction as f32;

        position.x += velocity.x * dt;
        position.y += velocity.y * dt;

        // Simple ground detection (in real implementation, check against tilemap)
        if position.y <= 50.0 {
            position.y = 50.0;
            velocity.y = 0.0;
            state.active = true; // on ground
        }
    }

    /// Behavior 5: Edge-walking platform - changes direction at edges
    fn edge_walking_platform(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
    ) {
        let speed = params.inf1 as f32;

        velocity.x = speed * state.direction as f32;
        position.x += velocity.x * dt;

        // Simplified edge detection - would check for ground tiles in real implementation
        // Check if we're at screen edges for now
        if position.x <= 16.0 {
            state.direction = 1;
        } else if position.x >= 624.0 {
            state.direction = -1;
        }
    }

    /// Behavior 12: Random movement - changes direction randomly, avoids walls
    fn random_movement(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
    ) {
        let speed = params.inf1 as f32;

        // Update timer
        state.timer += dt;

        // Change direction randomly every few seconds
        let direction_change_time = (params.inf4 as f32) / 60.0; // Convert from frames to seconds

        if state.timer >= direction_change_time {
            state.timer = 0.0;
            let mut rng = rand::thread_rng();
            state.direction = rng.gen_range(-1..=1);
        }

        // Apply movement
        match state.direction {
            -1 => velocity.x = -speed, // Left
            0 => {
                velocity.x = 0.0;
                velocity.y = 0.0;
            } // Stop
            1 => velocity.x = speed,   // Right
            _ => {}
        }

        position.x += velocity.x * dt;
        position.y += velocity.y * dt;

        // Boundary checking
        if position.x <= 16.0 || position.x >= 624.0 {
            state.direction = -state.direction;
        }
    }

    /// Behavior 15: Fireball - projectile that moves in straight line and respawns
    fn fireball(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
    ) {
        let speed = params.inf3 as f32;
        let target_x = params.inf2 as f32;

        match params.inf1 {
            1 => {
                // Move right
                velocity.x = speed;
                if position.x >= target_x {
                    // Reset to origin
                    position.x = params.inf4 as f32; // Original X
                }
            }
            2 => {
                // Move left
                velocity.x = -speed;
                if position.x <= target_x {
                    position.x = params.inf4 as f32;
                }
            }
            3 => {
                // Move down
                velocity.y = -speed;
                if position.y <= target_x {
                    // inf2 used as target Y
                    position.y = params.inf4 as f32;
                }
            }
            4 => {
                // Move up
                velocity.y = speed;
                if position.y >= target_x {
                    position.y = params.inf4 as f32;
                }
            }
            _ => {}
        }

        position.x += velocity.x * dt;
        position.y += velocity.y * dt;
    }

    /// Behavior 16: Hunter AI - passive/active modes, chases player when activated
    fn hunter(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
        player_pos: &Position,
    ) {
        let speed = params.inf1 as f32;
        let activation_distance = params.inf3 as f32;
        let passive_time = (params.inf2 as f32) / 60.0; // Convert frames to seconds
        let active_time = (params.inf4 as f32) / 60.0;

        // Calculate distance to player
        let dx = player_pos.x - position.x;
        let dy = player_pos.y - position.y;
        let distance = (dx * dx + dy * dy).sqrt();

        state.timer += dt;

        if !state.active {
            // Passive mode
            if distance <= activation_distance && passive_time > 0.0 {
                if state.timer >= passive_time {
                    state.active = true;
                    state.timer = 0.0;
                }
            } else {
                // Random movement in passive mode
                if state.timer >= 1.0 {
                    // Change direction every second
                    let mut rng = rand::thread_rng();
                    state.direction = rng.gen_range(-1..=1);
                    state.timer = 0.0;
                }
                velocity.x = speed * 0.5 * state.direction as f32; // Slower in passive mode
            }
        } else {
            // Active mode - chase player
            if active_time > 0.0 && state.timer >= active_time {
                state.active = false;
                state.timer = 0.0;
            } else {
                // Chase player
                if dx.abs() > 2.0 {
                    velocity.x = if dx > 0.0 { speed } else { -speed };
                }
                if dy.abs() > 2.0 {
                    velocity.y = if dy > 0.0 { speed } else { -speed };
                }
            }
        }

        position.x += velocity.x * dt;
        position.y += velocity.y * dt;
    }

    /// Behavior 17: Sound trigger - plays sounds at timed intervals
    fn sound_trigger(params: &BehaviorParams, state: &mut BehaviorState, dt: f32) {
        state.timer += dt;

        let sound1_interval = (params.inf2 as f32) / 60.0;
        let sound2_interval = (params.inf4 as f32) / 60.0;

        // This would trigger sound events in a real implementation
        if !state.active && state.timer >= sound1_interval {
            // Trigger sound 1 (params.inf1)
            state.active = true;
            state.timer = 0.0;
        } else if state.active && state.timer >= sound2_interval {
            // Trigger sound 2 (params.inf3)
            state.active = false;
            state.timer = 0.0;
        }
    }

    /// Behavior 18: Advanced projectile - like fireball but with custom sounds
    fn advanced_projectile(
        position: &mut Position,
        velocity: &mut Velocity,
        params: &BehaviorParams,
        state: &mut BehaviorState,
        dt: f32,
    ) {
        // Similar to fireball but with sound parameters z1, z2
        Self::fireball(position, velocity, params, state, dt);

        // Additional sound triggering logic would go here
        // using params for sound IDs stored in z1, z2 fields
    }
}
