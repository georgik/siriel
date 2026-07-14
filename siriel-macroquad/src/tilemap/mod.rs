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

                // Debug: draw tile index
                if show_indices {
                    draw_text(
                        &tile.to_string(),
                        screen_x + 2.0,
                        screen_y + 2.0,
                        10.0,
                        YELLOW,
                    );
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
