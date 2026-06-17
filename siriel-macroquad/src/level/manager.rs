// Siriel Macroquad - Level Manager

#![allow(dead_code)]

use super::types::*;
use std::collections::HashMap;

/// Level manager for handling level switching and state
#[derive(Debug, Clone)]
pub struct LevelManager {
    levels: HashMap<String, Level>,
    current_level: Option<String>,
    level_order: Vec<String>,
    completed: Vec<String>,
}

impl LevelManager {
    /// Create new level manager
    pub fn new() -> Self {
        Self {
            levels: HashMap::new(),
            current_level: None,
            level_order: Vec::new(),
            completed: Vec::new(),
        }
    }

    /// Register a level
    pub fn register(&mut self, id: String, level: Level) {
        self.level_order.push(id.clone());
        self.levels.insert(id, level);
    }

    /// Set current level by ID
    pub fn set_level(&mut self, id: &str) -> Result<(), String> {
        if self.levels.contains_key(id) {
            self.current_level = Some(id.to_string());
            Ok(())
        } else {
            Err(format!("Level '{}' not found", id))
        }
    }

    /// Get current level
    pub fn current(&self) -> Option<&Level> {
        if let Some(ref id) = self.current_level {
            self.levels.get(id)
        } else {
            None
        }
    }

    /// Get current level ID
    pub fn current_id(&self) -> Option<&str> {
        self.current_level.as_deref()
    }

    /// Move to next level
    pub fn next_level(&mut self) -> Result<(), String> {
        if let Some(current) = &self.current_level {
            if let Some(pos) = self.level_order.iter().position(|x| x == current) {
                if pos + 1 < self.level_order.len() {
                    let next = &self.level_order[pos + 1];
                    self.current_level = Some(next.clone());
                    Ok(())
                } else {
                    Err("No more levels".to_string())
                }
            } else {
                Err("Current level not in order".to_string())
            }
        } else {
            Err("No current level".to_string())
        }
    }

    /// Mark current level as completed
    pub fn mark_completed(&mut self) {
        if let Some(ref id) = self.current_level {
            if !self.completed.contains(id) {
                self.completed.push(id.clone());
            }
        }
    }

    /// Check if current level is completed
    pub fn is_completed(&self, id: &str) -> bool {
        self.completed.contains(&id.to_string())
    }

    /// Get list of all level IDs
    pub fn level_ids(&self) -> &[String] {
        &self.level_order
    }

    /// Get total level count
    pub fn level_count(&self) -> usize {
        self.levels.len()
    }

    /// Check if this is the last level
    pub fn is_last_level(&self) -> bool {
        if let Some(current) = &self.current_level {
            if let Some(pos) = self.level_order.iter().position(|x| x == current) {
                return pos + 1 == self.level_order.len();
            }
        }
        false
    }

    /// Get level by ID
    pub fn get_level(&self, id: &str) -> Option<&Level> {
        self.levels.get(id)
    }

    /// Reset all progress
    pub fn reset(&mut self) {
        self.completed.clear();
        if let Some(first) = self.level_order.first() {
            self.current_level = Some(first.clone());
        }
    }
}

impl Default for LevelManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Level state tracking
#[derive(Debug, Clone, PartialEq)]
pub enum LevelState {
    Playing,
    Completed,
    Failed,
}

/// Level transition data
#[derive(Debug, Clone)]
pub struct LevelTransition {
    pub from_level: String,
    pub to_level: String,
    pub reason: TransitionReason,
}

#[derive(Debug, Clone, PartialEq)]
pub enum TransitionReason {
    Completed,
    Failed,
    Skipped,
    Restarted,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_level(id: &str) -> Level {
        Level {
            meta: LevelMeta {
                name: id.to_string(),
                author: "Test".to_string(),
                version: "1.0".to_string(),
                width: 10,
                height: 10,
                music: None,
            },
            tiles: vec![vec![0; 10]; 10],
            player_start: (0, 0),
            messages: Vec::new(),
            creatures: Vec::new(),
        }
    }

    #[test]
    fn test_manager_creation() {
        let manager = LevelManager::new();
        assert_eq!(manager.level_count(), 0);
        assert!(manager.current().is_none());
    }

    #[test]
    fn test_register_levels() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));
        manager.register("level2".to_string(), create_test_level("Level 2"));

        assert_eq!(manager.level_count(), 2);
        assert_eq!(manager.level_ids(), &["level1", "level2"]);
    }

    #[test]
    fn test_set_current_level() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));

        assert!(manager.set_level("level1").is_ok());
        assert!(manager.current_id() == Some("level1"));
        assert!(manager.current().is_some());
    }

    #[test]
    fn test_set_invalid_level() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));

        assert!(manager.set_level("invalid").is_err());
    }

    #[test]
    fn test_next_level() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));
        manager.register("level2".to_string(), create_test_level("Level 2"));
        manager.register("level3".to_string(), create_test_level("Level 3"));

        manager.set_level("level1").unwrap();
        assert!(manager.next_level().is_ok());
        assert_eq!(manager.current_id(), Some("level2"));
    }

    #[test]
    fn test_next_level_at_end() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));

        manager.set_level("level1").unwrap();
        assert!(manager.next_level().is_err());
    }

    #[test]
    fn test_mark_completed() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));

        manager.set_level("level1").unwrap();
        manager.mark_completed();

        assert!(manager.is_completed("level1"));
    }

    #[test]
    fn test_is_last_level() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));
        manager.register("level2".to_string(), create_test_level("Level 2"));

        manager.set_level("level1").unwrap();
        assert!(!manager.is_last_level());

        manager.next_level().unwrap();
        assert!(manager.is_last_level());
    }

    #[test]
    fn test_reset() {
        let mut manager = LevelManager::new();
        manager.register("level1".to_string(), create_test_level("Level 1"));
        manager.register("level2".to_string(), create_test_level("Level 2"));

        manager.set_level("level2").unwrap();
        manager.mark_completed();

        manager.reset();
        assert_eq!(manager.current_id(), Some("level1"));
        assert!(!manager.is_completed("level1"));
    }
}
