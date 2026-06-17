// Siriel Macroquad - Menu Decoration
// GLIST tile-based menu decoration system

#![allow(dead_code)]

use macroquad::prelude::*;

/// GLIST decoration tile positions
#[derive(Clone, Copy, Debug)]
pub enum DecorationTile {
    /// Top-left corner
    TopLeft = 0,
    /// Top edge (repeating)
    TopEdge = 1,
    /// Top-right corner
    TopRight = 2,
    /// Left edge (repeating)
    LeftEdge = 3,
    /// Right edge (repeating)
    RightEdge = 4,
    /// Bottom-left corner
    BottomLeft = 5,
    /// Bottom edge (repeating)
    BottomEdge = 6,
    /// Bottom-right corner
    BottomRight = 7,
}

/// GLIST decoration system
pub struct GlistDecoration {
    /// Loaded tile texture (single texture for all tiles)
    tile_texture: Option<Texture2D>,
    /// Tile size (16x16 pixels)
    tile_size: f32,
}

impl GlistDecoration {
    /// Create new decoration system
    pub fn new() -> Self {
        Self {
            tile_texture: None,
            tile_size: 16.0,
        }
    }

    /// Load GLIST tiles from sprite sheet
    pub async fn load_tiles(&mut self) -> Result<(), String> {
        // Try to load from assets directory
        let texture_path = "assets/sprites/glist.png";

        // Load the sprite sheet
        let sheet = match load_texture(texture_path).await {
            Ok(t) => t,
            Err(e) => {
                eprintln!("Failed to load GLIST texture: {}", e);
                return Err(format!("Failed to load GLIST: {}", e));
            }
        };

        // Note: Macroquad doesn't have set_texture_filter in prelude
        // Texture filtering is handled by GPU settings

        // Store the whole sheet and use rect calculations during render
        self.tile_texture = Some(sheet);

        Ok(())
    }

    /// Check if tiles are loaded
    pub fn is_loaded(&self) -> bool {
        self.tile_texture.is_some()
    }

    /// Draw menu frame with decoration
    pub fn draw_frame(&self, x: f32, y: f32, width: f32, height: f32, fill_color: Color) {
        if !self.is_loaded() {
            // Fallback: draw simple rectangle
            draw_rectangle(x, y, width, height, fill_color);
            draw_rectangle_lines(x, y, width, height, 2.0, BLACK);
            return;
        }

        let sheet = self.tile_texture.as_ref().unwrap();
        let ts = self.tile_size;

        // Calculate tile counts
        let tiles_across = (width / ts).ceil() as usize;
        let tiles_down = (height / ts).ceil() as usize;

        // Draw filled interior
        let interior_x = x + ts;
        let interior_y = y + ts;
        let interior_w = width - 2.0 * ts;
        let interior_h = height - 2.0 * ts;

        if interior_w > 0.0 && interior_h > 0.0 {
            draw_rectangle(interior_x, interior_y, interior_w, interior_h, fill_color);
        }

        // Draw corner tiles
        self.draw_tile(sheet, DecorationTile::TopLeft, x, y);
        self.draw_tile(
            sheet,
            DecorationTile::TopRight,
            x + (tiles_across as f32 - 1.0) * ts,
            y,
        );
        self.draw_tile(
            sheet,
            DecorationTile::BottomLeft,
            x,
            y + (tiles_down as f32 - 1.0) * ts,
        );
        self.draw_tile(
            sheet,
            DecorationTile::BottomRight,
            x + (tiles_across as f32 - 1.0) * ts,
            y + (tiles_down as f32 - 1.0) * ts,
        );

        // Draw edge tiles
        // Top edge
        for i in 1..tiles_across - 1 {
            self.draw_tile(sheet, DecorationTile::TopEdge, x + i as f32 * ts, y);
        }

        // Bottom edge
        for i in 1..tiles_across - 1 {
            self.draw_tile(
                sheet,
                DecorationTile::BottomEdge,
                x + i as f32 * ts,
                y + (tiles_down as f32 - 1.0) * ts,
            );
        }

        // Left edge
        for i in 1..tiles_down - 1 {
            self.draw_tile(sheet, DecorationTile::LeftEdge, x, y + i as f32 * ts);
        }

        // Right edge
        for i in 1..tiles_down - 1 {
            self.draw_tile(
                sheet,
                DecorationTile::RightEdge,
                x + (tiles_across as f32 - 1.0) * ts,
                y + i as f32 * ts,
            );
        }
    }

    /// Draw single tile
    fn draw_tile(&self, sheet: &Texture2D, tile: DecorationTile, x: f32, y: f32) {
        let ts = self.tile_size;

        // Calculate source rect based on tile index
        let tile_idx = tile as usize;
        let src_x = (tile_idx % 4) as f32 * ts; // 4 tiles per row assumed
        let src_y = (tile_idx / 4) as f32 * ts;

        // Draw using draw_texture_ex with source rectangle
        draw_texture_ex(
            sheet,
            x,
            y,
            WHITE,
            DrawTextureParams {
                source: Some(Rect::new(src_x, src_y, ts, ts)),
                dest_size: Some(vec2(ts, ts)),
                rotation: 0.0,
                flip_x: false,
                flip_y: false,
                pivot: None,
            },
        );
    }

    /// Draw border only (no fill)
    pub fn draw_border_only(&self, x: f32, y: f32, width: f32, height: f32) {
        if !self.is_loaded() {
            // Fallback: draw simple lines
            draw_rectangle_lines(x, y, width, height, 2.0, BLACK);
            return;
        }

        let sheet = self.tile_texture.as_ref().unwrap();
        let ts = self.tile_size;
        let tiles_across = (width / ts).ceil() as usize;
        let tiles_down = (height / ts).ceil() as usize;

        // Draw only border tiles
        // Corners
        self.draw_tile(sheet, DecorationTile::TopLeft, x, y);
        self.draw_tile(
            sheet,
            DecorationTile::TopRight,
            x + (tiles_across as f32 - 1.0) * ts,
            y,
        );
        self.draw_tile(
            sheet,
            DecorationTile::BottomLeft,
            x,
            y + (tiles_down as f32 - 1.0) * ts,
        );
        self.draw_tile(
            sheet,
            DecorationTile::BottomRight,
            x + (tiles_across as f32 - 1.0) * ts,
            y + (tiles_down as f32 - 1.0) * ts,
        );

        // Edges
        for i in 1..tiles_across - 1 {
            self.draw_tile(sheet, DecorationTile::TopEdge, x + i as f32 * ts, y);
            self.draw_tile(
                sheet,
                DecorationTile::BottomEdge,
                x + i as f32 * ts,
                y + (tiles_down as f32 - 1.0) * ts,
            );
        }

        for i in 1..tiles_down - 1 {
            self.draw_tile(sheet, DecorationTile::LeftEdge, x, y + i as f32 * ts);
            self.draw_tile(
                sheet,
                DecorationTile::RightEdge,
                x + (tiles_across as f32 - 1.0) * ts,
                y + i as f32 * ts,
            );
        }
    }
}

impl Default for GlistDecoration {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decoration_creation() {
        let deco = GlistDecoration::new();
        assert!(!deco.is_loaded());
        assert_eq!(deco.tile_size, 16.0);
    }
}
