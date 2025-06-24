mod components;
mod level;
mod systems;

use bevy::prelude::*;
use bevy::window::{PresentMode, Window, WindowPlugin};
use components::GameState;

fn main() {
    App::new()
        // Configure the window using the new WindowPlugin API
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Siriel Adventures".into(),
                resolution: (640.0, 480.0).into(),
                present_mode: PresentMode::AutoVsync,
                ..Default::default()
            }),
            ..Default::default()
        }))
        // Initialize game state resource
        .init_resource::<GameState>()
        // Startup systems: camera, spritesheet, then level loading
        .add_systems(Startup, (
            systems::setup_camera, 
            systems::setup_texture_atlas
        ))
        .add_systems(Startup, 
            systems::setup_level_from_tiled.after(systems::setup_texture_atlas)
        )
        // Game loop systems
        .add_systems(Update, (
            systems::player_input,
            systems::physics_system.after(systems::player_input),
            systems::collision_system.after(systems::physics_system),
            systems::player_animation_system.after(systems::player_input),
            systems::animation_system,
            systems::exit_on_esc,
        ))
        .run();
}
