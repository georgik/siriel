use bevy::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Atlas descriptor for sprite sheets and texture atlases
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AtlasDescriptor {
    pub name: String,
    pub image_path: String,
    pub tile_size: (u32, u32),
    pub grid_size: (u32, u32), // columns, rows
    pub total_tiles: u32,

    // For texture atlases (tilemaps) - direct tile indexing
    pub special_tiles: Option<HashMap<String, u32>>, // name -> tile index

    // For animation atlases
    pub animations: Option<HashMap<String, AnimationDescriptor>>,
    pub animation_mapping: Option<HashMap<String, String>>, // state -> animation name

    pub metadata: Option<HashMap<String, String>>,
}

/// Animation descriptor for a single animation sequence
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AnimationDescriptor {
    pub frames: Vec<u32>, // frame indices in the atlas
    pub duration: f32,    // seconds per frame
    pub loop_mode: AnimationLoopMode,
}

/// How an animation should loop
#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum AnimationLoopMode {
    Once,     // Play once then stop
    Loop,     // Loop continuously
    PingPong, // Play forward then backward repeatedly
}

/// Resource for managing loaded atlases
#[derive(Resource, Default)]
pub struct AtlasManager {
    pub texture_atlas: Option<AtlasDescriptor>,
    pub avatar_atlas: Option<AtlasDescriptor>,
    pub objects_atlas: Option<AtlasDescriptor>,
    pub animations_atlas: Option<AtlasDescriptor>,
    pub menu_decoration_atlas: Option<AtlasDescriptor>,
    pub menu_decoration_texture: Option<Handle<Image>>,
    pub menu_decoration_layout: Option<Handle<TextureAtlasLayout>>,
    // Avatar-specific texture atlas
    pub avatar_texture: Option<Handle<Image>>,
    pub avatar_layout: Option<Handle<TextureAtlasLayout>>,
    pub objects_texture: Option<Handle<Image>>,
    pub objects_layout: Option<Handle<TextureAtlasLayout>>,
}

impl AtlasManager {
    /// Load atlas descriptor from RON file
    pub fn load_atlas(path: &str) -> Result<AtlasDescriptor, Box<dyn std::error::Error>> {
        let ron_string = std::fs::read_to_string(path)?;
        let atlas: AtlasDescriptor = ron::from_str(&ron_string)?;
        Ok(atlas)
    }

    /// Convert tile ID to texture atlas index for rendering
    /// RON files use direct tile indexing (0-based sequential)
    /// Tile ID 0 = empty/walkable (not rendered)
    /// Tile ID 1+ = texture atlas indices (direct mapping)
    pub fn tile_id_to_texture_index(&self, tile_id: u32) -> u32 {
        // Direct mapping: tile ID maps directly to atlas index
        // This works because RON files already use the correct atlas indices
        tile_id
    }

    /// Get tile index by name from special tiles
    pub fn get_special_tile(&self, name: &str) -> Option<u32> {
        if let Some(ref atlas) = self.texture_atlas {
            if let Some(ref special) = atlas.special_tiles {
                return special.get(name).copied();
            }
        }
        None
    }

    /// Get animation descriptor by name from avatar atlas
    pub fn get_avatar_animation(&self, name: &str) -> Option<&AnimationDescriptor> {
        if let Some(ref atlas) = self.avatar_atlas {
            if let Some(ref animations) = atlas.animations {
                return animations.get(name);
            }
        }
        None
    }

    /// Get animation descriptor by name from animations atlas
    pub fn get_animation(&self, name: &str) -> Option<&AnimationDescriptor> {
        if let Some(ref atlas) = self.animations_atlas {
            if let Some(ref animations) = atlas.animations {
                return animations.get(name);
            }
        }
        None
    }

    /// Get animation name by semantic mapping (e.g. "exit" -> "teleport")
    pub fn get_mapped_animation(&self, semantic_name: &str) -> Option<&AnimationDescriptor> {
        if let Some(ref atlas) = self.animations_atlas {
            if let Some(ref mapping) = atlas.animation_mapping {
                if let Some(animation_name) = mapping.get(semantic_name) {
                    if let Some(ref animations) = atlas.animations {
                        return animations.get(animation_name);
                    }
                }
            }
        }
        None
    }

    /// Convert 1D tile index to 2D grid coordinates
    pub fn tile_index_to_coords(&self, tile_index: u32) -> (u32, u32) {
        if let Some(ref atlas) = self.texture_atlas {
            let cols = atlas.grid_size.0;
            let x = tile_index % cols;
            let y = tile_index / cols;
            return (x, y);
        }
        (0, 0)
    }

    /// Convert 2D grid coordinates to 1D tile index  
    pub fn coords_to_tile_index(&self, x: u32, y: u32) -> u32 {
        if let Some(ref atlas) = self.texture_atlas {
            let cols = atlas.grid_size.0;
            return y * cols + x;
        }
        0
    }

