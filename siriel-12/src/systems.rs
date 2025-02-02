use bevy::prelude::*;
use bevy::sprite::{Sprite, TextureAtlas, TextureAtlasLayout};
use crate::components::*;
use crate::level::{TiledMap, TiledLayer, TiledObject};
use std::fs;

#[derive(Resource)]
pub struct SpriteSheetHandle {
    pub texture: Handle<Image>,
    pub layout: Handle<TextureAtlasLayout>,
}

/// Loads the tileset image (assets/textures.png) and creates a texture atlas assuming a 4×4 grid (16×16 tiles).
pub fn setup_texture_atlas(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    mut texture_atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
) {
    let texture_handle = asset_server.load("textures.png");
    // Create a layout for a 4x4 grid (i.e. 16 tiles) where each tile is 16×16.
    let layout = TextureAtlasLayout::from_grid(UVec2::splat(16), 4, 4, None, None);
    let layout_handle = texture_atlas_layouts.add(layout);
    commands.insert_resource(SpriteSheetHandle {
        texture: texture_handle,
        layout: layout_handle,
    });
}

/// Loads the level from a Tiled JSON file (assets/maps/level1.json) and spawns background and object entities.
pub fn setup_level_from_tiled(
    mut commands: Commands,
    sprite_sheet: Res<SpriteSheetHandle>,
) {
    // Load the level file.
    let level_path = "assets/maps/level1.json";
    let level_data = fs::read_to_string(level_path)
        .expect(&format!("Failed to read level file at {}", level_path));

    // Deserialize the JSON into a TiledMap.
    let tiled_map: TiledMap = serde_json::from_str(&level_data)
        .expect("Failed to parse Tiled map JSON");

    // Process each layer.
    for layer in tiled_map.layers {
        match layer {
            TiledLayer::TileLayer { name, data, width, height, .. } if name == "Background" => {
                // Spawn a sprite for each nonzero tile.
                // (Tiled GIDs are 1-indexed; subtract one for our texture atlas.)
                for row in 0..height {
                    for col in 0..width {
                        let idx = (row * width + col) as usize;
                        let gid = data[idx];
                        if gid == 0 {
                            continue; // Skip empty tiles.
                        }
                        let pos_x = (col as f32) * (tiled_map.tilewidth as f32);
                        let pos_y = (row as f32) * (tiled_map.tileheight as f32);
                        commands.spawn((
                            Sprite::from_atlas_image(
                                sprite_sheet.texture.clone(),
                                TextureAtlas {
                                    layout: sprite_sheet.layout.clone(),
                                    index: (gid - 1) as usize, // convert 1-indexed to 0-indexed.
                                },
                            ),
                            Transform::from_translation(Vec3::new(pos_x, pos_y, 0.0)),
                            // Optionally add a Tile marker component here.
                        ));
                    }
                }
            }
            TiledLayer::ObjectLayer { name, objects, .. } if name == "Objects" => {
                // For each object, spawn an entity. Here we map object names to tile indices.
                for obj in objects {
                    // Adjust this mapping to match your tileset.
                    let tile_index = match obj.name.as_str() {
                        "pear" => 1,
                        "coin" => 2,
                        "cherry" => 3,
                        _ => 0,
                    };
                    let mut entity_commands = commands.spawn((
                        Sprite::from_atlas_image(
                            sprite_sheet.texture.clone(),
                            TextureAtlas {
                                layout: sprite_sheet.layout.clone(),
                                index: tile_index,
                            },
                        ),
                        Transform::from_translation(Vec3::new(obj.x, obj.y, 1.0)),
                    ));
                    // Insert a marker component based on the object type.
                    if obj.object_type == "collectible" {
                        entity_commands.insert(Collectible);
                    }
                    // (You can handle other object types similarly.)
                }
            }
            _ => {}
        }
    }
}

/// Handles left/right input for the player.
pub fn player_input(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    time: Res<Time>,
    mut query: Query<&mut Transform, With<Player>>,
) {
    for mut transform in query.iter_mut() {
        let mut direction = 0.0;
        if keyboard_input.pressed(KeyCode::ArrowLeft) {
            direction -= 1.0;
        }
        if keyboard_input.pressed(KeyCode::ArrowRight) {
            direction += 1.0;
        }
        transform.translation.x += direction * 100.0 * time.delta_secs();
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

/// Applies a simple gravity effect to the player.
pub fn physics_system(
    mut query: Query<&mut Transform, With<Player>>,
    time: Res<Time>,
) {
    for mut transform in query.iter_mut() {
        transform.translation.y -= 9.8 * time.delta_secs();
    }
}

/// Checks for collisions between the player and collectibles.
pub fn collision_system(
    mut commands: Commands,
    player_query: Query<&Transform, With<Player>>,
    collectible_query: Query<(Entity, &Transform), With<Collectible>>,
) {
    for player_transform in player_query.iter() {
        for (entity, transform) in collectible_query.iter() {
            if player_transform.translation.distance(transform.translation) < 16.0 {
                commands.entity(entity).despawn();
                println!("Collected an item!");
            }
        }
    }
}
