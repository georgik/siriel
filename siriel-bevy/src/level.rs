use crate::atlas::AtlasManager;
use crate::components::*;
use crate::components::{BehaviorParams, BehaviorType};
use crate::menu::SelectedLevel;
use crate::resources::*;
use bevy::prelude::*;
use bevy_ecs_tilemap::prelude::*;
use ron::ser::{to_string_pretty, PrettyConfig};
use serde::{Deserialize, Serialize};
// MIE parser is no longer used in game engine - only in converter

/// Resource to store CLI arguments for use in Bevy systems
#[derive(Resource)]
pub struct GameArgs {
    pub level: Option<String>,
    pub verbose: bool,
    pub screenshot: Option<f32>, // Screenshot after N seconds, then quit
    pub screenshot_dir: Option<String>, // Directory to save screenshots
}

/// Level data structure - modern replacement for .MIE format
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LevelData {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub spawn_point: (f32, f32),
    pub background_image: Option<String>,
    pub tilemap: Vec<Vec<u16>>,
    pub entities: Vec<LevelEntity>,
    pub transitions: Vec<LevelTransition>,
    pub scripts: Vec<LevelScript>,
    pub messages: Vec<String>, // MSG1-MSG5 from original MIE files
    pub music: Option<String>,
    pub time_limit: Option<f32>,
}

