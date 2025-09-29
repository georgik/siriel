use crate::atlas::AtlasManager;
use crate::audio::{sound_mappings, SoundEvent};
use crate::components::*;
use crate::resources::*;
use bevy::prelude::*;

/// Setup the camera
pub fn setup_camera(mut commands: Commands) {
    commands.spawn(Camera2d::default());
}

/// Initial game setup
pub fn setup_game(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    mut game_state: ResMut<GameState>,
    tilemap_manager: Res<crate::level::TilemapManager>,
) {
    // Initialize game state
    game_state.score = 0;
    game_state.lives = 3;
    game_state.level = 1;
    game_state.timer = 300.0; // 5 minutes

    // Get spawn position from level data or use default
    let spawn_pos = if let Some(level) = &tilemap_manager.current_level {
        level.spawn_point
    } else {
        (320.0, 240.0)
    };

    // Create a simple colored sprite for the player (we'll replace with actual sprites later)
    commands.spawn((
        Player,
        Position {
            x: spawn_pos.0,
            y: spawn_pos.1,
        },
        Velocity::default(),
        Collider::default(),
        SpriteInfo::default(),
        Physics {
            on_ground: false,
            gravity_affected: true,
            jump_force: 400.0,
            max_fall_speed: 600.0,
        },
        AnimationState::default(),
        Health {
            current: 3,
            max: 3,
            invulnerable: false,
            invulnerability_timer: 0.0,
        },
        Sprite {
            color: Color::srgb(0.0, 0.5, 1.0),
            custom_size: Some(Vec2::new(16.0, 16.0)),
            ..default()
        },
        Transform::from_translation(Vec3::new(spawn_pos.0, spawn_pos.1, 1.0)),
    ));

    // Create some test entities with different behaviors
    create_test_entities(&mut commands);
}

fn create_test_entities(commands: &mut Commands) {
    // Static enemy
    commands.spawn((
        Position { x: 100.0, y: 200.0 },
        Velocity::default(),
        Collider::default(),
        Behavior {
            behavior_type: BehaviorType::Static,
            params: BehaviorParams::default(),
            state: BehaviorState::default(),
        },
        Sprite {
            color: Color::srgb(1.0, 0.0, 0.0),
            custom_size: Some(Vec2::new(16.0, 16.0)),
            ..default()
        },
        Transform::from_translation(Vec3::new(100.0, 200.0, 1.0)),
    ));

    // Horizontal oscillator
    commands.spawn((
        Position { x: 200.0, y: 300.0 },
        Velocity::default(),
        Collider::default(),
        Behavior {
            behavior_type: BehaviorType::HorizontalOscillator,
            params: BehaviorParams {
                inf1: 2,   // speed
                inf2: 400, // right boundary
                inf3: 200, // left boundary
                ..Default::default()
            },
            state: BehaviorState {
                direction: 1,
                ..Default::default()
            },
        },
        Sprite {
            color: Color::srgb(0.0, 1.0, 0.0),
            custom_size: Some(Vec2::new(16.0, 16.0)),
            ..default()
        },
        Transform::from_translation(Vec3::new(200.0, 300.0, 1.0)),
    ));
}

/// Handle player input
pub fn input_system(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut input_state: ResMut<InputState>,
    mut query: Query<&mut Velocity, With<Player>>,
    physics_config: Res<PhysicsConfig>,
) {
    // Update input state
    input_state.move_left =
        keyboard_input.pressed(KeyCode::ArrowLeft) || keyboard_input.pressed(KeyCode::KeyA);
    input_state.move_right =
        keyboard_input.pressed(KeyCode::ArrowRight) || keyboard_input.pressed(KeyCode::KeyD);
    input_state.move_up =
        keyboard_input.pressed(KeyCode::ArrowUp) || keyboard_input.pressed(KeyCode::KeyW);
    input_state.move_down =
        keyboard_input.pressed(KeyCode::ArrowDown) || keyboard_input.pressed(KeyCode::KeyS);
    input_state.jump_pressed = keyboard_input.just_pressed(KeyCode::Space);
    input_state.jump = keyboard_input.pressed(KeyCode::Space);
    input_state.action = keyboard_input.pressed(KeyCode::Enter);
    input_state.pause = keyboard_input.just_pressed(KeyCode::Escape);
    input_state.menu = keyboard_input.just_pressed(KeyCode::Tab);
    input_state.quit = keyboard_input.just_pressed(KeyCode::Escape);

    // Apply player movement
    if let Ok(mut velocity) = query.single_mut() {
        let move_speed = 200.0; // pixels per second

        velocity.x = 0.0;
        if input_state.move_left {
            velocity.x = -move_speed;
        }
        if input_state.move_right {
            velocity.x = move_speed;
        }

        // Jump handling will be done in physics system
    }
}

