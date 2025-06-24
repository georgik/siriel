use bevy::app::AppExit;
use bevy::prelude::*;
use bevy::sprite::{Sprite, TextureAtlas, TextureAtlasLayout};
use crate::components::*;
use crate::components::{PlayerState, PlayerDirection};
use crate::level::{TiledMap, TiledLayer};
use std::fs;

#[derive(Resource)]
pub struct SpriteSheetHandle {
    pub texture: Handle<Image>,
    pub layout: Handle<TextureAtlasLayout>,
}

#[derive(Resource)]
pub struct PlayerSpriteSheet {
    pub texture: Handle<Image>,
    pub layout: Handle<TextureAtlasLayout>,
}

/// Spawns a 2D camera so that our sprites are visible.
/// Note: In Bevy 0.15, simply spawning the `Camera2d` component automatically inserts
/// the necessary Transform and Visibility components.
pub fn setup_camera(mut commands: Commands) {
    commands.spawn(Camera2d::default());
}

/// Loads the tileset image (assets/textures.png) and creates a texture atlas layout
pub fn setup_texture_atlas(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    mut texture_atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
) {
    let texture_handle = asset_server.load("textures.png");
    // Create a layout for a 20x5 grid (100 tiles) where each tile is 16×16
    // This matches the original Siriel game's sprite arrangement
    let layout = TextureAtlasLayout::from_grid(UVec2::splat(16), 20, 5, None, None);
    let layout_handle = texture_atlas_layouts.add(layout);
    commands.insert_resource(SpriteSheetHandle {
        texture: texture_handle,
        layout: layout_handle,
    });
    
    // Load the player avatar spritesheet (siriel-avatar.png)
    let player_texture_handle = asset_server.load("siriel-avatar.png");
    // Create a layout for the player animation: 16 columns x 4 rows (16x16 tiles)
    // Row 0: 4 sprites idle/walking down
    // Row 1: 4 sprites walking left + 4 sprites walking right
    // Row 2: 8 sprites jump up + 3 sprites parachute animation
    // Row 3: 8 sprites jump up-left + 4 sprites walk up
    // Row 4: 8 sprites jump up-right + back/none button + 4 sparkle sprites
    let player_layout = TextureAtlasLayout::from_grid(UVec2::splat(16), 16, 4, None, None);
    let player_layout_handle = texture_atlas_layouts.add(player_layout);
    commands.insert_resource(PlayerSpriteSheet {
        texture: player_texture_handle,
        layout: player_layout_handle,
    });
}

