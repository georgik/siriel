// Siriel Macroquad - Creature AI System
// Based on SI35.PAS panak procedure analysis

#![allow(dead_code)]

use crate::core::TILE_SIZE;

/// Direction enumeration for AI movement
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Direction {
    Up = 3,
    Down = 2,
    Left = 0,
    Right = 1,
}

impl Direction {
    /// Convert from original fireball encoding (1=left, 2=right, 3=up, 4=down)
    pub fn from_fireball_code(code: i32) -> Option<Self> {
        match code {
            1 => Some(Direction::Left),
            2 => Some(Direction::Right),
            3 => Some(Direction::Up),
            4 => Some(Direction::Down),
            _ => None,
        }
    }

    /// Get opposite direction
    pub fn opposite(self) -> Direction {
        match self {
            Direction::Up => Direction::Down,
            Direction::Down => Direction::Up,
            Direction::Left => Direction::Right,
            Direction::Right => Direction::Left,
        }
    }

    /// Get dx, dy for this direction
    pub fn delta(self) -> (i32, i32) {
        match self {
            Direction::Up => (0, -1),
            Direction::Down => (0, 1),
            Direction::Left => (-1, 0),
            Direction::Right => (1, 0),
        }
    }
}

/// Behavior type (funk) from original SI35.PAS
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BehaviorType {
    /// Pickup item (simple collectible)
    Pickup = 0,
    /// Teleport (inf1, inf2 = target X, Y)
    Teleport = 1,
    /// Horizontal patrol (inf1=left, inf2=right, inf3=speed)
    HorizontalPatrol = 2,
    /// Vertical patrol (inf1=top, inf2=bottom, inf3=speed)
    VerticalPatrol = 3,
    /// Platform with gravity (falls off edges)
    PlatformGravity = 4,
    /// Edge-walking platform (turns at edges)
    PlatformEdge = 5,
    /// Animated collectible
    AnimatedCollectible = 6,
    /// Reveal objects (inf1 = group to reveal)
    Reveal = 7,
    /// Hide objects (inf1 = group to hide)
    Hide = 8,
    /// Level complete trigger
    LevelComplete = 9,
    /// Add life (inf1 = lives to add)
    AddLife = 10,
    /// (funk 11 - unused in original)
    Unused = 11,
    /// Random wanderer
    RandomWanderer = 12,
    /// Swap visibility (inf1=hide, inf2=show)
    SwapVisibility = 13,
    /// Room transfer (inf1=room, inf2,inf3=X,Y)
    RoomTransfer = 14,
    /// Fireball/projectile
    Fireball = 15,
    /// Chasing enemy (two-state: passive/active)
    ChasingEnemy = 16,
    /// Sound generator (alternating sounds)
    SoundGenerator = 17,
    /// Another fireball type
    FireballAlt = 18,
    /// Powerup (1=freeze, 2=god, 3=both)
    Powerup = 19,
}

impl BehaviorType {
    pub fn from_u32(value: u32) -> Option<Self> {
        match value {
            0 => Some(BehaviorType::Pickup),
            1 => Some(BehaviorType::Teleport),
            2 => Some(BehaviorType::HorizontalPatrol),
            3 => Some(BehaviorType::VerticalPatrol),
            4 => Some(BehaviorType::PlatformGravity),
            5 => Some(BehaviorType::PlatformEdge),
            6 => Some(BehaviorType::AnimatedCollectible),
            7 => Some(BehaviorType::Reveal),
            8 => Some(BehaviorType::Hide),
            9 => Some(BehaviorType::LevelComplete),
            10 => Some(BehaviorType::AddLife),
            11 => Some(BehaviorType::Unused),
            12 => Some(BehaviorType::RandomWanderer),
            13 => Some(BehaviorType::SwapVisibility),
            14 => Some(BehaviorType::RoomTransfer),
            15 => Some(BehaviorType::Fireball),
            16 => Some(BehaviorType::ChasingEnemy),
            17 => Some(BehaviorType::SoundGenerator),
            18 => Some(BehaviorType::FireballAlt),
            19 => Some(BehaviorType::Powerup),
            _ => None,
        }
    }
}

