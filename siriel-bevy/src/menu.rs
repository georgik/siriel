use crate::level::GameArgs;
use crate::resources::*;
use bevy::prelude::*;
use std::fs;

/// Component to mark menu UI entities for cleanup
#[derive(Component)]
pub struct MenuUI;

/// Initialize the level menu by scanning available level files
pub fn setup_level_menu(mut commands: Commands, mut level_menu: ResMut<LevelMenu>) {
    // Scan assets/levels directory for .ron files
    let levels_dir = "assets/levels";

    if let Ok(entries) = fs::read_dir(levels_dir) {
        let mut levels = Vec::new();

        for entry in entries {
            if let Ok(entry) = entry {
                let path = entry.path();
                if let Some(extension) = path.extension() {
                    if extension == "ron" {
                        if let Some(file_name) = path.file_stem() {
                            let name = file_name.to_string_lossy().to_string();
                            let display_name = format_level_name(&name);
                            let file_path = path.to_string_lossy().to_string();

                            levels.push(LevelInfo {
                                name: name.clone(),
                                display_name,
                                file_path,
                                description: None,
                            });
                        }
                    }
                }
            }
        }

        // Sort levels by name
        levels.sort_by(|a, b| a.name.cmp(&b.name));
        level_menu.available_levels = levels;
    }

    info!("Found {} level files", level_menu.available_levels.len());

    // If no levels found, add a placeholder
    if level_menu.available_levels.is_empty() {
        level_menu.available_levels.push(LevelInfo {
            name: "no_levels".to_string(),
            display_name: "No levels found".to_string(),
            file_path: "".to_string(),
            description: Some("Place .ron level files in assets/levels/".to_string()),
        });
    }
}

/// Component to track if borders have been spawned for this element
#[derive(Component)]
pub struct BordersSpawned;

/// System to spawn decorative border tiles around menu elements
pub fn spawn_menu_borders(
    mut commands: Commands,
    atlas_manager: Res<crate::atlas::AtlasManager>,
    border_query: Query<(Entity, &Node), (With<MenuBorder>, Without<BordersSpawned>)>,
) {
    let eligible_entities = border_query.iter().count();

    // Only run if we have entities that need borders
    if eligible_entities == 0 {
        return;
    }

    info!(
        "🔍 Border system: Processing {} entities that need borders",
        eligible_entities
    );

    if let (Some(ref atlas), Some(ref texture), Some(ref layout)) = (
        &atlas_manager.menu_decoration_atlas,
        &atlas_manager.menu_decoration_texture,
        &atlas_manager.menu_decoration_layout,
    ) {
        info!(
            "✅ Border assets available, spawning borders for {} entities",
            eligible_entities
        );

        for (entity, node) in border_query.iter() {
            let width = match node.width {
                Val::Px(w) => w,
                _ => 620.0, // Default fallback
            };
            let height = match node.height {
                Val::Px(h) => h,
                _ => 380.0, // Default fallback
            };

            spawn_decorative_border(
                &mut commands,
                width,
                height,
                atlas,
                texture.clone(),
                layout.clone(),
            );

            // Mark this entity as having borders spawned to prevent repeated spawning
            commands.entity(entity).insert(BordersSpawned);

            info!(
                "🎆 Decorative border completed for entity {:?} ({}x{})",
                entity, width, height
            );
        }
    }
}

