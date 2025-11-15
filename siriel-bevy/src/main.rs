use bevy::prelude::*;
use bevy::window::WindowResolution;
use bevy_ecs_tilemap::prelude::*;
use clap::Parser;

mod atlas;
mod audio;
mod behaviors;
mod components;
mod dat_extractor;
mod input;
mod level;
mod level_manager;
mod menu;
mod mie_parser;
mod resources;
mod systems;

use atlas::{load_atlas_descriptors, AtlasManager};
use audio::{sound_mappings, SirielAudioPlugin, SoundEvent};
use components::*;
use input::GamepadInputPlugin;
use level::{GameArgs, *};
use level_manager::{level_switch_system, print_level_info_system, LevelManager};
use menu::*;
use menu::{cleanup_intro_screen, handle_intro_input, spawn_intro_screen};
use resources::*;
use systems::*;

const SCREEN_WIDTH: f32 = 640.0;
const SCREEN_HEIGHT: f32 = 480.0;

/// CLI arguments for Siriel game
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Level file path to load (e.g. assets/levels/FMIS02.ron)
    #[arg(short, long)]
    level: Option<String>,

    /// Verbose output for debugging
    #[arg(short, long)]
    verbose: bool,

    /// Take screenshot after N seconds and exit (for comparison with original)
    #[arg(short, long)]
    screenshot: Option<f32>,

    /// Directory to save screenshots (default: screenshots/)
    #[arg(long, default_value = "screenshots")]
    screenshot_dir: Option<String>,
}

fn main() {
    let args = Args::parse();

    // Determine initial state based on CLI arguments
    let initial_state = if args.level.is_some() {
        AppState::InGame // Skip intro and menu if level is specified via CLI
    } else {
        AppState::IntroScreen // Start with intro screen
    };

    // Print usage help if needed
    if args.verbose {
        println!("🎮 Siriel 3.5 - Bevy Edition");
        println!("📁 Available levels in assets/levels/:");
        if let Ok(entries) = std::fs::read_dir("assets/levels/") {
            for entry in entries {
                if let Ok(entry) = entry {
                    if let Some(filename) = entry.path().file_name() {
                        if let Some(name) = filename.to_str() {
                            if name.ends_with(".ron") {
                                println!("   - assets/levels/{}", name);
                            }
                        }
                    }
                }
            }
        }
        println!();
        println!("💡 Usage: cargo run -- --level assets/levels/FMIS02.ron");
        println!();
    }

    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Siriel 3.5 - Bevy Edition".into(),
                resolution: WindowResolution::new(SCREEN_WIDTH as u32, SCREEN_HEIGHT as u32),
                resizable: false,
                ..default()
            }),
            ..default()
        }))
        .add_plugins(TilemapPlugin)
        .add_plugins(SirielAudioPlugin)
        .add_plugins(GamepadInputPlugin)
        .init_state::<AppState>()
        .insert_state(initial_state)
        .init_resource::<GameState>()
        .init_resource::<PhysicsConfig>()
        .init_resource::<InputState>()
        .init_resource::<SpriteAtlas>()
        .init_resource::<TilemapManager>()
        .init_resource::<AtlasManager>()
        .init_resource::<LevelMenu>()
        .init_resource::<menu::MenuInputTimer>()
        .init_resource::<menu::MenuRefreshTracker>()
        .insert_resource(LevelManager::new())
        .insert_resource(GameArgs {
            level: args.level,
            verbose: args.verbose,
            screenshot: args.screenshot,
            screenshot_dir: args.screenshot_dir,
        })
        // Startup systems (run once)
        .add_systems(
            Startup,
            (
                setup_camera,
                load_sprite_assets,
                load_atlas_descriptors,
                setup_level_menu,
            ),
        )
        // Intro screen systems
        .add_systems(OnEnter(AppState::IntroScreen), spawn_intro_screen)
        .add_systems(
            Update,
            handle_intro_input.run_if(in_state(AppState::IntroScreen)),
        )
        .add_systems(OnExit(AppState::IntroScreen), cleanup_intro_screen)
        // Menu systems
        .add_systems(OnEnter(AppState::Menu), spawn_level_menu_ui_when_ready)
        .add_systems(
            Update,
            (
                refresh_menu_ui_when_levels_loaded,
                spawn_menu_borders, // Re-enabled with UI-based implementation
                handle_menu_input,
                handle_menu_mouse,
                update_menu_ui,
            )
                .run_if(in_state(AppState::Menu)),
        )
        .add_systems(OnExit(AppState::Menu), cleanup_menu_ui)
        // Game systems
        .add_systems(
            OnEnter(AppState::InGame),
            (level::cleanup_previous_level, start_background_music),
        )
        .add_systems(
            Update,
            setup_game
                .run_if(assets_loaded.and(not(player_spawned)))
                .run_if(in_state(AppState::InGame)),
        )
        .add_systems(
            Update,
            (
                load_level_system.run_if(assets_loaded.and(not(level_loaded))),
                spawn_level_entities.run_if(level_loaded.and(not(entities_spawned))),
            )
                .run_if(in_state(AppState::InGame)),
        )
        .add_systems(
            Update,
            (
                // Phase 1: Input and logic
                input_system,
                physics_system,
                tilemap_collision_system, // Add tilemap collision system
                behavior_system,
                // Phase 2: Animation and rendering preparation
                animation_system,
                avatar_animation_state_system,
                avatar_animation_update_system,
                // Phase 3: Texture atlas systems (must run after sprite info updates)
                avatar_texture_atlas_system,
                entity_texture_atlas_system,
                animated_entity_texture_atlas_system,
                // Phase 4: Final systems
                collision_system,
                render_debug_system,
                level_switch_system,
                print_level_info_system,
                screenshot_system,
            )
                .run_if(in_state(AppState::InGame)),
        )
        .run();
}

