// Siriel Macroquad - Object Spritesheet (objects-fmis.png + objects-fmis.ron)

use macroquad::prelude::*;
use serde::Deserialize;

/// RON metadata structure for objects spritesheet
#[derive(Deserialize)]
#[allow(dead_code)]
struct ObjectsMetadata {
    tile_size: u32,
    columns: u32,
    rows: u32,
    animations: Vec<ObjectDef>,
}

#[derive(Deserialize)]
struct ObjectDef {
    name: String,
    row: u32,
    frame_count: u32,
    fps: u8,
}

/// Object spritesheet for creatures/collectibles
pub struct ObjectsAtlas {
    pub texture: Texture2D,
    pub columns: i32,
    pub tile_size: i32,
    /// Row index for each object
    object_rows: Vec<(String, u32)>,
    /// Frame count for each object
    frame_counts: Vec<(String, u32)>,
    /// FPS for each object
    fps_values: Vec<(String, u8)>,
}

impl ObjectsAtlas {
    /// Load objects spritesheet from PNG + RON metadata
    pub async fn load() -> Result<Self, String> {
        eprintln!("=== Objects Loading ===");

        let texture = load_texture("assets/sprites/objects-fmis.png")
            .await
            .map_err(|e| format!("Failed to load objects: {:?}", e))?;

        texture.set_filter(FilterMode::Nearest);
        eprintln!("Texture loaded: objects-fmis.png");
        eprintln!("Texture size: {}x{}", texture.width(), texture.height());

        // Load RON metadata
        let ron_path = "assets/sprites/objects-fmis.ron";
        let ron_content = load_string(ron_path)
            .await
            .map_err(|e| format!("Failed to read {}: {:?}", ron_path, e))?;
        let metadata: ObjectsMetadata =
            ron::from_str(&ron_content).map_err(|e| format!("Failed to parse RON: {}", e))?;

        eprintln!("RON metadata loaded:");
        eprintln!("  tile_size: {}", metadata.tile_size);
        eprintln!("  columns: {}", metadata.columns);
        eprintln!("  rows: {}", metadata.rows);
        eprintln!("  object count: {}", metadata.animations.len());

        let tile_size = metadata.tile_size as i32;
        let columns = metadata.columns as i32;

        let mut object_rows = Vec::new();
        let mut frame_counts = Vec::new();
        let mut fps_values = Vec::new();

        eprintln!("Objects loaded:");
        for obj_def in &metadata.animations {
            object_rows.push((obj_def.name.clone(), obj_def.row));
            frame_counts.push((obj_def.name.clone(), obj_def.frame_count));
            fps_values.push((obj_def.name.clone(), obj_def.fps));

            eprintln!(
                "  - {}: row={}, frames={}, fps={}",
                obj_def.name, obj_def.row, obj_def.frame_count, obj_def.fps
            );
        }

        eprintln!("=== Objects Loading Complete ===");

        Ok(Self {
            texture,
            columns,
            tile_size,
            object_rows,
            frame_counts,
            fps_values,
        })
    }

    /// Get source rectangle for object at specific frame
    pub fn get_frame_rect(&self, obj_name: &str, frame: i32) -> Rect {
        let row = self
            .object_rows
            .iter()
            .find(|(name, _)| name == obj_name)
            .map(|(_, row)| *row as i32)
            .unwrap_or_else(|| {
                eprintln!("WARNING: Object '{}' not found in spritesheet", obj_name);
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

    /// Get frame count for object
    pub fn frame_count(&self, obj_name: &str) -> u32 {
        self.frame_counts
            .iter()
            .find(|(name, _)| name == obj_name)
            .map(|(_, count)| *count)
            .unwrap_or(1)
    }

    /// Get FPS for object
    pub fn fps(&self, obj_name: &str) -> u8 {
        self.fps_values
            .iter()
            .find(|(name, _)| name == obj_name)
            .map(|(_, fps)| *fps)
            .unwrap_or(1)
    }

    /// Draw object at position with animation frame
    pub fn draw(&self, obj_name: &str, frame: i32, x: f32, y: f32, tint: Color) {
        let src = self.get_frame_rect(obj_name, frame);

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

    /// Check if object name exists
    pub fn has_object(&self, obj_name: &str) -> bool {
        self.object_rows.iter().any(|(name, _)| name == obj_name)
    }
}