/// Spawn the actual border tiles around a menu element
fn spawn_decorative_border(
    commands: &mut Commands,
    width: f32,
    height: f32,
    atlas: &crate::atlas::AtlasDescriptor,
    texture: Handle<Image>,
    layout: Handle<TextureAtlasLayout>,
) {
    let tile_size = 16.0; // Original atlas tile size
    let scale = 1.0; // No scaling - use original size
    let scaled_tile_size = tile_size * scale;

    // Get the tile indices from the atlas
    let corner_tl = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-corner-tl"))
        .copied()
        .unwrap_or(0);
    let corner_tr = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-corner-tr"))
        .copied()
        .unwrap_or(2);
    let corner_bl = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-corner-bl"))
        .copied()
        .unwrap_or(5);
    let corner_br = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-corner-br"))
        .copied()
        .unwrap_or(7);
    let edge_top = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-edge-top"))
        .copied()
        .unwrap_or(1);
    let edge_bottom = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-edge-bottom"))
        .copied()
        .unwrap_or(6);
    let edge_left = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-edge-left"))
        .copied()
        .unwrap_or(3);
    let edge_right = atlas
        .special_tiles
        .as_ref()
        .and_then(|tiles| tiles.get("menu-edge-right"))
        .copied()
        .unwrap_or(4);

    info!(
        "🎨 Creating decorative border: {}x{} with scaled tiles {}",
        width, height, scaled_tile_size
    );

    // Calculate border dimensions based on the menu list area
    let border_width = ((width / scaled_tile_size) as u32) + 2; // Add 2 for border tiles around content
    let border_height = ((height / scaled_tile_size) as u32) + 2; // Add 2 for border tiles around content

    // Position border to frame the menu list (centered on screen)
    let start_x = -(border_width as f32 * scaled_tile_size) / 2.0 + scaled_tile_size / 2.0;
    let start_y = (border_height as f32 * scaled_tile_size) / 2.0 - scaled_tile_size / 2.0;

    info!(
        "📐 Border dimensions: {}x{} tiles around {}x{} menu area",
        border_width, border_height, width, height
    );

    // Spawn border frame
    for row in 0..border_height {
        for col in 0..border_width {
            let tile_index = if row == 0 && col == 0 {
                corner_tl // Top-left
            } else if row == 0 && col == border_width - 1 {
                corner_tr // Top-right
            } else if row == border_height - 1 && col == 0 {
                corner_bl // Bottom-left
            } else if row == border_height - 1 && col == border_width - 1 {
                corner_br // Bottom-right
            } else if row == 0 {
                edge_top // Top edge
            } else if row == border_height - 1 {
                edge_bottom // Bottom edge
            } else if col == 0 {
                edge_left // Left edge
            } else if col == border_width - 1 {
                edge_right // Right edge
            } else {
                continue; // Skip interior (transparent)
            };

            let world_x = start_x + col as f32 * scaled_tile_size;
            let world_y = start_y - row as f32 * scaled_tile_size;

            // Spawn as UI element instead of world sprite for guaranteed visibility
            commands.spawn((
                MenuBorderTile, // Mark for cleanup
                ImageNode {
                    image: texture.clone(),
                    texture_atlas: Some(TextureAtlas {
                        layout: layout.clone(),
                        index: tile_index as usize,
                    }),
                    ..default()
                },
                Node {
                    position_type: PositionType::Absolute,
                    left: Val::Px(320.0 + world_x), // Convert to UI coordinates (center screen + offset)
                    top: Val::Px(240.0 - world_y), // Convert to UI coordinates (center screen + offset)
                    width: Val::Px(scaled_tile_size),
                    height: Val::Px(scaled_tile_size),
                    ..default()
                },
                ZIndex(1000), // Ensure high Z-index for UI layering
            ));
        }
    }

    info!(
        "✨ Decorative border frame completed: {}x{} tiles (16x16 each) around menu",
        border_width, border_height
    );
}

/// Component to mark individual border tiles for cleanup
#[derive(Component)]
pub struct MenuBorderTile;

/// Component to mark intro screen elements for cleanup
#[derive(Component)]
pub struct IntroScreen;