/// Physics system - handles gravity, jumping, and basic movement
pub fn physics_system(
    time: Res<Time>,
    physics_config: Res<PhysicsConfig>,
    input_state: Res<InputState>,
    mut query: Query<(&mut Position, &mut Velocity, &mut Physics), With<Player>>,
    mut sound_events: EventWriter<SoundEvent>,
) {
    let dt = time.delta_secs();

    for (mut position, mut velocity, mut physics) in query.iter_mut() {
        // Apply gravity
        if physics.gravity_affected && !physics.on_ground {
            velocity.y -= physics_config.gravity * dt;
            if velocity.y < -physics.max_fall_speed {
                velocity.y = -physics.max_fall_speed;
            }
        }

        // Handle jumping
        if input_state.jump_pressed && physics.on_ground {
            velocity.y = physics.jump_force;
            physics.on_ground = false;
            // Play jump/pickup sound
            sound_events.send(SoundEvent::PlayEffect(sound_mappings::PICKUP.to_string()));
        }

        // Apply friction
        if physics.on_ground {
            velocity.x *= physics_config.ground_friction;
        } else {
            velocity.x *= physics_config.air_friction;
        }

        // Update position
        position.x += velocity.x * dt;
        position.y += velocity.y * dt;

        // Simple ground detection (we'll improve this with proper collision later)
        if position.y <= 50.0 {
            position.y = 50.0;
            velocity.y = 0.0;
            physics.on_ground = true;
        }

        // Screen boundaries
        if position.x < 8.0 {
            position.x = 8.0;
        }
        if position.x > 632.0 {
            position.x = 632.0;
        }
    }
}

/// Behavior system - implements the 18 different entity behaviors
pub fn behavior_system(
    time: Res<Time>,
    mut query: Query<(&mut Position, &mut Velocity, &mut Behavior), Without<Player>>,
) {
    let dt = time.delta_secs();

    for (mut position, mut velocity, mut behavior) in query.iter_mut() {
        match behavior.behavior_type {
            BehaviorType::Static => {
                // No movement
                velocity.x = 0.0;
                velocity.y = 0.0;
            }

            BehaviorType::HorizontalOscillator => {
                let speed = behavior.params.inf1 as f32;
                let left_bound = behavior.params.inf3 as f32;
                let right_bound = behavior.params.inf2 as f32;

                // Move in current direction
                velocity.x = speed * behavior.state.direction as f32;
                position.x += velocity.x * dt;

                // Check boundaries and reverse direction
                if position.x <= left_bound {
                    position.x = left_bound;
                    behavior.state.direction = 1;
                } else if position.x >= right_bound {
                    position.x = right_bound;
                    behavior.state.direction = -1;
                }
            }

            BehaviorType::VerticalOscillator => {
                let speed = behavior.params.inf1 as f32;
                let top_bound = behavior.params.inf3 as f32;
                let bottom_bound = behavior.params.inf2 as f32;

                velocity.y = speed * behavior.state.direction as f32;
                position.y += velocity.y * dt;

                if position.y <= top_bound {
                    position.y = top_bound;
                    behavior.state.direction = 1;
                } else if position.y >= bottom_bound {
                    position.y = bottom_bound;
                    behavior.state.direction = -1;
                }
            }

            // TODO: Implement remaining behavior types
            _ => {
                // Placeholder for other behaviors
            }
        }
    }
}

/// Legacy animation system for AnimationState components (kept for compatibility)
pub fn legacy_animation_system(time: Res<Time>, mut query: Query<&mut AnimationState>) {
    let dt = time.delta_secs();

    for mut anim_state in query.iter_mut() {
        anim_state.timer += dt;

        if anim_state.timer >= anim_state.frame_duration {
            anim_state.timer = 0.0;
            if anim_state.loop_animation {
                anim_state.current_frame = (anim_state.current_frame + 1) % 4; // Assume 4 frames max
            }
        }
    }
}

