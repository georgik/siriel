// Siriel Macroquad - Tilemap Renderer

use crate::core::MAP_WIDTH;
use macroquad::prelude::*;

/// Test level data (26 rows x 42 columns)

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
