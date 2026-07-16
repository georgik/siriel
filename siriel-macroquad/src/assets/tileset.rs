// Siriel Macroquad - Tileset (texture-basic.png)

use crate::assets::CollisionMask;
use crate::core::SPRITE_SIZE;
use macroquad::prelude::*;

/// Tileset for map tiles from texture-basic.png
/// - Dimensions: 304x64 pixels
/// - Grid: 19 columns x 4 rows = 76 tiles
/// - Tile size: 16x16 pixels
pub struct Tileset {
    pub texture: Texture2D,
    pub columns: i32,
    pub tile_count: i32,
    /// Pre-computed collision masks for pixel-perfect collision
    pub collision_masks: Vec<CollisionMask>,
}

impl Tileset {
    /// Load tileset from PNG file and generate collision masks
    pub async fn load(path: &str) -> Result<Self, String> {
        // Load as Image first (CPU-side for pixel access)
        let image_data = load_file(path)
            .await
            .map_err(|e| format!("Failed to load file: {:?}", e))?;

        let image = Image::from_file_with_format(&image_data, Some(ImageFormat::Png))
            .map_err(|e| format!("Failed to decode image: {:?}", e))?;

        // Create texture (GPU-side for rendering)
        let texture = Texture2D::from_image(&image);
        texture.set_filter(FilterMode::Nearest);

        let columns = (texture.width() / SPRITE_SIZE as f32) as i32;
        let rows = (texture.height() / SPRITE_SIZE as f32) as i32;
        let tile_count = columns * rows;

        // Precompute collision masks for all tiles (CPU-side, one-time cost)
        let mut collision_masks = Vec::new();
        for i in 0..tile_count {
            let mask = CollisionMask::from_tile(&image, i as usize, columns as usize, 128);
            collision_masks.push(mask);
        }

        Ok(Self {
            texture,
            columns,
            tile_count,
            collision_masks,
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

    /// Check if specific pixel in a tile is solid
    pub fn is_pixel_solid(&self, tile_index: i32, pixel_x: usize, pixel_y: usize) -> bool {
        if tile_index < 0 || tile_index >= self.tile_count as i32 {
            return false;
        }
        let idx = tile_index as usize;
        if idx < self.collision_masks.len() {
            self.collision_masks[idx].is_solid_at(pixel_x, pixel_y)
        } else {
            false
        }
    }
}
