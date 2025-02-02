use bevy::prelude::*;
use bevy::sprite::{Sprite, TextureAtlas, TextureAtlasLayout};
use crate::components::*;
use crate::level::{LEVEL_WIDTH, LEVEL_HEIGHT};

#[derive(Resource)]
pub struct SpriteSheetHandle {
    pub texture: Handle<Image>,
    pub layout: Handle<TextureAtlasLayout>,
}

/// Loads the spritesheet and creates a texture atlas layout from a 4×4 grid of 16×16 sprites.
/// The image is expected at assets/spritesheet.png.
pub fn setup_texture_atlas(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    mut texture_atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
) {
    let texture_handle = asset_server.load("spritesheet.png");
    // Create a layout for a 4x4 grid where each cell is 16×16 pixels.
    let layout = TextureAtlasLayout::from_grid(UVec2::splat(16), 4, 4, None, None);
    let layout_handle = texture_atlas_layouts.add(layout);
    commands.insert_resource(SpriteSheetHandle {
        texture: texture_handle,
        layout: layout_handle,
    });
}

/// Sets up the level by spawning a grid of background tiles, the player, and a sample collectible.
pub fn setup_level(
    mut commands: Commands,
    sprite_sheet: Res<SpriteSheetHandle>,
) {
    // Spawn background tiles.
    for y in 0..LEVEL_HEIGHT {
        for x in 0..LEVEL_WIDTH {
            commands.spawn((
                Sprite::from_atlas_image(
                    sprite_sheet.texture.clone(),
                    TextureAtlas {
                        layout: sprite_sheet.layout.clone(),
                        index: 0, // Tile sprite index.
                    },
                ),
                Transform::from_translation(Vec3::new(x as f32 * 16.0, y as f32 * 16.0, 0.0)),
                Tile,
            ));
        }
    }

    // Spawn the player with animation.
    commands.spawn((
        Sprite::from_atlas_image(
            sprite_sheet.texture.clone(),
            TextureAtlas {
                layout: sprite_sheet.layout.clone(),
                index: 1, // Player's initial sprite.
            },
        ),
        Transform::from_translation(Vec3::new(100.0, 100.0, 1.0)),
        Player { lives: 3 },
        AnimationIndices { first: 1, last: 4 }, // Walking animation frames from index 1 to 4.
        AnimationTimer(Timer::from_seconds(0.2, TimerMode::Repeating)),
    ));

    // Spawn a sample collectible.
    commands.spawn((
        Sprite::from_atlas_image(
            sprite_sheet.texture.clone(),
            TextureAtlas {
                layout: sprite_sheet.layout.clone(),
                index: 5, // Collectible sprite index.
            },
        ),
        Transform::from_translation(Vec3::new(200.0, 100.0, 1.0)),
        Collectible,
    ));
}

/// Handles left/right input for the player.
/// Moves the player horizontally.
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
/// On collision (using a simple distance threshold), the collectible is despawned.
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
