// Siriel Macroquad - Menu Item
// Individual menu item definition

#![allow(dead_code)]

use serde::{Deserialize, Serialize};

/// Action to perform when menu item is activated
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum MenuAction {
    /// No action
    None,
    /// Go to specific game mode
    GotoMode(String),
    /// Load specific level
    LoadLevel(String),
    /// Start new game
    NewGame,
    /// Continue game
    Continue,
    /// Quit game
    Quit,
    /// Go back to previous menu
    Back,
    /// Custom action with identifier
    Custom(String),
    /// Submenu identifier
    Submenu(String),
}

/// Individual menu item
#[derive(Clone, Debug)]
pub struct MenuItem {
    /// Display text
    pub text: String,
    /// Optional shortcut key
    pub key: Option<char>,
    /// Action to perform when selected
    pub action: Option<MenuAction>,
    /// Is this a separator
    pub is_separator: bool,
    /// Whether item is enabled
    pub enabled: bool,
}

impl MenuItem {
    /// Create new menu item
    pub fn new(text: String, action: MenuAction) -> Self {
        Self {
            text,
            key: None,
            action: Some(action),
            is_separator: false,
            enabled: true,
        }
    }

    /// Create with custom key
    pub fn with_key(mut self, key: char) -> Self {
        self.key = Some(key);
        self
    }

    /// Create disabled item
    pub fn disabled(mut self) -> Self {
        self.enabled = false;
        self
    }

    /// Create separator item
    pub fn separator() -> Self {
        Self {
            text: String::new(),
            key: None,
            action: None,
            is_separator: true,
            enabled: false,
        }
    }

    /// Check if item is separator
    pub fn is_separator(&self) -> bool {
        self.is_separator
    }

    /// Get display text with key hint
    pub fn display_text(&self) -> String {
        if let Some(key) = self.key {
            format!("{} - {}", key, self.text)
        } else {
            self.text.clone()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_menu_item_creation() {
        let item = MenuItem::new(
            "Start Game".to_string(),
            MenuAction::GotoMode("playing".to_string()),
        );
        assert_eq!(item.text, "Start Game");
        assert!(item.action.is_some());
        assert!(!item.is_separator());
        assert!(item.enabled);
    }

    #[test]
    fn test_menu_item_with_key() {
        let item = MenuItem::new(
            "Start Game".to_string(),
            MenuAction::GotoMode("playing".to_string()),
        )
        .with_key('S');
        assert_eq!(item.key, Some('S'));
    }

    #[test]
    fn test_menu_item_disabled() {
        let item = MenuItem::new("Locked".to_string(), MenuAction::None).disabled();
        assert!(!item.enabled);
    }

    #[test]
    fn test_separator() {
        let item = MenuItem::separator();
        assert!(item.is_separator());
        assert!(!item.enabled);
        assert!(item.action.is_none());
    }

    #[test]
    fn test_display_text() {
        let item = MenuItem::new("Start".to_string(), MenuAction::None).with_key('S');
        assert_eq!(item.display_text(), "S - Start");
    }

    #[test]
    fn test_display_text_no_key() {
        let item = MenuItem::new("Start".to_string(), MenuAction::None);
        assert_eq!(item.display_text(), "Start");
    }
}
