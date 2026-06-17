// Siriel Macroquad - Creature Entities with AI Behaviors
// Based on original predmet structure from AKTIV35.PAS

use super::ai::*;
use super::types::EntityType;
use crate::core::TILE_SIZE;

/// Creature entity with AI behavior
/// Matches original predmet structure from AKTIV35.PAS
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct Creature {
    /// Basic entity properties
    pub base: super::types::BaseEntity,

    /// Entity code (e.g., "ZNNA", "YNN~")
    pub code: String,

    /// Behavior type (funk)
    pub behavior: BehaviorType,

    /// Parameters from original inf1-inf7
    pub inf1: i32, // Boundary/parameter 1
    pub inf2: i32, // Boundary/parameter 2
    pub inf3: i32, // Speed/parameter 3
    pub inf4: i32, // Distance/parameter 4
    pub inf5: i32, // Reset X/counter
    pub inf6: i32, // Reset Y/duration
    pub inf7: i32, // Direction/state

    /// Origin position (for fireball respawn)
    pub origin_x: i32,
    pub origin_y: i32,

    /// Current direction
    pub direction: Direction,
    pub moving_left: bool,

    /// Room number (1 = current room)
    pub room: u8,

    /// Animation frame
    pub frame: i32,
    pub anim_speed: i32,

    /// Visible flag
    pub visible: bool,

    /// Group code (A-Z for visibility)
    pub group: Option<char>,

    /// Value for collectibles
    pub value: i32,
}

#[allow(dead_code)]
impl Creature {
    /// Create new creature from parsed TOML data
    pub fn from_toml(
        code: &str,
        sprite_id: i32,
        x: i32,
        y: i32,
        behavior: u32,
        param1: i32,
        param2: i32,
        param3: i32,
        param4: i32,
    ) -> Option<Self> {
        let entity_code = EntityCode::parse(code)?;
        let behavior_type = BehaviorType::from_u32(behavior)?;

        // Convert grid coordinates to pixels
        let pixel_x = x * TILE_SIZE;
        let pixel_y = y * TILE_SIZE;

        let entity_type = match entity_code.danger {
            DangerLevel::None => EntityType::Item,
            DangerLevel::Mortal | DangerLevel::NoGod => EntityType::Enemy,
        };

        let value = match &entity_code.visibility {
            Visibility::Group(c) => ((*c as i32) - ('A' as i32)) * 10,
            _ => 10,
        };

        Some(Self {
            base: super::types::BaseEntity::new(
                pixel_x as f32,
                pixel_y as f32,
                TILE_SIZE,
                TILE_SIZE,
                entity_type,
            ),
            code: code.to_string(),
            behavior: behavior_type,
            inf1: param1,
            inf2: param2,
            inf3: param3,
            inf4: param4,
            inf5: 0,
            inf6: 0,
            inf7: 0,
            origin_x: pixel_x,
            origin_y: pixel_y,
            direction: Direction::Right,
            moving_left: false,
            room: 1,
            frame: sprite_id,
            anim_speed: 1,
            visible: matches!(entity_code.visibility, Visibility::Always),
            group: match entity_code.visibility {
                Visibility::Group(c) => Some(c),
                _ => None,
            },
            value,
        })
    }

    /// Update creature AI behavior
    pub fn update_ai(&mut self, detector: &dyn CollisionDetector, player_x: i32, player_y: i32) {
        if !self.visible || !self.base.alive {
            return;
        }

        match self.behavior {
            BehaviorType::HorizontalPatrol => {
                self.update_horizontal_patrol(detector);
            }
            BehaviorType::VerticalPatrol => {
                self.update_vertical_patrol(detector);
            }
            BehaviorType::RandomWanderer => {
                self.update_random_wanderer(detector);
            }
            BehaviorType::ChasingEnemy => {
                self.update_chasing_enemy(detector, player_x, player_y);
            }
            BehaviorType::Fireball | BehaviorType::FireballAlt => {
                self.update_fireball(detector);
            }
            BehaviorType::SoundGenerator => {
                self.update_sound_generator();
            }
            BehaviorType::AnimatedCollectible => {
                self.update_animated_collectible();
            }
            BehaviorType::PlatformGravity => {
                self.update_platform_gravity(detector);
            }
            BehaviorType::PlatformEdge => {
                self.update_platform_edge(detector);
            }
            _ => {
                // Static behaviors don't need updates
            }
        }
    }

