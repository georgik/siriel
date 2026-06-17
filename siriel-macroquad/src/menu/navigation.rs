// Siriel Macroquad - Menu Navigation
// Keyboard input handling for menus

use crate::menu::item::MenuItem;
use macroquad::prelude::*;

/// Result of menu navigation
#[derive(Clone, Debug, PartialEq)]
pub enum NavigationResult {
    /// No navigation occurred
    None,
    /// Selection changed to index
    Selected(usize),
    /// Item activated at index
    Activate(usize),
    /// Menu cancelled (ESC pressed)
    Cancel,
}

/// Menu navigation handler
pub struct MenuNavigation {
    /// Key repeat delay in seconds
    key_repeat_delay: f32,
    /// Time since last key press
    last_key_time: f32,
}

impl MenuNavigation {
    /// Create new navigation handler
    pub fn new() -> Self {
        Self {
            key_repeat_delay: 0.12, // 120ms like siriel-modern
            last_key_time: 0.0,
        }
    }

    /// Set key repeat delay
    pub fn set_repeat_delay(&mut self, delay: f32) {
        self.key_repeat_delay = delay;
    }

    /// Update navigation based on input
    pub fn update(
        &mut self,
        items: &[MenuItem],
        selected: usize,
        _first_visible: usize,
        visible_count: usize,
        dt: f32,
    ) -> NavigationResult {
        self.last_key_time += dt;

        // Check for menu items
        if items.is_empty() {
            return NavigationResult::None;
        }

        let mut new_selected = selected;

        // Up arrow - move up
        if is_key_down(KeyCode::Up) {
            if self.last_key_time >= self.key_repeat_delay {
                new_selected = self.find_previous_selectable(items, selected);
                self.last_key_time = 0.0;
            }
        }
        // Down arrow - move down
        else if is_key_down(KeyCode::Down) {
            if self.last_key_time >= self.key_repeat_delay {
                new_selected = self.find_next_selectable(items, selected);
                self.last_key_time = 0.0;
            }
        }
        // Page up - move up by page
        else if is_key_pressed(KeyCode::PageUp) {
            new_selected = self.find_previous_selectable(items, selected);
            // Move more items for page up
            for _ in 0..visible_count.saturating_sub(1) {
                new_selected = self.find_previous_selectable(items, new_selected);
            }
        }
        // Page down - move down by page
        else if is_key_pressed(KeyCode::PageDown) {
            new_selected = self.find_next_selectable(items, selected);
            // Move more items for page down
            for _ in 0..visible_count.saturating_sub(1) {
                new_selected = self.find_next_selectable(items, new_selected);
            }
        }
        // Home - go to first
        else if is_key_pressed(KeyCode::Home) {
            new_selected = self.find_first_selectable(items);
        }
        // End - go to last
        else if is_key_pressed(KeyCode::End) {
            new_selected = self.find_last_selectable(items);
        }
        // Enter or Space - activate
        else if is_key_pressed(KeyCode::Enter) || is_key_pressed(KeyCode::Space) {
            return NavigationResult::Activate(selected);
        }
        // Escape - cancel
        else if is_key_pressed(KeyCode::Escape) {
            return NavigationResult::Cancel;
        }
        // Number keys - direct selection
        else if let Some(direct) = self.check_number_keys() {
            if direct < items.len() && items[direct].enabled && !items[direct].is_separator() {
                return NavigationResult::Activate(direct);
            }
        }
        // Letter keys for shortcuts
        else if let Some(shortcut) = self.check_shortcut_keys(items) {
            return NavigationResult::Activate(shortcut);
        }

        // Check if selection changed
        if new_selected != selected {
            NavigationResult::Selected(new_selected)
        } else {
            NavigationResult::None
        }
    }

    /// Find previous selectable item
    fn find_previous_selectable(&self, items: &[MenuItem], current: usize) -> usize {
        if items.is_empty() {
            return 0;
        }

        let mut idx = current;
        loop {
            if idx == 0 {
                idx = items.len() - 1; // Wrap to end
            } else {
                idx -= 1;
            }

            if items[idx].enabled && !items[idx].is_separator() {
                return idx;
            }

            if idx == current {
                break; // No selectable item found
            }
        }

        current
    }

    /// Find next selectable item
    fn find_next_selectable(&self, items: &[MenuItem], current: usize) -> usize {
        if items.is_empty() {
            return 0;
        }

        let mut idx = current;
        loop {
            idx += 1;
            if idx >= items.len() {
                idx = 0; // Wrap to start
            }

            if items[idx].enabled && !items[idx].is_separator() {
                return idx;
            }

            if idx == current {
                break; // No selectable item found
            }
        }

        current
    }

