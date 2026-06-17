// Siriel Macroquad - Menu Renderer
// Menu rendering and text display

use crate::menu::item::MenuItem;
use macroquad::prelude::*;

/// Menu rendering style
#[derive(Clone, Debug)]
pub enum MenuStyle {
    /// Classic style (like siriel-modern)
    Classic,
    /// Modern style
    Modern,
    /// Minimal style
    Minimal,
}

/// Menu renderer
pub struct MenuRenderer {
    /// Font size for items
    item_font_size: f32,
    /// Font size for title
    title_font_size: f32,
    /// Line height
    line_height: f32,
}

impl MenuRenderer {
    /// Create new menu renderer
    pub fn new() -> Self {
        Self {
            item_font_size: 16.0,
            title_font_size: 20.0,
            line_height: 18.0,
        }
    }

    /// Draw menu items
    pub fn draw_items(
        &self,
        items: &[MenuItem],
        selected: usize,
        first_visible: usize,
        visible_count: usize,
        x: f32,
        y: f32,
        width: f32,
        selected_color: Color,
        normal_color: Color,
    ) {
        let mut current_y = y;

        // Draw visible items
        let end_visible = (first_visible + visible_count).min(items.len());

        for i in first_visible..end_visible {
            let item = &items[i];

            // Skip if separator (draw line instead)
            if item.is_separator() {
                self.draw_separator(x, current_y, width);
                current_y += self.line_height / 2.0;
                continue;
            }

            // Choose color based on selection and enabled state
            let color = if i == selected {
                selected_color
            } else if item.enabled {
                normal_color
            } else {
                Color::new(0.5, 0.5, 0.5, 1.0) // Gray for disabled
            };

            // Get display text
            let text = item.display_text();

            // Draw selection indicator for selected item
            if i == selected {
                self.draw_selection_indicator(x - 16.0, current_y + self.item_font_size / 2.0);
            }

            // Draw item text
            draw_text(&text, x, current_y, self.item_font_size, color);

            current_y += self.line_height;
        }
    }

    /// Draw title
    pub fn draw_title(&self, title: &str, x: f32, y: f32, color: Color) {
        let text_width = measure_text(title, None, self.title_font_size as u16, 1.0).width;
        let title_x = x - text_width as f32 / 2.0;

        draw_text(
            title,
            title_x,
            y - self.title_font_size / 2.0,
            self.title_font_size,
            color,
        );
    }

    /// Draw separator line
    fn draw_separator(&self, x: f32, y: f32, width: f32) {
        draw_line(
            x,
            y + self.line_height / 2.0,
            x + width,
            y + self.line_height / 2.0,
            1.0,
            DARKGRAY,
        );
    }

    /// Draw selection indicator (small avatar or cursor)
    fn draw_selection_indicator(&self, x: f32, y: f32) {
        // Draw small triangle or cursor
        let size = 8.0;
        draw_triangle(
            vec2(x, y - size / 2.0),
            vec2(x + size, y),
            vec2(x, y + size / 2.0),
            BLACK,
        );
    }

    /// Set item font size
    pub fn set_item_font_size(&mut self, size: f32) {
        self.item_font_size = size;
    }

    /// Set title font size
    pub fn set_title_font_size(&mut self, size: f32) {
        self.title_font_size = size;
    }

    /// Set line height
    pub fn set_line_height(&mut self, height: f32) {
        self.line_height = height;
    }
}

impl Default for MenuRenderer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::menu::item::MenuAction;

    #[test]
    fn test_renderer_creation() {
        let renderer = MenuRenderer::new();
        assert_eq!(renderer.item_font_size, 16.0);
        assert_eq!(renderer.title_font_size, 20.0);
    }

    #[test]
    fn test_font_size_setting() {
        let mut renderer = MenuRenderer::new();
        renderer.set_item_font_size(20.0);
        assert_eq!(renderer.item_font_size, 20.0);
    }
}
