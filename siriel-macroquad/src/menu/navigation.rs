// Siriel Macroquad - Menu Navigation
// Keyboard and touch input handling for menus

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
    /// Last touch position (for detecting tap vs hold)
    last_touch_pos: Option<(f32, f32)>,
    /// Touch start time
    touch_start_time: f32,
    /// Virtual up button area (for touch navigation)
    pub up_area: Option<(f32, f32, f32, f32)>,
    /// Virtual down button area (for touch navigation)
    pub down_area: Option<(f32, f32, f32, f32)>,
    /// Menu items positions (for touch selection)
    item_positions: Vec<(usize, f32, f32, f32, f32)>, // (index, x, y, width, height)
}

impl MenuNavigation {
    /// Create new navigation handler
    pub fn new() -> Self {
        Self {
            key_repeat_delay: 0.12, // 120ms like siriel-modern
            last_key_time: 0.0,
            last_touch_pos: None,
            touch_start_time: 0.0,
            up_area: None,
            down_area: None,
            item_positions: Vec::new(),
        }
    }

    /// Set up touch areas for navigation buttons
    pub fn setup_touch_areas(
        &mut self,
        _menu_x: f32,
        _menu_y: f32,
        _menu_width: f32,
        _menu_height: f32,
    ) {
        let w = screen_width();

        // Up button: top-left corner of screen
        self.up_area = Some((w - 70.0, 80.0, 50.0, 50.0));
        // Down button: below up button
        self.down_area = Some((w - 70.0, 140.0, 50.0, 50.0));
    }

    /// Set menu item positions for touch selection
    pub fn set_item_positions(&mut self, positions: Vec<(usize, f32, f32, f32, f32)>) {
        self.item_positions = positions;
    }

    /// Check if touch point is in a menu item
    fn check_item_touch(&self, x: f32, y: f32) -> Option<usize> {
        for (index, ix, iy, iw, ih) in &self.item_positions {
            if x >= *ix && x <= ix + iw && y >= *iy && y <= iy + ih {
                return Some(*index);
            }
        }
        None
    }

    /// Handle touch input
    fn handle_touch(&mut self, items: &[MenuItem], selected: usize) -> NavigationResult {
        for touch in touches() {
            let x = touch.position.x;
            let y = touch.position.y;

            // Check if this is a new touch
            if self.last_touch_pos.is_none() {
                self.last_touch_pos = Some((x, y));
                self.touch_start_time = get_time() as f32;
            }

            // Check menu item tap (only on initial touch, not hold)
            if let Some(item_idx) = self.check_item_touch(x, y) {
                if item_idx < items.len() && !items[item_idx].is_separator() {
                    // Instant activate on touch (short tap)
                    return NavigationResult::Activate(item_idx);
                }
            }

            // Check navigation buttons
            if let Some((ux, uy, uw, uh)) = self.up_area {
                if x >= ux && x <= ux + uw && y >= uy && y <= uy + uh {
                    return NavigationResult::Selected(
                        self.find_previous_selectable(items, selected),
                    );
                }
            }

            if let Some((dx, dy, dw, dh)) = self.down_area {
                if x >= dx && x <= dx + dw && y >= dy && y <= dy + dh {
                    return NavigationResult::Selected(self.find_next_selectable(items, selected));
                }
            }
        }

        // No active touches
        if touches().is_empty() {
            self.last_touch_pos = None;
        }

        NavigationResult::None
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

        // Handle touch input first (takes priority on mobile)
        if Self::is_touch_active() {
            let touch_result = self.handle_touch(items, selected);
            if touch_result != NavigationResult::None {
                return touch_result;
            }
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

    /// Check if touch is active
    fn is_touch_active() -> bool {
        !touches().is_empty()
    }

    /// Draw navigation buttons (for touch devices)
    pub fn draw_touch_buttons(&self) {
        if !Self::is_touch_active() && !cfg!(target_arch = "wasm32") {
            return;
        }

        if let Some((ux, uy, uw, uh)) = self.up_area {
            let color = Color::new(0.3, 0.3, 0.3, 0.6);
            draw_rectangle(ux, uy, uw, uh, color);
            draw_rectangle_lines(ux, uy, uw, uh, 2.0, WHITE);
            draw_text("▲", ux + 15.0, uy + 30.0, 24.0, WHITE);
        }

        if let Some((dx, dy, dw, dh)) = self.down_area {
            let color = Color::new(0.3, 0.3, 0.3, 0.6);
            draw_rectangle(dx, dy, dw, dh, color);
            draw_rectangle_lines(dx, dy, dw, dh, 2.0, WHITE);
            draw_text("▼", dx + 15.0, dy + 30.0, 24.0, WHITE);
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
