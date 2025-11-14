use crate::atlas::AtlasManager;
use crate::audio::{sound_mappings, SoundEvent};
use crate::components::*;
use crate::level::GameEntity;
use crate::resources::*;
use bevy::prelude::*;

/// Setup the camera
pub fn setup_camera(mut commands: Commands) {
    commands.spawn(Camera2d::default());
}

/// Initial game setup
pub fn setup_game(
    mut commands: Commands,
    _asset_server: Res<AssetServer>,
    mut game_state: ResMut<GameState>,
    tilemap_manager: Res<crate::level::TilemapManager>,
    atlas_manager: Res<AtlasManager>,
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

    // Create animated avatar sprite for the player
    // Apply avatar texture if available, otherwise fallback to colored sprite
    let mut entity_commands = if let Some(ref avatar_texture) = atlas_manager.avatar_texture {
        commands.spawn((
            Player,
            Sprite {
                image: avatar_texture.clone(),
                custom_size: Some(Vec2::new(16.0, 16.0)),
                ..default()
            },
            Transform::from_translation(Vec3::new(spawn_pos.0, spawn_pos.1, 1.0)),
        ))
    } else {
        // Fallback to colored sprite if avatar texture not loaded
        commands.spawn((
            Player,
            Sprite {
                color: Color::srgb(0.0, 0.5, 1.0), // Blue colored sprite as fallback
                custom_size: Some(Vec2::new(16.0, 16.0)),
                ..default()
            },
            Transform::from_translation(Vec3::new(spawn_pos.0, spawn_pos.1, 1.0)),
        ))
    };

    // Add all the game-specific components
    entity_commands.insert((
        Position {
            x: spawn_pos.0,
            y: spawn_pos.1,
        },
        Velocity::default(),
        Collider::default(),
        Physics {
            on_ground: false,
            gravity_affected: true,
            jump_force: 400.0,
            max_fall_speed: 600.0,
        },
        AvatarAnimation::default(),
        Health {
            current: 3,
            max: 3,
            invulnerable: false,
            invulnerability_timer: 0.0,
        },
        SpriteInfo {
            texture_id: 0, // Avatar texture ID
            frame: 0,      // Start with first frame (idle)
            facing_left: false,
        },
    ));

    // Create some test entities with different behaviors
    create_test_entities(&mut commands, &atlas_manager);
}

fn create_test_entities(_commands: &mut Commands, _atlas_manager: &AtlasManager) {
    // Test entities are now handled by spawn_level_entities system
    // This function is kept for future debugging if needed
    info!("📝 Test entities disabled - using RON level entities instead");
}