/// Entity interaction type (position 1 of entity code)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InteractionType {
    /// PickupWalk - collectible by walking over
    PickupWalk,
    /// SpecialTouch - trigger on touch
    SpecialTouch,
    /// SpecialEnter - trigger on entry
    SpecialEnter,
    /// Use - action button
    Use,
    /// Talk - dialog
    Talk,
}

impl InteractionType {
    pub fn from_char(c: char) -> Option<Self> {
        match c {
            'Z' => Some(InteractionType::PickupWalk),
            'Y' => Some(InteractionType::SpecialTouch),
            'X' => Some(InteractionType::SpecialEnter),
            'W' => Some(InteractionType::Use),
            'V' => Some(InteractionType::Talk),
            _ => None,
        }
    }
}

/// Entity danger level (position 3 of entity code)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DangerLevel {
    None,
    Mortal,
    NoGod,
}

impl DangerLevel {
    pub fn from_char(c: char) -> Option<Self> {
        match c {
            'N' => Some(DangerLevel::None),
            'S' => Some(DangerLevel::Mortal),
            'D' => Some(DangerLevel::NoGod),
            _ => None,
        }
    }
}

/// Entity visibility (position 4 of entity code)
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Visibility {
    Always,
    ExitDoor,
    Group(char),
}

impl Visibility {
    pub fn from_char(c: char) -> Option<Self> {
        match c {
            'A' => Some(Visibility::Always),
            '~' => Some(Visibility::ExitDoor),
            'A'..='Z' => Some(Visibility::Group(c)),
            _ => None,
        }
    }
}

/// Parsed entity code (e.g., "ZNNA")
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EntityCode {
    pub interaction: InteractionType,
    pub animated: bool,
    pub danger: DangerLevel,
    pub visibility: Visibility,
}

impl EntityCode {
    pub fn parse(code: &str) -> Option<Self> {
        if code.len() != 4 {
            return None;
        }

        let chars: Vec<char> = code.chars().collect();

        Some(EntityCode {
            interaction: InteractionType::from_char(chars[0])?,
            animated: chars[1] == 'A',
            danger: DangerLevel::from_char(chars[2])?,
            visibility: Visibility::from_char(chars[3])?,
        })
    }
}

/// Collision detection interface
/// Equivalent to po3 from POCHECK3.INC
pub trait CollisionDetector {
    /// Check if point (x, y) collides with terrain
    fn is_solid(&self, x: i32, y: i32) -> bool;

    /// Check if entity can move to position (returns true if NO collision)
    fn can_move_to(&self, x: i32, y: i32, width: i32, height: i32) -> bool {
        // Check corners - return true only if no collision
        !self.is_solid(x, y)
            && !self.is_solid(x + width, y)
            && !self.is_solid(x, y + height)
            && !self.is_solid(x + width, y + height)
    }

    /// Get tile at pixel coordinates
    fn get_tile_at(&self, x: i32, y: i32) -> i32;
}

/// Movement helper
/// Equivalent to smeruj from SI35.PAS lines 67-91
pub fn move_with_collision(
    detector: &dyn CollisionDetector,
    x: i32,
    y: i32,
    direction: Direction,
    speed: i32,
    width: i32,
    height: i32,
) -> (i32, i32) {
    let (dx, dy) = direction.delta();
    let new_x = x + dx * speed;
    let new_y = y + dy * speed;

    // Check collision
    if detector.can_move_to(new_x, new_y, width, height) {
        (new_x, new_y)
    } else {
        (x, y)
    }
}

/// Check ground beneath entity
/// Equivalent to po3 check in platform behaviors
pub fn has_ground_at(detector: &dyn CollisionDetector, x: i32, y: i32) -> bool {
    // Check tile below position
    let tile_below = detector.get_tile_at(x, y + TILE_SIZE);
    tile_below != 0
}