/// Collision system - detects collisions between entities
pub fn collision_system(
    mut player_query: Query<
        (&mut Position, &Collider, &mut Health),
        (With<Player>, Without<Behavior>),
    >,
    entity_query: Query<(&Position, &Collider), (Without<Player>, With<Behavior>)>,
    mut game_state: ResMut<GameState>,
    mut sound_events: EventWriter<SoundEvent>,
) {
    if let Ok((player_pos, player_collider, mut player_health)) = player_query.single_mut() {
        for (entity_pos, entity_collider) in entity_query.iter() {
            // Simple AABB collision detection
            let player_left = player_pos.x - player_collider.width / 2.0;
            let player_right = player_pos.x + player_collider.width / 2.0;
            let player_top = player_pos.y + player_collider.height / 2.0;
            let player_bottom = player_pos.y - player_collider.height / 2.0;

            let entity_left = entity_pos.x - entity_collider.width / 2.0;
            let entity_right = entity_pos.x + entity_collider.width / 2.0;
            let entity_top = entity_pos.y + entity_collider.height / 2.0;
            let entity_bottom = entity_pos.y - entity_collider.height / 2.0;

            // Check for overlap
            if player_right > entity_left
                && player_left < entity_right
                && player_top > entity_bottom
                && player_bottom < entity_top
            {
                // Collision detected - handle it
                if !player_health.invulnerable {
                    player_health.current -= 1;
                    player_health.invulnerable = true;
                    player_health.invulnerability_timer = 2.0; // 2 seconds of invulnerability

                    // Play hit sound
                    sound_events.send(SoundEvent::PlayEffect(sound_mappings::HIT.to_string()));

                    if player_health.current <= 0 {
                        game_state.lives -= 1;
                        // Play explosion sound on death
                        sound_events.send(SoundEvent::PlayEffect(
                            sound_mappings::EXPLOSION.to_string(),
                        ));
                        // TODO: Respawn player or game over
                    }
                }
            }
        }
    }
}

/// Load sprite assets from the assets directory
pub fn load_sprite_assets(mut sprite_atlas: ResMut<SpriteAtlas>, asset_server: Res<AssetServer>) {
    sprite_atlas.player_texture = Some(asset_server.load("sprites/siriel-avatar.png"));
    sprite_atlas.objects_texture = Some(asset_server.load("sprites/objects-basic.png"));
    sprite_atlas.tiles_texture = Some(asset_server.load("sprites/texture-basic.png"));
    sprite_atlas.animations_texture = Some(asset_server.load("sprites/animations-basic.png"));
    sprite_atlas.sprite_size = 16.0;
    sprite_atlas.loaded = true;

    println!("Loaded Siriel sprite assets");
}

/// Update sprite positions based on entity positions
pub fn render_debug_system(mut query: Query<(&Position, &mut Transform)>) {
    for (position, mut transform) in query.iter_mut() {
        transform.translation.x = position.x;
        transform.translation.y = position.y;
    }
}

/// Animation system - updates animated entities using the animations atlas
pub fn animation_system(
    time: Res<Time>,
    atlas_manager: Res<AtlasManager>,
    mut animated_query: Query<(&mut AnimatedEntity, &mut SpriteInfo)>,
) {
    let dt = time.delta_secs();

    for (mut animated, mut sprite_info) in animated_query.iter_mut() {
        animated.timer += dt;

        // Check if we should advance to next frame
        if animated.timer >= animated.duration_per_frame {
            animated.timer = 0.0;
            animated.current_frame_index =
                (animated.current_frame_index + 1) % animated.total_frames;

            // Get the animation descriptor to get the actual frame indices
            if let Some(animation) = atlas_manager.get_animation(&animated.animation_name) {
                if animated.current_frame_index < animation.frames.len() {
                    let frame_id = animation.frames[animated.current_frame_index];
                    sprite_info.frame = frame_id as usize;
                }
            }
        }
    }
}

/// Handle quitting the game when ESC is pressed
pub fn quit_system(
    input_state: Res<InputState>,
    mut app_exit_events: EventWriter<bevy::app::AppExit>,
) {
    if input_state.quit {
        info!("ESC pressed - Quitting game");
        app_exit_events.send(bevy::app::AppExit::Success);
    }
}