/// Start background music when the game begins
fn start_background_music(mut sound_events: MessageWriter<SoundEvent>) {
    // Play level music on startup
    sound_events.write(SoundEvent::PlayMusic(
        sound_mappings::LEVEL_MUSIC.to_string(),
    ));
}

/// Condition to check if assets are loaded
fn assets_loaded(
    sprite_atlas: Res<SpriteAtlas>,
    atlas_manager: Res<AtlasManager>,
    asset_server: Res<AssetServer>,
) -> bool {
    // First check if handles exist
    let handles_exist = sprite_atlas.loaded
        && sprite_atlas.tiles_texture.is_some()
        && atlas_manager.texture_atlas.is_some()
        && atlas_manager.avatar_texture.is_some()
        && atlas_manager.avatar_layout.is_some()
        && atlas_manager.objects_texture.is_some()
        && atlas_manager.objects_layout.is_some()
        && atlas_manager.animations_texture.is_some()
        && atlas_manager.animations_layout.is_some();

    if !handles_exist {
        return false;
    }

    // Then verify the actual assets are loaded by the asset server
    let mut all_loaded = true;

    if let Some(ref handle) = sprite_atlas.tiles_texture {
        all_loaded &= asset_server.is_loaded_with_dependencies(handle);
    }
    if let Some(ref handle) = atlas_manager.avatar_texture {
        all_loaded &= asset_server.is_loaded_with_dependencies(handle);
    }
    if let Some(ref handle) = atlas_manager.objects_texture {
        all_loaded &= asset_server.is_loaded_with_dependencies(handle);
    }
    if let Some(ref handle) = atlas_manager.animations_texture {
        all_loaded &= asset_server.is_loaded_with_dependencies(handle);
    }

    all_loaded
}

/// Condition to check if level is loaded
fn level_loaded(tilemap_manager: Res<TilemapManager>) -> bool {
    tilemap_manager.current_level.is_some()
}

/// Condition to check if entities are spawned
fn entities_spawned(query: Query<&crate::level::GameEntity, Without<Player>>) -> bool {
    !query.is_empty()
}

/// Condition to check if player is spawned
fn player_spawned(query: Query<&Player>) -> bool {
    !query.is_empty()
}