    /// Horizontal patrol (funk=2)
    /// SI35.PAS lines 284-289
    fn update_horizontal_patrol(&mut self, detector: &dyn CollisionDetector) {
        let x = self.base.x as i32;

        // Check boundaries and reverse if needed
        if x <= self.inf1 {
            self.moving_left = false;
        } else if x >= self.inf2 {
            self.moving_left = true;
        }

        // Move
        let direction = if self.moving_left {
            Direction::Left
        } else {
            Direction::Right
        };

        let (new_x, _) = move_with_collision(
            detector,
            x,
            self.base.y as i32,
            direction,
            self.inf3,
            self.base.width,
            self.base.height,
        );

        self.base.x = new_x as f32;
    }

    /// Vertical patrol (funk=3)
    /// SI35.PAS lines 290-296
    fn update_vertical_patrol(&mut self, detector: &dyn CollisionDetector) {
        let y = self.base.y as i32;

        // Check boundaries
        if y <= self.inf1 {
            self.inf7 = 1; // Move down
        } else if y >= self.inf2 {
            self.inf7 = 0; // Move up
        }

        let direction = match self.inf7 {
            0 => Direction::Up,
            _ => Direction::Down,
        };

        let (_, new_y) = move_with_collision(
            detector,
            self.base.x as i32,
            y,
            direction,
            self.inf3,
            self.base.width,
            self.base.height,
        );

        self.base.y = new_y as f32;
    }

    /// Random wanderer (funk=12)
    /// SI35.PAS lines 225-283
    fn update_random_wanderer(&mut self, detector: &dyn CollisionDetector) {
        // Decrease distance counter
        self.inf4 -= self.inf3;

        // Check if should change direction
        let should_change = if self.inf1 == 0 {
            // Screen edge mode
            let x = self.base.x as i32;
            let y = self.base.y as i32;
            x < 10 || x > 598 || y < 10 || y > 438 || self.inf4 < 4
        } else {
            // Texture-aware mode - check collision
            false // TODO: Implement collision check
        };

        if should_change {
            // Pick new random direction
            self.inf3 = rand::random::<u32>() as i32 % 4;
            self.inf4 = rand::random::<u32>() as i32 % 200 + 20;
        }

        // Move in current direction
        let direction = match self.inf3 {
            0 => Direction::Left,
            1 => Direction::Right,
            2 => Direction::Down,
            _ => Direction::Up,
        };

        let (new_x, new_y) = move_with_collision(
            detector,
            self.base.x as i32,
            self.base.y as i32,
            direction,
            self.inf2,
            self.base.width,
            self.base.height,
        );

        self.base.x = new_x as f32;
        self.base.y = new_y as f32;
    }