/// Format level name for display (e.g., "FMIS01" -> "First Mission 01")
fn format_level_name(name: &str) -> String {
    match name {
        "FMIS01" => "First Mission 01".to_string(),
        "FMIS02" => "First Mission 02".to_string(),
        "FMIS03" => "First Mission 03".to_string(),
        "FMIS04" => "First Mission 04".to_string(),
        "FMIS05" => "First Mission 05".to_string(),
        "FMIS06" => "First Mission 06".to_string(),
        "FMIS07" => "First Mission 07".to_string(),
        "FMIS08" => "First Mission 08".to_string(),
        "FMIS09" => "First Mission 09".to_string(),
        "FMIS10" => "First Mission 10".to_string(),
        "FMIS11" => "First Mission 11".to_string(),
        "FMIS12" => "First Mission 12".to_string(),
        _ => {
            // Try to make it more readable
            if name.starts_with("FMIS") {
                format!("First Mission {}", &name[4..])
            } else if name.starts_with("CAUL") {
                format!("Cauldron {}", &name[4..])
            } else if name.starts_with("GBALL") {
                format!("Golden Ball {}", &name[5..])
            } else {
                name.to_string()
            }
        }
    }
}

// === INTRO SCREEN SYSTEMS ===

/// Spawn the intro screen
pub fn spawn_intro_screen(mut commands: Commands) {
    info!("Spawning intro screen with title and instructions");

    // Root UI container
    commands
        .spawn((
            IntroScreen, // Mark for cleanup
            Node {
                width: Val::Percent(100.0),
                height: Val::Percent(100.0),
                flex_direction: FlexDirection::Column,
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                ..default()
            },
        ))
        .with_children(|parent| {
            // Title text
            parent.spawn((
                Text::new("Siriel 3.5 - Bevy Edition"),
                TextFont {
                    font_size: 48.0,
                    ..default()
                },
                TextColor(Color::srgb(1.0, 1.0, 1.0)), // White text
                Node {
                    margin: UiRect::bottom(Val::Px(30.0)),
                    ..default()
                },
            ));

            // Instructions text
            parent.spawn((
                Text::new("Press Enter to continue"),
                TextFont {
                    font_size: 18.0,
                    ..default()
                },
                TextColor(Color::srgb(0.8, 0.8, 0.8)), // Light gray text
                TextLayout::new_with_justify(Justify::Center),
            ));
        });

    info!("Intro screen spawned");
}

/// Handle input on the intro screen
pub fn handle_intro_input(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut next_state: ResMut<NextState<AppState>>,
) {
    if keyboard_input.just_pressed(KeyCode::Enter) {
        info!("Enter pressed - transitioning from IntroScreen to Menu");
        next_state.set(AppState::Menu);
    }
}

/// Clean up intro screen elements when leaving the intro screen
pub fn cleanup_intro_screen(mut commands: Commands, intro_query: Query<Entity, With<IntroScreen>>) {
    for entity in intro_query.iter() {
        commands.entity(entity).despawn();
    }
    info!("Intro screen cleaned up");
}

/// Spawn the level selection menu UI when ready
pub fn spawn_level_menu_ui_when_ready(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    level_menu: Res<LevelMenu>,
) {
    spawn_level_menu_ui(&mut commands, &asset_server, &level_menu);
}

/// Track if UI has been refreshed to avoid repeated refreshes
#[derive(Resource, Default)]
pub struct MenuRefreshTracker {
    pub refreshed: bool,
}

/// Refresh menu UI when level list becomes available
pub fn refresh_menu_ui_when_levels_loaded(
    mut commands: Commands,
    asset_server: Res<AssetServer>,
    level_menu: Res<LevelMenu>,
    existing_ui: Query<Entity, With<MenuUI>>,
    mut refresh_tracker: ResMut<MenuRefreshTracker>,
) {
    // Only refresh once when levels become available
    if level_menu.is_changed()
        && !level_menu.available_levels.is_empty()
        && !existing_ui.is_empty()
        && !refresh_tracker.refreshed
    {
        // Remove existing UI
        for entity in existing_ui.iter() {
            commands.entity(entity).despawn();
        }

        // Spawn fresh UI with levels
        spawn_level_menu_ui(&mut commands, &asset_server, &level_menu);

        // Mark as refreshed
        refresh_tracker.refreshed = true;
    }
}

