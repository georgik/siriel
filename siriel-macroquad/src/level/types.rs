// Siriel Macroquad - Level Type Definitions

#![allow(dead_code)]

use crate::core::{MAP_HEIGHT, MAP_WIDTH};
use crate::entities::Creature;
use serde::{Deserialize, Serialize};

/// Entity type from MIE 4-letter code
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum EntityType {
    /// Z-type - Collectible by walking
    Collectible,
    /// Y-type - Immediate action trigger
    Trigger,
    /// X-type - Requires Enter key
    Interactable,
    /// W-type - Doors, switches
    UseObject,
    /// V-type - NPC/dialog
    Talk,
}

/// Entity AI behavior
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Behavior {
    Static,
    HorizontalOscillator,
    VerticalOscillator,
    PlatformWithGravity,
    EdgeWalking,
    RandomMovement,
    Hunter,
    Fireball,
    AdvancedProjectile,
    SoundTrigger,
    Teleport,
    ShowGroup,
    HideGroup,
    LevelComplete,
    AddLife,
    TextureChange,
    SwapRoomVisibility,
    TransferToStage,
}

impl Default for Behavior {
    fn default() -> Self {
        Behavior::Static
    }
}

/// Visibility group
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Group {
    A,
    B,
    C,
    D,
    E,
    F,
    G,
}

impl Default for Group {
    fn default() -> Self {
        Group::A
    }
}

/// Grid position
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GridPos {
    pub x: i32,
    pub y: i32,
}

/// Localized message with support for multiple languages
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocalizedMessage {
    #[serde(default = "default_en")]
    pub en: String,
    #[serde(default)]
    pub sk: Option<String>,
    #[serde(default)]
    pub de: Option<String>,
    #[serde(default)]
    pub fr: Option<String>,
}

fn default_en() -> String {
    String::new()
}

impl LocalizedMessage {
    pub fn get(&self, lang: &str) -> &str {
        match lang {
            "sk" if self.sk.is_some() => self.sk.as_ref().unwrap(),
            "de" if self.de.is_some() => self.de.as_ref().unwrap(),
            "fr" if self.fr.is_some() => self.fr.as_ref().unwrap(),
            _ => &self.en,
        }
    }
}

/// Level entity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LevelEntity {
    pub id: String,
    pub entity_type: EntityType,
    pub sprite_name: String,
    pub position: GridPos,
    pub behavior: Behavior,
    #[serde(default)]
    pub params: Vec<i32>,
    #[serde(default)]
    pub danger: bool,
    #[serde(default)]
    pub group: Group,
}

/// Map data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MapData {
    pub width: usize,
    pub height: usize,
    pub tiles: Vec<Vec<i32>>,
}

impl MapData {
    pub fn get_tile(&self, x: usize, y: usize) -> i32 {
        if y < self.tiles.len() && x < self.tiles[y].len() {
            self.tiles[y][x]
        } else {
            0
        }
    }

    pub fn set_tile(&mut self, x: usize, y: usize, tile: i32) {
        if y < self.tiles.len() && x < self.tiles[y].len() {
            self.tiles[y][x] = tile;
        }
    }

    pub fn is_solid(&self, x: usize, y: usize) -> bool {
        let tile = self.get_tile(x, y);
        tile >= 24 // Tiles 24+ are solid
    }
}

/// Level metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LevelMeta {
    pub name: String,
    #[serde(default)]
    pub author: String,
    #[serde(default)]
    pub version: String,
    pub width: usize,
    pub height: usize,
    #[serde(default)]
    pub music: Option<String>,
}

impl Default for LevelMeta {
    fn default() -> Self {
        Self {
            name: "Untitled".to_string(),
            author: "Unknown".to_string(),
            version: "1.0".to_string(),
            width: MAP_WIDTH,
            height: MAP_HEIGHT,
            music: None,
        }
    }
}

/// Complete level data (RON format)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LevelData {
    pub name: String,
    #[serde(default)]
    pub music: String,
    pub start_position: GridPos,
    pub map: MapData,
    #[serde(default)]
    pub entities: Vec<LevelEntity>,
    #[serde(default)]
    pub messages: Vec<LocalizedMessage>,
    #[serde(default)]
    pub transitions: Vec<Transition>,
}

/// Room transition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transition {
    pub from_id: String,
    pub to_level: String,
    pub target_position: GridPos,
}

/// Level entry in datadisc
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatadiscLevel {
    pub id: String,
    pub key: char,
    pub name: String,
    pub file: String,
}

/// Datadisc metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Datadisc {
    pub name: String,
    #[serde(default)]
    pub description: String,
    pub levels: Vec<DatadiscLevel>,
}