/// Handle player input
pub fn input_system(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut input_state: ResMut<InputState>,
    mut query: Query<&mut Velocity, With<Player>>,
    mut next_state: ResMut<NextState<crate::resources::AppState>>,
    _physics_config: Res<PhysicsConfig>,
    // Gamepad input parameters
    mut gamepad_events: MessageReader<crate::input::GamepadInputEvent>,
    gamepad_button_state: Res<crate::input::GamepadButtonState>,
    gamepad_config: Res<crate::input::GamepadConfig>,
    gamepad_manager: Res<crate::input::GamepadManager>,
    gamepads: Query<&bevy::input::gamepad::Gamepad>,
    _gamepad_axis_state: Res<crate::input::GamepadAxisState>,
) {
    // Reset gamepad-related input flags
    let mut gamepad_move_left = false;
    let mut gamepad_move_right = false;
    let mut gamepad_jump_pressed = false;
    let mut gamepad_action = false;
    let mut gamepad_pause = false;
    let mut gamepad_menu = false;
    let mut analog_movement: f32 = 0.0;

    // Process gamepad events (for just_pressed detection)
    for event in gamepad_events.read() {
        match event {
            crate::input::GamepadInputEvent::ButtonPressed { action, .. } => match action {
                crate::input::GameAction::Jump => gamepad_jump_pressed = true,
                crate::input::GameAction::Action => gamepad_action = true,
                crate::input::GameAction::Pause => gamepad_pause = true,
                crate::input::GameAction::Menu => gamepad_menu = true,
                _ => {}
            },
            _ => {}
        }
    }

    // Check gamepad state directly every frame for continuous input (D-pad and analog stick)
    if let Some(active_gamepad_entity) = gamepad_manager.get_active_gamepad() {
        if let Ok(gamepad) = gamepads.get(active_gamepad_entity) {
            use bevy::input::gamepad::{GamepadAxis, GamepadButton};

            // Check D-pad for digital movement (continuous while held)
            if gamepad.pressed(GamepadButton::DPadLeft) {
                gamepad_move_left = true;
            }
            if gamepad.pressed(GamepadButton::DPadRight) {
                gamepad_move_right = true;
            }

            // Check left analog stick for movement (continuous state checking)
            let deadzone = gamepad_config.deadzone;
            if let Some(x_value) = gamepad.get(GamepadAxis::LeftStickX) {
                if x_value.abs() > deadzone {
                    analog_movement = x_value * gamepad_config.sensitivity;
                }
            }

            // Check if jump button is held (not just pressed)
            if gamepad.pressed(GamepadButton::South) {
                // South button is mapped to Jump
                // Don't set gamepad_jump_pressed here, just for held detection
            }
        }
    }

    // Check if gamepad jump is held (for continuous jump input)
    let gamepad_jump_held = crate::input::is_gamepad_action_active(
        &gamepad_button_state,
        &gamepad_config,
        crate::input::GameAction::Jump,
    );

    // Update input state - combine keyboard and gamepad
    input_state.move_left = keyboard_input.pressed(KeyCode::ArrowLeft)
        || keyboard_input.pressed(KeyCode::KeyA)
        || gamepad_move_left;
    input_state.move_right = keyboard_input.pressed(KeyCode::ArrowRight)
        || keyboard_input.pressed(KeyCode::KeyD)
        || gamepad_move_right;
    input_state.move_up =
        keyboard_input.pressed(KeyCode::ArrowUp) || keyboard_input.pressed(KeyCode::KeyW);
    input_state.move_down =
        keyboard_input.pressed(KeyCode::ArrowDown) || keyboard_input.pressed(KeyCode::KeyS);
    input_state.jump_pressed = keyboard_input.just_pressed(KeyCode::Space) || gamepad_jump_pressed;
    input_state.jump = keyboard_input.pressed(KeyCode::Space) || gamepad_jump_held;
    input_state.action = keyboard_input.pressed(KeyCode::Enter) || gamepad_action;
    input_state.pause = keyboard_input.just_pressed(KeyCode::Escape) || gamepad_pause;
    input_state.menu = keyboard_input.just_pressed(KeyCode::Tab) || gamepad_menu;
    input_state.quit = keyboard_input.just_pressed(KeyCode::Escape);

    // Handle ESC key or pause button to return to menu
    if keyboard_input.just_pressed(KeyCode::Escape) || gamepad_pause {
        next_state.set(crate::resources::AppState::Menu);
    }

    // Apply player movement
    if let Ok(mut velocity) = query.single_mut() {
        let move_speed = 200.0; // pixels per second

        // Analog stick takes priority over digital input
        if analog_movement.abs() > 0.01 {
            velocity.x = analog_movement * move_speed;
        } else {
            velocity.x = 0.0;
            if input_state.move_left {
                velocity.x = -move_speed;
            }
            if input_state.move_right {
                velocity.x = move_speed;
            }
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
    mut sound_events: MessageWriter<SoundEvent>,
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
            sound_events.write(SoundEvent::PlayEffect(sound_mappings::PICKUP.to_string()));
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
        match (&behavior.behavior_type, &behavior.params) {
            (BehaviorType::Static, BehaviorParams::Static) => {
                // No movement
                velocity.x = 0.0;
                velocity.y = 0.0;
            }

            (
                BehaviorType::HorizontalOscillator,
                BehaviorParams::HorizontalOscillator {
                    left_bound,
                    right_bound,
                    speed,
                },
            ) => {
                // Speed parameter from MIE file represents movement per animation frame
                // Animations run at 10 fps (0.1s per frame), so speed * 10 = pixels/sec
                let speed_pixels_per_sec = *speed as f32 * 10.0;

                // Convert bounds from grid units (as stored in MIE) to Bevy pixel coordinates
                // Same transformation as entity positions:
                // 1. Grid to pixels: multiply by 8
                // 2. Add border offset: +16px for X alignment
                // 3. Center coordinate system: subtract 320 (screen width / 2)
                let left_pixels = *left_bound as f32 * 8.0 + 16.0;
                let right_pixels = *right_bound as f32 * 8.0 + 16.0;
                let left_centered = left_pixels - 320.0;
                let right_centered = right_pixels - 320.0;

                // Move in current direction
                velocity.x = speed_pixels_per_sec * behavior.state.direction as f32;
                position.x += velocity.x * dt;

                // Check boundaries and reverse direction
                if position.x <= left_centered {
                    position.x = left_centered;
                    behavior.state.direction = 1;
                } else if position.x >= right_centered {
                    position.x = right_centered;
                    behavior.state.direction = -1;
                }
            }

            (
                BehaviorType::VerticalOscillator,
                BehaviorParams::VerticalOscillator {
                    top_bound,
                    bottom_bound,
                    speed,
                },
            ) => {
                // Speed parameter from MIE file represents movement per animation frame
                // Animations run at 10 fps (0.1s per frame), so speed * 10 = pixels/sec
                let speed_pixels_per_sec = *speed as f32 * 10.0;

                // Convert bounds from grid units (as stored in MIE) to Bevy pixel coordinates
                // Same transformation as entity positions:
                // 1. Grid to pixels: multiply by 8
                // 2. Add border offset: +8px top + 48px alignment
                // 3. Flip Y and center: 240 - y_pixels (screen height / 2)
                let top_pixels = *top_bound as f32 * 8.0 + 8.0 + 48.0;
                let bottom_pixels = *bottom_bound as f32 * 8.0 + 8.0 + 48.0;
                let top_centered = 240.0 - top_pixels; // Note: top becomes lower Y after flip
                let bottom_centered = 240.0 - bottom_pixels; // bottom becomes higher Y after flip

                velocity.y = speed_pixels_per_sec * behavior.state.direction as f32;
                position.y += velocity.y * dt;

                // After Y-flip, top_centered < bottom_centered, so swap logic
                if position.y <= top_centered {
                    position.y = top_centered;
                    behavior.state.direction = 1;
                } else if position.y >= bottom_centered {
                    position.y = bottom_centered;
                    behavior.state.direction = -1;
                }
            }

            (BehaviorType::AnimatedCollectible, BehaviorParams::AnimatedCollectible { .. }) => {
                // Animated collectibles are static but use animation
                velocity.x = 0.0;
                velocity.y = 0.0;
            }

            // TODO: Implement remaining behavior types
            _ => {
                // Placeholder for other behaviors
                velocity.x = 0.0;
                velocity.y = 0.0;
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
    mut sound_events: MessageWriter<SoundEvent>,
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
                    sound_events.write(SoundEvent::PlayEffect(sound_mappings::HIT.to_string()));

                    if player_health.current <= 0 {
                        game_state.lives -= 1;
                        // Play explosion sound on death
                        sound_events.write(SoundEvent::PlayEffect(
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
        // Get the animation descriptor to get the duration and frame indices
        if let Some(animation) = atlas_manager.get_animation(&animated.animation_name) {
            animated.timer += dt;

            // Use the duration from the atlas descriptor, not the hardcoded value
            if animated.timer >= animation.duration {
                animated.timer = 0.0;
                animated.current_frame_index =
                    (animated.current_frame_index + 1) % animation.frames.len();

                // Update sprite frame
                if animated.current_frame_index < animation.frames.len() {
                    let frame_id = animation.frames[animated.current_frame_index];
                    sprite_info.frame = frame_id as usize;
                }
            }
        }
    }
}

/// Avatar animation state system - determines which animation to play based on player state
pub fn avatar_animation_state_system(
    input_state: Res<InputState>,
    mut player_query: Query<(&Velocity, &Physics, &mut AvatarAnimation), With<Player>>,
) {
    for (velocity, physics, mut avatar_anim) in player_query.iter_mut() {
        // Determine animation based on player state
        let new_animation = if !physics.on_ground {
            if velocity.y > 100.0 {
                // Jumping up
                if velocity.x < -10.0 {
                    "jump_left"
                } else if velocity.x > 10.0 {
                    "jump_right"
                } else {
                    "jump_up"
                }
            } else {
                // Falling
                "fall"
            }
        } else if velocity.x.abs() > 10.0 {
            // Walking
            avatar_anim.facing_left = velocity.x < 0.0;
            if input_state.move_up {
                "walk_up"
            } else if velocity.x < 0.0 {
                "walk_left"
            } else {
                "walk_right"
            }
        } else {
            // Idle
            if input_state.move_down {
                "idle_down"
            } else {
                "idle"
            }
        };

        // Only change animation if it's different to reset frame timing
        if avatar_anim.current_animation != new_animation {
            avatar_anim.current_animation = new_animation.to_string();
            avatar_anim.current_frame_index = 0;
            avatar_anim.timer = 0.0;
        }
    }
}

/// Avatar animation update system - updates the sprite frame using SpriteInfo
pub fn avatar_animation_update_system(
    time: Res<Time>,
    atlas_manager: Res<AtlasManager>,
    mut player_query: Query<(&mut AvatarAnimation, &mut SpriteInfo), With<Player>>,
) {
    let dt = time.delta_secs();

    for (mut avatar_anim, mut sprite_info) in player_query.iter_mut() {
        if let Some(animation) = atlas_manager.get_avatar_animation(&avatar_anim.current_animation)
        {
            avatar_anim.timer += dt;

            // Check if we should advance to next frame
            if avatar_anim.timer >= animation.duration {
                avatar_anim.timer = 0.0;

                // Advance frame based on loop mode
                match animation.loop_mode {
                    crate::atlas::AnimationLoopMode::Loop => {
                        avatar_anim.current_frame_index =
                            (avatar_anim.current_frame_index + 1) % animation.frames.len();
                    }
                    crate::atlas::AnimationLoopMode::Once => {
                        if avatar_anim.current_frame_index < animation.frames.len() - 1 {
                            avatar_anim.current_frame_index += 1;
                        }
                    }
                    crate::atlas::AnimationLoopMode::PingPong => {
                        // TODO: Implement ping pong animation
                        avatar_anim.current_frame_index =
                            (avatar_anim.current_frame_index + 1) % animation.frames.len();
                    }
                }

                // Update sprite frame index
                if avatar_anim.current_frame_index < animation.frames.len() {
                    sprite_info.frame = animation.frames[avatar_anim.current_frame_index] as usize;
                }
            }
        }
    }
}

/// Avatar texture atlas rendering system - updates texture atlas index
pub fn avatar_texture_atlas_system(
    atlas_manager: Res<AtlasManager>,
    mut player_query: Query<(&SpriteInfo, &mut Sprite), (With<Player>, With<AvatarAnimation>)>,
) {
    if let (Some(ref _avatar_atlas), Some(ref layout_handle)) =
        (&atlas_manager.avatar_atlas, &atlas_manager.avatar_layout)
    {
        for (sprite_info, mut sprite) in player_query.iter_mut() {
            // Update texture atlas to show the specific frame
            sprite.texture_atlas = Some(TextureAtlas {
                layout: layout_handle.clone(),
                index: sprite_info.frame,
            });

            // Ensure the sprite uses the correct custom size (16x16)
            sprite.custom_size = Some(Vec2::new(16.0, 16.0));
        }
    }
}

/// Entity texture atlas rendering system - updates game entity sprites to use proper textures  
pub fn entity_texture_atlas_system(
    atlas_manager: Res<AtlasManager>,
    mut entity_query: Query<
        (&SpriteInfo, &mut Sprite),
        (With<GameEntity>, Without<Player>, Without<AnimatedEntity>),
    >,
) {
    if let (Some(ref _objects_atlas), Some(ref objects_layout)) =
        (&atlas_manager.objects_atlas, &atlas_manager.objects_layout)
    {
        for (sprite_info, mut sprite) in entity_query.iter_mut() {
            // Update entity to use texture atlas instead of solid color
            sprite.texture_atlas = Some(TextureAtlas {
                layout: objects_layout.clone(),
                index: sprite_info.frame.min(19), // objects-basic has 20 sprites (0-19)
            });

            // Remove the solid color now that we're using textures
            sprite.color = Color::WHITE;
            sprite.custom_size = Some(Vec2::new(16.0, 16.0));
        }
    } else {
        // Only warn once when atlas is not available
        let entity_count = entity_query.iter().count();
        if entity_count > 0 {
            warn!(
                "❌ Entity texture atlas not available: atlas={}, layout={} - {} entities waiting",
                atlas_manager.objects_atlas.is_some(),
                atlas_manager.objects_layout.is_some(),
                entity_count
            );
        }
    }
}

/// Animated entity texture atlas rendering system - updates animated entities with animations texture
pub fn animated_entity_texture_atlas_system(
    atlas_manager: Res<AtlasManager>,
    mut entity_query: Query<
        (&SpriteInfo, &mut Sprite),
        (With<AnimatedEntity>, With<GameEntity>, Without<Player>),
    >,
) {
    if let (Some(ref _animations_texture), Some(ref animations_layout)) = (
        &atlas_manager.animations_texture,
        &atlas_manager.animations_layout,
    ) {
        for (sprite_info, mut sprite) in entity_query.iter_mut() {
            // Update entity to use animations texture atlas
            sprite.texture_atlas = Some(TextureAtlas {
                layout: animations_layout.clone(),
                index: sprite_info.frame.min(63), // animations atlas has 64 sprites (0-63)
            });

            // Ensure proper rendering
            sprite.color = Color::WHITE;
            sprite.custom_size = Some(Vec2::new(16.0, 16.0));
        }
    }
}

/// Handle quitting the game when ESC is pressed
/// TODO: Add dedicated quit key separate from menu return
#[allow(dead_code)]
pub fn quit_system(
    input_state: Res<InputState>,
    mut app_exit_events: MessageWriter<bevy::app::AppExit>,
) {
    if input_state.quit {
        info!("ESC pressed - Quitting game");
        app_exit_events.write(bevy::app::AppExit::Success);
    }
}

/// Screenshot system - takes screenshot after specified time and exits
pub fn screenshot_system(
    mut commands: Commands,
    game_args: Res<crate::level::GameArgs>,
    time: Res<Time>,
    mut app_exit_events: MessageWriter<bevy::app::AppExit>,
    mut screenshot_timer: Local<f32>,
    mut screenshot_taken: Local<bool>,
) {
    if let Some(screenshot_delay) = game_args.screenshot {
        *screenshot_timer += time.delta_secs();

        if *screenshot_timer >= screenshot_delay && !*screenshot_taken {
            let level_name = if let Some(ref level_path) = game_args.level {
                // Extract level name from path (e.g., "assets/levels/FMIS01.ron" -> "FMIS01")
                std::path::Path::new(level_path)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("unknown")
            } else {
                "default"
            };

            info!(
                "📸 Screenshot mode: {} seconds elapsed for {}",
                screenshot_delay, level_name
            );

            // Use configurable output directory
            let output_dir = game_args.screenshot_dir.as_deref().unwrap_or("screenshots");

            // Create output directory if it doesn't exist
            let _ = std::fs::create_dir_all(output_dir);

            let screenshot_path = format!("{}/{}.png", output_dir, level_name);
            info!("📸 Taking actual screenshot: {}", screenshot_path);

            // Take screenshot using Bevy 0.17 API
            commands
                .spawn(bevy::render::view::screenshot::Screenshot::primary_window())
                .observe(bevy::render::view::screenshot::save_to_disk(
                    screenshot_path.clone(),
                ));

            info!("✅ Screenshot saved to: {}", screenshot_path);
            *screenshot_taken = true;

            // Exit after a short delay to ensure screenshot is saved
            info!("✅ Screenshot process completed, exiting in 1 second...");
        }

        // Exit after screenshot + 1 second delay
        if *screenshot_taken && *screenshot_timer >= screenshot_delay + 1.0 {
            app_exit_events.write(bevy::app::AppExit::Success);
        }
    }
}
