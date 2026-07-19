// Siriel Macroquad - Touch Controls for Mobile/WASM
// Provides on-screen virtual buttons for touch devices

use macroquad::prelude::*;

/// Virtual button for touch input
#[derive(Clone, Debug)]
pub struct VirtualButton {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
    pub label: String,
    pub pressed: bool,
    pub key_code: KeyCode, // Also trigger keyboard equivalent
}

impl VirtualButton {
    pub fn new(x: f32, y: f32, width: f32, height: f32, label: &str, key_code: KeyCode) -> Self {
        Self {
            x,
            y,
            width,
            height,
            label: label.to_string(),
            pressed: false,
            key_code,
        }
    }

    /// Check if point is inside button
    pub fn contains(&self, px: f32, py: f32) -> bool {
        px >= self.x && px <= self.x + self.width && py >= self.y && py <= self.y + self.height
    }

    /// Draw button with pressed state
    pub fn draw(&self) {
        let color = if self.pressed {
            Color::new(0.7, 0.7, 0.7, 0.8)
        } else {
            Color::new(0.3, 0.3, 0.3, 0.6)
        };

        // Background
        draw_rectangle(self.x, self.y, self.width, self.height, color);
        draw_rectangle_lines(self.x, self.y, self.width, self.height, 2.0, WHITE);

        // Label
        let text_size = 20.0;
        let text_width = measure_text(&self.label, None, text_size as u16, 1.0).width;
        draw_text(
            &self.label,
            self.x + (self.width - text_width as f32) / 2.0,
            self.y + (self.height - text_size) / 2.0 + text_size * 0.7,
            text_size,
            WHITE,
        );
    }
}

/// Touch input manager
pub struct TouchControls {
    pub left_btn: VirtualButton,
    pub right_btn: VirtualButton,
    pub jump_btn: VirtualButton,
    pub esc_btn: VirtualButton,
    pub menu_tap: Option<(f32, f32)>,
}

impl TouchControls {
    pub fn new() -> Self {
        Self {
            left_btn: VirtualButton::new(20.0, 500.0, 60.0, 60.0, "←", KeyCode::Left),
            right_btn: VirtualButton::new(90.0, 500.0, 60.0, 60.0, "→", KeyCode::Right),
            jump_btn: VirtualButton::new(650.0, 500.0, 80.0, 60.0, "JUMP", KeyCode::Space),
            esc_btn: VirtualButton::new(700.0, 20.0, 60.0, 40.0, "ESC", KeyCode::Escape),
            menu_tap: None,
        }
    }

    /// Update button positions based on screen size
    pub fn update_layout(&mut self) {
        let w = screen_width();
        let h = screen_height();

        // D-pad on bottom left
        self.left_btn.x = w * 0.02;
        self.left_btn.y = h - 100.0;
        self.right_btn.x = w * 0.1;
        self.right_btn.y = h - 100.0;

        // Jump on bottom right
        self.jump_btn.x = w - 100.0;
        self.jump_btn.y = h - 100.0;

        // ESC on top right
        self.esc_btn.x = w - 70.0;
        self.esc_btn.y = 10.0;
    }

    /// Update touch state and return input values
    pub fn update(&mut self) -> (bool, bool, bool, bool) {
        self.update_layout();

        // Reset pressed state
        self.left_btn.pressed = false;
        self.right_btn.pressed = false;
        self.jump_btn.pressed = false;
        self.esc_btn.pressed = false;
        self.menu_tap = None;

        // Handle all active touches
        for touch in touches() {
            let x = touch.position.x;
            let y = touch.position.y;

            // Check ESC
            if self.esc_btn.contains(x, y) {
                self.esc_btn.pressed = true;
                continue;
            }

            // Check movement
            if self.left_btn.contains(x, y) {
                self.left_btn.pressed = true;
            }
            if self.right_btn.contains(x, y) {
                self.right_btn.pressed = true;
            }

            // Check jump
            if self.jump_btn.contains(x, y) {
                self.jump_btn.pressed = true;
            }

            // Store tap for menu handling (if no button pressed)
            if !self.left_btn.pressed
                && !self.right_btn.pressed
                && !self.jump_btn.pressed
                && !self.esc_btn.pressed
            {
                // Only register menu tap on touch start (single frame)
                self.menu_tap = Some((x, y));
            }
        }

        (
            self.left_btn.pressed,
            self.right_btn.pressed,
            self.jump_btn.pressed,
            self.esc_btn.pressed,
        )
    }

    /// Check if any touch is active
    pub fn is_touch_active() -> bool {
        !touches().is_empty()
    }

    /// Draw all controls (only if touch device or always for debug)
    pub fn draw(&self) {
        // Only draw on touch devices (WASM mobile) or if buttons pressed
        if Self::is_touch_active() || cfg!(target_arch = "wasm32") {
            self.left_btn.draw();
            self.right_btn.draw();
            self.jump_btn.draw();
            self.esc_btn.draw();
        }
    }

    /// Get menu tap position (consumed after one frame)
    pub fn take_menu_tap(&mut self) -> Option<(f32, f32)> {
        self.menu_tap.take()
    }
}

impl Default for TouchControls {
    fn default() -> Self {
        Self::new()
    }
}