/// Loads the level from a Tiled JSON file and spawns game entities
pub fn setup_level_from_tiled(
    mut commands: Commands,
    sprite_sheet: Res<SpriteSheetHandle>,
    player_sprite_sheet: Res<PlayerSpriteSheet>,
    mut game_state: ResMut<GameState>,
) {
    // Load the level file
    let level_path = "assets/maps/level1.json";
    let level_data = fs::read_to_string(level_path)
        .expect(&format!("Failed to read level file at {}", level_path));

    // Deserialize the JSON into a TiledMap
    let tiled_map: TiledMap = serde_json::from_str(&level_data)
        .expect("Failed to parse Tiled map JSON");

    let mut collectibles_count = 0;
    let mut player_spawned = false;

    // Process each layer
    for layer in tiled_map.layers {
        match layer {
            TiledLayer::TileLayer { name, data, width, height: declared_height, .. } if name == "Background" => {
                // Process tile layer for platforms and terrain
                let effective_height = (data.len() as u32) / width;
                if effective_height != declared_height {
                    warn!("Tile layer declared height {} but data contains {} rows", declared_height, data.len());
                }
                
                for row in 0..effective_height {
                    for col in 0..width {
                        let idx = (row * width + col) as usize;
                        if let Some(&gid) = data.get(idx) {
                            if gid == 0 {
                                continue; // Skip empty tiles
                            }
                            
                            let pos_x = (col as f32) * (tiled_map.tilewidth as f32);
                            let pos_y = (effective_height as f32 * tiled_map.tileheight as f32) - (row as f32 + 1.0) * (tiled_map.tileheight as f32);
                            
                            // Determine tile type based on GID
                            let is_solid = match gid {
                                2..=9 => true,  // Platform tiles (solid)
                                _ => false,
                            };
                            
                            let mut tile_entity = commands.spawn((
                                Sprite::from_atlas_image(
                                    sprite_sheet.texture.clone(),
                                    TextureAtlas {
                                        layout: sprite_sheet.layout.clone(),
                                        index: (gid - 1) as usize,
                                    },
                                ),
                                Transform::from_translation(Vec3::new(pos_x, pos_y, 0.0)),
                                TileType {
                                    tile_id: gid,
                                    solid: is_solid,
                                    deadly: false,
                                },
                            ));
                            
                            if is_solid {
                                tile_entity.insert(SolidTile);
                            } else {
                                tile_entity.insert(BackgroundTile);
                            }
                        }
                    }
                }
            }
            TiledLayer::ObjectLayer { name, objects, .. } if name == "Objects" => {
                // Process objects (collectibles, player spawn, etc.)
                for obj in objects {
                    let tile_index = match obj.name.as_str() {
                        "pear" => 11,
                        "coin" => 12,
                        "cherry" => 13,
                        "apple" => 10,
                        _ => 0,
                    };
                    
                    // Convert Tiled coordinates (top-left origin) to Bevy coordinates (center origin)
                    let pos_x = obj.x;
                    let pos_y = (tiled_map.height * tiled_map.tileheight) as f32 - obj.y - 16.0;
                    
                    if obj.object_type == "collectible" {
                        collectibles_count += 1;
                        let value = match obj.name.as_str() {
                            "cherry" => 5,
                            "pear" => 10,
                            "apple" => 15,
                            "coin" => 50,
                            _ => 10,
                        };
                        
                        commands.spawn((
                            Sprite::from_atlas_image(
                                sprite_sheet.texture.clone(),
                                TextureAtlas {
                                    layout: sprite_sheet.layout.clone(),
                                    index: tile_index,
                                },
                            ),
                            Transform::from_translation(Vec3::new(pos_x, pos_y, 1.0)),
                            Collectible {
                                value,
                                collected: false,
                            },
                        ));
                    }
                }
            }
            _ => {}
        }
    }
    
    // Spawn player at starting position if not already spawned
    if !player_spawned {
        let start_x = 88.0; // From level properties
        let start_y = 300.0; // Adjusted for screen coordinates
        
        commands.spawn((
            Sprite::from_atlas_image(
                player_sprite_sheet.texture.clone(),
                TextureAtlas {
                    layout: player_sprite_sheet.layout.clone(),
                    index: 0, // Start with first idle sprite (row 0, col 0)
                },
            ),
            Transform::from_translation(Vec3::new(start_x, start_y, 2.0)),
            Player {
                lives: 3,
                score: 0,
                on_ground: false,
                jump_speed: 200.0,
                move_speed: 120.0,
                state: PlayerState::Idle,
                direction: PlayerDirection::Down,
            },
            Physics {
                velocity: Vec2::ZERO,
                on_ground: false,
                gravity: 500.0,
                max_fall_speed: 300.0,
            },
            PlayerAnimation {
                current_frame: 0,
                frame_timer: 0.0,
                frame_duration: 0.2, // 200ms per frame
            },
            CameraTarget,
        ));
    }
    
    // Update game state
    game_state.collectibles_remaining = collectibles_count;
}

/// Handles player input for movement and jumping like original Siriel
pub fn player_input(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut query: Query<(&mut Physics, &mut Player)>,
) {
    for (mut physics, mut player) in query.iter_mut() {
        // Horizontal movement
        let mut horizontal_input = 0.0;
        if keyboard_input.pressed(KeyCode::ArrowLeft) || keyboard_input.pressed(KeyCode::KeyA) {
            horizontal_input -= 1.0;
            player.direction = PlayerDirection::Left;
        }
        if keyboard_input.pressed(KeyCode::ArrowRight) || keyboard_input.pressed(KeyCode::KeyD) {
            horizontal_input += 1.0;
            player.direction = PlayerDirection::Right;
        }
        
        // Apply horizontal movement
        physics.velocity.x = horizontal_input * player.move_speed;
        
        // Update player state based on movement
        if physics.on_ground {
            if horizontal_input.abs() > 0.0 {
                player.state = PlayerState::Walking;
            } else {
                player.state = PlayerState::Idle;
            }
        } else {
            if physics.velocity.y > 0.0 {
                player.state = PlayerState::Jumping;
            } else {
                player.state = PlayerState::Falling;
                // Add parachute logic here if falling for too long
            }
        }
        
        // Jumping (only when on ground)
        if (keyboard_input.just_pressed(KeyCode::Space) || 
            keyboard_input.just_pressed(KeyCode::ArrowUp) || 
            keyboard_input.just_pressed(KeyCode::KeyW)) && physics.on_ground {
            physics.velocity.y = player.jump_speed;
            physics.on_ground = false;
            player.state = PlayerState::Jumping;
        }
    }
}