/// Legacy Level (for backwards compatibility)
#[derive(Debug, Clone)]
pub struct Level {
    pub meta: LevelMeta,
    pub tiles: Vec<Vec<i32>>,
    pub player_start: (i32, i32),
    /// Level messages (MSG1-MSG5 from original)
    pub messages: Vec<String>,
    /// Creatures loaded from TOML
    pub creatures: Vec<Creature>,
}

impl Level {
    /// Create empty level with default metadata
    pub fn empty() -> Self {
        Self {
            meta: LevelMeta::default(),
            tiles: vec![vec![0; MAP_WIDTH]; MAP_HEIGHT],
            player_start: (88, 88),
            messages: Vec::new(),
            creatures: Vec::new(),
        }
    }

    /// Create level from data
    pub fn from_data(meta: LevelMeta, tiles: Vec<Vec<i32>>, player_start: (i32, i32)) -> Self {
        Self {
            meta,
            tiles,
            player_start,
            messages: Vec::new(),
            creatures: Vec::new(),
        }
    }

    /// Get tile at position
    pub fn get_tile(&self, x: usize, y: usize) -> i32 {
        if y < self.tiles.len() && x < self.tiles[y].len() {
            self.tiles[y][x]
        } else {
            0
        }
    }

    /// Set tile at position
    pub fn set_tile(&mut self, x: usize, y: usize, tile: i32) {
        if y < self.tiles.len() && x < self.tiles[y].len() {
            self.tiles[y][x] = tile;
        }
    }

    /// Add creature to level
    pub fn add_creature(&mut self, creature: Creature) {
        self.creatures.push(creature);
    }

    /// Get all creatures
    pub fn creatures(&self) -> &[Creature] {
        &self.creatures
    }

    /// Get mutable creatures for updating
    pub fn creatures_mut(&mut self) -> &mut [Creature] {
        &mut self.creatures
    }
}

impl LevelData {
    /// Convert to legacy Level format
    pub fn to_legacy(&self) -> Level {
        // Convert localized messages to simple strings (English by default)
        let messages: Vec<String> = self.messages.iter().map(|m| m.en.clone()).collect();

        // Convert entities to creatures
        use crate::entities::{Creature, BehaviorType};
        let creatures: Vec<Creature> = self
            .entities
            .iter()
            .filter_map(|entity| {
                // Map behavior string to BehaviorType
                let behavior = match entity.behavior {
                    Behavior::Static => BehaviorType::Pickup,
                    Behavior::HorizontalOscillator => BehaviorType::HorizontalPatrol,
                    Behavior::VerticalOscillator => BehaviorType::VerticalPatrol,
                    Behavior::PlatformWithGravity => BehaviorType::PlatformGravity,
                    Behavior::EdgeWalking => BehaviorType::PlatformEdge,
                    Behavior::RandomMovement => BehaviorType::RandomWanderer,
                    Behavior::Hunter => BehaviorType::ChasingEnemy,
                    Behavior::Fireball => BehaviorType::Fireball,
                    Behavior::AdvancedProjectile => BehaviorType::FireballAlt,
                    Behavior::Teleport => BehaviorType::Teleport,
                    Behavior::LevelComplete => BehaviorType::LevelComplete,
                    Behavior::AddLife => BehaviorType::AddLife,
                    _ => BehaviorType::Pickup,
                };

                // Store sprite_name in the frame field for now
                // TODO: Add sprite_name field to Creature
                Some(Creature::from_entity(
                    &entity.id,
                    &entity.sprite_name,
                    entity.position.x,
                    entity.position.y,
                    behavior,
                    entity.danger,
                    Some(match entity.group {
                        Group::A => 'A',
                        Group::B => 'B',
                        Group::C => 'C',
                        Group::D => 'D',
                        Group::E => 'E',
                        Group::F => 'F',
                        Group::G => 'G',
                    }),
                ))
            })
            .collect();

        Level {
            meta: LevelMeta {
                name: self.name.clone(),
                author: "Converted".to_string(),
                version: "1.0".to_string(),
                width: self.map.width,
                height: self.map.height,
                music: if self.music.is_empty() {
                    None
                } else {
                    Some(self.music.clone())
                },
            },
            tiles: self.map.tiles.clone(),
            player_start: (self.start_position.x, self.start_position.y),
            messages,
            creatures,
        }
    }
}

/// Level definition for compile-time inclusion
pub trait LevelDef {
    fn meta() -> LevelMeta;
    fn tiles() -> Vec<Vec<i32>>;
    fn player_start() -> (i32, i32);

    fn to_level() -> Level {
        Level::from_data(Self::meta(), Self::tiles(), Self::player_start())
    }
}
