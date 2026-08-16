// Siriel Macroquad - Menu Navigation
// Keyboard and touch input handling for menus

use crate::menu::item::MenuItem;
use macroquad::prelude::*;
use std::sync::atomic::{AtomicU64, Ordering};

// Global timestamp of last touch activation (in milliseconds since epoch)
// Used to prevent double-trigger across menu instances
static LAST_TOUCH_ACTIVATION: AtomicU64 = AtomicU64::new(0);
const TOUCH_ACTIVATION_COOLDOWN: u64 = 300; // ms

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
    /// Scroll offset changed (for menu scrolling)
    Scroll(i32), // positive = scroll down, negative = scroll up
}

/// Menu navigation handler
pub struct MenuNavigation {
    /// Key repeat delay in seconds (keyboard)
    key_repeat_delay: f32,
    /// Touch button repeat delay in seconds (slower for mobile)
    touch_repeat_delay: f32,
    /// Time since last key press
    last_key_time: f32,
    /// Last touch position (for detecting tap vs hold)
    last_touch_pos: Option<(f32, f32)>,
    /// Touch start time
    touch_start_time: f32,
    /// Last navigation button time (for repeat delay)
    last_nav_button_time: f32,
    /// Which nav button was last pressed (Some(Up) or Some(Down))
    last_nav_button: Option<bool>, // true = up, false = down
    /// Virtual up button area (for touch navigation)
    pub up_area: Option<(f32, f32, f32, f32)>,
    /// Virtual down button area (for touch navigation)
    pub down_area: Option<(f32, f32, f32, f32)>,
    /// Menu items positions (for touch selection)
    item_positions: Vec<(usize, f32, f32, f32, f32)>, // (index, x, y, width, height)
    /// Track mouse button state for release detection
    mouse_was_pressed: bool,
    /// Track touch start positions for tap validation
    touch_start_positions: Vec<(usize, f32, f32)>, // (id, x, y)
    /// Recently consumed touch IDs to prevent double-trigger
    consumed_touches: Vec<(usize, f32)>, // (id, time_consumed)
    /// Track swipe start positions (id, start_y)
    swipe_start: Vec<(usize, f32)>,
    /// Swipe detection threshold in pixels
    swipe_threshold: f32,
}

