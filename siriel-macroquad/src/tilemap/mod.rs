// Siriel Macroquad - Tilemap Renderer

use crate::assets::Tileset;
use crate::core::{MAP_WIDTH, TILE_SIZE};
use macroquad::prelude::*;

/// Draw tilemap from 2D array
pub fn draw_tilemap(
    tileset: &Tileset,
    tilemap: &[Vec<i32>],
    offset_x: f32,
    offset_y: f32,
    show_indices: bool,
) {
    // Draw grid lines first (behind tiles)
    if show_indices {
        let map_width_px = tilemap.first().map_or(0, |r| r.len() * TILE_SIZE as usize);
        let map_height_px = tilemap.len() * TILE_SIZE as usize;

        // Vertical lines every tile (16px)
        for x in (0..=map_width_px).step_by(TILE_SIZE as usize) {
            draw_line(
                offset_x + x as f32,
                offset_y,
                offset_x + x as f32,
                offset_y + map_height_px as f32,
                1.0,
                GRAY,
            );
        }

        // Horizontal lines every tile (16px)
        for y in (0..=map_height_px).step_by(TILE_SIZE as usize) {
            draw_line(
                offset_x,
                offset_y + y as f32,
                offset_x + map_width_px as f32,
                offset_y + y as f32,
                1.0,
                GRAY,
            );
        }
    }

    for (y, row) in tilemap.iter().enumerate() {
        for (x, &tile) in row.iter().enumerate() {
            // Skip empty tiles
            if tile == 0 {
                continue;
            }

            let screen_x = offset_x + (x as i32 * TILE_SIZE) as f32;
            let screen_y = offset_y + (y as i32 * TILE_SIZE) as f32;

            // Check if tile is valid for spritesheet
            if tile < tileset.tile_count {
                tileset.draw_tile(tile, screen_x, screen_y, WHITE);

                // Debug: draw tile index and coordinates
                if show_indices {
                    // Show tile ID on every tile
                    draw_text(
                        &tile.to_string(),
                        screen_x + 2.0,
                        screen_y + 2.0,
                        8.0,
                        YELLOW,
                    );

                    // Show (x,y) only every 10th tile
                    if x % 10 == 0 && y % 10 == 0 {
                        draw_text(
                            &format!("({},{})", x, y),
                            screen_x + 2.0,
                            screen_y + 11.0,
                            8.0,
                            WHITE,
                        );
                    }
                }
            }
        }
    }
}

/// Test level data (26 rows x 42 columns)
#[allow(dead_code)]
pub fn get_test_level() -> Vec<Vec<i32>> {
    vec![
        // Row 0-24: Empty space (zeros)
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        vec![0; 42],
        // Row 25: Ground
        vec![
            24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
            24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
        ],
    ]
}

/// Create a platform in the tilemap
#[allow(dead_code)]
pub fn add_platform(
    tilemap: &mut Vec<Vec<i32>>,
    row: usize,
    start_x: usize,
    end_x: usize,
    tile: i32,
) {
    if row < tilemap.len() && start_x < MAP_WIDTH && end_x <= MAP_WIDTH {
        for x in start_x..end_x {
            tilemap[row][x] = tile;
        }
    }
}