/// Spawn the level selection menu UI
fn spawn_level_menu_ui(
    commands: &mut Commands,
    _asset_server: &AssetServer,
    level_menu: &LevelMenu,
) {
    // Root menu container
    commands
        .spawn((
            MenuUI,
            Node {
                width: Val::Percent(100.0),
                height: Val::Percent(100.0),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                flex_direction: FlexDirection::Column,
                ..default()
            },
            BackgroundColor(Color::srgb(0.1, 0.1, 0.2)),
        ))
        .with_children(|parent| {
            // Title
            parent.spawn((
                Text::new("SIRIEL - Level Selection"),
                TextFont {
                    font_size: 24.0, // Reduced from 32.0
                    ..default()
                },
                TextColor(Color::WHITE),
                Node {
                    margin: UiRect::bottom(Val::Px(15.0)), // Reduced from 30.0
                    ..default()
                },
            ));

            // Instructions
            parent.spawn((
                Text::new(
                    "Use Arrow Keys or Mouse to select - Enter or Click to play - ESC to quit",
                ),
                TextFont {
                    font_size: 12.0, // Reduced from 16.0
                    ..default()
                },
                TextColor(Color::srgb(0.7, 0.7, 0.7)),
                Node {
                    margin: UiRect::bottom(Val::Px(10.0)), // Reduced from 20.0
                    ..default()
                },
            ));

            // Level list container with decorative border
            parent
                .spawn((
                    Node {
                        width: Val::Px(620.0),  // Increased width to use more screen
                        height: Val::Px(380.0), // Increased height for more levels
                        flex_direction: FlexDirection::Column,
                        overflow: Overflow::clip(),
                        border: UiRect::all(Val::Px(16.0)), // Space for 16px border tiles
                        ..default()
                    },
                    //BackgroundColor(Color::srgb(0.15, 0.15, 0.25)),
                    MenuBorder, // Component to mark this for border rendering
                ))
                .with_children(|list_parent| {
                    if level_menu.available_levels.is_empty() {
                        // Show loading message
                        list_parent
                            .spawn((Node {
                                width: Val::Percent(100.0),
                                height: Val::Px(100.0),
                                justify_content: JustifyContent::Center,
                                align_items: AlignItems::Center,
                                ..default()
                            },))
                            .with_children(|loading_parent| {
                                loading_parent.spawn((
                                    Text::new("Loading levels..."),
                                    TextFont {
                                        font_size: 16.0,
                                        ..default()
                                    },
                                    TextColor(Color::srgb(0.7, 0.7, 0.7)),
                                ));
                            });
                    } else {
                        // Add level entries
                        let visible_start = level_menu.scroll_offset;
                        let visible_end = (visible_start + level_menu.max_visible)
                            .min(level_menu.available_levels.len());

                        for (index, level_info) in level_menu.available_levels
                            [visible_start..visible_end]
                            .iter()
                            .enumerate()
                        {
                            let actual_index = visible_start + index;
                            let is_selected = actual_index == level_menu.selected_index;

                            list_parent
                                .spawn((
                                    MenuLevelItem {
                                        index: actual_index,
                                    },
                                    Button,
                                    Node {
                                        width: Val::Percent(100.0),
                                        height: Val::Px(18.0), // Reduced from 25.0 to fit more levels
                                        padding: UiRect::all(Val::Px(4.0)), // Reduced padding
                                        justify_content: JustifyContent::FlexStart,
                                        align_items: AlignItems::Center,
                                        ..default()
                                    },
                                    BackgroundColor(if is_selected {
                                        Color::srgb(0.3, 0.3, 0.5)
                                    } else {
                                        Color::NONE
                                    }),
                                ))
                                .with_children(|item_parent| {
                                    item_parent.spawn((
                                        Text::new(&level_info.display_name),
                                        TextFont {
                                            font_size: 14.0, // Reduced from 18.0 for better fit
                                            ..default()
                                        },
                                        TextColor(if is_selected {
                                            Color::WHITE
                                        } else {
                                            Color::srgb(0.8, 0.8, 0.8)
                                        }),
                                    ));
                                });
                        }
                    }
                });

            // Footer info
            if !level_menu.available_levels.is_empty()
                && level_menu.selected_index < level_menu.available_levels.len()
            {
                let selected_level = &level_menu.available_levels[level_menu.selected_index];
                if let Some(ref desc) = selected_level.description {
                    parent.spawn((
                        Text::new(desc.clone()),
                        TextFont {
                            font_size: 14.0,
                            ..default()
                        },
                        TextColor(Color::srgb(0.6, 0.6, 0.6)),
                        Node {
                            margin: UiRect::top(Val::Px(20.0)),
                            ..default()
                        },
                    ));
                }
            }
        });
}

