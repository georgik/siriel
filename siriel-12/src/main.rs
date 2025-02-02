mod components;
mod level;
mod systems;

use bevy::prelude::*;
use components::*;
use systems::*;

fn main() {
    App::new()
        // Set the original resolution (640×480) and window title.
        .insert_resource(WindowDescriptor {
            title: "Siriel".to_string(),
            width: 640.0,
            height: 480.0,
            ..Default::default()
        })
        .add_plugins(DefaultPlugins)
        // Insert our HUD state.
        .insert_resource(HudState {
            score: 0,
            level_password: None,
        })
        // Startup systems to load the spritesheet and set up the level.
        .add_systems(Startup, (setup_texture_atlas, setup_level))
        // Regular systems: handle input, animate, apply gravity, collision, and update HUD.
        .add_systems(
            Update,
            (
                player_input,
                animation_system,
                physics_system,
                collision_system,
                hud_update_system,
            ),
        )
        .run();
}