    /// Chasing enemy (funk=16)
    /// SI35.PAS lines 196-224
    fn update_chasing_enemy(
        &mut self,
        detector: &dyn CollisionDetector,
        player_x: i32,
        player_y: i32,
    ) {
        let x = self.base.x as i32;
        let y = self.base.y as i32;

        self.inf6 += 1;

        if self.inf5 == 0 {
            // Passive mode
            if self.inf6 >= self.inf2 && self.inf3 > 0 {
                // Switch to active mode
                self.inf5 = 1;
                self.inf6 = 0;
            } else {
                // Random patrol
                if self.inf7 == 0 {
                    self.inf7 = rand::random::<u32>() as i32 % 4 + 1;
                }

                let dir = match self.inf7 {
                    1 => Direction::Up,
                    2 => Direction::Down,
                    3 => Direction::Left,
                    _ => Direction::Right,
                };

                let (new_x, new_y) = move_with_collision(
                    detector,
                    x,
                    y,
                    dir,
                    self.inf1,
                    self.base.width,
                    self.base.height,
                );

                self.base.x = new_x as f32;
                self.base.y = new_y as f32;

                // Check if moved, if not reset direction
                if new_x == x && new_y == y {
                    self.inf7 = 0;
                }
            }
        } else {
            // Active mode - chase player
            if self.inf6 >= self.inf3 && self.inf2 > 0 {
                // Switch back to passive mode
                self.inf5 = 0;
                self.inf6 = 0;
            } else {
                // Chase player
                if x > player_x {
                    self.moving_left = true;
                    let (new_x, _) = move_with_collision(
                        detector,
                        x,
                        y,
                        Direction::Left,
                        self.inf1,
                        self.base.width,
                        self.base.height,
                    );
                    self.base.x = new_x as f32;
                }
                if y > player_y {
                    let (_, new_y) = move_with_collision(
                        detector,
                        self.base.x as i32,
                        y,
                        Direction::Up,
                        self.inf1,
                        self.base.width,
                        self.base.height,
                    );
                    self.base.y = new_y as f32;
                }
                if x < player_x {
                    self.moving_left = false;
                    let (new_x, _) = move_with_collision(
                        detector,
                        self.base.x as i32,
                        y,
                        Direction::Right,
                        self.inf1,
                        self.base.width,
                        self.base.height,
                    );
                    self.base.x = new_x as f32;
                }
                if y < player_y {
                    let (_, new_y) = move_with_collision(
                        detector,
                        self.base.x as i32,
                        self.base.y as i32,
                        Direction::Down,
                        self.inf1,
                        self.base.width,
                        self.base.height,
                    );
                    self.base.y = new_y as f32;
                }
            }
        }
    }

    /// Fireball/projectile (funk=15, 18)
    /// SI35.PAS lines 323-342
    fn update_fireball(&mut self, _detector: &dyn CollisionDetector) {
        let x = self.base.x as i32;
        let y = self.base.y as i32;
        let speed = self.inf3;

        // Move toward target based on direction (inf1)
        // CRITICAL: inf1 encoding is non-standard: 1=left, 2=right, 3=up, 4=down
        let reached = match self.inf1 {
            1 => {
                // Moving left
                if x < self.inf2 {
                    self.base.x -= speed as f32;
                    false
                } else {
                    true
                }
            }
            2 => {
                // Moving right
                if x > self.inf2 {
                    self.base.x += speed as f32;
                    false
                } else {
                    true
                }
            }
            3 => {
                // Moving up
                if y < self.inf2 {
                    self.base.y -= speed as f32;
                    false
                } else {
                    true
                }
            }
            4 => {
                // Moving down
                if y > self.inf2 {
                    self.base.y += speed as f32;
                    false
                } else {
                    true
                }
            }
            _ => true,
        };

        // Respawn if reached target
        if reached {
            self.inf5 += 1;
            if self.inf5 > 10 {
                // Reset to origin
                self.base.x = self.origin_x as f32;
                self.base.y = self.origin_y as f32;
                self.inf5 = 0;
            }
        }
    }

    /// Sound generator (funk=17)
    /// SI35.PAS lines 178-195
    fn update_sound_generator(&mut self) {
        self.inf5 += 1;

        if self.inf6 == 0 {
            // Waiting for sound A
            if self.inf5 > self.inf2 {
                // Play sound A (inf1)
                self.inf6 = 1;
                self.inf5 = 0;
            }
        } else {
            // Waiting for sound B
            if self.inf5 > self.inf4 {
                // Play sound B (inf3)
                self.inf6 = 0;
                self.inf5 = 0;
            }
        }
    }

