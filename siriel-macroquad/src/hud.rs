// Siriel Macroquad - HUD Display System

use crate::core::GAME_WIDTH;
use macroquad::prelude::*;

/// HUD renderer matching original DOS Siriel layout
pub struct Hud {
    /// Frame texture for HUD border (optional - use fallback if None)
    frame_texture: Option<Texture2D>,
    /// Heart sprite for lives display
    heart_texture: Option<Texture2D>,
}

impl Hud {
    /// Create new HUD instance
    pub fn new() -> Self {
        Self {
            frame_texture: None,
            heart_texture: None,
        }
    }

    /// Load optional HUD assets (frame, hearts)
    pub async fn load_assets(&mut self) -> Result<(), String> {
        // Try to load HUD frame texture
        if let Ok(texture) = load_texture("assets/sprites/hud_frame.png").await {
            texture.set_filter(FilterMode::Nearest);
            self.frame_texture = Some(texture);
        }

        // Try to load heart texture for lives
        if let Ok(texture) = load_texture("assets/sprites/heart.png").await {
            texture.set_filter(FilterMode::Nearest);
            self.heart_texture = Some(texture);
        }

        Ok(())
    }

    /// Draw complete HUD
    ///
    /// Layout: [INVENTORY]  [LEVEL NAME]  [SCORE | LIVES]
    /// Placed at BOTTOM of screen (matches original DOS - vypisy=460 on 480px screen)
    pub fn draw(
        &self,
        level_name: &str,
        score: i32,
        lives: i32,
        inventory_items: &[Option<&str>], // Up to 3 item sprite names
        objects: &crate::assets::ObjectsAtlas,
    ) {
        let (screen_w, screen_h) = (screen_width(), screen_height());

        // HUD at bottom of screen (original: vypisy=460 on 480px screen)
        // Taller bar for proper spacing (original ~50px)
        let hud_height = 50.0;
        let hud_y = screen_h - hud_height - 20.0; // 20px margin from bottom edge
        let hud_width = GAME_WIDTH as f32;

        // Center HUD horizontally
        let hud_x = (screen_w - hud_width) / 2.0;

        // Draw HUD background (dark gray border with lighter interior)
        draw_rectangle(hud_x, hud_y, hud_width, hud_height, DARKGRAY);
        draw_rectangle(
            hud_x + 2.0,
            hud_y + 2.0,
            hud_width - 4.0,
            hud_height - 4.0,
            Color::new(0.4, 0.4, 0.45, 1.0),
        );

        // Draw border frame
        draw_rectangle_lines(hud_x, hud_y, hud_width, hud_height, 2.0, BLACK);

        // === LEFT SECTION: Inventory (3 items, like original) ===
        // Original: label at X=40, items at X=80,115,150 (35px spacing)
        let _inv_label_x = hud_x + 40.0;
        let inv_y = hud_y + hud_height - 18.0; // Lower position for taller bar
        let item_start_x = hud_x + 80.0;
        let item_spacing = 35.0;
        let item_size = 16.0;

        // Draw "INVENTORY:" label (or use empty string for now)
        // draw_text("ITEMS:", inv_label_x, inv_y, 14.0, WHITE);

        // Draw inventory slots (3 items)
        for i in 0..3 {
            let slot_x = item_start_x + i as f32 * item_spacing;
            // Draw item if present
            if let Some(item_name) = inventory_items.get(i).and_then(|o| *o) {
                if objects.has_object(item_name) {
                    objects.draw(item_name, 0, slot_x, inv_y, WHITE);
                }
            } else {
                // Empty slot - draw placeholder (like original sprite 45)
                draw_rectangle_lines(slot_x, inv_y, item_size, 16.0, 1.0, DARKGRAY);
            }
        }

        // === CENTER SECTION: Level Name ===
        let center_x = hud_x + hud_width / 2.0;
        let text_y = hud_y + hud_height / 2.0 + 5.0;

        // Draw level name centered
        draw_text_centered(level_name, center_x, text_y, 16.0, WHITE);

        // === RIGHT SECTION: Score and Lives ===
        // Original: score at X=498,Y=vypisy-26, lives at X=450,Y=vypisy-9
        let score_x = hud_x + hud_width - 142.0; // 640 - 498 = 142 from right edge
        let score_y = hud_y + 8.0; // Higher position for score (vypisy-26 relative)
        let lives_x = hud_x + hud_width - 190.0; // 640 - 450 = 190 from right edge
        let lives_y = hud_y + hud_height - 18.0; // Lower position for lives (vypisy-9 relative)

        // Score value (6 digits, like original)
        draw_text(&format!("{:06}", score), score_x, score_y, 16.0, YELLOW);

        // Lives label
        draw_text("LIVES:", lives_x, lives_y, 14.0, LIGHTGRAY);

        // Lives (hearts) - max 5 shown
        let heart_start_x = lives_x + 58.0; // 508 relative position
        let heart_size = 16.0;
        let hearts_to_show = lives.min(5);

        if let Some(heart_tex) = &self.heart_texture {
            for i in 0..hearts_to_show {
                let heart_x = heart_start_x + i as f32 * (heart_size);
                draw_texture(heart_tex, heart_x, lives_y, WHITE);
            }
        } else {
            // Fallback: draw red hearts
            for i in 0..hearts_to_show {
                let heart_x = heart_start_x + i as f32 * heart_size;
                draw_rectangle(heart_x, lives_y, heart_size - 2.0, heart_size - 2.0, RED);
            }
        }
    }
}

impl Default for Hud {
    fn default() -> Self {
        Self::new()
    }
}

/// Draw text centered horizontally at position
fn draw_text_centered(text: &str, x: f32, y: f32, font_size: f32, color: Color) {
    let text_width = measure_text(text, None, font_size as u16, 1.0).width;
    draw_text(
        text,
        x - text_width as f32 / 2.0,
        y - font_size / 2.0,
        font_size,
        color,
    );
}
