// Siriel Macroquad - Collision Masks for Pixel-Perfect Collision
// Pre-computed collision data for tiles, matching original Siriel's pixel-level collision

use macroquad::prelude::Image;

/// Collision mask for a single tile
/// Tracks which pixels are solid (non-transparent)
pub struct CollisionMask {
    /// Solid pixels (true = solid, false = transparent)
    pub solid: Vec<bool>,
    pub width: usize,
    pub height: usize,
}

impl CollisionMask {
    /// Extract tile sub-image from atlas and build collision mask
    pub fn from_tile(
        image: &Image,
        tile_index: usize,
        columns: usize,
        alpha_threshold: u8,
    ) -> Self {
        let tile_w = 16;
        let tile_h = 16;
        let img_w = image.width() as usize;
        let img_h = image.height() as usize;

        let col = tile_index % columns;
        let row = tile_index / columns;
        let start_x = col * tile_w;
        let start_y = row * tile_h;

        let mut solid = Vec::with_capacity(tile_w * tile_h);

        for y in 0..tile_h {
            for x in 0..tile_w {
                let px = start_x + x;
                let py = start_y + y;

                if px < img_w && py < img_h {
                    let pixel = image.get_pixel(px as u32, py as u32);
                    // Alpha >= threshold = solid pixel (original used color index 13)
                    // pixel.a is f32 (0.0-1.0), threshold is u8 (0-255), convert
                    let threshold_f32 = alpha_threshold as f32 / 255.0;
                    solid.push(pixel.a >= threshold_f32);
                } else {
                    solid.push(false);
                }
            }
        }

        Self {
            solid,
            width: tile_w,
            height: tile_h,
        }
    }

    /// Check if specific pixel offset is solid
    pub fn is_solid_at(&self, x: usize, y: usize) -> bool {
        if x >= self.width || y >= self.height {
            return false;
        }
        self.solid[y * self.width + x]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bounds_check() {
        // Create a simple mask for testing
        let mask = CollisionMask {
            solid: vec![false; 256],
            width: 16,
            height: 16,
        };
        // Out of bounds should return false
        assert!(!mask.is_solid_at(16, 0));
        assert!(!mask.is_solid_at(0, 16));
        // In bounds but false should return false
        assert!(!mask.is_solid_at(0, 0));
    }
}
