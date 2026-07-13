// Siriel Macroquad - Tileset (texture-basic.png)

use crate::core::SPRITE_SIZE;
use macroquad::prelude::*;

/// Tileset for map tiles from texture-basic.png
/// - Dimensions: 304x64 pixels
/// - Grid: 19 columns x 4 rows = 76 tiles
/// - Tile size: 16x16 pixels
#[allow(dead_code)]
pub struct Tileset {
    pub texture: Texture2D,
    pub columns: i32,
    pub rows: i32,
    pub tile_count: i32,
}

impl Tileset {
    /// Load tileset from PNG file
    pub async fn load(path: &str) -> Result<Self, String> {
        let texture = load_texture(path)
            .await
            .map_err(|e| format!("Failed to load texture: {:?}", e))?;

        texture.set_filter(FilterMode::Nearest);

        let columns = (texture.width() / SPRITE_SIZE as f32) as i32;
        let rows = (texture.height() / SPRITE_SIZE as f32) as i32;

        Ok(Self {
            texture,
            columns,
            rows,
            tile_count: columns * rows,
        })
    }

    /// Get source rectangle for tile index
    pub fn get_tile_rect(&self, index: i32) -> Rect {
        if index < 0 || index >= self.tile_count {
            return Rect::default();
        }

        let col = index % self.columns;
        let row = index / self.columns;

        Rect {
            x: col as f32 * SPRITE_SIZE as f32,
            y: row as f32 * SPRITE_SIZE as f32,
            w: SPRITE_SIZE as f32,
            h: SPRITE_SIZE as f32,
        }
    }

    /// Draw tile at screen position (16px)
    pub fn draw_tile(&self, index: i32, x: f32, y: f32, tint: Color) {
        let src = self.get_tile_rect(index);
        if src.w == 0.0 {
            return; // Invalid tile
        }

        draw_texture_ex(
            &self.texture,
            x,
            y,
            tint,
            DrawTextureParams {
                source: Some(src),
                ..Default::default()
            },
        );
    }
}