    /// Animated collectible (funk=6)
    fn update_animated_collectible(&mut self) {
        // Update animation frame
        self.frame = (self.frame + self.anim_speed) % 4;
    }

    /// Platform with gravity (funk=4)
    /// SI35.PAS lines 297-311
    fn update_platform_gravity(&mut self, detector: &dyn CollisionDetector) {
        let x = self.base.x as i32;
        let y = self.base.y as i32;

        // Check ground at both feet
        let has_left_ground = has_ground_at(detector, x + 4, y - 12);
        let has_right_ground = has_ground_at(detector, x - 12, y - 12);

        if !has_left_ground && !has_right_ground {
            // No ground - fall
            let (new_x, new_y) =
                apply_gravity(detector, x, y, self.inf3, self.base.width, self.base.height);
            self.base.x = new_x as f32;
            self.base.y = new_y as f32;

            // Reset if fallen too far
            if new_y > self.inf6 + 50 {
                self.base.x = self.inf5 as f32;
                self.base.y = self.inf6 as f32;
            }
        } else {
            // Move horizontally
            let direction = if self.moving_left {
                Direction::Left
            } else {
                Direction::Right
            };

            let (new_x, _) = move_with_collision(
                detector,
                x,
                y,
                direction,
                self.inf1,
                self.base.width,
                self.base.height,
            );

            // Reset if can't move
            if new_x == x {
                self.base.x = self.inf5 as f32;
                self.base.y = self.inf6 as f32;
            } else {
                self.base.x = new_x as f32;
            }
        }
    }

    /// Edge-walking platform (funk=5)
    /// SI35.PAS lines 312-322
    fn update_platform_edge(&mut self, detector: &dyn CollisionDetector) {
        let x = self.base.x as i32;

        // Check for edge (no ground ahead)
        let left_edge = !has_ground_at(detector, x - 11, self.base.y as i32 - 3);
        let right_edge = !has_ground_at(detector, x + 3, self.base.y as i32 - 3);

        if left_edge {
            self.moving_left = false;
        } else if right_edge {
            self.moving_left = true;
        }

        // Move in current direction
        let direction = if self.moving_left {
            Direction::Left
        } else {
            Direction::Right
        };

        let (new_x, _) = move_with_collision(
            detector,
            x,
            self.base.y as i32,
            direction,
            self.inf1,
            self.base.width,
            self.base.height,
        );

        // Reset if can't move
        if new_x == x {
            self.base.x = self.inf5 as f32;
            self.base.y = self.inf6 as f32;
        } else {
            self.base.x = new_x as f32;
        }
    }

    /// Reveal group (funk=7)
    pub fn reveal_group(&self, group: char) -> bool {
        if self.behavior == BehaviorType::Reveal {
            self.group == Some(group)
        } else {
            false
        }
    }

    /// Hide group (funk=8)
    pub fn hide_group(&self, group: char) -> bool {
        if self.behavior == BehaviorType::Hide {
            self.group == Some(group)
        } else {
            false
        }
    }

    /// Check if level complete (funk=9)
    pub fn is_level_complete(&self) -> bool {
        self.behavior == BehaviorType::LevelComplete
    }

    /// Get teleport target (funk=1)
    pub fn get_teleport_target(&self) -> Option<(i32, i32)> {
        if self.behavior == BehaviorType::Teleport {
            Some((self.inf1, self.inf2))
        } else {
            None
        }
    }

    /// Get room transfer target (funk=14)
    pub fn get_room_transfer(&self) -> Option<(u8, i32, i32)> {
        if self.behavior == BehaviorType::RoomTransfer {
            Some((self.inf1 as u8, self.inf2, self.inf3))
        } else {
            None
        }
    }

    /// Get powerup type (funk=19)
    pub fn get_powerup_type(&self) -> Option<i32> {
        if self.behavior == BehaviorType::Powerup {
            Some(self.inf1)
        } else {
            None
        }
    }

