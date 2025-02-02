mod components;
mod level;
mod systems;

use bevy::prelude::*;
use bevy::window::{PresentMode, Window, WindowPlugin};
use systems::*;

fn main() {
    App::new()
        // Use the new WindowPlugin configuration for Bevy 0.15.
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Siriel".into(),
                resolution: (640.0, 480.0).into(),
                present_mode: PresentMode::AutoVsync,
                ..Default::default()
            }),
            ..Default::default()
        }))
        // Startup systems: load the spritesheet and set up the level.
        .add_systems(Startup, (systems::setup_texture_atlas, systems::setup_level))
        // Gameplay systems: handle input, animation, physics, and collision.
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