impl MenuNavigation {
    /// Create new navigation handler
    pub fn new() -> Self {
        Self {
            key_repeat_delay: 0.12,   // 120ms like siriel-modern
            touch_repeat_delay: 0.25, // 250ms for touch - slower, more controlled
            last_key_time: 0.0,
            last_touch_pos: None,
            touch_start_time: 0.0,
            last_nav_button_time: 0.0,
            last_nav_button: None,
            up_area: None,
            down_area: None,
            item_positions: Vec::new(),
            mouse_was_pressed: false,
            touch_start_positions: Vec::new(),
            consumed_touches: Vec::new(),
            swipe_start: Vec::new(),
            swipe_threshold: 50.0, // 50px minimum swipe
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
        let h = screen_height();
        let btn_size = 70.0;
        let spacing = 15.0;
        let margin = 15.0;

        // Position buttons at right edge, vertically centered
        // This avoids overlap with menu items which are typically left/center
        let start_x = w - btn_size - margin;
        let center_y = h / 2.0;
        let total_height = btn_size * 2.0 + spacing;
        let start_y = center_y - total_height / 2.0;

        // Up button: right side, centered
        self.up_area = Some((start_x, start_y, btn_size, btn_size));
        // Down button: below up button
        self.down_area = Some((start_x, start_y + btn_size + spacing, btn_size, btn_size));
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
        let current_touches = touches();
        let current_time_ms = (get_time() * 1000.0) as u64;

        // Check if we're in cooldown period from previous activation
        let last_activation = LAST_TOUCH_ACTIVATION.load(Ordering::Relaxed);
        if current_time_ms.saturating_sub(last_activation) < TOUCH_ACTIVATION_COOLDOWN {
            // Still process swipe/scroll during cooldown, just not activation
        }

        // Track active touch IDs
        let active_ids: Vec<usize> = current_touches.iter().map(|t| t.id as usize).collect();

        // Process new touches (record start position)
        for touch in &current_touches {
            let id = touch.id as usize;
            let x = touch.position.x;
            let y = touch.position.y;

            // Check if this is a new touch (not in start positions)
            if !self
                .touch_start_positions
                .iter()
                .any(|(tid, _, _)| *tid == id)
            {
                // Only track if not recently consumed
                if !self.consumed_touches.iter().any(|(tid, _)| *tid == id) {
                    self.touch_start_positions.push((id, x, y));
                    // Also track for swipe detection
                    self.swipe_start.push((id, y));
                }
            } else {
                // Check for swipe gesture on existing touches
                if let Some(swipe_idx) = self.swipe_start.iter().position(|(tid, _)| *tid == id) {
                    let start_y = self.swipe_start[swipe_idx].1;
                    let dy = y - start_y;

                    // Detect vertical swipe
                    if dy.abs() > self.swipe_threshold {
                        // Check if not on a menu item (swipe on empty space or background)
                        let on_item = self.check_item_touch(x, y).is_some();

                        if !on_item {
                            // Swipe detected - trigger scroll
                            // Swipe up (dy < 0) should show later items (scroll down)
                            // Swipe down (dy > 0) should show earlier items (scroll up)
                            let scroll_amount = if dy < 0.0 { 1 } else { -1 };
                            return NavigationResult::Scroll(scroll_amount);
                        }
                    }
                }
            }
        }

        // Process touches that ended (check for tap completion)
        let mut result = NavigationResult::None;
        let mut i = 0;
        while i < self.touch_start_positions.len() {
            let (id, start_x, start_y) = self.touch_start_positions[i];

            // Check if this touch is still active
            if !active_ids.contains(&id) {
                // Remove from swipe tracking
                self.swipe_start.retain(|(tid, _)| *tid != id);

                // Touch ended - check if it was a tap on a menu item
                if let Some(item_idx) = self.check_item_touch(start_x, start_y) {
                    if item_idx < items.len() && !items[item_idx].is_separator() {
                        // Check cooldown again for activation
                        let last_activation = LAST_TOUCH_ACTIVATION.load(Ordering::Relaxed);
                        if current_time_ms.saturating_sub(last_activation)
                            >= TOUCH_ACTIVATION_COOLDOWN
                        {
                            // Set global cooldown
                            LAST_TOUCH_ACTIVATION.store(current_time_ms, Ordering::Relaxed);
                            result = NavigationResult::Activate(item_idx);
                        }
                    }
                }
                // Remove this touch from start positions
                self.touch_start_positions.remove(i);
            } else {
                i += 1;
            }
        }

        if result != NavigationResult::None {
            return result;
        }

        // Handle navigation buttons (only while touching)
        for touch in &current_touches {
            let id = touch.id as usize;

            // Skip if this touch was recently consumed
            if self.consumed_touches.iter().any(|(tid, _)| *tid == id) {
                continue;
            }

            let x = touch.position.x;
            let y = touch.position.y;

            if let Some((ux, uy, uw, uh)) = self.up_area {
                if x >= ux && x <= ux + uw && y >= uy && y <= uy + uh {
                    // Check if enough time passed since last nav
                    if self.last_nav_button != Some(true)
                        || (current_time_ms as f32 / 1000.0 - self.last_nav_button_time)
                            >= self.touch_repeat_delay
                    {
                        self.last_nav_button = Some(true);
                        self.last_nav_button_time = current_time_ms as f32 / 1000.0;
                        return NavigationResult::Selected(
                            self.find_previous_selectable(items, selected),
                        );
                    }
                }
            }

            if let Some((dx, dy, dw, dh)) = self.down_area {
                if x >= dx && x <= dx + dw && y >= dy && y <= dy + dh {
                    // Check if enough time passed since last nav
                    if self.last_nav_button != Some(false)
                        || (current_time_ms as f32 / 1000.0 - self.last_nav_button_time)
                            >= self.touch_repeat_delay
                    {
                        self.last_nav_button = Some(false);
                        self.last_nav_button_time = current_time_ms as f32 / 1000.0;
                        return NavigationResult::Selected(
                            self.find_next_selectable(items, selected),
                        );
                    }
                }
            }
        }

        // Clean up stale touch positions if list gets too large
        if self.touch_start_positions.len() > 10 {
            self.touch_start_positions.clear();
        }
        if self.swipe_start.len() > 10 {
            self.swipe_start.clear();
        }

        NavigationResult::None
    }

    /// Set key repeat delay
    pub fn set_repeat_delay(&mut self, delay: f32) {
        self.key_repeat_delay = delay;
    }

    /// Check mouse click on menu items (only on release to prevent double-trigger)
    fn handle_mouse_click(&mut self, items: &[MenuItem], _selected: usize) -> NavigationResult {
        let is_pressed = is_mouse_button_down(MouseButton::Left);
        let current_time_ms = (get_time() * 1000.0) as u64;

        // Detect release (was pressed, now not)
        if self.mouse_was_pressed && !is_pressed {
            // Check cooldown
            let last_activation = LAST_TOUCH_ACTIVATION.load(Ordering::Relaxed);
            if current_time_ms.saturating_sub(last_activation) < TOUCH_ACTIVATION_COOLDOWN {
                self.mouse_was_pressed = is_pressed;
                return NavigationResult::None;
            }

            let (mx, my) = mouse_position();
            if let Some(item_idx) = self.check_item_touch(mx, my) {
                if item_idx < items.len() && !items[item_idx].is_separator() {
                    // Set global cooldown
                    LAST_TOUCH_ACTIVATION.store(current_time_ms, Ordering::Relaxed);
                    return NavigationResult::Activate(item_idx);
                }
            }
        }

        self.mouse_was_pressed = is_pressed;
        NavigationResult::None
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

        // Handle mouse clicks (desktop direct activation)
        let mouse_result = self.handle_mouse_click(items, selected);
        if mouse_result != NavigationResult::None {
            return mouse_result;
        }

        // Handle touch input (mobile direct activation)
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

        // Check if buttons are currently pressed
        let touches = touches();
        let up_pressed = self.last_nav_button == Some(true) && !touches.is_empty();
        let down_pressed = self.last_nav_button == Some(false) && !touches.is_empty();

        if let Some((ux, uy, uw, uh)) = self.up_area {
            let color = if up_pressed {
                Color::new(0.5, 0.5, 0.7, 0.8) // Highlighted when pressed
            } else {
                Color::new(0.3, 0.3, 0.3, 0.7)
            };
            draw_rectangle(ux, uy, uw, uh, color);
            draw_rectangle_lines(ux, uy, uw, uh, 3.0, WHITE);
            // Draw larger arrow
            draw_text("▲", ux + uw / 2.0 - 12.0, uy + uh / 2.0 + 10.0, 32.0, WHITE);
        }

        if let Some((dx, dy, dw, dh)) = self.down_area {
            let color = if down_pressed {
                Color::new(0.5, 0.5, 0.7, 0.8) // Highlighted when pressed
            } else {
                Color::new(0.3, 0.3, 0.3, 0.7)
            };
            draw_rectangle(dx, dy, dw, dh, color);
            draw_rectangle_lines(dx, dy, dw, dh, 3.0, WHITE);
            // Draw larger arrow
            draw_text("▼", dx + dw / 2.0 - 12.0, dy + dh / 2.0 + 10.0, 32.0, WHITE);
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
