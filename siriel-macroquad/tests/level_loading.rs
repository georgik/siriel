// Tests for level loading and parsing

use serde::Deserialize;
use siriel_macroquad::level::loader::{load_from_ron, load_from_ron_async};
use siriel_macroquad::level::types::{
    Behavior, EntityType, GridPos, LevelData, LevelEntity, MapData,
};

#[test]
fn test_load_fmis01_ron() {
    let path = std::path::Path::new("assets/levels/fmis01.ron");
    let level = load_from_ron(path).expect("Failed to load fmis01.ron");

    // Check basic level data
    assert_eq!(level.meta.name, "START");
    assert_eq!(level.player_start, (88, 88));

    // Check map dimensions
    assert_eq!(level.tiles[0].len(), 39); // width
    assert_eq!(level.tiles.len(), 27); // height

    // Check creatures loaded
    assert!(
        !level.creatures.is_empty(),
        "Level should have creatures/entities"
    );

    // First creature should be a pear collectible
    let first_creature = &level.creatures[0];
    assert_eq!(first_creature.sprite_name, "pear");
    assert_eq!(first_creature.base.x, 64.0);
    assert_eq!(first_creature.base.y, 144.0);
}

#[test]
fn test_leveldata_deserialize() {
    let ron_content =
        std::fs::read_to_string("assets/levels/fmis01.ron").expect("Failed to read fmis01.ron");

    let mut parser =
        ron::Deserializer::from_str(&ron_content).expect("Failed to create RON parser");

    let level_data: LevelData =
        LevelData::deserialize(&mut parser).expect("Failed to deserialize LevelData");

    // Check entities
    assert!(
        !level_data.entities.is_empty(),
        "LevelData should have entities"
    );

    // Check first entity
    let first = &level_data.entities[0];
    assert_eq!(
        first.entity_type,
        siriel_macroquad::level::types::EntityType::Collectible
    );
    assert_eq!(first.sprite_name, "pear");
    assert_eq!(
        first.behavior,
        siriel_macroquad::level::types::Behavior::Static
    );

    // Check named params for collectible
    assert_eq!(first.event_id, Some(3));
    assert_eq!(first.score, Some(10));
    assert_eq!(first.target_level, None);
}

#[test]
fn test_to_legacy_params_conversion() {
    use siriel_macroquad::level::types::*;

    // Create test LevelData with collectible
    let level_data = LevelData {
        name: "Test".to_string(),
        music: "TEST".to_string(),
        start_position: GridPos { x: 0, y: 0 },
        map: MapData {
            width: 10,
            height: 10,
            tiles: vec![vec![0; 10]; 10],
        },
        entities: vec![
            LevelEntity {
                id: "test1".to_string(),
                entity_type: EntityType::Collectible,
                sprite_name: "pear".to_string(),
                position: GridPos { x: 64, y: 144 },
                behavior: Behavior::Static,
                event_id: Some(3),
                score: Some(10),
                target_level: None,
                sound_id: None,
                left_grid: None,
                right_grid: None,
                top_grid: None,
                bottom_grid: None,
                speed: None,
                initial_dir: None,
                danger: false,
                group: "A".to_string(),
            },
            // Horizontal oscillator
            LevelEntity {
                id: "test2".to_string(),
                entity_type: EntityType::Talk, // dummy type
                sprite_name: "monster".to_string(),
                position: GridPos { x: 100, y: 100 },
                behavior: Behavior::HorizontalOscillator,
                event_id: None,
                score: None,
                target_level: None,
                sound_id: None,
                left_grid: Some(5),
                right_grid: Some(15),
                top_grid: None,
                bottom_grid: None,
                speed: Some(2),
                initial_dir: Some(0),
                danger: true,
                group: "A".to_string(),
            },
        ],
        messages: vec![],
        transitions: vec![],
    };

    let level = level_data.to_legacy();

    // Check creatures were created
    assert_eq!(level.creatures.len(), 2);

    // First creature (collectible)
    let c1 = &level.creatures[0];
    assert_eq!(c1.sprite_name, "pear");
    // inf1 should be event_id * 8 = 3 * 8 = 24
    // inf2 should be score * 8 = 10 * 8 = 80
    assert_eq!(c1.inf1, 24);
    assert_eq!(c1.inf2, 80);

    // Second creature (horizontal oscillator)
    let c2 = &level.creatures[1];
    assert_eq!(c2.sprite_name, "monster");
    // left_grid * 8 = 5 * 8 = 40
    // right_grid * 8 = 15 * 8 = 120
    assert_eq!(c2.inf1, 40);
    assert_eq!(c2.inf2, 120);
    assert_eq!(c2.inf3, 2); // speed
    assert_eq!(c2.inf7, 0); // initial_dir
}