/// Component for level menu items
#[derive(Component)]
pub struct MenuLevelItem {
    pub index: usize,
}

/// Component to mark UI elements that should have decorative borders
#[derive(Component)]
pub struct MenuBorder;

/// Menu input timer for key repeat
#[derive(Resource)]
pub struct MenuInputTimer {
    pub timer: Timer,
    pub initial_delay: Timer,
}

impl Default for MenuInputTimer {
    fn default() -> Self {
        Self {
            timer: Timer::from_seconds(0.1, TimerMode::Repeating), // 100ms repeat rate
            initial_delay: Timer::from_seconds(0.4, TimerMode::Once), // 400ms initial delay
        }
    }
}

/// Handle menu input (keyboard)
pub fn handle_menu_input(
    keyboard_input: Res<ButtonInput<KeyCode>>,
    mut level_menu: ResMut<LevelMenu>,
    mut next_state: ResMut<NextState<AppState>>,
    mut commands: Commands,
    game_args: Res<GameArgs>,
    time: Res<Time>,
    mut menu_timer: ResMut<MenuInputTimer>,
) {
    if level_menu.available_levels.is_empty() {
        return;
    }

    // Don't allow input if the first level is the placeholder "no_levels"
    if level_menu.available_levels.len() == 1 && level_menu.available_levels[0].name == "no_levels"
    {
        return;
    }

    let mut selection_changed = false;

    // Handle up/down navigation with key repeat
    let up_pressed = keyboard_input.pressed(KeyCode::ArrowUp);
    let down_pressed = keyboard_input.pressed(KeyCode::ArrowDown);

    // Update timers
    menu_timer.timer.tick(time.delta());
    menu_timer.initial_delay.tick(time.delta());

    // Check for initial key press or repeated input
    let should_move = keyboard_input.just_pressed(KeyCode::ArrowUp)
        || keyboard_input.just_pressed(KeyCode::ArrowDown)
        || (menu_timer.initial_delay.is_finished() && menu_timer.timer.just_finished());

    if should_move {
        if up_pressed && level_menu.selected_index > 0 {
            level_menu.selected_index -= 1;
            selection_changed = true;
        } else if down_pressed && level_menu.selected_index < level_menu.available_levels.len() - 1
        {
            level_menu.selected_index += 1;
            selection_changed = true;
        }
    }

    // Reset timers when keys are released
    if !up_pressed && !down_pressed {
        menu_timer.timer.reset();
        menu_timer.initial_delay.reset();
    }

    // Adjust scroll if needed
    if selection_changed {
        if level_menu.selected_index < level_menu.scroll_offset {
            level_menu.scroll_offset = level_menu.selected_index;
        } else if level_menu.selected_index >= level_menu.scroll_offset + level_menu.max_visible {
            level_menu.scroll_offset = level_menu.selected_index - level_menu.max_visible + 1;
        }
    }

    // Handle level selection
    if keyboard_input.just_pressed(KeyCode::Enter) || keyboard_input.just_pressed(KeyCode::Space) {
        if !level_menu.available_levels.is_empty()
            && level_menu.selected_index < level_menu.available_levels.len()
        {
            let selected_level = &level_menu.available_levels[level_menu.selected_index];
            load_selected_level(&mut commands, &selected_level.file_path);
            next_state.set(AppState::InGame);
        }
    }

    // Handle quit
    if keyboard_input.just_pressed(KeyCode::Escape) {
        if game_args.verbose {
            info!("ESC pressed in menu - quitting game");
        }
        std::process::exit(0);
    }
}