/// Handles player animation based on state and direction like original Siriel
pub fn player_animation_system(
    time: Res<Time>,
    mut query: Query<(&Player, &mut PlayerAnimation, &mut Sprite)>,
) {
    for (player, mut animation, mut sprite) in query.iter_mut() {
        animation.frame_timer += time.delta_secs();
        
        // Calculate sprite index based on player state and direction
        let (base_index, frame_count) = match (player.state, player.direction) {
            // Row 0: Idle/Walking down (4 sprites: 0-3)
            (PlayerState::Idle, PlayerDirection::Down) => (0, 1), // Just first sprite for idle
            (PlayerState::Walking, PlayerDirection::Down) => (0, 4), // All 4 sprites for walking
            
            // Row 1: Walking left (4 sprites: 16-19), Walking right (4 sprites: 20-23)
            (PlayerState::Idle, PlayerDirection::Left) => (16, 1), // First left sprite for idle
            (PlayerState::Walking, PlayerDirection::Left) => (16, 4), // All left walking sprites
            (PlayerState::Idle, PlayerDirection::Right) => (20, 1), // First right sprite for idle  
            (PlayerState::Walking, PlayerDirection::Right) => (20, 4), // All right walking sprites
            
            // Row 2: Jump up (8 sprites: 32-39), Parachute (3 sprites: 40-42)
            (PlayerState::Jumping, PlayerDirection::Down) => (32, 8),
            (PlayerState::Falling, PlayerDirection::Down) => (32, 8), // Use jump sprites for falling
            (PlayerState::Parachuting, _) => (40, 3),
            
            // Row 3: Jump up-left (8 sprites: 48-55), Walk up (4 sprites: 56-59)
            (PlayerState::Jumping, PlayerDirection::Left) => (48, 8),
            (PlayerState::Falling, PlayerDirection::Left) => (48, 8),
            (PlayerState::Walking, PlayerDirection::Up) => (56, 4),
            (PlayerState::Idle, PlayerDirection::Up) => (56, 1),
            
            // Row 4: Jump up-right (8 sprites: 64-71)
            (PlayerState::Jumping, PlayerDirection::Right) => (64, 8),
            (PlayerState::Falling, PlayerDirection::Right) => (64, 8),
            
            // Default fallback
            _ => (0, 1),
        };
        
        // Update animation frame
        if animation.frame_timer >= animation.frame_duration {
            animation.frame_timer = 0.0;
            animation.current_frame = (animation.current_frame + 1) % frame_count;
        }
        
        // Update sprite atlas index
        if let Some(ref mut atlas) = sprite.texture_atlas {
            atlas.index = base_index + animation.current_frame;
        }
    }
}

/// Advances animations for entities with AnimationIndices and AnimationTimer components.
pub fn animation_system(
    time: Res<Time>,
    mut query: Query<(&AnimationIndices, &mut AnimationTimer, &mut Sprite)>,
) {
    for (indices, mut timer, mut sprite) in query.iter_mut() {
        timer.tick(time.delta());
        if timer.just_finished() {
            if let Some(ref mut atlas) = sprite.texture_atlas {
                atlas.index = if atlas.index == indices.last {
                    indices.first
                } else {
                    atlas.index + 1
                };
            }
        }
    }
}