    /// Get lives to add (funk=10)
    pub fn get_lives_to_add(&self) -> Option<i32> {
        if self.behavior == BehaviorType::AddLife {
            Some(self.inf1)
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_creature_from_toml() {
        let creature = Creature::from_toml("ZNNA", 1, 8, 17, 1, 3, 10, 0, 0);
        assert!(creature.is_some());

        let c = creature.unwrap();
        assert_eq!(c.code, "ZNNA");
        assert_eq!(c.base.x, (8 * TILE_SIZE) as f32);
        assert_eq!(c.base.y, (17 * TILE_SIZE) as f32);
        assert_eq!(c.behavior, BehaviorType::Teleport);
        assert_eq!(c.inf1, 3);
        assert_eq!(c.inf2, 10);
    }

    #[test]
    fn test_creature_invalid_code() {
        let creature = Creature::from_toml("XXXX", 1, 8, 17, 1, 3, 10, 0, 0);
        assert!(creature.is_none());
    }

    #[test]
    fn test_creature_invalid_behavior() {
        let creature = Creature::from_toml("ZNNA", 1, 8, 17, 99, 3, 10, 0, 0);
        assert!(creature.is_none());
    }

    #[test]
    fn test_direction_from_code() {
        let code = EntityCode::parse("ZNNA").unwrap();
        assert_eq!(code.interaction, InteractionType::PickupWalk);
        assert!(!code.animated);
        assert_eq!(code.danger, DangerLevel::None);
    }

    #[test]
    fn test_animated_code() {
        let code = EntityCode::parse("ZANA").unwrap();
        assert!(code.animated);
    }

    #[test]
    fn test_deadly_code() {
        // Format: [Interaction][Animation][Danger][Visibility]
        // Z=PickupWalk, A=Animated, S=Mortal, A=Always
        let code = EntityCode::parse("ZASA").unwrap();
        assert_eq!(code.danger, DangerLevel::Mortal);
        assert!(code.animated);

        // Z=PickupWalk, N=NotAnimated, D=NoGod, A=Always
        let code = EntityCode::parse("ZNDA").unwrap();
        assert_eq!(code.danger, DangerLevel::NoGod);
        assert!(!code.animated);
    }

    #[test]
    fn test_exit_door_code() {
        let code = EntityCode::parse("YNN~").unwrap();
        assert_eq!(code.visibility, Visibility::ExitDoor);
        assert_eq!(code.interaction, InteractionType::SpecialTouch);
    }

    #[test]
    fn test_group_visibility() {
        let code = EntityCode::parse("ZNNC").unwrap();
        assert_eq!(code.visibility, Visibility::Group('C'));
    }

    #[test]
    fn test_teleport_target() {
        let creature = Creature::from_toml("ZNNA", 1, 10, 20, 1, 100, 200, 0, 0).unwrap();
        let target = creature.get_teleport_target();
        assert_eq!(target, Some((100, 200)));
    }

    #[test]
    fn test_room_transfer() {
        let creature = Creature::from_toml("ZNNA", 1, 10, 20, 14, 2, 50, 100, 0).unwrap();
        let transfer = creature.get_room_transfer();
        assert_eq!(transfer, Some((2, 50, 100)));
    }

    #[test]
    fn test_powerup_type() {
        let creature = Creature::from_toml("ZNNA", 1, 10, 20, 19, 2, 0, 0, 0).unwrap();
        let powerup = creature.get_powerup_type();
        assert_eq!(powerup, Some(2)); // God mode
    }

    #[test]
    fn test_lives_to_add() {
        let creature = Creature::from_toml("ZNNA", 1, 10, 20, 10, 3, 0, 0, 0).unwrap();
        let lives = creature.get_lives_to_add();
        assert_eq!(lives, Some(3));
    }
}
