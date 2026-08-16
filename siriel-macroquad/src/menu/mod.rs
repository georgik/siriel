// Siriel Macroquad - Menu System
// Phase 11: Menu rendering with GLIST decoration

#![allow(dead_code)]

mod decoration;
mod item;
mod navigation;
mod renderer;

pub use decoration::GlistDecoration;
pub use item::{MenuAction, MenuItem};
pub use navigation::{MenuNavigation, NavigationResult};
pub use renderer::MenuRenderer;

use macroquad::prelude::*;

/// Menu configuration
#[derive(Clone, Debug)]
pub struct MenuConfig {
    /// Position X in pixels
    pub x: f32,
    /// Position Y in pixels
    pub y: f32,
    /// Width in pixels (0 = auto)
    pub width: f32,
    /// Height in pixels (0 = auto)
    pub height: f32,
    /// Title text
    pub title: String,
    /// Primary color (text highlight, borders)
    pub primary_color: Color,
    /// Secondary color (normal text)
    pub secondary_color: Color,
    /// Background color
    pub background_color: Color,
}

impl Default for MenuConfig {
    fn default() -> Self {
        Self {
            x: 100.0,
            y: 100.0,
            width: 0.0,
            height: 0.0,
            title: String::new(),
            primary_color: BLACK,
            secondary_color: WHITE,
            background_color: Color::new(0.52, 0.58, 0.67, 1.0), // #6C94D0
        }
    }
}

/// Complete menu system
pub struct Menu {
    /// Menu configuration
    config: MenuConfig,
    /// Menu items
    items: Vec<MenuItem>,
    /// Current selection index
    selected: usize,
    /// First visible item (for scrolling)
    first_visible: usize,
    /// Visible items count
    visible_count: usize,
    /// Navigation handler
    navigation: MenuNavigation,
    /// Renderer
    renderer: MenuRenderer,
    /// Decoration
    decoration: GlistDecoration,
}

impl Menu {
    /// Create new menu
    pub fn new(config: MenuConfig) -> Self {
        Self {
            config,
            items: Vec::new(),
            selected: 0,
            first_visible: 0,
            visible_count: 10,
            navigation: MenuNavigation::new(),
            renderer: MenuRenderer::new(),
            decoration: GlistDecoration::new(),
        }
    }

    /// Add menu item
    pub fn add_item(&mut self, text: impl Into<String>, action: MenuAction) {
        self.items.push(MenuItem::new(text.into(), action));
    }

    /// Add menu item with custom key
    pub fn add_item_with_key(&mut self, key: char, text: impl Into<String>, action: MenuAction) {
        let mut item = MenuItem::new(text.into(), action);
        item.key = Some(key);
        self.items.push(item);
    }

    /// Add separator
    pub fn add_separator(&mut self) {
        self.items.push(MenuItem::separator());
    }

    /// Get current selection
    pub fn selected(&self) -> usize {
        self.selected
    }

    /// Set selected item
    pub fn set_selected(&mut self, index: usize) {
        if index < self.items.len() && !self.items[index].is_separator() {
            self.selected = index;
        }
    }

    /// Update menu (handle input, animation)
    pub fn update(&mut self, dt: f32) -> NavigationResult {
        // Handle navigation
        let result = self.navigation.update(
            &self.items,
            self.selected,
            self.first_visible,
            self.visible_count,
            dt,
        );

        // Update selection based on navigation
        match result {
            NavigationResult::None => {}
            NavigationResult::Selected(index) => {
                self.selected = index;
                self.scroll_into_view(index);
            }
            NavigationResult::Activate(index) => {
                // Update selection to match clicked item
                self.selected = index;
                self.scroll_into_view(index);
                if let Some(_action) = self.items.get(index).and_then(|i| i.action.as_ref()) {
                    return NavigationResult::Activate(index);
                }
            }
            NavigationResult::Cancel => {
                return NavigationResult::Cancel;
            }
            NavigationResult::Scroll(amount) => {
                // Scroll the visible window
                let new_first = if amount > 0 {
                    // Scroll down - show later items
                    self.first_visible.saturating_add(amount as usize)
                } else {
                    // Scroll up - show earlier items
                    self.first_visible.saturating_sub((-amount) as usize)
                };

                // Clamp to valid range
                let max_first = self.items.len().saturating_sub(self.visible_count.max(1));
                self.first_visible = new_first.min(max_first);

                // Don't return Scroll result to caller - it's handled internally
                return NavigationResult::None;
            }
        }

        NavigationResult::Selected(self.selected)
    }

