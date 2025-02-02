use bevy::prelude::*;
use bevy::sprite::{Sprite, TextureAtlas, TextureAtlasLayout};
use crate::components::*;
use crate::level::{LEVEL_WIDTH, LEVEL_HEIGHT};

/// A resource that holds both the spritesheet texture and its atlas layout.
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
                Sprite {
                    image: sprite_sheet.texture.clone(),
                    // For tiles we use the sprite at index 0.
                    texture_atlas: Some(TextureAtlas {
                        layout: sprite_sheet.layout.clone(),
                        index: 0,
                    }),
                    ..Default::default()
                },
                Transform::from_translation(Vec3::new(x as f32 * 16.0, y as f32 * 16.0, 0.0)),
                Tile,
            ));
        }
    }

    // Spawn the player.
    commands.spawn((
        Sprite {
            image: sprite_sheet.texture.clone(),
            // The player's initial sprite is at index 1.
            texture_atlas: Some(TextureAtlas {
                layout: sprite_sheet.layout.clone(),
                index: 1,
            }),
            ..Default::default()
        },
        Transform::from_translation(Vec3::new(100.0, 100.0, 1.0)),
        Player { lives: 3 },
        Animation {
            current_frame: 0,
            frame_timer: Timer::from_seconds(0.2, TimerMode::Repeating),
            // Define a walking animation using sprite indices.
            frames: vec![1, 2, 3, 4],
        },
    ));

    // Spawn a sample collectible.
    commands.spawn((
        Sprite {
            image: sprite_sheet.texture.clone(),
            // The collectible uses the sprite at index 5.
            texture_atlas: Some(TextureAtlas {
                layout: sprite_sheet.layout.clone(),
                index: 5,
            }),
            ..Default::default()
        },
        Transform::from_translation(Vec3::new(200.0, 100.0, 1.0)),
        Collectible,
    ));
}

/// Handles left/right input for the player.
/// Moves the player horizontally and advances the animation timer.
pub fn player_input(
    keyboard_input: Res<Input<KeyCode>>,
    time: Res<Time>,
    mut query: Query<(&mut Transform, &mut Animation), With<Player>>,
) {
    for (mut transform, mut animation) in query.iter_mut() {
        let mut direction = 0.0;
        if keyboard_input.pressed(KeyCode::Left) {
            direction -= 1.0;
        }
        if keyboard_input.pressed(KeyCode::Right) {
            direction += 1.0;
        }
        transform.translation.x += direction * 100.0 * time.delta_seconds();

        // Advance the animation timer.
        animation.frame_timer.tick(time.delta());
        if animation.frame_timer.finished() {
            animation.current_frame = (animation.current_frame + 1) % animation.frames.len();
        }
    }
}

/// Advances animations for entities with an Animation component.
/// This system updates the sprite's atlas index to display the correct frame.
pub fn animation_system(
    time: Res<Time>,
    mut query: Query<(&mut Animation, &mut Sprite)>,
) {
    for (mut animation, mut sprite) in query.iter_mut() {
        animation.frame_timer.tick(time.delta());
        if animation.frame_timer.finished() {
            animation.current_frame = (animation.current_frame + 1) % animation.frames.len();
            if let Some(ref mut atlas) = sprite.texture_atlas {
                atlas.index = animation.frames[animation.current_frame] as u32;
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
        transform.translation.y -= 9.8 * time.delta_seconds();
    }
}

/// Checks for collisions between the player and collectibles.
/// On collision (using a simple distance threshold), the collectible is despawned and the HUD score is increased.
pub fn collision_system(
    mut commands: Commands,
    mut hud_state: ResMut<HudState>,
    player_query: Query<&Transform, With<Player>>,
    collectible_query: Query<(Entity, &Transform), With<Collectible>>,
) {
    for player_transform in player_query.iter() {
        for (entity, transform) in collectible_query.iter() {
            if player_transform.translation.distance(transform.translation) < 16.0 {
                commands.entity(entity).despawn();
                hud_state.score += 10;
                println!("Collected an item! Score: {}", hud_state.score);
            }
        }
    }
}

/// Updates the HUD. In this minimal demo, we simply print the current HUD state to the console.
pub fn hud_update_system(hud_state: Res<HudState>) {
    println!(
        "HUD Update - Score: {}, Level Password: {:?}",
        hud_state.score, hud_state.level_password
    );
}
