// Siriel Macroquad - Collision Detection for Creatures
// Implements CollisionDetector trait for tilemap

use crate::core::TILE_SIZE;
use crate::entities::ai::CollisionDetector;

/// Tilemap collision detector
pub struct TilemapDetector<'a> {
    tiles: &'a Vec<Vec<i32>>,
}

impl<'a> TilemapDetector<'a> {
    pub fn new(tiles: &'a Vec<Vec<i32>>) -> Self {
        Self { tiles }
    }

    /// Convert pixel coordinates to tile coordinates
    fn pixel_to_tile(&self, x: i32, y: i32) -> (usize, usize) {
        let tile_x = (x as usize) / (TILE_SIZE as usize);
        let tile_y = (y as usize) / (TILE_SIZE as usize);
        (tile_x, tile_y)
    }

    /// Check if tile ID is solid
    fn is_solid_tile(tile_id: i32) -> bool {
        // Tiles 24-63 are solid (terrain tiles)
        tile_id >= 24 && tile_id < 64
    }
}

impl<'a> CollisionDetector for TilemapDetector<'a> {
    fn is_solid(&self, x: i32, y: i32) -> bool {
        let (tile_x, tile_y) = self.pixel_to_tile(x, y);
        if tile_y < self.tiles.len() && tile_x < self.tiles[tile_y].len() {
            let tile_id = self.tiles[tile_y][tile_x];
            Self::is_solid_tile(tile_id)
        } else {
            // Out of bounds is solid
            true
        }
    }

    fn get_tile_at(&self, x: i32, y: i32) -> i32 {
        let (tile_x, tile_y) = self.pixel_to_tile(x, y);
        if tile_y < self.tiles.len() && tile_x < self.tiles[tile_y].len() {
            self.tiles[tile_y][tile_x]
        } else {
            0
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pixel_to_tile() {
        let tiles = vec![vec![0; 10]; 10];
        let detector = TilemapDetector::new(&tiles);

        assert_eq!(detector.pixel_to_tile(0, 0), (0, 0));
        assert_eq!(detector.pixel_to_tile(8, 8), (1, 1));
        assert_eq!(detector.pixel_to_tile(16, 24), (2, 3));
    }

    #[test]
    fn test_is_solid_tile() {
        assert!(TilemapDetector::is_solid_tile(24));
        assert!(TilemapDetector::is_solid_tile(30));
        assert!(TilemapDetector::is_solid_tile(63));
        assert!(!TilemapDetector::is_solid_tile(0));
        assert!(!TilemapDetector::is_solid_tile(23));
        assert!(!TilemapDetector::is_solid_tile(64));
    }

    #[test]
    fn test_is_solid_empty_map() {
        let tiles = vec![vec![0; 10]; 10];
        let detector = TilemapDetector::new(&tiles);

        assert!(!detector.is_solid(16, 16));
    }

    #[test]
    fn test_is_solid_with_terrain() {
        let mut tiles = vec![vec![0; 10]; 10];
        tiles[2][3] = 30; // Solid tile

        let detector = TilemapDetector::new(&tiles);
        // Pixel (24, 16) = tile (3, 2)
        assert!(detector.is_solid(26, 18));
        assert!(!detector.is_solid(8, 8));
    }

    #[test]
    fn test_is_solid_out_of_bounds() {
        let tiles = vec![vec![0; 10]; 10];
        let detector = TilemapDetector::new(&tiles);

        // Out of bounds should be solid
        assert!(detector.is_solid(-1, 0));
        assert!(detector.is_solid(0, -1));
        assert!(detector.is_solid(1000, 0));
        assert!(detector.is_solid(0, 1000));
    }

    #[test]
    fn test_can_move_to() {
        let mut tiles = vec![vec![0; 10]; 10];
        tiles[4][4] = 30; // Solid tile at (4, 4)

        let detector = TilemapDetector::new(&tiles);

        // 16x16 entity at (32, 32) touches tiles (4,4) to (6,6)
        // Should collide with solid tile at (4, 4) because corner (32, 32) maps to tile (4, 4)
        assert!(!detector.can_move_to(32, 32, 16, 16));

        // 16x16 entity at (8, 8) touches tiles (1,1) to (3,3), no collision
        assert!(detector.can_move_to(8, 8, 16, 16));
    }

    #[test]
    fn test_get_tile_at() {
        let mut tiles = vec![vec![0; 10]; 10];
        tiles[2][3] = 42;

        let detector = TilemapDetector::new(&tiles);
        // Pixel (24, 16) = tile (3, 2)
        assert_eq!(detector.get_tile_at(26, 18), 42);
        assert_eq!(detector.get_tile_at(8, 8), 0);
    }
}
