use crate::atlas::AtlasManager;
use crate::level::{create_test_level, load_level_from_file, LevelData};
use bevy::prelude::*;

/// Resource for managing current level and level progression
#[derive(Resource, Default)]
pub struct LevelManager {
    pub current_level_name: String,
    pub available_levels: Vec<String>,
    pub current_index: usize,
}

impl LevelManager {
    pub fn new() -> Self {
        let available_levels = vec![
            "1".to_string(),      // Original test/start level
            "FMIS02".to_string(), // >LIGHT
            "FMIS03".to_string(), // >RULES
            "FMIS04".to_string(), // >RAIDER
            "FMIS05".to_string(), // >FACE
            "FMIS06".to_string(), // >ROMULUS
            "FMIS08".to_string(), // >PACMAN
            "FMIS09".to_string(), // >SABREWOLF
            "FMIS10".to_string(), // >BABYLON
            "FMIS11".to_string(), // >RAILWAY
            "FMIS12".to_string(), // >FLOATER
        ];

        Self {
            current_level_name: "FMIS02".to_string(), // Start with First Mission Level 2
            available_levels,
            current_index: 1, // Index of FMIS02
        }
    }

    pub fn next_level(&mut self) {
        if self.current_index < self.available_levels.len() - 1 {
            self.current_index += 1;
            self.current_level_name = self.available_levels[self.current_index].clone();
        }
    }

    pub fn previous_level(&mut self) {
        if self.current_index > 0 {
            self.current_index -= 1;
            self.current_level_name = self.available_levels[self.current_index].clone();
        }
    }

    pub fn get_current_level_path(&self) -> String {
        format!("assets/levels/{}.ron", self.current_level_name)
    }

    pub fn load_current_level(&self) -> LevelData {
        let level_path = self.get_current_level_path();

        match load_level_from_file(&level_path) {
            Ok(level) => {
                info!(
                    "Successfully loaded level: {} ({})",
                    self.current_level_name, level.name
                );
                level
            }
            Err(e) => {
                warn!("Failed to load level {}: {}", self.current_level_name, e);
                warn!("Falling back to test level");
                create_test_level()
            }
        }
    }
}

/// System for handling level switching via keyboard input
pub fn level_switch_system(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut level_manager: ResMut<LevelManager>,
    mut commands: Commands,
    mut tilemap_manager: ResMut<crate::level::TilemapManager>,
    sprite_atlas: Res<crate::resources::SpriteAtlas>,
    atlas_manager: Res<AtlasManager>,
) {
    let mut level_changed = false;

    // N = Next level, P = Previous level
    if keyboard_input.just_pressed(KeyCode::KeyN) {
        level_manager.next_level();
        level_changed = true;
        info!(
            "Switching to next level: {}",
            level_manager.current_level_name
        );
    }

    if keyboard_input.just_pressed(KeyCode::KeyP) {
        level_manager.previous_level();
        level_changed = true;
        info!(
            "Switching to previous level: {}",
            level_manager.current_level_name
        );
    }

    // Numbers 1-9 for direct level selection
    if keyboard_input.just_pressed(KeyCode::Digit1) {
        if level_manager.available_levels.len() > 0 {
            level_manager.current_index = 0;
            level_manager.current_level_name = level_manager.available_levels[0].clone();
            level_changed = true;
        }
    }

    if keyboard_input.just_pressed(KeyCode::Digit2) {
        if level_manager.available_levels.len() > 1 {
            level_manager.current_index = 1;
            level_manager.current_level_name = level_manager.available_levels[1].clone();
            level_changed = true;
        }
    }

    if keyboard_input.just_pressed(KeyCode::Digit3) {
        if level_manager.available_levels.len() > 2 {
            level_manager.current_index = 2;
            level_manager.current_level_name = level_manager.available_levels[2].clone();
            level_changed = true;
        }
    }

    if keyboard_input.just_pressed(KeyCode::Digit4) {
        if level_manager.available_levels.len() > 3 {
            level_manager.current_index = 3;
            level_manager.current_level_name = level_manager.available_levels[3].clone();
            level_changed = true;
        }
    }

    if keyboard_input.just_pressed(KeyCode::Digit5) {
        if level_manager.available_levels.len() > 4 {
            level_manager.current_index = 4;
            level_manager.current_level_name = level_manager.available_levels[4].clone();
            level_changed = true;
        }
    }

    // If level changed, reload the game with new level
    if level_changed {
        let new_level = level_manager.load_current_level();

        if sprite_atlas.loaded && sprite_atlas.tiles_texture.is_some() {
            // Clear existing tilemap entities (simplified approach)
            // In a full implementation, you'd want to properly clean up entities
            info!(
                "Reloading tilemap for level: {}",
                level_manager.current_level_name
            );

            // Spawn new tilemap with atlas support
            crate::level::spawn_tilemap_with_atlas(
                &mut commands,
                &new_level,
                &sprite_atlas,
                Some(&*atlas_manager),
            );
            tilemap_manager.current_level = Some(new_level);
        }
    }
}

/// Print level info for debugging
pub fn print_level_info_system(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    level_manager: Res<LevelManager>,
) {
    if keyboard_input.just_pressed(KeyCode::KeyI) {
        info!("=== LEVEL INFO ===");
        info!(
            "Current level: {} (index {})",
            level_manager.current_level_name, level_manager.current_index
        );
        info!("Available levels: {:?}", level_manager.available_levels);
        info!("Controls: N=Next, P=Previous, 1-5=Direct selection, I=Info");
        info!("==================");
    }
}