/// Apply gravity to entity
/// Equivalent to gravitacia from SI35.PAS lines 22-29
pub fn apply_gravity(
    detector: &dyn CollisionDetector,
    x: i32,
    y: i32,
    speed: i32,
    width: i32,
    height: i32,
) -> (i32, i32) {
    let new_y = y + speed;

    // Check if landing on solid ground
    if detector.can_move_to(x, new_y, width, height) {
        (x, new_y)
    } else {
        (x, y) // Landed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_direction_from_fireball() {
        assert_eq!(Direction::from_fireball_code(1), Some(Direction::Left));
        assert_eq!(Direction::from_fireball_code(2), Some(Direction::Right));
        assert_eq!(Direction::from_fireball_code(3), Some(Direction::Up));
        assert_eq!(Direction::from_fireball_code(4), Some(Direction::Down));
        assert_eq!(Direction::from_fireball_code(0), None);
        assert_eq!(Direction::from_fireball_code(5), None);
    }

    #[test]
    fn test_direction_opposite() {
        assert_eq!(Direction::Up.opposite(), Direction::Down);
        assert_eq!(Direction::Down.opposite(), Direction::Up);
        assert_eq!(Direction::Left.opposite(), Direction::Right);
        assert_eq!(Direction::Right.opposite(), Direction::Left);
    }

    #[test]
    fn test_direction_delta() {
        assert_eq!(Direction::Up.delta(), (0, -1));
        assert_eq!(Direction::Down.delta(), (0, 1));
        assert_eq!(Direction::Left.delta(), (-1, 0));
        assert_eq!(Direction::Right.delta(), (1, 0));
    }

    #[test]
    fn test_behavior_type_from_u32() {
        assert_eq!(BehaviorType::from_u32(0), Some(BehaviorType::Pickup));
        assert_eq!(
            BehaviorType::from_u32(2),
            Some(BehaviorType::HorizontalPatrol)
        );
        assert_eq!(BehaviorType::from_u32(16), Some(BehaviorType::ChasingEnemy));
        assert_eq!(BehaviorType::from_u32(99), None);
    }

    #[test]
    fn test_entity_code_parse() {
        let code = EntityCode::parse("ZNNA").unwrap();
        assert_eq!(code.interaction, InteractionType::PickupWalk);
        assert_eq!(code.animated, false);
        assert_eq!(code.danger, DangerLevel::None);
        assert_eq!(code.visibility, Visibility::Always);

        let code = EntityCode::parse("ZANA").unwrap();
        assert_eq!(code.interaction, InteractionType::PickupWalk);
        assert_eq!(code.animated, true);
        assert_eq!(code.danger, DangerLevel::None);
        assert_eq!(code.visibility, Visibility::Always);

        let code = EntityCode::parse("YNN~").unwrap();
        assert_eq!(code.interaction, InteractionType::SpecialTouch);
        assert_eq!(code.animated, false);
        assert_eq!(code.danger, DangerLevel::None);
        assert_eq!(code.visibility, Visibility::ExitDoor);

        assert!(EntityCode::parse("ABC").is_none()); // Too short
        assert!(EntityCode::parse("ABCDE").is_none()); // Too long
    }

    #[test]
    fn test_interaction_type_from_char() {
        assert_eq!(
            InteractionType::from_char('Z'),
            Some(InteractionType::PickupWalk)
        );
        assert_eq!(
            InteractionType::from_char('Y'),
            Some(InteractionType::SpecialTouch)
        );
        assert_eq!(
            InteractionType::from_char('X'),
            Some(InteractionType::SpecialEnter)
        );
        assert_eq!(InteractionType::from_char('W'), Some(InteractionType::Use));
        assert_eq!(InteractionType::from_char('V'), Some(InteractionType::Talk));
        assert_eq!(InteractionType::from_char('A'), None);
    }

    #[test]
    fn test_danger_level_from_char() {
        assert_eq!(DangerLevel::from_char('N'), Some(DangerLevel::None));
        assert_eq!(DangerLevel::from_char('S'), Some(DangerLevel::Mortal));
        assert_eq!(DangerLevel::from_char('D'), Some(DangerLevel::NoGod));
        assert_eq!(DangerLevel::from_char('A'), None);
    }

    #[test]
    fn test_visibility_from_char() {
        assert_eq!(Visibility::from_char('A'), Some(Visibility::Always));
        assert_eq!(Visibility::from_char('~'), Some(Visibility::ExitDoor));

        let group_c = Visibility::from_char('C');
        assert!(matches!(group_c, Some(Visibility::Group('C'))));
    }
}