    /// Draw menu
    pub fn draw(&mut self) {
        // Calculate auto dimensions if needed
        let (width, height) = self.calculate_dimensions();

        // Draw decoration
        self.decoration.draw_frame(
            self.config.x,
            self.config.y,
            width,
            height,
            self.config.background_color,
        );

        // Draw menu items
        let item_start_y = self.config.y + 24.0; // Offset for title
        let item_x = self.config.x + 32.0; // Offset for decoration
        let item_width = width - 64.0;

        self.renderer.draw_items(
            &self.items,
            self.selected,
            self.first_visible,
            self.visible_count,
            item_x,
            item_start_y,
            item_width,
            self.config.primary_color,
            self.config.secondary_color,
        );

        // Draw scrollbar if needed
        let items_height =
            self.visible_count.min(self.items.len()) as f32 * self.renderer.line_height();
        self.renderer.draw_scrollbar(
            item_x,
            item_start_y,
            item_width,
            items_height,
            self.first_visible,
            self.items.len(),
            self.visible_count,
        );

        // Draw title
        if !self.config.title.is_empty() {
            self.renderer.draw_title(
                &self.config.title,
                self.config.x + width / 2.0,
                self.config.y + 12.0,
                self.config.primary_color,
            );
        }
    }

    /// Calculate menu dimensions
    fn calculate_dimensions(&self) -> (f32, f32) {
        let width = if self.config.width > 0.0 {
            self.config.width
        } else {
            // Auto calculate based on actual text measurement
            let max_width = self
                .items
                .iter()
                .map(|i| {
                    let text = i.display_text();
                    measure_text(&text, None, self.renderer.item_font_size() as u16, 1.0).width
                })
                .fold(0.0_f32, |a, b| a.max(b));
            max_width + 64.0 // Padding for decoration + scrollbar
        };

        let height = if self.config.height > 0.0 {
            self.config.height
        } else {
            // Auto calculate based on visible items
            let title_height = if self.config.title.is_empty() {
                0.0
            } else {
                self.renderer.title_font_size() + 8.0 // Title + spacing
            };
            let items_height =
                self.visible_count.min(self.items.len()) as f32 * self.renderer.line_height();
            title_height + items_height + 32.0 // Padding
        };

        (width, height)
    }

    /// Center menu on screen
    pub fn center_on_screen(&mut self) {
        let (width, height) = self.calculate_dimensions();
        let screen_w = screen_width();
        let screen_h = screen_height();

        self.config.x = (screen_w - width) / 2.0;
        self.config.y = (screen_h - height) / 2.0;
    }

    /// Scroll to ensure item is visible
    fn scroll_into_view(&mut self, index: usize) {
        if self.items.is_empty() || self.visible_count == 0 {
            return;
        }

        // Keep selected item in middle third of visible area
        let padding = 2; // Show 2 items above/below selection
        let _effective_visible = self.visible_count.saturating_sub(padding * 2);

        // If selection is before visible area
        if index < self.first_visible + padding {
            self.first_visible = index.saturating_sub(padding);
        }
        // If selection is after visible area
        else if index >= self.first_visible + self.visible_count - padding {
            self.first_visible = index + padding + 1 - self.visible_count;
        }

        // Clamp to valid range
        let max_first = self.items.len().saturating_sub(1);
        self.first_visible = self.first_visible.min(max_first);
    }

    /// Get selected action
    pub fn selected_action(&self) -> Option<&MenuAction> {
        self.items.get(self.selected)?.action.as_ref()
    }

    /// Clear all items
    pub fn clear(&mut self) {
        self.items.clear();
        self.selected = 0;
        self.first_visible = 0;
    }

