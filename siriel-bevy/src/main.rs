use bevy::prelude::*;
use bevy::window::WindowResolution;
use bevy_ecs_tilemap::prelude::*;
use clap::Parser;

mod atlas;
mod audio;
mod behaviors;
mod components;
mod dat_extractor;
mod level;
mod level_manager;
mod menu;
mod mie_parser;
mod resources;
mod systems;

use atlas::{load_atlas_descriptors, AtlasManager};
use audio::{sound_mappings, SirielAudioPlugin, SoundEvent};
use components::*;
use level::{GameArgs, *};
use level_manager::{level_switch_system, print_level_info_system, LevelManager};
use menu::*;
use menu::{cleanup_intro_screen, handle_intro_input, spawn_intro_screen};
use resources::*;
use systems::*;

const SCREEN_WIDTH: f32 = 640.0;
const SCREEN_HEIGHT: f32 = 480.0;
const SPRITE_SIZE: f32 = 16.0;

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
            (
                setup_game,
                level::cleanup_previous_level,
                load_level_system,
                spawn_level_entities,
                start_background_music,
            )
                .chain(), // Ensure cleanup runs before level loading
        )
        .add_systems(
            Update,
            (
                input_system,
                physics_system,
                behavior_system,
                animation_system,
                avatar_animation_state_system,
                avatar_animation_update_system,
                avatar_texture_atlas_system,
                collision_system,
                render_debug_system,
                level_switch_system,
                print_level_info_system,
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
