// Siriel Macroquad - Entity Types

#![allow(dead_code)]

/// Entity type identifier
#[derive(Debug, Clone, PartialEq)]
pub enum EntityType {
    Player,
    Enemy,
    Item,
    Decoration,
}

/// Entity state
#[derive(Debug, Clone, PartialEq)]
pub enum EntityState {
    Idle,
    Moving,
    Dying,
    Dead,
    Collected,
}

/// Base entity trait
pub trait Entity {
    /// Get entity position
    fn position(&self) -> (f32, f32);

    /// Set entity position
    fn set_position(&mut self, x: f32, y: f32);

    /// Get entity size
    fn size(&self) -> (i32, i32);

    /// Update entity
    fn update(&mut self, dt: f32);

    /// Check collision with point
    fn collides_with(&self, x: f32, y: f32) -> bool {
        let (ex, ey) = self.position();
        let (ew, eh) = self.size();
        x >= ex && x <= ex + ew as f32 && y >= ey && y <= ey + eh as f32
    }

    /// Check collision with another entity
    fn collides_with_entity(&self, other: &dyn Entity) -> bool {
        let (x1, y1) = self.position();
        let (w1, h1) = self.size();
        let (x2, y2) = other.position();
        let (w2, h2) = other.size();

        x1 < x2 + w2 as f32 && x1 + w1 as f32 > x2 && y1 < y2 + h2 as f32 && y1 + h1 as f32 > y2
    }
}

/// Base entity implementation
#[derive(Debug, Clone)]
pub struct BaseEntity {
    pub x: f32,
    pub y: f32,
    pub width: i32,
    pub height: i32,
    pub entity_type: EntityType,
    pub state: EntityState,
    pub alive: bool,
}

impl BaseEntity {
    pub fn new(x: f32, y: f32, width: i32, height: i32, entity_type: EntityType) -> Self {
        Self {
            x,
            y,
            width,
            height,
            entity_type,
            state: EntityState::Idle,
            alive: true,
        }
    }
}

impl Entity for BaseEntity {
    fn position(&self) -> (f32, f32) {
        (self.x, self.y)
    }

    fn set_position(&mut self, x: f32, y: f32) {
        self.x = x;
        self.y = y;
    }

    fn size(&self) -> (i32, i32) {
        (self.width, self.height)
    }

    fn update(&mut self, _dt: f32) {
        // Base entity doesn't move
    }
}

/// Enemy types
#[derive(Debug, Clone, PartialEq)]
pub enum EnemyType {
    Walker,
    Jumper,
    Flyer,
}

/// Enemy entity
#[derive(Debug, Clone)]
pub struct Enemy {
    pub base: BaseEntity,
    pub enemy_type: EnemyType,
    pub vx: f32,
    pub vy: f32,
    pub patrol_start: f32,
    pub patrol_end: f32,
    pub health: i32,
}

impl Enemy {
    pub fn new(x: f32, y: f32, enemy_type: EnemyType) -> Self {
        Self {
            base: BaseEntity::new(x, y, 16, 16, EntityType::Enemy),
            enemy_type,
            vx: 0.5,
            vy: 0.0,
            patrol_start: x - 32.0,
            patrol_end: x + 32.0,
            health: 1,
        }
    }

    pub fn with_patrol(mut self, start: f32, end: f32) -> Self {
        self.patrol_start = start;
        self.patrol_end = end;
        self
    }
}

impl Entity for Enemy {
    fn position(&self) -> (f32, f32) {
        (self.base.x, self.base.y)
    }

    fn set_position(&mut self, x: f32, y: f32) {
        self.base.x = x;
        self.base.y = y;
    }

    fn size(&self) -> (i32, i32) {
        (self.base.width, self.base.height)
    }

    fn update(&mut self, _dt: f32) {
        if !self.base.alive {
            return;
        }

        // Simple patrol behavior
        self.base.x += self.vx;

        // Reverse at patrol bounds
        if self.base.x <= self.patrol_start || self.base.x >= self.patrol_end {
            self.vx = -self.vx;
        }
    }
}

/// Item types
#[derive(Debug, Clone, PartialEq)]
pub enum ItemType {
    Coin,
    Health,
    Powerup,
    Key,
}

/// Item entity
#[derive(Debug, Clone)]
pub struct Item {
    pub base: BaseEntity,
    pub item_type: ItemType,
    pub value: i32,
    pub collectible: bool,
}

impl Item {
    pub fn new(x: f32, y: f32, item_type: ItemType) -> Self {
        let value = match item_type {
            ItemType::Coin => 10,
            ItemType::Health => 1,
            ItemType::Powerup => 100,
            ItemType::Key => 1,
        };

        Self {
            base: BaseEntity::new(x, y, 8, 8, EntityType::Item),
            item_type,
            value,
            collectible: true,
        }
    }
}

impl Entity for Item {
    fn position(&self) -> (f32, f32) {
        (self.base.x, self.base.y)
    }

    fn set_position(&mut self, x: f32, y: f32) {
        self.base.x = x;
        self.base.y = y;
    }

    fn size(&self) -> (i32, i32) {
        (self.base.width, self.base.height)
    }

    fn update(&mut self, _dt: f32) {
        // Items don't move by themselves
    }
}

/// Entity collision result
#[derive(Debug, Clone, PartialEq)]
pub enum CollisionResult {
    None,
    EnemyHit,
    ItemCollected(ItemType),
    Solid,
}
