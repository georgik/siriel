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
            }
            NavigationResult::Activate(index) => {
                if let Some(_action) = self.items.get(index).and_then(|i| i.action.as_ref()) {
                    return NavigationResult::Activate(index);
                }
            }
            NavigationResult::Cancel => {
                return NavigationResult::Cancel;
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
        self.renderer.draw_items(
            &self.items,
            self.selected,
            self.first_visible,
            self.visible_count,
            self.config.x + 32.0, // Offset for decoration
            item_start_y,
            width - 64.0,
            self.config.primary_color,
            self.config.secondary_color,
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
            // Auto calculate based on items
            let max_width = self
                .items
                .iter()
                .map(|i| i.text.len() as f32 * 8.0)
                .fold(0.0_f32, |a, b| a.max(b));
            max_width + 64.0 // Padding for decoration
        };

        let height = if self.config.height > 0.0 {
            self.config.height
        } else {
            // Auto calculate based on visible items
            let title_height = if self.config.title.is_empty() {
                0.0
            } else {
                24.0
            };
            let items_height = self.visible_count.min(self.items.len()) as f32 * 16.0;
            title_height + items_height + 32.0 // Padding
        };

        (width, height)
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
        let item_height = 16.0;

        let mut positions = Vec::new();
        for (i, item) in self.items.iter().enumerate() {
            if !item.is_separator() {
                let y = item_start_y + (i as f32 - self.first_visible as f32) * item_height;
                // Only include if potentially visible
                if y >= item_start_y - item_height
                    && y <= item_start_y + (self.visible_count as f32 * item_height)
                {
                    positions.push((i, item_x, y, item_width, item_height));
                }
            }
        }
        positions
    }

    /// Draw menu with touch support
    pub fn draw_with_touch(&mut self) {
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
