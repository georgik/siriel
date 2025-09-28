use bevy::prelude::*;
use bevy::window::WindowResolution;
use bevy_ecs_tilemap::prelude::*;
use clap::Parser;

mod audio;
mod components;
mod systems;
mod resources;
mod behaviors;
mod level;
mod dat_extractor;
mod mie_parser;
mod level_manager;
mod atlas;

use audio::{SirielAudioPlugin, SoundEvent, sound_mappings};
use components::*;
use systems::*;
use resources::*;
use level::{*, GameArgs};
use level_manager::{LevelManager, level_switch_system, print_level_info_system};
use atlas::{AtlasManager, load_atlas_descriptors};

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
                resolution: WindowResolution::new(SCREEN_WIDTH, SCREEN_HEIGHT),
                resizable: false,
                ..default()
            }),
            ..default()
        }))
        .add_plugins(TilemapPlugin)
        .add_plugins(SirielAudioPlugin)
        .init_resource::<GameState>()
        .init_resource::<PhysicsConfig>()
        .init_resource::<InputState>()
        .init_resource::<SpriteAtlas>()
        .init_resource::<TilemapManager>()
        .init_resource::<AtlasManager>()
        .insert_resource(LevelManager::new())
        .insert_resource(GameArgs {
            level: args.level,
            verbose: args.verbose,
        })
        .add_systems(Startup, (setup_camera, setup_game, load_sprite_assets, load_atlas_descriptors, load_level_system, spawn_level_entities, start_background_music))
        .add_systems(
            Update,
            (
                input_system,
                quit_system,
                physics_system,
                behavior_system,
                animation_system,
                collision_system,
                render_debug_system,
                level_switch_system,
                print_level_info_system,
            ).chain(),
        )
        .run();
}

/// Start background music when the game begins
fn start_background_music(
    mut sound_events: EventWriter<SoundEvent>,
) {
    // Play level music on startup
    sound_events.send(SoundEvent::PlayMusic(sound_mappings::LEVEL_MUSIC.to_string()));
}
