// Siriel Macroquad - Level System Tests

use super::loader::*;
use super::types::*;

#[cfg(test)]
mod integration_tests {
    use super::*;

    #[test]
    fn test_empty_level_dimensions() {
        let level = Level::empty();
        assert_eq!(level.meta.width, 42);
        assert_eq!(level.meta.height, 26);
        assert_eq!(level.tiles.len(), 26);
        assert_eq!(level.tiles[0].len(), 42);
    }

    #[test]
    fn test_empty_level_all_zeros() {
        let level = Level::empty();
        for row in &level.tiles {
            for &tile in row {
                assert_eq!(tile, 0);
            }
        }
    }

    #[test]
    fn test_player_spawn_position() {
        let level = Level::empty();
        assert_eq!(level.player_start, (88, 88));
    }

    #[test]
    fn test_get_tile_within_bounds() {
        let level = Level::empty();
        assert_eq!(level.get_tile(0, 0), 0);
        assert_eq!(level.get_tile(41, 25), 0);
    }

    #[test]
    fn test_get_tile_out_of_bounds() {
        let level = Level::empty();
        assert_eq!(level.get_tile(100, 0), 0);
        assert_eq!(level.get_tile(0, 100), 0);
    }

    #[test]
    fn test_set_tile() {
        let mut level = Level::empty();
        level.set_tile(10, 10, 24);
        assert_eq!(level.get_tile(10, 10), 24);
    }

    #[test]
    fn test_set_tile_out_of_bounds() {
        let mut level = Level::empty();
        // Should not panic
        level.set_tile(100, 100, 24);
    }

    #[test]
    fn test_level_from_data() {
        let meta = LevelMeta {
            name: "Test".to_string(),
            author: "Author".to_string(),
            version: "1.0".to_string(),
            width: 3,
            height: 2,
            music: None,
        };
        let tiles = vec![vec![1, 2, 3], vec![4, 5, 6]];
        let level = Level::from_data(meta.clone(), tiles, (100, 100));

        assert_eq!(level.meta.name, "Test");
        assert_eq!(level.player_start, (100, 100));
        assert_eq!(level.get_tile(0, 0), 1);
        assert_eq!(level.get_tile(2, 1), 6);
    }

    #[test]
    fn test_level_meta_default() {
        let meta = LevelMeta::default();
        assert_eq!(meta.name, "Untitled");
        assert_eq!(meta.author, "Unknown");
        assert_eq!(meta.version, "1.0");
        assert_eq!(meta.width, 42);
        assert_eq!(meta.height, 26);
    }

    #[test]
    fn test_parse_tilemap_empty() {
        let result = parse_tilemap("[]");
        assert!(result.is_ok());
        assert_eq!(result.unwrap().len(), 0);
    }

    #[test]
    fn test_parse_tilemap_single_row() {
        let result = parse_tilemap("[[1, 2, 3]]");
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![vec![1, 2, 3]]);
    }

    #[test]
    fn test_parse_tilemap_multiple_rows() {
        let result = parse_tilemap("[[1, 2], [3, 4], [5, 6]]");
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), vec![vec![1, 2], vec![3, 4], vec![5, 6]]);
    }

    #[test]
    fn test_parse_tilemap_with_spaces() {
        let result = parse_tilemap("[[ 1 , 2 ], [ 3 , 4 ]]");
        assert!(result.is_ok());
    }

    #[test]
    fn test_parse_tilemap_invalid_no_brackets() {
        let result = parse_tilemap("1, 2, 3");
        assert!(result.is_err());
    }

    #[test]
    fn test_parse_level_file_minimal() {
        let input = r#"
name: "Test"
author: "Author"
player_start: (10, 20)
tiles: [[1, 2], [3, 4]]
"#;
        let level = parse_level_file(input).unwrap();
        assert_eq!(level.meta.name, "Test");
        assert_eq!(level.meta.author, "Author");
        assert_eq!(level.player_start, (10, 20));
        assert_eq!(level.tiles, vec![vec![1, 2], vec![3, 4]]);
    }

    #[test]
    fn test_parse_level_file_with_comments() {
        let input = r#"
// This is a comment
name: "Test"
// Another comment
author: "Author"
player_start: (10, 20)
tiles: [[1, 2]]
"#;
        let level = parse_level_file(input).unwrap();
        assert_eq!(level.meta.name, "Test");
    }

    #[test]
    fn test_parse_level_file_empty_lines() {
        let input = r#"

name: "Test"


author: "Author"

tiles: [[1]]

"#;
        let level = parse_level_file(input).unwrap();
        assert_eq!(level.meta.name, "Test");
    }

    #[test]
    fn test_parse_level_file_no_tiles() {
        let input = r#"
name: "Test"
author: "Author"
"#;
        let result = parse_level_file(input);
        assert!(result.is_err());
    }

    #[test]
    fn test_level_width_height_calculation() {
        let meta = LevelMeta::default();
        let tiles = vec![vec![0; 10]; 5];
        let mut level = Level::from_data(meta, tiles, (0, 0));

        level.meta.width = 10;
        level.meta.height = 5;

        assert_eq!(level.meta.width, 10);
        assert_eq!(level.meta.height, 5);
    }

    #[test]
    fn test_solid_tile_detection() {
        let mut level = Level::empty();
        level.set_tile(5, 5, 24);
        assert!(level.get_tile(5, 5) >= 24);

        level.set_tile(6, 6, 10);
        assert!(level.get_tile(6, 6) < 24);
    }

    #[test]
    fn test_level_clone() {
        let level = Level::empty();
        let cloned = level.clone();
        assert_eq!(level.meta.name, cloned.meta.name);
        assert_eq!(level.tiles.len(), cloned.tiles.len());
    }
}
