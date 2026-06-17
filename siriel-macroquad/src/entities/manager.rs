// Siriel Macroquad - Entity Manager

#![allow(dead_code)]

use super::types::*;

/// Entity manager for handling all game entities
#[derive(Debug)]
pub struct EntityManager {
    enemies: Vec<Enemy>,
    items: Vec<Item>,
    score: i32,
    coins_collected: i32,
}

impl EntityManager {
    /// Create new entity manager
    pub fn new() -> Self {
        Self {
            enemies: Vec::new(),
            items: Vec::new(),
            score: 0,
            coins_collected: 0,
        }
    }

    /// Add enemy to manager
    pub fn add_enemy(&mut self, enemy: Enemy) {
        self.enemies.push(enemy);
    }

    /// Add item to manager
    pub fn add_item(&mut self, item: Item) {
        self.items.push(item);
    }

    /// Get all enemies
    pub fn enemies(&self) -> &[Enemy] {
        &self.enemies
    }

    /// Get all items
    pub fn items(&self) -> &[Item] {
        &self.items
    }

    /// Get mutable enemies for updating
    pub fn enemies_mut(&mut self) -> &mut [Enemy] {
        &mut self.enemies
    }

    /// Get mutable items for updating
    pub fn items_mut(&mut self) -> &mut [Item] {
        &mut self.items
    }

    /// Update all entities
    pub fn update(&mut self, dt: f32) {
        // Update enemies
        for enemy in &mut self.enemies {
            enemy.update(dt);
        }

        // Update items
        for item in &mut self.items {
            item.update(dt);
        }

        // Remove dead enemies and collected items
        self.enemies.retain(|e| e.base.alive);
        self.items.retain(|i| i.base.alive);
    }

    /// Check player collision with entities
    pub fn check_player_collision(&mut self, player_x: f32, player_y: f32) -> Vec<CollisionResult> {
        let mut results = Vec::new();

        // Check enemy collisions
        for enemy in &self.enemies {
            if enemy.base.alive && enemy.collides_with(player_x, player_y) {
                results.push(CollisionResult::EnemyHit);
            }
        }

        // Check item collisions
        for item in &mut self.items {
            if item.base.alive && item.collectible && item.collides_with(player_x, player_y) {
                item.base.alive = false;
                item.base.state = EntityState::Collected;
                results.push(CollisionResult::ItemCollected(item.item_type.clone()));

                // Update score
                match item.item_type {
                    ItemType::Coin => {
                        self.score += item.value;
                        self.coins_collected += 1;
                    }
                    ItemType::Health => {
                        self.score += item.value;
                    }
                    ItemType::Powerup => {
                        self.score += item.value;
                    }
                    ItemType::Key => {
                        self.score += item.value;
                    }
                }
            }
        }

        results
    }

    /// Get current score
    pub fn score(&self) -> i32 {
        self.score
    }

    /// Get coins collected
    pub fn coins_collected(&self) -> i32 {
        self.coins_collected
    }

    /// Clear all entities
    pub fn clear(&mut self) {
        self.enemies.clear();
        self.items.clear();
    }

    /// Get entity counts
    pub fn counts(&self) -> (usize, usize) {
        (self.enemies.len(), self.items.len())
    }
}

impl Default for EntityManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_manager_creation() {
        let manager = EntityManager::new();
        assert_eq!(manager.score(), 0);
        assert_eq!(manager.coins_collected(), 0);
        assert_eq!(manager.counts(), (0, 0));
    }

    #[test]
    fn test_add_enemy() {
        let mut manager = EntityManager::new();
        let enemy = Enemy::new(100.0, 100.0, EnemyType::Walker);
        manager.add_enemy(enemy);

        assert_eq!(manager.counts(), (1, 0));
        assert_eq!(manager.enemies().len(), 1);
    }

    #[test]
    fn test_add_item() {
        let mut manager = EntityManager::new();
        let item = Item::new(100.0, 100.0, ItemType::Coin);
        manager.add_item(item);

        assert_eq!(manager.counts(), (0, 1));
        assert_eq!(manager.items().len(), 1);
    }

    #[test]
    fn test_enemy_collision() {
        let mut manager = EntityManager::new();
        let enemy = Enemy::new(100.0, 100.0, EnemyType::Walker);
        manager.add_enemy(enemy);

        let results = manager.check_player_collision(100.0, 100.0);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0], CollisionResult::EnemyHit);
    }

    #[test]
    fn test_item_collection() {
        let mut manager = EntityManager::new();
        let item = Item::new(100.0, 100.0, ItemType::Coin);
        manager.add_item(item);

        let results = manager.check_player_collision(100.0, 100.0);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0], CollisionResult::ItemCollected(ItemType::Coin));
        assert_eq!(manager.score(), 10);
        assert_eq!(manager.coins_collected(), 1);
    }

    #[test]
    fn test_remove_collected_items() {
        let mut manager = EntityManager::new();
        let item = Item::new(100.0, 100.0, ItemType::Coin);
        manager.add_item(item);

        // Collect item
        manager.check_player_collision(100.0, 100.0);

        // Update to remove collected items
        manager.update(0.0);

        assert_eq!(manager.counts(), (0, 0));
    }

    #[test]
    fn test_clear_entities() {
        let mut manager = EntityManager::new();
        manager.add_enemy(Enemy::new(100.0, 100.0, EnemyType::Walker));
        manager.add_item(Item::new(100.0, 100.0, ItemType::Coin));

        manager.clear();
        assert_eq!(manager.counts(), (0, 0));
    }

    #[test]
    fn test_enemy_patrol() {
        let enemy = Enemy::new(100.0, 100.0, EnemyType::Walker).with_patrol(50.0, 150.0);

        assert_eq!(enemy.patrol_start, 50.0);
        assert_eq!(enemy.patrol_end, 150.0);
    }
}