/// Applies gravity and handles physics like the original Siriel game
pub fn physics_system(
    mut physics_query: Query<(&mut Transform, &mut Physics)>,
    tile_query: Query<&Transform, (With<SolidTile>, Without<Physics>)>,
    time: Res<Time>,
) {
    let delta = time.delta_secs();
    
    for (mut transform, mut physics) in physics_query.iter_mut() {
        // Apply gravity
        physics.velocity.y -= physics.gravity * delta;
        
        // Limit fall speed
        if physics.velocity.y < -physics.max_fall_speed {
            physics.velocity.y = -physics.max_fall_speed;
        }
        
        // Store current position for collision checking
        let old_pos = transform.translation;
        let new_x = old_pos.x + physics.velocity.x * delta;
        let new_y = old_pos.y + physics.velocity.y * delta;
        
        // Check horizontal collision
        let mut can_move_x = true;
        for tile_transform in tile_query.iter() {
            if check_collision(
                Vec2::new(new_x, old_pos.y),
                Vec2::splat(16.0),
                tile_transform.translation.xy(),
                Vec2::splat(16.0),
            ) {
                can_move_x = false;
                physics.velocity.x = 0.0;
                break;
            }
        }
        
        // Check vertical collision
        let mut can_move_y = true;
        physics.on_ground = false;
        
        for tile_transform in tile_query.iter() {
            if check_collision(
                Vec2::new(if can_move_x { new_x } else { old_pos.x }, new_y),
                Vec2::splat(16.0),
                tile_transform.translation.xy(),
                Vec2::splat(16.0),
            ) {
                can_move_y = false;
                
                // Check if landing on top of platform
                if physics.velocity.y < 0.0 && old_pos.y > tile_transform.translation.y {
                    physics.on_ground = true;
                    physics.velocity.y = 0.0;
                    transform.translation.y = tile_transform.translation.y + 16.0;
                } else {
                    physics.velocity.y = 0.0;
                }
                break;
            }
        }
        
        // Apply movement
        if can_move_x {
            transform.translation.x = new_x;
        }
        if can_move_y {
            transform.translation.y = new_y;
        }
    }
}

/// Simple AABB collision detection
fn check_collision(pos1: Vec2, size1: Vec2, pos2: Vec2, size2: Vec2) -> bool {
    let half_size1 = size1 / 2.0;
    let half_size2 = size2 / 2.0;
    
    pos1.x - half_size1.x < pos2.x + half_size2.x &&
    pos1.x + half_size1.x > pos2.x - half_size2.x &&
    pos1.y - half_size1.y < pos2.y + half_size2.y &&
    pos1.y + half_size1.y > pos2.y - half_size2.y
}

/// Handles collisions between player and collectibles/hazards
pub fn collision_system(
    mut commands: Commands,
    mut game_state: ResMut<GameState>,
    player_query: Query<&Transform, With<Player>>,
    mut collectible_query: Query<(Entity, &Transform, &mut Collectible)>,
    hazard_query: Query<(&Transform, &Hazard), Without<Player>>,
) {
    for player_transform in player_query.iter() {
        // Check collectible collisions
        for (entity, transform, mut collectible) in collectible_query.iter_mut() {
            if !collectible.collected && 
               check_collision(
                   player_transform.translation.xy(),
                   Vec2::splat(16.0),
                   transform.translation.xy(),
                   Vec2::splat(16.0),
               ) {
                collectible.collected = true;
                game_state.score += collectible.value;
                game_state.collectibles_remaining = game_state.collectibles_remaining.saturating_sub(1);
                commands.entity(entity).despawn();
                println!("Collected item! Score: {}, Remaining: {}", 
                        game_state.score, game_state.collectibles_remaining);
                
                // Check level completion
                if game_state.collectibles_remaining == 0 {
                    game_state.level_complete = true;
                    println!("Level Complete!");
                }
            }
        }
        
        // Check hazard collisions
        for (hazard_transform, hazard) in hazard_query.iter() {
            if check_collision(
                player_transform.translation.xy(),
                Vec2::splat(16.0),
                hazard_transform.translation.xy(),
                Vec2::splat(16.0),
            ) {
                game_state.lives = game_state.lives.saturating_sub(hazard.damage);
                println!("Hit hazard! Lives remaining: {}", game_state.lives);
                
                if game_state.lives == 0 {
                    game_state.game_over = true;
                    println!("Game Over!");
                }
            }
        }
    }
}

/// Quits the application when the ESC key is pressed.
pub fn exit_on_esc(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut exit: EventWriter<AppExit>,
) {
    if keyboard_input.just_pressed(KeyCode::Escape) {
        exit.send(AppExit::Success);
    }
}