    /// Find first selectable item
    fn find_first_selectable(&self, items: &[MenuItem]) -> usize {
        for (i, item) in items.iter().enumerate() {
            if item.enabled && !item.is_separator() {
                return i;
            }
        }
        0
    }

    /// Find last selectable item
    fn find_last_selectable(&self, items: &[MenuItem]) -> usize {
        for i in (0..items.len()).rev() {
            if items[i].enabled && !items[i].is_separator() {
                return i;
            }
        }
        items.len().saturating_sub(1)
    }

    /// Check for number key press (1-9)
    fn check_number_keys(&self) -> Option<usize> {
        let keys = [
            KeyCode::Key1,
            KeyCode::Key2,
            KeyCode::Key3,
            KeyCode::Key4,
            KeyCode::Key5,
            KeyCode::Key6,
            KeyCode::Key7,
            KeyCode::Key8,
            KeyCode::Key9,
        ];

        for (i, &key) in keys.iter().enumerate() {
            if is_key_pressed(key) {
                return Some(i);
            }
        }

        None
    }

    /// Check for shortcut key press
    fn check_shortcut_keys(&self, items: &[MenuItem]) -> Option<usize> {
        // Common shortcut keys
        let shortcuts = [
            ('n', KeyCode::N),
            ('s', KeyCode::S),
            ('q', KeyCode::Q),
            ('c', KeyCode::C),
            ('b', KeyCode::B),
            ('r', KeyCode::R),
            ('p', KeyCode::P),
            ('l', KeyCode::L),
            ('h', KeyCode::H),
            ('a', KeyCode::A),
            ('x', KeyCode::X),
            ('y', KeyCode::Y),
        ];

        // Map pressed keys to shortcuts
        for (ch, key) in shortcuts {
            if is_key_pressed(key) {
                // Find item with this shortcut
                for (i, item) in items.iter().enumerate() {
                    if item.key == Some(ch) && item.enabled {
                        return Some(i);
                    }
                }
            }
        }

        None
    }
}

impl Default for MenuNavigation {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::menu::item::MenuAction;

    #[test]
    fn test_navigation_creation() {
        let nav = MenuNavigation::new();
        assert_eq!(nav.key_repeat_delay, 0.12);
    }

    #[test]
    fn test_find_previous_selectable() {
        let items = vec![
            MenuItem::new("Item 1".to_string(), MenuAction::None),
            MenuItem::separator(),
            MenuItem::new("Item 2".to_string(), MenuAction::None),
        ];

        let nav = MenuNavigation::new();

        // From index 2, should go to 0 (skipping separator at 1)
        let result = nav.find_previous_selectable(&items, 2);
        assert_eq!(result, 0);
    }

    #[test]
    fn test_find_next_selectable() {
        let items = vec![
            MenuItem::new("Item 1".to_string(), MenuAction::None),
            MenuItem::separator(),
            MenuItem::new("Item 2".to_string(), MenuAction::None),
        ];

        let nav = MenuNavigation::new();

        // From index 0, should go to 2 (skipping separator at 1)
        let result = nav.find_next_selectable(&items, 0);
        assert_eq!(result, 2);
    }

    #[test]
    fn test_find_first_selectable() {
        let items = vec![
            MenuItem::separator(),
            MenuItem::new("Item 1".to_string(), MenuAction::None),
        ];

        let nav = MenuNavigation::new();
        let result = nav.find_first_selectable(&items);
        assert_eq!(result, 1);
    }

    #[test]
    fn test_find_last_selectable() {
        let items = vec![
            MenuItem::new("Item 1".to_string(), MenuAction::None),
            MenuItem::separator(),
        ];

        let nav = MenuNavigation::new();
        let result = nav.find_last_selectable(&items);
        assert_eq!(result, 0);
    }

    #[test]
    fn test_wrapping() {
        let items = vec![
            MenuItem::new("Item 1".to_string(), MenuAction::None),
            MenuItem::new("Item 2".to_string(), MenuAction::None),
        ];

        let nav = MenuNavigation::new();

        // From first item, previous should wrap to last
        let result = nav.find_previous_selectable(&items, 0);
        assert_eq!(result, 1);

        // From last item, next should wrap to first
        let result = nav.find_next_selectable(&items, 1);
        assert_eq!(result, 0);
    }
}
