// Siriel Macroquad - Avatar Animation (siriel-avatar.png)

use crate::core::{AnimState, Animation, LoopMode, SPRITE_SIZE};
use macroquad::prelude::*;

/// Avatar spritesheet for player animations
/// - Source: siriel-avatar.png (224x64 pixels = 14x4 grid)
/// - Grid layout (GZAL format from original DOS)
pub struct AvatarAtlas {
    pub texture: Texture2D,
    pub columns: i32,
    pub animations: Vec<Animation>,
}

impl AvatarAtlas {
    /// Load avatar spritesheet from PNG file
    pub async fn load() -> Result<Self, String> {
        let texture = load_texture("assets/sprites/siriel-avatar.png")
            .await
            .map_err(|e| format!("Failed to load avatar: {:?}", e))?;

        texture.set_filter(FilterMode::Nearest);

        // siriel-avatar.png is 224x64 = 14x4 grid of 16x16 tiles
        let columns = 14;

        let animations = vec![
            // === Idle Animations ===
            Animation {
                name: "idle_down".into(),
                start_frame: 0,
                frame_count: 4,
                duration: 0.25,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "idle_left".into(),
                start_frame: 4,
                frame_count: 4,
                duration: 0.25,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "idle_right".into(),
                start_frame: 8,
                frame_count: 4,
                duration: 0.25,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "idle_up".into(),
                start_frame: 31,
                frame_count: 4,
                duration: 0.25,
                loop_mode: LoopMode::Loop,
            },
            // === Walking Animations ===
            Animation {
                name: "walk_left".into(),
                start_frame: 4,
                frame_count: 4,
                duration: 0.1,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "walk_right".into(),
                start_frame: 8,
                frame_count: 4,
                duration: 0.1,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "walk_up".into(),
                start_frame: 31,
                frame_count: 4,
                duration: 0.1,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "walk_down".into(),
                start_frame: 0,
                frame_count: 4,
                duration: 0.1,
                loop_mode: LoopMode::Loop,
            },
            // === Jump/Fall Animations ===
            Animation {
                name: "jump_up".into(),
                start_frame: 12,
                frame_count: 8,
                duration: 0.1,
                loop_mode: LoopMode::Once,
            },
            Animation {
                name: "jump_left".into(),
                start_frame: 23,
                frame_count: 8,
                duration: 0.1,
                loop_mode: LoopMode::Once,
            },
            Animation {
                name: "jump_right".into(),
                start_frame: 35,
                frame_count: 8,
                duration: 0.1,
                loop_mode: LoopMode::Once,
            },
            Animation {
                name: "parachute".into(),
                start_frame: 20,
                frame_count: 3,
                duration: 0.15,
                loop_mode: LoopMode::Loop,
            },
            // === Legacy Animations (for compatibility) ===
            Animation {
                name: "left".into(),
                start_frame: 4,
                frame_count: 4,
                duration: 0.1,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "right".into(),
                start_frame: 8,
                frame_count: 4,
                duration: 0.1,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "up".into(),
                start_frame: 31,
                frame_count: 4,
                duration: 0.1,
                loop_mode: LoopMode::Loop,
            },
            Animation {
                name: "jump_left_up".into(),
                start_frame: 23,
                frame_count: 8,
                duration: 0.1,
                loop_mode: LoopMode::Once,
            },
        ];

        Ok(Self {
            texture,
            columns,
            animations,
        })
    }

    /// Get source rectangle for frame index
    pub fn get_frame_rect(&self, frame: i32) -> Rect {
        let col = frame % self.columns;
        let row = frame / self.columns;

        Rect {
            x: col as f32 * SPRITE_SIZE as f32,
            y: row as f32 * SPRITE_SIZE as f32,
            w: SPRITE_SIZE as f32,
            h: SPRITE_SIZE as f32,
        }
    }

    /// Update animation state
    pub fn update_anim(&self, state: &mut AnimState, dt: f32) {
        state.update(&self.animations, dt);
    }

    /// Get current frame for animation state
    pub fn get_current_frame(&self, state: &AnimState) -> i32 {
        let anim = match self.animations.iter().find(|a| a.name == state.current) {
            Some(a) => a,
            None => return 0,
        };

        anim.start_frame + state.frame
    }

    /// Draw avatar at position
    pub fn draw(&self, state: &AnimState, x: f32, y: f32, tint: Color) {
        let frame = self.get_current_frame(state);
        let src = self.get_frame_rect(frame);

        draw_texture_ex(
            &self.texture,
            x,
            y,
            tint,
            DrawTextureParams {
                source: Some(src),
                ..Default::default()
            },
        );
    }

    /// Draw avatar with horizontal flip
    pub fn draw_flip_x(&self, state: &AnimState, x: f32, y: f32, tint: Color) {
        let frame = self.get_current_frame(state);
        let src = self.get_frame_rect(frame);

        draw_texture_ex(
            &self.texture,
            x,
            y,
            tint,
            DrawTextureParams {
                source: Some(src),
                flip_x: true,
                ..Default::default()
            },
        );
    }
}