/// Decoded entity code properties from the 4-character MIE entity code
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct EntityCodeProps {
    pub interaction_kind: InteractionKind,
    pub animated: bool,
    pub danger: DangerLevel,
    pub appear: AppearCondition,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum InteractionKind {
    PickupWalk,   // Z - pickup by walking over
    SpecialTouch, // Y - special action on immediate touch
    SpecialEnter, // X - special action when pressing Enter
    Use,          // W - use object (doors, switches)
    Talk,         // V - talk/NPC dialog
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum DangerLevel {
    None,   // N - harmless
    Mortal, // S - kills player on contact
    NoGod,  // D - special hazard that bypasses invincibility
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AppearCondition {
    pub mode: AppearMode,
    pub group_char: Option<char>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum AppearMode {
    Immediate,          // A - visible from level start
    Group,              // any letter - appears when group is activated
    ExitOnAllCollected, // ~ - appears when all collectibles gathered
}

/// Entity definition in level data
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LevelEntity {
    pub id: String,
    pub entity_type: String,
    pub position: (f32, f32),
    pub sprite_id: u16,
    pub behavior_type: BehaviorType,
    pub behavior_params: BehaviorParams,
    pub room: u8,
    pub pickupable: bool,
    pub pickup_value: u32,
    pub sound_effects: Option<(u8, u8)>,
    pub entity_props: Option<EntityCodeProps>, // Decoded entity code properties
}

/// Level transition (doors, teleports, etc.)
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LevelTransition {
    pub from_area: (f32, f32, f32, f32), // x, y, width, height
    pub to_level: String,
    pub to_position: (f32, f32),
    pub transition_type: String, // "door", "teleport", "stairs", etc.
    pub required_item: Option<String>,
}

/// Script for interactive elements and cutscenes
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LevelScript {
    pub id: String,
    pub trigger_type: String, // "interact", "collision", "timer", etc.
    pub trigger_area: Option<(f32, f32, f32, f32)>,
    pub commands: Vec<ScriptCommand>,
}

/// Modern script command - replaces the original Slovak system
#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum ScriptCommand {
    // Text and dialog
    ShowText {
        text: String,
        speaker: Option<String>,
    },
    ShowDialog {
        speaker: String,
        text: String,
        choices: Option<Vec<String>>,
    },

    // Game state
    SetVariable {
        name: String,
        value: i32,
    },
    CheckVariable {
        name: String,
        value: i32,
        goto_script: String,
    },
    GiveItem {
        item_id: String,
    },
    RemoveItem {
        item_id: String,
    },
    CheckItem {
        item_id: String,
        goto_script: String,
    },

    // Player actions
    AddScore {
        points: u32,
    },
    AddLife {
        lives: i32,
    },
    SetPosition {
        x: f32,
        y: f32,
    },
    TransferToLevel {
        level: String,
        position: (f32, f32),
    },

    // Audio/Visual
    PlaySound {
        sound_id: String,
    },
    PlayMusic {
        music_id: String,
    },
    ShowImage {
        image_path: String,
        duration: Option<f32>,
    },
    FadeOut {
        duration: f32,
    },
    FadeIn {
        duration: f32,
    },

    // Tilemap changes
    ChangeTile {
        x: u32,
        y: u32,
        tile_id: u16,
    },
    ChangeTileArea {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
        tile_id: u16,
    },

    // Entity manipulation
    SpawnEntity {
        entity: LevelEntity,
    },
    RemoveEntity {
        entity_id: String,
    },
    SetEntityBehavior {
        entity_id: String,
        behavior_type: BehaviorType,
        behavior_params: BehaviorParams,
    },

    // Flow control
    Wait {
        duration: f32,
    },
    WaitForKey,
    GotoScript {
        script_id: String,
    },
    EndScript,

    // Game mechanics
    SetFreezTimer {
        duration: f32,
        sound: Option<String>,
    },
    SetGodMode {
        duration: f32,
        sound: Option<String>,
    },
    EndLevel,
}

/// Tilemap component for level rendering
#[derive(Resource, Default)]
pub struct TilemapManager {
    pub current_level: Option<LevelData>,
    /// TODO: Track tilemap entity for cleanup/updates
    #[allow(dead_code)]
    pub tilemap_entity: Option<Entity>,
    /// TODO: Use for coordinate-to-tile calculations
    #[allow(dead_code)]
    pub tile_size: TilemapTileSize,
    #[allow(dead_code)]
    pub map_size: TilemapSize,
}

/// Component to mark game entities for cleanup when switching levels
#[derive(Component)]
pub struct GameEntity;

/// Component to mark tilemap entities for cleanup when switching levels
#[derive(Component)]
pub struct GameTilemap;

/// System to clean up previous level before loading new one
pub fn cleanup_previous_level(
    mut commands: Commands,
    mut tilemap_manager: ResMut<TilemapManager>,
    game_entities: Query<Entity, With<GameEntity>>,
    tilemap_entities: Query<Entity, With<GameTilemap>>,
    all_tiles: Query<Entity, With<TilePos>>,
) {
    // Remove all game entities
    for entity in game_entities.iter() {
        commands.entity(entity).despawn();
    }

    // Remove all tilemap entities
    for entity in tilemap_entities.iter() {
        commands.entity(entity).despawn();
    }

    // Remove all individual tiles
    for entity in all_tiles.iter() {
        commands.entity(entity).despawn();
    }

    // Clear the current level data so it doesn't get reused
    tilemap_manager.current_level = None;
}

/// System to load a level from RON format with CLI support
pub fn load_level_system(
    mut commands: Commands,
    mut tilemap_manager: ResMut<TilemapManager>,
    sprite_atlas: Res<SpriteAtlas>,
    atlas_manager: Res<AtlasManager>,
    game_args: Res<GameArgs>,
    selected_level: Option<Res<SelectedLevel>>,
    _asset_server: Res<AssetServer>,
) {
    let level = if let Some(selected) = selected_level {
        // Level selected from menu
        load_level_by_path(&selected.path, game_args.verbose)
    } else if let Some(level_path) = &game_args.level {
        // CLI level file specified
        load_level_by_path(level_path, game_args.verbose)
    } else {
        // Default fallback chain
        load_default_level()
    };

    if sprite_atlas.loaded && sprite_atlas.tiles_texture.is_some() {
        spawn_tilemap_with_atlas(&mut commands, &level, &sprite_atlas, Some(&*atlas_manager));
        tilemap_manager.current_level = Some(level);
    }
}

/// Load level by CLI-specified path (RON files only)
fn load_level_by_path(level_path: &str, verbose: bool) -> LevelData {
    // Log current working directory for debugging
    match std::env::current_dir() {
        Ok(cwd) => info!("📂 Current working directory: {}", cwd.display()),
        Err(e) => warn!("❌ Could not get current working directory: {}", e),
    }

    info!("🎯 Loading CLI-specified level file: {}", level_path);

    // Check if file exists before attempting to load
    let exists = std::path::Path::new(level_path).exists();
    if verbose {
        info!("🔍 Checking file: {} (exists: {})", level_path, exists);
    }

    match load_level_from_file(level_path) {
        Ok(level) => {
            info!(
                "✅ Successfully loaded RON level: {} from {}",
                level.name, level_path
            );
            level
        }
        Err(e) => {
            warn!("❌ Failed to load RON file {}: {}", level_path, e);
            warn!("💡 Hint: Check that the file path is correct and the file exists");
            create_test_level()
        }
    }
}

/// Load default level with fallback chain (RON files only)
fn load_default_level() -> LevelData {
    // Log current working directory for debugging path issues
    match std::env::current_dir() {
        Ok(cwd) => info!("📂 Current working directory: {}", cwd.display()),
        Err(e) => warn!("❌ Could not get current working directory: {}", e),
    }

    // Try our converted RON levels in order of preference
    let default_levels = vec![
        ("FMIS01", "assets/levels/FMIS01.ron"), // First Mission Level 1 - START
        ("FMIS02", "assets/levels/FMIS02.ron"), // First Mission Level 2 - LIGHT
        ("1", "assets/levels/1.ron"),           // Generic level file
    ];

    for (level_id, path) in default_levels {
        // Check if file exists before attempting to load
        let exists = std::path::Path::new(path).exists();
        info!("🔍 Checking default file: {} (exists: {})", path, exists);

        match load_level_from_file(path) {
            Ok(level) => {
                info!(
                    "✅ Successfully loaded default RON level: {} ({}) from {}",
                    level_id, level.name, path
                );
                return level;
            }
            Err(e) => {
                warn!("❌ Failed to load {}: {}", path, e);
            }
        }
    }

    warn!("❌ No RON levels found in assets/levels/, using test level");
    warn!("💡 Hint: Run the convert_mie tool to convert MIE files to RON format");
    create_test_level()
}

/// Direct spawn function for level manager
#[allow(dead_code)]
pub fn spawn_tilemap_direct(
    commands: &mut Commands,
    level: &LevelData,
    sprite_atlas: &SpriteAtlas,
) {
    spawn_tilemap(commands, level, sprite_atlas);
}

/// Direct spawn function for level manager with atlas support
#[allow(dead_code)]
pub fn spawn_tilemap_direct_with_atlas(
    commands: &mut Commands,
    level: &LevelData,
    sprite_atlas: &SpriteAtlas,
    atlas_manager: Option<&AtlasManager>,
) {
    spawn_tilemap_with_atlas(commands, level, sprite_atlas, atlas_manager);
}

/// Create a simple test level for demonstration
pub fn create_test_level() -> LevelData {
    LevelData {
        name: "Test Level".to_string(),
        width: 40,
        height: 30,
        spawn_point: (320.0, 240.0),
        background_image: None,
        tilemap: create_test_tilemap(),
        entities: vec![
            LevelEntity {
                id: "enemy1".to_string(),
                entity_type: "enemy".to_string(),
                position: (200.0, 300.0),
                sprite_id: 1,
                behavior_type: BehaviorType::HorizontalOscillator,
                behavior_params: BehaviorParams::HorizontalOscillator {
                    left_bound: 150,
                    right_bound: 350,
                    speed: 2,
                },
                room: 1,
                pickupable: false,
                pickup_value: 0,
                sound_effects: None,
                entity_props: None,
            },
            LevelEntity {
                id: "pickup1".to_string(),
                entity_type: "gem".to_string(),
                position: (400.0, 200.0),
                sprite_id: 5,
                behavior_type: BehaviorType::Static,
                behavior_params: BehaviorParams::Static,
                room: 1,
                pickupable: true,
                pickup_value: 100,
                sound_effects: Some((1, 0)), // pickup sound
                entity_props: None,
            },
        ],
        transitions: vec![],
        scripts: vec![],
        messages: vec![],
        music: None,
        time_limit: Some(300.0), // 5 minutes
    }
}

/// Create a simple test tilemap
fn create_test_tilemap() -> Vec<Vec<u16>> {
    let mut tilemap = vec![vec![0u16; 40]; 30];

    // Create some ground at the bottom
    for x in 0..40 {
        tilemap[28][x] = 1; // ground tile
        tilemap[29][x] = 2; // dirt tile
    }

    // Add some platforms
    for x in 10..20 {
        tilemap[20][x] = 1;
    }

    for x in 25..35 {
        tilemap[15][x] = 1;
    }

    // Add walls on sides
    for y in 0..30 {
        tilemap[y][0] = 3; // wall tile
        tilemap[y][39] = 3;
    }

    tilemap
}

/// Spawn tilemap entities using bevy_ecs_tilemap
#[allow(dead_code)]
pub fn spawn_tilemap(commands: &mut Commands, level: &LevelData, sprite_atlas: &SpriteAtlas) {
    spawn_tilemap_with_atlas(commands, level, sprite_atlas, None);
}

/// Spawn tilemap entities using bevy_ecs_tilemap with atlas support
pub fn spawn_tilemap_with_atlas(
    commands: &mut Commands,
    level: &LevelData,
    sprite_atlas: &SpriteAtlas,
    atlas_manager: Option<&AtlasManager>,
) {
    if let Some(texture_handle) = &sprite_atlas.tiles_texture {
        let map_size = TilemapSize {
            x: level.width,
            y: level.height,
        };
        let tilemap_entity = commands.spawn_empty().id();
        let mut tile_storage = TileStorage::empty(map_size);

        // Spawn tiles with Y-axis flipped for Bevy's coordinate system
        for y in 0..level.height {
            for x in 0..level.width {
                let tile_id = level.tilemap[y as usize][x as usize];

                // Convert tile ID to proper texture index using atlas
                let tile_index = if let Some(atlas) = atlas_manager {
                    // Use atlas mapping for texture indices
                    atlas.tile_id_to_texture_index(tile_id as u32)
                } else {
                    // Fallback: direct mapping
                    // Tile ID 0 = transparent/empty (not rendered)
                    // Tile ID 1+ = solid tiles (use texture index)
                    if tile_id > 0 {
                        tile_id as u32 - 1
                    } else {
                        0
                    }
                };

                // Only spawn solid tiles (tile ID > 0)
                // Tile ID 0 = empty/walkable space (not rendered)
                if tile_id > 0 {
                    // Flip Y coordinate: original (0,0) at top-left becomes bottom-left in Bevy
                    let flipped_y = level.height - 1 - y;
                    let tile_entity = commands
                        .spawn(TileBundle {
                            position: TilePos { x, y: flipped_y },
                            tilemap_id: TilemapId(tilemap_entity),
                            texture_index: TileTextureIndex(tile_index),
                            ..default()
                        })
                        .id();
                    tile_storage.set(&TilePos { x, y: flipped_y }, tile_entity);
                }
            }
        }

        let tile_size = TilemapTileSize { x: 16.0, y: 16.0 };
        let grid_size = tile_size.into();
        let map_type = TilemapType::default();

        // Calculate tilemap position with 8px CRT border offset
        // Original game had 8px border on all sides
        let tilemap_x = -(map_size.x as f32) * tile_size.x / 2.0 + 8.0; // +8px right for left border
        let tilemap_y = -(map_size.y as f32) * tile_size.y / 2.0 - 8.0; // -8px down for top border

        commands.entity(tilemap_entity).insert((
            TilemapBundle {
                grid_size,
                map_type,
                size: map_size,
                storage: tile_storage,
                texture: TilemapTexture::Single(texture_handle.clone()),
                tile_size,
                transform: Transform::from_xyz(tilemap_x, tilemap_y, 0.0),
                ..default()
            },
            GameTilemap, // Add cleanup component
        ));
    }
}

/// System to spawn entities from level data
pub fn spawn_level_entities(
    mut commands: Commands,
    tilemap_manager: Res<TilemapManager>,
    sprite_atlas: Res<SpriteAtlas>,
    atlas_manager: Res<crate::atlas::AtlasManager>,
) {
    if let Some(level) = &tilemap_manager.current_level {
        if sprite_atlas.loaded {
            info!(
                "🎮 Spawning {} entities from level: {}",
                level.entities.len(),
                level.name
            );
            for entity_data in &level.entities {
                spawn_entity_from_data(&mut commands, entity_data, &sprite_atlas, &atlas_manager);
            }
        }
    }
}

/// Helper function to spawn an entity from level data
fn spawn_entity_from_data(
    commands: &mut Commands,
    entity_data: &LevelEntity,
    _sprite_atlas: &SpriteAtlas,
    atlas_manager: &crate::atlas::AtlasManager,
) {
    use crate::components::AnimatedEntity;

    // Debug info reduced - only log if verbose mode needed

    // Determine if entity is animated
    let is_animated = entity_data
        .entity_props
        .as_ref()
        .map(|props| props.animated)
        .unwrap_or(false);

    // Create sprite with appropriate texture based on animation
    let sprite = if is_animated {
        // Use animations texture for animated entities
        if let Some(ref animations_texture) = atlas_manager.animations_texture {
            Sprite {
                image: animations_texture.clone(),
                color: Color::WHITE,
                custom_size: Some(Vec2::new(16.0, 16.0)),
                ..default()
            }
        } else {
            // Fallback to debug color
            Sprite {
                color: Color::srgb(0.0, 1.0, 0.0), // Green for animated
                custom_size: Some(Vec2::new(16.0, 16.0)),
                ..default()
            }
        }
    } else if let Some(ref objects_texture) = atlas_manager.objects_texture {
        // Use objects texture for static entities
        Sprite {
            image: objects_texture.clone(),
            color: Color::WHITE, // White for proper texture display
            custom_size: Some(Vec2::new(16.0, 16.0)),
            ..default()
        }
    } else {
        // Fallback colors based on entity type for debugging
        let debug_color = match entity_data.entity_type.as_str() {
            "ZNNA" => Color::srgb(1.0, 0.0, 0.0), // Red for collectibles
            "ZANA" => Color::srgb(0.0, 1.0, 0.0), // Green for animated collectibles
            "YNN~" => Color::srgb(0.0, 0.0, 1.0), // Blue for exit portal
            _ => Color::srgb(1.0, 0.5, 0.0),      // Orange for unknown
        };
        Sprite {
            color: debug_color,
            custom_size: Some(Vec2::new(16.0, 16.0)),
            ..default()
        }
    };

    let entity_bundle = (
        Position {
            x: entity_data.position.0,
            y: entity_data.position.1,
        },
        Velocity::default(),
        Collider::default(),
        Behavior {
            behavior_type: entity_data.behavior_type,
            params: entity_data.behavior_params.clone(),
            state: BehaviorState {
                direction: 1,
                ..Default::default()
            },
        },
        sprite,
        Transform::from_translation(Vec3::new(
            entity_data.position.0,
            entity_data.position.1,
            2.0, // Higher Z to be above tilemap
        )),
        GameEntity, // Add cleanup component
    );

    // Spawn debug rectangle outline around entity
    spawn_debug_rectangle(commands, entity_data.position.0, entity_data.position.1);

    // Check if entity should be animated
    let mut entity_commands = if let Some(ref props) = entity_data.entity_props {
        if props.animated {
            // Determine animation name based on entity type or sprite_id
            let animation_name =
                get_animation_name_for_entity(&entity_data.entity_type, entity_data.sprite_id);

            let cmd = commands.spawn((
                entity_bundle,
                SpriteInfo {
                    texture_id: entity_data.sprite_id as usize,
                    frame: entity_data.sprite_id as usize, // Will be updated by animation system
                    facing_left: false,
                },
                AnimatedEntity {
                    animation_name: animation_name.clone(),
                    current_frame_index: 0,
                    timer: 0.0,
                    duration_per_frame: 0.1, // Default duration, can be overridden
                    total_frames: 4,         // Most animations have 4 frames
                    base_sprite_id: entity_data.sprite_id as u32,
                },
            ));

            cmd
        } else {
            commands.spawn((
                entity_bundle,
                SpriteInfo {
                    texture_id: entity_data.sprite_id as usize,
                    frame: entity_data.sprite_id as usize,
                    facing_left: false,
                },
            ))
        }
    } else {
        commands.spawn((
            entity_bundle,
            SpriteInfo {
                texture_id: entity_data.sprite_id as usize,
                frame: entity_data.sprite_id as usize,
                facing_left: false,
            },
        ))
    };

    // Add pickup component if needed
    if entity_data.pickupable {
        entity_commands.insert(Pickup {
            pickup_type: entity_data.sprite_id,
            value: entity_data.pickup_value,
        });
    }
}

/// Spawn a debug rectangle outline around an entity position
fn spawn_debug_rectangle(commands: &mut Commands, x: f32, y: f32) {
    // Create thin border lines around the entity (18x18 to show around 16x16 sprite)
    let border_size = 18.0;
    let line_width = 1.0;
    let border_color = Color::srgba(1.0, 1.0, 0.0, 0.8); // Semi-transparent yellow

    // Top line
    commands.spawn((
        Sprite {
            color: border_color,
            custom_size: Some(Vec2::new(border_size, line_width)),
            ..default()
        },
        Transform::from_translation(Vec3::new(x, y + border_size / 2.0, 2.1)),
        GameEntity, // For cleanup
    ));

    // Bottom line
    commands.spawn((
        Sprite {
            color: border_color,
            custom_size: Some(Vec2::new(border_size, line_width)),
            ..default()
        },
        Transform::from_translation(Vec3::new(x, y - border_size / 2.0, 2.1)),
        GameEntity, // For cleanup
    ));

    // Left line
    commands.spawn((
        Sprite {
            color: border_color,
            custom_size: Some(Vec2::new(line_width, border_size)),
            ..default()
        },
        Transform::from_translation(Vec3::new(x - border_size / 2.0, y, 2.1)),
        GameEntity, // For cleanup
    ));

    // Right line
    commands.spawn((
        Sprite {
            color: border_color,
            custom_size: Some(Vec2::new(line_width, border_size)),
            ..default()
        },
        Transform::from_translation(Vec3::new(x + border_size / 2.0, y, 2.1)),
        GameEntity, // For cleanup
    ));
}

/// Map entity types to animation names in the animations atlas
fn get_animation_name_for_entity(entity_type: &str, _sprite_id: u16) -> String {
    match entity_type {
        // Exit portal
        "YNN~" => "teleport".to_string(),
        // Fruits
        "YFRU" => "pear".to_string(),
        "YFRC" => "cherry".to_string(),
        // Heart/life
        "YHEA" => "heart".to_string(),
        // Defaults
        _ => "coin".to_string(),
    }
}
/// Save level to RON file
#[allow(dead_code)]
pub fn save_level_to_file(
    level: &LevelData,
    filename: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    // Configure RON formatting for readable tilemaps
    let config = PrettyConfig::new()
        .depth_limit(2)
        .separate_tuple_members(true)
        .enumerate_arrays(false)
        .compact_arrays(true); // This makes arrays format on single lines

    let ron_string = to_string_pretty(level, config)?;
    std::fs::write(format!("assets/levels/{}", filename), ron_string)?;
    Ok(())
}

/// Load level from RON format  
pub fn load_level_from_file(filename: &str) -> Result<LevelData, Box<dyn std::error::Error>> {
    let ron_string = std::fs::read_to_string(filename)?;
    let level: LevelData = ron::from_str(&ron_string)?;
    Ok(level)
}

// MIE conversion functions have been moved to the convert_mie binary
// The game engine now only loads RON files