/// Handle menu mouse interactions
pub fn handle_menu_mouse(
    mut interaction_query: Query<
        (&Interaction, &MenuLevelItem, &mut BackgroundColor),
        (Changed<Interaction>, With<Button>),
    >,
    mut level_menu: ResMut<LevelMenu>,
    mut next_state: ResMut<NextState<AppState>>,
    mut commands: Commands,
) {
    for (interaction, menu_item, mut bg_color) in interaction_query.iter_mut() {
        match *interaction {
            Interaction::Pressed => {
                // Load the selected level
                if menu_item.index < level_menu.available_levels.len() {
                    let selected_level = &level_menu.available_levels[menu_item.index];
                    load_selected_level(&mut commands, &selected_level.file_path);
                    next_state.set(AppState::InGame);
                }
            }
            Interaction::Hovered => {
                *bg_color = BackgroundColor(Color::srgb(0.25, 0.25, 0.4));
                level_menu.selected_index = menu_item.index;
            }
            Interaction::None => {
                let is_selected = menu_item.index == level_menu.selected_index;
                *bg_color = BackgroundColor(if is_selected {
                    Color::srgb(0.3, 0.3, 0.5)
                } else {
                    Color::NONE
                });
            }
        }
    }
}

/// Load the selected level and prepare game state
fn load_selected_level(commands: &mut Commands, level_path: &str) {
    info!("Loading level: {}", level_path);

    // Insert resource to tell the game which level to load
    commands.insert_resource(SelectedLevel {
        path: level_path.to_string(),
    });
}

/// Resource to communicate selected level to game systems
#[derive(Resource)]
pub struct SelectedLevel {
    pub path: String,
}

/// Clean up menu UI when leaving menu state
pub fn cleanup_menu_ui(
    mut commands: Commands,
    menu_query: Query<Entity, With<MenuUI>>,
    border_query: Query<Entity, With<MenuBorderTile>>,
    borders_spawned_query: Query<Entity, With<BordersSpawned>>,
) {
    // Clean up main menu UI
    for entity in menu_query.iter() {
        commands.entity(entity).despawn();
    }

    // Clean up border tiles (now UI elements)
    for entity in border_query.iter() {
        commands.entity(entity).despawn();
    }

    // Remove BordersSpawned components to allow re-spawning on next menu visit
    for entity in borders_spawned_query.iter() {
        commands.entity(entity).remove::<BordersSpawned>();
    }
}

/// Update menu UI when selection changes (for keyboard navigation visual feedback)
pub fn update_menu_ui(
    level_menu: Res<LevelMenu>,
    mut query: Query<(Entity, &MenuLevelItem, &mut BackgroundColor), With<MenuLevelItem>>,
    children_query: Query<&Children>,
    mut text_query: Query<&mut TextColor>,
) {
    if !level_menu.is_changed() {
        return;
    }

    for (entity, menu_item, mut bg_color) in query.iter_mut() {
        let is_selected = menu_item.index == level_menu.selected_index;

        *bg_color = BackgroundColor(if is_selected {
            Color::srgb(0.3, 0.3, 0.5)
        } else {
            Color::NONE
        });

        // Update text color for children
        if let Ok(children) = children_query.get(entity) {
            for child in children.iter() {
                if let Ok(mut text_color) = text_query.get_mut(child) {
                    *text_color = TextColor(if is_selected {
                        Color::WHITE
                    } else {
                        Color::srgb(0.8, 0.8, 0.8)
                    });
                }
            }
        }
    }
}
