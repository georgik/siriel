// Siriel Macroquad - Avatar Animation (siriel-avatar.png + siriel-avatar.ron)

use crate::core::{AnimState, Animation, LoopMode};
use macroquad::prelude::*;
use serde::Deserialize;
use std::fs;

/// RON metadata structure for avatar spritesheet
#[derive(Deserialize)]
#[allow(dead_code)]
struct AvatarMetadata {
    tile_size: u32,
    columns: u32,
    rows: u32,
    animations: Vec<AnimationDef>,
}

#[derive(Deserialize)]
struct AnimationDef {
    name: String,
    row: u32,
    frame_count: u32,
    fps: u8,
}

/// Avatar spritesheet for player animations
/// - Source: siriel-avatar.png (128x240 pixels = 8x15 grid)
/// - Each animation occupies its own row
pub struct AvatarAtlas {
    pub texture: Texture2D,
    pub columns: i32,
    pub tile_size: i32,
    animations: Vec<Animation>,
    /// Row index for each animation (for frame calculation)
    animation_rows: Vec<(String, u32)>,
}

impl AvatarAtlas {
    /// Load avatar spritesheet from PNG + RON metadata
    pub async fn load() -> Result<Self, String> {
        eprintln!("=== Avatar Loading ===");

        let texture = load_texture("assets/sprites/siriel-avatar.png")
            .await
            .map_err(|e| format!("Failed to load avatar: {:?}", e))?;

        texture.set_filter(FilterMode::Nearest);
        eprintln!("Texture loaded: siriel-avatar.png");
        eprintln!("Texture size: {}x{}", texture.width(), texture.height());

        // Load RON metadata
        let ron_path = "assets/sprites/siriel-avatar.ron";
        let ron_content = fs::read_to_string(ron_path)
            .map_err(|e| format!("Failed to read {}: {}", ron_path, e))?;
        let metadata: AvatarMetadata =
            ron::from_str(&ron_content).map_err(|e| format!("Failed to parse RON: {}", e))?;

        eprintln!("RON metadata loaded:");
        eprintln!("  tile_size: {}", metadata.tile_size);
        eprintln!("  columns: {}", metadata.columns);
        eprintln!("  rows: {}", metadata.rows);
        eprintln!("  animation count: {}", metadata.animations.len());

        let tile_size = metadata.tile_size as i32;
        let columns = metadata.columns as i32;

        // Build animation list with row tracking
        let mut animations = Vec::new();
        let mut animation_rows = Vec::new();

        eprintln!("Animations loaded:");
        for anim_def in &metadata.animations {
            let duration = if anim_def.fps > 0 {
                1.0 / anim_def.fps as f32
            } else {
                1.0
            };

            // Determine loop mode
            let loop_mode = if anim_def.frame_count == 1 {
                LoopMode::Once
            } else if anim_def.name == "parachute" || anim_def.name.starts_with("walk") {
                LoopMode::Loop
            } else if anim_def.name.starts_with("jump") {
                LoopMode::Once
            } else if anim_def.name == "idle" || anim_def.name == "stars" {
                LoopMode::Loop
            } else {
                LoopMode::Loop
            };

            animations.push(Animation {
                name: anim_def.name.clone(),
                start_frame: 0,
                frame_count: anim_def.frame_count as i32,
                duration,
                loop_mode,
            });

            animation_rows.push((anim_def.name.clone(), anim_def.row));

            eprintln!(
                "  - {}: row={}, frames={}, fps={}, duration={:.3}",
                anim_def.name, anim_def.row, anim_def.frame_count, anim_def.fps, duration
            );
        }

        eprintln!("=== Avatar Loading Complete ===");

        Ok(Self {
            texture,
            columns,
            tile_size,
            animations,
            animation_rows,
        })
    }

    /// Get source rectangle for animation at specific frame
    pub fn get_frame_rect(&self, anim_name: &str, frame: i32) -> Rect {
        let row = self
            .animation_rows
            .iter()
            .find(|(name, _)| name == anim_name)
            .map(|(_, row)| *row as i32)
            .unwrap_or_else(|| {
                eprintln!(
                    "WARNING: Animation '{}' not found in spritesheet",
                    anim_name
                );
                0
            });

        let col = frame % self.columns;

        Rect {
            x: col as f32 * self.tile_size as f32,
            y: row as f32 * self.tile_size as f32,
            w: self.tile_size as f32,
            h: self.tile_size as f32,
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
            None => {
                eprintln!(
                    "WARNING: Requested animation '{}' not found. Available animations:",
                    state.current
                );
                for a in &self.animations {
                    eprintln!("  - {}", a.name);
                }
                return 0;
            }
        };

        anim.start_frame + state.frame
    }

    /// Draw avatar at position
    pub fn draw(&self, state: &AnimState, x: f32, y: f32, tint: Color) {
        let frame = self.get_current_frame(state);
        let src = self.get_frame_rect(&state.current, frame);

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
        let src = self.get_frame_rect(&state.current, frame);

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
