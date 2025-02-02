mod components;
mod level;
mod systems;

use bevy::prelude::*;
use bevy::window::{PresentMode, Window, WindowPlugin};
use systems::*;

fn main() {
    App::new()
        // Configure the window using the new WindowPlugin API.
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Siriel".into(),
                resolution: (640.0, 480.0).into(),
                present_mode: PresentMode::AutoVsync,
                ..Default::default()
            }),
            ..Default::default()
        }))
        // Startup systems: first load the spritesheet, then load the level from Tiled.
        .add_systems(Startup, systems::setup_texture_atlas)
        .add_systems(Startup, systems::setup_level_from_tiled.after(systems::setup_texture_atlas))
        // Regular systems.
        .add_systems(
            Update,
            (
                systems::player_input,
                systems::animation_system,
                systems::physics_system,
                systems::collision_system,
            ),
        )
        .run();
}
