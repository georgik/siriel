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
        // Use larger sizes for WASM/mobile
        let (item_font_size, title_font_size, line_height) = if cfg!(target_arch = "wasm32") {
            (24.0, 28.0, 36.0) // Larger for mobile touch
        } else {
            (16.0, 20.0, 18.0) // Desktop sizes
        };

        Self {
            item_font_size,
            title_font_size,
            line_height,
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

            // Get display text
            let text = item.display_text();

            // Choose color based on selection and enabled state
            let color = if i == selected {
                selected_color
            } else if item.enabled {
                normal_color
            } else {
                Color::new(0.5, 0.5, 0.5, 1.0) // Gray for disabled
            };

            // Draw item text (draw_text uses baseline as y)
            draw_text(&text, x, current_y, self.item_font_size, color);

            // Draw selection highlight background for selected item
            // Highlight positioned above baseline (text visual area)
            if i == selected {
                let text_visual_top = current_y - self.item_font_size * 0.85;
                let text_visual_height = self.item_font_size;
                self.draw_selection_highlight(
                    x - 8.0,
                    text_visual_top - 2.0,
                    width + 16.0,
                    text_visual_height + 4.0,
                );
                // Arrow centered on text visual center
                let text_center_y = text_visual_top + text_visual_height / 2.0;
                self.draw_selection_indicator(x - 16.0, text_center_y);
            }

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

    /// Draw selection highlight background
    fn draw_selection_highlight(&self, x: f32, y: f32, width: f32, height: f32) {
        // Semi-transparent highlight
        let highlight_color = Color::new(0.2, 0.4, 0.8, 0.3);
        draw_rectangle(x, y, width, height, highlight_color);
        // Border
        draw_rectangle_lines(x, y, width, height, 2.0, Color::new(0.3, 0.6, 1.0, 0.6));
    }

    /// Draw scroll indicator (showing more items above/below)
    fn draw_scroll_indicator(&self, _x: f32, _y: f32, _is_up: bool) {
        // No longer used - replaced by scrollbar
    }

    /// Draw visible scrollbar
    pub fn draw_scrollbar(
        &self,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        first_visible: usize,
        total_items: usize,
        visible_count: usize,
    ) {
        if total_items <= visible_count {
            return; // No scrollbar needed
        }

        let bar_width = 8.0;
        let bar_x = x + width - bar_width - 2.0;
        let track_height = height;

        // Draw track (dark gray for visibility)
        draw_rectangle(
            bar_x,
            y,
            bar_width,
            track_height,
            Color::new(0.3, 0.3, 0.3, 0.8),
        );

        // Calculate thumb size and position
        let scroll_ratio = visible_count as f32 / total_items as f32;
        let thumb_height = (track_height * scroll_ratio).max(20.0); // Min 20px height
        let position_ratio = first_visible as f32 / (total_items - visible_count) as f32;
        let thumb_y = y + (track_height - thumb_height) * position_ratio;

        // Draw thumb (lighter color with border)
        draw_rectangle(
            bar_x,
            thumb_y,
            bar_width,
            thumb_height,
            Color::new(0.6, 0.6, 0.6, 0.9),
        );
        draw_rectangle_lines(
            bar_x,
            thumb_y,
            bar_width,
            thumb_height,
            1.0,
            Color::new(0.2, 0.2, 0.2, 1.0),
        );
    }

    /// Set item font size
    pub fn set_item_font_size(&mut self, size: f32) {
        self.item_font_size = size;
    }

    /// Get item font size
    pub fn item_font_size(&self) -> f32 {
        self.item_font_size
    }

    /// Get title font size
    pub fn title_font_size(&self) -> f32 {
        self.title_font_size
    }

    /// Set title font size
    pub fn set_title_font_size(&mut self, size: f32) {
        self.title_font_size = size;
    }

    /// Set line height
    pub fn set_line_height(&mut self, height: f32) {
        self.line_height = height;
    }

    /// Get line height
    pub fn line_height(&self) -> f32 {
        self.line_height
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
