// Siriel Macroquad - Camera System

#![allow(dead_code)]

use crate::core::{GAME_HEIGHT, GAME_WIDTH};

/// Camera for viewport management
#[derive(Debug, Clone)]
pub struct Camera {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub follow_lag: f32,
    pub target_x: Option<f32>,
    pub target_y: Option<f32>,
    pub bounds: Option<CameraBounds>,
}

/// Camera bounds for level limits
#[derive(Debug, Clone, Copy)]
pub struct CameraBounds {
    pub min_x: f32,
    pub max_x: f32,
    pub min_y: f32,
    pub max_y: f32,
}

impl Camera {
    /// Create new camera
    pub fn new() -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            width: GAME_WIDTH as f32,
            height: GAME_HEIGHT as f32,
            follow_lag: 0.1,
            target_x: None,
            target_y: None,
            bounds: None,
        }
    }

    /// Create camera with bounds
    pub fn with_bounds(min_x: f32, max_x: f32, min_y: f32, max_y: f32) -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            width: GAME_WIDTH as f32,
            height: GAME_HEIGHT as f32,
            follow_lag: 0.1,
            target_x: None,
            target_y: None,
            bounds: Some(CameraBounds {
                min_x,
                max_x,
                min_y,
                max_y,
            }),
        }
    }

    /// Set target position to follow
    pub fn follow(&mut self, x: f32, y: f32) {
        self.target_x = Some(x);
        self.target_y = Some(y);
    }

    /// Stop following
    pub fn stop_following(&mut self) {
        self.target_x = None;
        self.target_y = None;
    }

    /// Update camera position
    pub fn update(&mut self, _dt: f32) {
        if let (Some(tx), Some(ty)) = (self.target_x, self.target_y) {
            // Calculate desired position (center on target)
            let desired_x = tx - self.width / 2.0;
            let desired_y = ty - self.height / 2.0;

            // Smooth follow with lag
            let diff_x = desired_x - self.x;
            let diff_y = desired_y - self.y;

            self.x += diff_x * self.follow_lag;
            self.y += diff_y * self.follow_lag;

            // Apply bounds
            if let Some(bounds) = self.bounds {
                self.x = self.x.max(bounds.min_x).min(bounds.max_x);
                self.y = self.y.max(bounds.min_y).min(bounds.max_y);
            }
        }
    }

    /// Get camera position
    pub fn position(&self) -> (f32, f32) {
        (self.x, self.y)
    }

    /// Set camera position directly
    pub fn set_position(&mut self, x: f32, y: f32) {
        self.x = x;
        self.y = y;

        if let Some(bounds) = self.bounds {
            self.x = self.x.max(bounds.min_x).min(bounds.max_x);
            self.y = self.y.max(bounds.min_y).min(bounds.max_y);
        }
    }

    /// Convert world position to screen position
    pub fn world_to_screen(&self, world_x: f32, world_y: f32) -> (f32, f32) {
        (world_x - self.x, world_y - self.y)
    }

    /// Convert screen position to world position
    pub fn screen_to_world(&self, screen_x: f32, screen_y: f32) -> (f32, f32) {
        (screen_x + self.x, screen_y + self.y)
    }

    /// Check if world point is visible
    pub fn is_visible(&self, world_x: f32, world_y: f32, padding: f32) -> bool {
        world_x >= self.x - padding
            && world_x <= self.x + self.width + padding
            && world_y >= self.y - padding
            && world_y <= self.y + self.height + padding
    }

    /// Check if rectangle is visible
    pub fn is_rect_visible(&self, x: f32, y: f32, w: f32, h: f32) -> bool {
        x < self.x + self.width && x + w > self.x && y < self.y + self.height && y + h > self.y
    }
}

impl Default for Camera {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_camera_creation() {
        let camera = Camera::new();
        assert_eq!(camera.x, 0.0);
        assert_eq!(camera.y, 0.0);
        assert_eq!(camera.width, GAME_WIDTH as f32);
    }

    #[test]
    fn test_camera_with_bounds() {
        let camera = Camera::with_bounds(0.0, 1000.0, 0.0, 500.0);
        assert!(camera.bounds.is_some());
    }

    #[test]
    fn test_follow() {
        let mut camera = Camera::new();
        camera.follow(100.0, 100.0);
        assert_eq!(camera.target_x, Some(100.0));
        assert_eq!(camera.target_y, Some(100.0));
    }

    #[test]
    fn test_stop_following() {
        let mut camera = Camera::new();
        camera.follow(100.0, 100.0);
        camera.stop_following();
        assert!(camera.target_x.is_none());
    }

    #[test]
    fn test_set_position() {
        let mut camera = Camera::new();
        camera.set_position(50.0, 50.0);
        assert_eq!(camera.x, 50.0);
        assert_eq!(camera.y, 50.0);
    }

    #[test]
    fn test_bounds_clamp() {
        let mut camera = Camera::with_bounds(0.0, 100.0, 0.0, 100.0);
        camera.set_position(-10.0, 50.0);
        assert_eq!(camera.x, 0.0); // Clamped to min

        camera.set_position(150.0, 50.0);
        assert_eq!(camera.x, 100.0); // Clamped to max
    }

    #[test]
    fn test_world_to_screen() {
        let mut camera = Camera::new();
        camera.set_position(50.0, 50.0);
        let (sx, sy) = camera.world_to_screen(100.0, 100.0);
        assert_eq!(sx, 50.0);
        assert_eq!(sy, 50.0);
    }

    #[test]
    fn test_screen_to_world() {
        let mut camera = Camera::new();
        camera.set_position(50.0, 50.0);
        let (wx, wy) = camera.screen_to_world(50.0, 50.0);
        assert_eq!(wx, 100.0);
        assert_eq!(wy, 100.0);
    }

    #[test]
    fn test_is_visible() {
        let mut camera = Camera::new();
        camera.set_position(0.0, 0.0);
        assert!(camera.is_visible(50.0, 50.0, 0.0));
        assert!(!camera.is_visible(-10.0, 50.0, 0.0));
        // Point at 700.0 should not be visible within 640px game width
        assert!(!camera.is_visible(700.0, 50.0, 0.0));
    }

    #[test]
    fn test_is_rect_visible() {
        let mut camera = Camera::new();
        camera.set_position(0.0, 0.0);
        assert!(camera.is_rect_visible(50.0, 50.0, 16.0, 16.0));
        assert!(!camera.is_rect_visible(-20.0, 50.0, 16.0, 16.0));
    }

    #[test]
    fn test_follow_update() {
        let mut camera = Camera::new();
        // Follow a point that would cause positive camera movement
        camera.follow(400.0, 300.0);

        // Initial position
        assert_eq!(camera.x, 0.0);

        // After multiple updates, should move toward target
        for _ in 0..10 {
            camera.update(0.1);
        }
        assert!(camera.x > 0.0);
    }
}
