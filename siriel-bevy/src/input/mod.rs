//! Input handling module for Siriel-Bevy
//!
//! This module provides comprehensive input support including:
//! - Keyboard input (existing)
//! - Gamepad input (new)
//! - Input configuration and remapping
//! - Cross-platform compatibility

pub mod gamepad;
pub mod gamepad_config;
pub mod gamepad_plugin;

// Re-export key types for convenience
pub use gamepad::*;
pub use gamepad_config::*;
pub use gamepad_plugin::*;

/// Actions that can be performed in the game
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum GameAction {
    // Movement
    MoveLeft,
    MoveRight,
    Jump,

    // Gameplay
    Action, // Interact/pickup
    Pause,
    Menu,

    // Debug
    ToggleDebug,
    Screenshot,

    // Special (for testing)
    NextLevel,
    RestartLevel,
}

impl GameAction {
    /// Get a human-readable name for this action
    pub fn name(&self) -> &'static str {
        match self {
            GameAction::MoveLeft => "Move Left",
            GameAction::MoveRight => "Move Right",
            GameAction::Jump => "Jump",
            GameAction::Action => "Action",
            GameAction::Pause => "Pause",
            GameAction::Menu => "Menu",
            GameAction::ToggleDebug => "Toggle Debug",
            GameAction::Screenshot => "Screenshot",
            GameAction::NextLevel => "Next Level",
            GameAction::RestartLevel => "Restart Level",
        }
    }
}