    /// Get menu decoration tile index by name
    pub fn get_menu_decoration_tile(&self, name: &str) -> Option<u32> {
        if let Some(ref atlas) = self.menu_decoration_atlas {
            if let Some(ref special) = atlas.special_tiles {
                return special.get(name).copied();
            }
        }
        None
    }
}

/// System to load atlas descriptors at startup
pub fn load_atlas_descriptors(
    mut atlas_manager: ResMut<AtlasManager>,
    asset_server: Res<AssetServer>,
    mut texture_atlas_layouts: ResMut<Assets<TextureAtlasLayout>>,
) {
    // Load texture atlas for tilemaps
    match AtlasManager::load_atlas("assets/sprites/texture-basic.atlas.ron") {
        Ok(atlas) => {
            info!(
                "✅ Loaded texture atlas: {} ({}x{} tiles)",
                atlas.name, atlas.grid_size.0, atlas.grid_size.1
            );
            atlas_manager.texture_atlas = Some(atlas);
        }
        Err(e) => {
            warn!("❌ Failed to load texture atlas: {}", e);
        }
    }

    // Load avatar atlas for player animations
    match AtlasManager::load_atlas("assets/sprites/siriel-avatar.atlas.ron") {
        Ok(atlas) => {
            info!(
                "✅ Loaded avatar atlas: {} ({}x{} frames)",
                atlas.name, atlas.grid_size.0, atlas.grid_size.1
            );
            // Load the texture handle
            atlas_manager.avatar_texture = Some(asset_server.load(&atlas.image_path));

            // Create texture atlas layout for Bevy 0.17
            let layout = TextureAtlasLayout::from_grid(
                UVec2::new(atlas.tile_size.0, atlas.tile_size.1),
                atlas.grid_size.0,
                atlas.grid_size.1,
                None,
                None,
            );
            let layout_handle = texture_atlas_layouts.add(layout);
            atlas_manager.avatar_layout = Some(layout_handle);

            atlas_manager.avatar_atlas = Some(atlas);
        }
        Err(e) => {
            warn!("❌ Failed to load avatar atlas: {}", e);
        }
    }

    // Load objects atlas for collectible items
    match AtlasManager::load_atlas("assets/sprites/objects-basic.atlas.ron") {
        Ok(atlas) => {
            info!(
                "✅ Loaded objects atlas: {} ({}x{} objects)",
                atlas.name, atlas.grid_size.0, atlas.grid_size.1
            );
            // Load the texture handle
            atlas_manager.objects_texture = Some(asset_server.load(&atlas.image_path));

            // Create texture atlas layout for Bevy 0.17
            let layout = TextureAtlasLayout::from_grid(
                UVec2::new(atlas.tile_size.0, atlas.tile_size.1),
                atlas.grid_size.0,
                atlas.grid_size.1,
                None,
                None,
            );
            let layout_handle = texture_atlas_layouts.add(layout);
            atlas_manager.objects_layout = Some(layout_handle);

            atlas_manager.objects_atlas = Some(atlas);
        }
        Err(e) => {
            warn!("❌ Failed to load objects atlas: {}", e);
        }
    }

    // Load animations atlas for environmental/collectible animations
    match AtlasManager::load_atlas("assets/sprites/animations-basic.atlas.ron") {
        Ok(atlas) => {
            info!(
                "✅ Loaded animations atlas: {} ({}x{} frames)",
                atlas.name, atlas.grid_size.0, atlas.grid_size.1
            );
            atlas_manager.animations_atlas = Some(atlas);
        }
        Err(e) => {
            warn!("❌ Failed to load animations atlas: {}", e);
        }
    }

    // Load menu decoration atlas for UI borders
    match AtlasManager::load_atlas("assets/menu-decoration.atlas.ron") {
        Ok(atlas) => {
            info!(
                "✅ Loaded menu decoration atlas: {} ({}x{} tiles)",
                atlas.name, atlas.grid_size.0, atlas.grid_size.1
            );
            // Load the texture handle
            atlas_manager.menu_decoration_texture = Some(asset_server.load(&atlas.image_path));

            // Create texture atlas layout for Bevy 0.17
            let layout = TextureAtlasLayout::from_grid(
                UVec2::new(atlas.tile_size.0, atlas.tile_size.1),
                atlas.grid_size.0,
                atlas.grid_size.1,
                None,
                None,
            );
            let layout_handle = texture_atlas_layouts.add(layout);
            atlas_manager.menu_decoration_layout = Some(layout_handle);

            atlas_manager.menu_decoration_atlas = Some(atlas);
        }
        Err(e) => {
            warn!("❌ Failed to load menu decoration atlas: {}", e);
        }
    }
}
