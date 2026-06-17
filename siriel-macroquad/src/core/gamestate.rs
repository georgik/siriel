// Siriel Macroquad - Game States

#![allow(dead_code)]

/// Game state modes
#[derive(Debug, Clone, PartialEq)]
pub enum GameMode {
    TitleScreen,
    MainMenu,
    LevelSelector,
    Playing,
    LevelTransition,
    Paused,
    GameOver,
    Victory,
    LevelComplete,
}

/// Transition effect
#[derive(Debug, Clone)]
pub struct Transition {
    pub active: bool,
    pub progress: f32,
    pub duration: f32,
    pub fade_out: bool,
}

impl Transition {
    pub fn new(duration: f32) -> Self {
        Self {
            active: true,
            progress: 0.0,
            duration,
            fade_out: true,
        }
    }

    pub fn update(&mut self, dt: f32) -> bool {
        if !self.active {
            return false;
        }

        self.progress += dt;

        if self.progress >= self.duration {
            if self.fade_out {
                self.progress = 0.0;
                self.fade_out = false;
                return false; // Still in transition (fade in next)
            } else {
                self.active = false;
                return true; // Complete
            }
        }

        false
    }

    pub fn alpha(&self) -> f32 {
        if !self.active {
            return 0.0;
        }

        let t = (self.progress / self.duration).min(1.0);
        if self.fade_out { t } else { 1.0 - t }
    }

    pub fn is_complete(&self) -> bool {
        !self.active
    }
}

/// Game session state
#[derive(Debug, Clone)]
pub struct GameSession {
    pub current_level: usize,
    pub total_levels: usize,
    pub score: i32,
    pub lives: i32,
    pub health: i32,
    pub coins: i32,
    pub game_mode: GameMode,
}

impl GameSession {
    pub fn new(total_levels: usize) -> Self {
        Self {
            current_level: 0,
            total_levels,
            score: 0,
            lives: 3,
            health: 3,
            coins: 0,
            game_mode: GameMode::TitleScreen,
        }
    }

    pub fn start_game(&mut self) {
        self.current_level = 0;
        self.score = 0;
        self.lives = 3;
        self.health = 3;
        self.coins = 0;
        self.game_mode = GameMode::Playing;
    }

    pub fn next_level(&mut self) {
        self.current_level += 1;
        if self.current_level >= self.total_levels {
            self.game_mode = GameMode::Victory;
        } else {
            self.game_mode = GameMode::LevelComplete;
        }
    }

    pub fn restart_level(&mut self) {
        self.health = 3;
        self.game_mode = GameMode::Playing;
    }

    pub fn lose_life(&mut self) {
        self.lives -= 1;
        if self.lives <= 0 {
            self.game_mode = GameMode::GameOver;
        } else {
            self.restart_level();
        }
    }

    pub fn take_damage(&mut self) {
        self.health -= 1;
        if self.health <= 0 {
            self.lose_life();
        }
    }

    pub fn add_score(&mut self, points: i32) {
        self.score += points;
    }

    pub fn add_coin(&mut self) {
        self.coins += 1;
        self.add_score(10);
    }

    pub fn is_last_level(&self) -> bool {
        self.current_level + 1 >= self.total_levels
    }

    pub fn level_progress(&self) -> String {
        format!("{}/{}", self.current_level + 1, self.total_levels)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_session_creation() {
        let session = GameSession::new(5);
        assert_eq!(session.total_levels, 5);
        assert_eq!(session.lives, 3);
        assert_eq!(session.health, 3);
        assert_eq!(session.score, 0);
    }

    #[test]
    fn test_start_game() {
        let mut session = GameSession::new(5);
        session.start_game();
        assert_eq!(session.current_level, 0);
        assert_eq!(session.game_mode, GameMode::Playing);
    }

    #[test]
    fn test_next_level() {
        let mut session = GameSession::new(5);
        session.start_game();
        session.next_level();
        assert_eq!(session.current_level, 1);
        assert_eq!(session.game_mode, GameMode::LevelComplete);
    }

    #[test]
    fn test_victory_on_last_level() {
        let mut session = GameSession::new(1);
        session.start_game();
        session.next_level();
        assert_eq!(session.game_mode, GameMode::Victory);
    }

    #[test]
    fn test_take_damage() {
        let mut session = GameSession::new(5);
        session.start_game();
        session.take_damage();
        assert_eq!(session.health, 2);
    }

    #[test]
    fn test_lose_life() {
        let mut session = GameSession::new(5);
        session.start_game();
        session.health = 1;
        session.take_damage();
        assert_eq!(session.lives, 2);
        assert_eq!(session.health, 3); // Restarted
    }

    #[test]
    fn test_game_over() {
        let mut session = GameSession::new(5);
        session.start_game();
        session.lives = 1;
        session.health = 1;
        session.take_damage();
        assert_eq!(session.game_mode, GameMode::GameOver);
    }

    #[test]
    fn test_add_score() {
        let mut session = GameSession::new(5);
        session.add_score(100);
        assert_eq!(session.score, 100);
    }

    #[test]
    fn test_add_coin() {
        let mut session = GameSession::new(5);
        session.add_coin();
        assert_eq!(session.coins, 1);
        assert_eq!(session.score, 10);
    }

    #[test]
    fn test_level_progress() {
        let session = GameSession::new(5);
        assert_eq!(session.level_progress(), "1/5");
    }

    #[test]
    fn test_transition_creation() {
        let transition = Transition::new(1.0);
        assert!(transition.active);
        assert_eq!(transition.duration, 1.0);
    }

    #[test]
    fn test_transition_update() {
        let mut transition = Transition::new(1.0);
        transition.update(0.5);
        assert_eq!(transition.progress, 0.5);
        assert!(!transition.update(0.6)); // Should complete fade out
        assert!(!transition.fade_out);
    }

    #[test]
    fn test_transition_alpha() {
        let mut transition = Transition::new(1.0);
        assert_eq!(transition.alpha(), 0.0);
        transition.progress = 0.5;
        assert_eq!(transition.alpha(), 0.5);
        transition.fade_out = false;
        assert_eq!(transition.alpha(), 0.5);
    }
}