    /// Update visible count based on screen size
    pub fn update_visible_count(&mut self) {
        let screen_h = screen_height();
        let line_height = self.renderer.line_height();
        let title_height = if self.config.title.is_empty() {
            0.0
        } else {
            24.0
        };
        let padding = 32.0;

        // Calculate how many items fit in available space
        let available_height = screen_h - self.config.y - padding - title_height;
        self.visible_count = (available_height / line_height).floor() as usize;
        self.visible_count = self.visible_count.max(3); // Minimum 3 items
    }

    /// Load decoration textures (GLIST tiles)
    pub async fn load_decoration(&mut self) -> Result<(), String> {
        self.decoration.load_tiles().await
    }

    /// Get navigation handler for touch setup
    pub fn navigation_mut(&mut self) -> &mut MenuNavigation {
        &mut self.navigation
    }

    /// Get item positions for touch detection
    pub fn get_item_positions(&self) -> Vec<(usize, f32, f32, f32, f32)> {
        let (width, _) = self.calculate_dimensions();
        let item_start_y = self.config.y + 24.0;
        let item_x = self.config.x + 32.0;
        let item_width = width - 64.0;
        let font_size = self.renderer.item_font_size();
        let line_height = self.renderer.line_height();

        let mut positions = Vec::new();
        for (i, item) in self.items.iter().enumerate() {
            if !item.is_separator() {
                // Text baseline position (same as draw_items)
                let text_baseline_y =
                    item_start_y + (i as f32 - self.first_visible as f32) * line_height;
                // Text visual area (for touch detection)
                let text_visual_top = text_baseline_y - font_size * 0.85;
                let text_visual_height = font_size;

                // Only include if potentially visible
                if text_baseline_y >= item_start_y - line_height
                    && text_baseline_y <= item_start_y + (self.visible_count as f32 * line_height)
                {
                    // Touch area with padding
                    positions.push((
                        i,
                        item_x - 8.0,
                        text_visual_top - 4.0,
                        item_width + 16.0,
                        text_visual_height + 8.0,
                    ));
                }
            }
        }
        positions
    }

    /// Draw menu with touch support
    pub fn draw_with_touch(&mut self) {
        // Update item positions for touch detection
        let positions = self.get_item_positions();
        self.navigation.set_item_positions(positions);

        self.draw();
        // Draw touch navigation buttons
        self.navigation.draw_touch_buttons();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_menu_creation() {
        let config = MenuConfig::default();
        let menu = Menu::new(config);
        assert_eq!(menu.items.len(), 0);
        assert_eq!(menu.selected(), 0);
    }

    #[test]
    fn test_add_item() {
        let mut menu = Menu::new(MenuConfig::default());
        menu.add_item("Start Game", MenuAction::GotoMode("playing".to_string()));
        assert_eq!(menu.items.len(), 1);
    }

    #[test]
    fn test_add_separator() {
        let mut menu = Menu::new(MenuConfig::default());
        menu.add_item("Item 1", MenuAction::None);
        menu.add_separator();
        menu.add_item("Item 2", MenuAction::None);
        assert_eq!(menu.items.len(), 3);
        assert!(menu.items[1].is_separator());
    }

    #[test]
    fn test_selected_action() {
        let mut menu = Menu::new(MenuConfig::default());
        menu.add_item("Start", MenuAction::GotoMode("playing".to_string()));
        menu.add_item("Quit", MenuAction::Quit);

        if let Some(MenuAction::GotoMode(mode)) = menu.selected_action() {
            assert_eq!(mode, "playing");
        } else {
            panic!("Expected GotoMode action");
        }
    }

    #[test]
    fn test_set_selected() {
        let mut menu = Menu::new(MenuConfig::default());
        menu.add_item("Item 1", MenuAction::None);
        menu.add_item("Item 2", MenuAction::None);
        menu.add_item("Item 3", MenuAction::None);

        menu.set_selected(1);
        assert_eq!(menu.selected(), 1);

        menu.set_selected(5); // Out of bounds
        assert_eq!(menu.selected(), 1); // Should not change
    }
}
