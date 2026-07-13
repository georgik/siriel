// Siriel Macroquad - Main Entry Point

mod assets;
mod audio;
mod core;
mod effects;
mod entities;
mod level;
mod menu;
mod player;
mod tilemap;

use assets::*;
use audio::*;
use clap::Parser;
use core::*;
use effects::*;
use entities::*;
use level::*;
use macroquad::prelude::*;
use menu::*;
use player::*;
use std::path::Path;
use tilemap::*;

/// Siriel Macroquad - Modern 2D Game Engine
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Auto-exit after N frames
    #[arg(short, long, default_value_t = 0)]
    timeout: u32,

    /// Save screenshot to path
    #[arg(short, long)]
    screenshot: Option<String>,

    /// Frame to capture screenshot (default: timeout value)
    #[arg(long, default_value_t = 0)]
    screenshot_at: u32,

    /// Enable debug output
    #[arg(short, long)]
    debug: bool,

    /// Load specific level file (RON format)
    #[arg(short, long)]
    level: Option<String>,
}

/// Game state
struct GameState {
    frame_count: u32,
    timeout: u32,
    screenshot: Option<String>,
    screenshot_at: u32,
    screenshot_taken: bool,
    debug: bool,
    level_manager: LevelManager,
    entity_manager: EntityManager,
    creatures: Vec<Creature>,
    player_health: i32,
    particles: ParticleSystem,
    sound_manager: SoundManager,
    // Powerup state
    god_mode: bool,
    freeze_mode: bool,
    powerup_timer: f32,
    // Menu system
    main_menu: Menu,
    level_selector: Menu,
    current_game_mode: GameMode,
}

impl GameState {
    fn new(args: &Args) -> Self {
        let screenshot_at = if args.screenshot_at > 0 {
            args.screenshot_at
        } else {
            args.timeout
        };

        // Create level manager and load levels from RON
        let mut level_manager = LevelManager::new();

        // Load specified level if provided
        if let Some(ref level_path) = args.level {
            let path = Path::new(level_path);
            match load_level_auto(path) {
                Ok(level) => {
                    let id = "custom".to_string();
                    level_manager.register(id.clone(), level);
                    eprintln!("Loaded level from: {}", level_path);
                }
                Err(e) => {
                    eprintln!("Failed to load level {}: {}", level_path, e);
                }
            }
        }

        // Load levels from RON files (converted from MIE)
        let level_files = [
            ("fmis01", "assets/levels/fmis01.ron"),
            ("fmis02", "assets/levels/fmis02.ron"),
            ("fmis03", "assets/levels/fmis03.ron"),
            ("fmis04", "assets/levels/fmis04.ron"),
            ("fmis05", "assets/levels/fmis05.ron"),
            ("fmis06", "assets/levels/fmis06.ron"),
            ("fmis07", "assets/levels/fmis07.ron"),
            ("fmis08", "assets/levels/fmis08.ron"),
            ("fmis09", "assets/levels/fmis09.ron"),
            ("fmis10", "assets/levels/fmis10.ron"),
        ];

        for (id, path) in &level_files {
            match load_from_ron(Path::new(path)) {
                Ok(level) => {
                    level_manager.register(id.to_string(), level);
                }
                Err(e) => {
                    if args.debug {
                        eprintln!("Failed to load level {}: {}", path, e);
                    }
                }
            }
        }

        // Set first level or create default if none loaded
        if level_manager.level_count() > 0 {
            level_manager.set_level("level1").ok();
        } else {
            // Fallback to empty level - register as level1 so menu items work
            let mut default_level = Level::empty();
            default_level.meta.name = "Default Level".to_string();
            level_manager.register("level1".to_string(), default_level);
            level_manager.set_level("level1").unwrap();
        }

        // Create entity manager
        let entity_manager = EntityManager::new();

        // Create main menu
        let mut main_menu = Menu::new(MenuConfig {
            x: 200.0,
            y: 150.0,
            title: "SIRIEL MACROQUAD".to_string(),
            primary_color: BLACK,
            secondary_color: WHITE,
            background_color: Color::new(0.52, 0.58, 0.67, 1.0),
            ..Default::default()
        });
        main_menu.add_item_with_key('N', "New Game", MenuAction::NewGame);
        main_menu.add_item_with_key(
            'L',
            "Level Select",
            MenuAction::GotoMode("level_selector".to_string()),
        );
        main_menu.add_separator();
        main_menu.add_item_with_key('Q', "Quit", MenuAction::Quit);

        // Create level selector
        let mut level_selector = Menu::new(MenuConfig {
            x: 180.0,
            y: 120.0,
            title: "Select Level".to_string(),
            primary_color: BLACK,
            secondary_color: WHITE,
            background_color: Color::new(0.52, 0.58, 0.67, 1.0),
            ..Default::default()
        });
        level_selector.add_item_with_key(
            '1',
            "Level 01 - Empty Plains",
            MenuAction::LoadLevel("level1".to_string()),
        );
        level_selector.add_item_with_key(
            '2',
            "Level 02 - Platform Gardens",
            MenuAction::LoadLevel("level2".to_string()),
        );
        level_selector.add_separator();
        level_selector.add_item_with_key(
            'B',
            "Back",
            MenuAction::GotoMode("main_menu".to_string()),
        );

        Self {
            frame_count: 0,
            timeout: args.timeout,
            screenshot: args.screenshot.clone(),
            screenshot_at,
            screenshot_taken: false,
            debug: args.debug,
            level_manager,
            entity_manager,
            creatures: Vec::new(),
            player_health: 3,
            particles: ParticleSystem::new(),
            sound_manager: SoundManager::new(),
            god_mode: false,
            freeze_mode: false,
            powerup_timer: 0.0,
            main_menu,
            level_selector,
            current_game_mode: GameMode::MainMenu,
        }
    }

    /// Load creatures from current level
    fn load_creatures_from_level(&mut self) {
        if let Some(current_level) = self.level_manager.current() {
            self.creatures = current_level.creatures.clone();
        }
    }

    fn should_exit(&self) -> bool {
        if self.timeout > 0 && self.frame_count >= self.timeout {
            return true;
        }
        false
    }

    fn handle_menu_action(&mut self, action: &MenuAction) {
        match action {
            MenuAction::NewGame => {
                // Start new game - try level1, fallback to first available
                let level_id: String = if self.level_manager.get_level("level1").is_some() {
                    "level1".to_string()
                } else if let Some(first) = self.level_manager.level_ids().first() {
                    first.clone()
                } else {
                    if self.debug {
                        eprintln!("No levels available!");
                    }
                    return;
                };

                if let Err(e) = self.level_manager.set_level(&level_id) {
                    if self.debug {
                        eprintln!("Failed to load level {}: {}", level_id, e);
                    }
                    return;
                }
                self.load_creatures_from_level();
                self.current_game_mode = GameMode::Playing;
                self.player_health = 3;
            }
            MenuAction::GotoMode(mode) => match mode.as_str() {
                "main_menu" => self.current_game_mode = GameMode::MainMenu,
                "level_selector" => self.current_game_mode = GameMode::LevelSelector,
                "playing" => self.current_game_mode = GameMode::Playing,
                _ => {}
            },
            MenuAction::LoadLevel(level_id) => {
                if let Err(e) = self.level_manager.set_level(level_id) {
                    if self.debug {
                        eprintln!("Failed to load level: {}", e);
                    }
                } else {
                    self.load_creatures_from_level();
                    self.current_game_mode = GameMode::Playing;
                    self.player_health = 3;
                }
            }
            MenuAction::Quit => {
                // Will exit on next frame check
            }
            _ => {}
        }
    }

    fn take_screenshot(&mut self) -> bool {
        if self.screenshot_taken {
            return false;
        }

        if self.screenshot.is_some() && self.frame_count >= self.screenshot_at {
            self.screenshot_taken = true;
            return true;
        }
        false
    }
}

#[macroquad::main("Siriel Macroquad")]
async fn main() {
    // Parse CLI args (for desktop only - WASM ignores these)
    let args = Args::parse();
    let mut game = GameState::new(&args);

    // Load assets
    let avatar = match AvatarAtlas::load().await {
        Ok(a) => a,
        Err(e) => {
            eprintln!("Failed to load avatar: {}", e);
            return;
        }
    };

    let tileset = match Tileset::load("assets/sprites/texture-basic.png").await {
        Ok(t) => t,
        Err(e) => {
            eprintln!("Failed to load tileset: {}", e);
            return;
        }
    };

    // Initialize player at level spawn position
    let mut player_physics = PhysicsState::new(88.0, 88.0);
    let mut player_anim = AnimState::new(anim::IDLE);

    loop {
        let dt = get_frame_time();

        // Handle game modes
        match game.current_game_mode {
            GameMode::MainMenu => {
                // Update main menu
                match game.main_menu.update(dt) {
                    menu::NavigationResult::Activate(_index) => {
                        if let Some(action) = game.main_menu.selected_action().cloned() {
                            game.handle_menu_action(&action);
                        }
                    }
                    menu::NavigationResult::Cancel => {
                        break; // Exit game
                    }
                    _ => {}
                }

                // Render
                clear_background(WHITE);

                // Draw main menu
                game.main_menu.draw();

                // Draw title
                draw_text_centered("SIRIEL MACROQUAD", screen_width() / 2.0, 80.0, 40.0, BLACK);

                // Draw version info
                draw_text(
                    "Phase 11 - Menu System",
                    10.0,
                    screen_height() - 30.0,
                    16.0,
                    DARKGRAY,
                );

                next_frame().await;
                game.frame_count += 1;

                if game.should_exit() {
                    break;
                }
                continue;
            }
            GameMode::LevelSelector => {
                // Update level selector
                match game.level_selector.update(dt) {
                    menu::NavigationResult::Activate(_index) => {
                        if let Some(action) = game.level_selector.selected_action().cloned() {
                            game.handle_menu_action(&action);
                        }
                    }
                    menu::NavigationResult::Cancel => {
                        game.current_game_mode = GameMode::MainMenu;
                    }
                    _ => {}
                }

                // Render
                clear_background(WHITE);
                game.level_selector.draw();

                next_frame().await;
                game.frame_count += 1;

                if game.should_exit() {
                    break;
                }
                continue;
            }
            GameMode::Playing => {
                // Game loop continues below
            }
            _ => {
                // Other modes - for now just go to main menu
                game.current_game_mode = GameMode::MainMenu;
                continue;
            }
        }

        // ESC to go to menu, exit if in menu already
        if is_key_pressed(KeyCode::Escape) {
            game.current_game_mode = GameMode::MainMenu;
        }

        // Level switching: N for next level
        if is_key_pressed(KeyCode::N) {
            if let Err(e) = game.level_manager.next_level() {
                if game.debug {
                    eprintln!("Next level error: {}", e);
                }
            } else {
                // Reset player position on level change
                player_physics.x = 88.0;
                player_physics.y = 88.0;
                player_physics.vx = 0.0;
                player_physics.vy = 0.0;
                game.load_creatures_from_level();
                game.sound_manager.play(SoundType::Select);
            }
        }

        // Handle input
        player_physics.handle_input();

        // Update physics with tilemap collision
        if let Some(current_level) = game.level_manager.current() {
            player_physics.update_with_collision(&current_level.tiles, dt);
        }

        // Update entities
        game.entity_manager.update(dt);

        // Update creature AI
        let mut level_complete_triggered = false;
        if let Some(current_level) = game.level_manager.current() {
            let detector = TilemapDetector::new(&current_level.tiles);
            let player_pos = player_physics.position();
            let player_x = player_pos.x as i32;
            let player_y = player_pos.y as i32;

            // Only update AI if not frozen
            if !game.freeze_mode {
                for creature in &mut game.creatures {
                    creature.update_ai(&detector, player_x, player_y);
                }
            }
        }

        // Check creature-player collisions
        // Collect pending visibility changes first
        let mut reveal_groups: Vec<char> = Vec::new();
        let mut hide_groups: Vec<char> = Vec::new();

        let player_pos = player_physics.position();
        let player_rect = (
            player_pos.x as i32,
            player_pos.y as i32,
            16, // player width
            32, // player height
        );

        for creature in &mut game.creatures {
            if creature.visible && creature.base.alive {
                let creature_rect = (
                    creature.base.x as i32,
                    creature.base.y as i32,
                    creature.base.width as i32,
                    creature.base.height as i32,
                );

                // Simple AABB collision
                if player_rect.0 < creature_rect.0 + creature_rect.2
                    && player_rect.0 + player_rect.2 > creature_rect.0
                    && player_rect.1 < creature_rect.1 + creature_rect.3
                    && player_rect.1 + player_rect.3 > creature_rect.1
                {
                    // Collision!
                    match creature.behavior {
                        BehaviorType::Pickup | BehaviorType::AnimatedCollectible => {
                            // Collectible
                            creature.base.alive = false;
                            game.particles
                                .sparkle(creature.base.x + 8.0, creature.base.y + 8.0);
                            game.sound_manager.play(SoundType::Coin);
                        }
                        BehaviorType::Teleport => {
                            if let Some((tx, ty)) = creature.get_teleport_target() {
                                player_physics.x = tx as f32;
                                player_physics.y = ty as f32;
                                game.sound_manager.play(SoundType::Select);
                            }
                        }
                        BehaviorType::LevelComplete => {
                            game.level_manager.mark_completed();
                            game.sound_manager.play(SoundType::Select);
                            level_complete_triggered = true;
                        }
                        BehaviorType::AddLife => {
                            if let Some(lives) = creature.get_lives_to_add() {
                                game.player_health += lives;
                                creature.base.alive = false;
                                game.sound_manager.play(SoundType::Health);
                            }
                        }
                        BehaviorType::Reveal => {
                            // Queue reveal for this group
                            if let Some(group) = creature.group {
                                reveal_groups.push(group);
                            }
                            creature.base.alive = false;
                            game.sound_manager.play(SoundType::Select);
                        }
                        BehaviorType::Hide => {
                            // Queue hide for this group
                            if let Some(group) = creature.group {
                                hide_groups.push(group);
                            }
                            creature.base.alive = false;
                            game.sound_manager.play(SoundType::Select);
                        }
                        BehaviorType::SwapVisibility => {
                            // Swap: hide group1, show group2
                            let hide_group = creature.inf1 as u8 as char;
                            let show_group = creature.inf2 as u8 as char;
                            hide_groups.push(hide_group);
                            reveal_groups.push(show_group);
                            creature.base.alive = false;
                            game.sound_manager.play(SoundType::Select);
                        }
                        BehaviorType::RoomTransfer => {
                            if let Some((_room, tx, ty)) = creature.get_room_transfer() {
                                player_physics.x = tx as f32;
                                player_physics.y = ty as f32;
                                game.sound_manager.play(SoundType::Select);
                            }
                        }
                        BehaviorType::Powerup => {
                            if let Some(powerup_type) = creature.get_powerup_type() {
                                game.powerup_timer = 600.0; // 10 seconds at 60fps
                                match powerup_type {
                                    1 => {
                                        game.freeze_mode = true;
                                    }
                                    2 => {
                                        game.god_mode = true;
                                    }
                                    3 => {
                                        game.freeze_mode = true;
                                        game.god_mode = true;
                                    }
                                    _ => {}
                                }
                                creature.base.alive = false;
                                game.particles
                                    .sparkle(creature.base.x + 8.0, creature.base.y + 8.0);
                                game.sound_manager.play(SoundType::Health);
                            }
                        }
                        _ => {
                            if matches!(
                                creature.behavior,
                                BehaviorType::Fireball
                                    | BehaviorType::FireballAlt
                                    | BehaviorType::ChasingEnemy
                            ) {
                                if !game.god_mode {
                                    game.player_health -= 1;
                                    player_physics.vx = if player_physics.facing_left {
                                        3.0
                                    } else {
                                        -3.0
                                    };
                                    player_physics.vy = -3.0;
                                    game.particles.dust(player_pos.x + 8.0, player_pos.y + 8.0);
                                    game.sound_manager.play(SoundType::Hurt);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Apply queued visibility changes
        for group in reveal_groups {
            for creature in &mut game.creatures {
                if creature.group == Some(group) {
                    creature.visible = true;
                }
            }
        }
        for group in hide_groups {
            for creature in &mut game.creatures {
                if creature.group == Some(group) {
                    creature.visible = false;
                }
            }
        }

        // Update powerup timer
        if game.powerup_timer > 0.0 {
            game.powerup_timer -= dt;
            if game.powerup_timer <= 0.0 {
                game.god_mode = false;
                game.freeze_mode = false;
            }
        }

        // Handle level complete after creature loop
        if level_complete_triggered {
            if game.level_manager.is_last_level() {
                // Game complete!
                game.current_game_mode = GameMode::MainMenu;
            } else {
                game.level_manager.next_level().ok();
                player_physics.x = 88.0;
                player_physics.y = 88.0;
                game.load_creatures_from_level();
            }
        }

        // Check entity collisions
        let pos = player_physics.position();
        let was_on_ground = player_physics.on_ground;
        let collisions = game.entity_manager.check_player_collision(pos.x, pos.y);
        for collision in collisions {
            match collision {
                CollisionResult::EnemyHit => {
                    game.player_health -= 1;
                    // Push player back
                    player_physics.vx = if player_physics.facing_left {
                        2.0
                    } else {
                        -2.0
                    };
                    player_physics.vy = -2.0;
                    // Damage particles and sound
                    game.particles.dust(pos.x + 8.0, pos.y + 8.0);
                    game.sound_manager.play(SoundType::Hurt);
                }
                CollisionResult::ItemCollected(item_type) => {
                    // Collection sparkle and sound
                    game.particles.sparkle(pos.x + 8.0, pos.y + 8.0);
                    match item_type {
                        ItemType::Coin => game.sound_manager.play(SoundType::Coin),
                        ItemType::Health => game.sound_manager.play(SoundType::Health),
                        _ => {}
                    }
                    if game.debug {
                        eprintln!("Collected: {:?}", item_type);
                    }
                }
                _ => {}
            }
        }

        // Landing particles and sound
        if player_physics.on_ground && !was_on_ground && player_physics.vy >= 0.0 {
            game.particles.dust(pos.x + 8.0, pos.y + 16.0);
            game.sound_manager.play(SoundType::Land);
        }

        // Update particles
        game.particles.update(dt);

        // Respawn if health reaches 0
        if game.player_health <= 0 {
            player_physics.x = 88.0;
            player_physics.y = 88.0;
            player_physics.vx = 0.0;
            player_physics.vy = 0.0;
            game.player_health = 3;
        }

        // Update animation
        let anim_name = player_physics.get_animation();
        player_anim.set_anim(anim_name);
        avatar.update_anim(&mut player_anim, dt);

        // Debug: Log animation state occasionally
        if game.debug && game.frame_count % 60 == 0 {
            eprintln!(
                "Animation: name={}, frame={}, playing={}",
                player_anim.current, player_anim.frame, player_anim.playing
            );
        }

        // Render
        clear_background(WHITE);

        let game_x = (screen_width() - GAME_WIDTH as f32) / 2.0;
        let game_y = (screen_height() - GAME_HEIGHT as f32) / 2.0 + 20.0;

        draw_rectangle(
            game_x,
            game_y,
            GAME_WIDTH as f32,
            GAME_HEIGHT as f32,
            DARKGRAY,
        );
        draw_rectangle_lines(
            game_x,
            game_y,
            GAME_WIDTH as f32,
            GAME_HEIGHT as f32,
            2.0,
            BLACK,
        );

        // Draw tilemap
        if let Some(current_level) = game.level_manager.current() {
            draw_tilemap(&tileset, &current_level.tiles, game_x, game_y);

            // Draw entities
            // Draw enemies (red rectangles)
            for enemy in game.entity_manager.enemies() {
                if enemy.base.alive {
                    let ex = game_x + enemy.base.x;
                    let ey = game_y + enemy.base.y;
                    draw_rectangle(
                        ex,
                        ey,
                        enemy.base.width as f32,
                        enemy.base.height as f32,
                        RED,
                    );
                }
            }

            // Draw items (yellow circles for coins, green for health)
            for item in game.entity_manager.items() {
                if item.base.alive {
                    let ix = game_x + item.base.x;
                    let iy = game_y + item.base.y;
                    let color = match item.item_type {
                        ItemType::Coin => GOLD,
                        ItemType::Health => LIME,
                        ItemType::Powerup => PURPLE,
                        ItemType::Key => SKYBLUE,
                    };
                    draw_circle(ix + 4.0, iy + 4.0, 4.0, color);
                }
            }

            // Draw creatures from level
            for creature in &game.creatures {
                if creature.visible && creature.base.alive {
                    let cx = game_x + creature.base.x;
                    let cy = game_y + creature.base.y;

                    // Color based on behavior/danger
                    let color = match creature.behavior {
                        BehaviorType::Pickup | BehaviorType::AnimatedCollectible => GOLD,
                        BehaviorType::Teleport => MAGENTA,
                        BehaviorType::LevelComplete => GREEN,
                        BehaviorType::AddLife => LIME,
                        BehaviorType::Fireball | BehaviorType::FireballAlt => ORANGE,
                        BehaviorType::ChasingEnemy => RED,
                        BehaviorType::HorizontalPatrol | BehaviorType::VerticalPatrol => SKYBLUE,
                        BehaviorType::PlatformGravity | BehaviorType::PlatformEdge => BROWN,
                        _ => GRAY,
                    };

                    // Draw creature (simple colored rectangle for now)
                    draw_rectangle(
                        cx,
                        cy,
                        creature.base.width as f32,
                        creature.base.height as f32,
                        color,
                    );

                    // Draw border for enemies
                    if matches!(
                        creature.behavior,
                        BehaviorType::Fireball
                            | BehaviorType::FireballAlt
                            | BehaviorType::ChasingEnemy
                    ) {
                        draw_rectangle_lines(
                            cx,
                            cy,
                            creature.base.width as f32,
                            creature.base.height as f32,
                            1.0,
                            DARKGRAY,
                        );
                    }
                }
            }
        }

        // Draw player (spritesheet has directional frames, no flip needed)
        let pos = player_physics.position();
        avatar.draw(&player_anim, game_x + pos.x, game_y + pos.y, WHITE);

        // Draw particles (over everything)
        game.particles.draw();

        // HUD
        draw_text("SIRIEL MACROQUAD", 10.0, 10.0, 20.0, DARKGRAY);

        // Stats bar
        draw_text(
            &format!(
                "HP: {}  Score: {}  Coins: {}",
                game.player_health,
                game.entity_manager.score(),
                game.entity_manager.coins_collected()
            ),
            10.0,
            40.0,
            16.0,
            DARKGRAY,
        );

        if let Some(current_level) = game.level_manager.current() {
            draw_text(
                &format!("Level: {}", current_level.meta.name),
                10.0,
                60.0,
                16.0,
                DARKGRAY,
            );
        }

        draw_text(&format!("FPS: {}", get_fps()), 10.0, 80.0, 16.0, DARKGRAY);
        draw_text(
            &format!("Frame: {}", game.frame_count),
            10.0,
            100.0,
            16.0,
            DARKGRAY,
        );
        draw_text(
            &format!("Anim: {}", player_anim.current),
            10.0,
            120.0,
            16.0,
            DARKGRAY,
        );
        draw_text(
            &format!("Pos: ({:.0}, {:.0})", pos.x, pos.y),
            10.0,
            140.0,
            16.0,
            DARKGRAY,
        );
        draw_text(
            &format!("On Ground: {}", player_physics.on_ground),
            10.0,
            160.0,
            16.0,
            DARKGRAY,
        );

        // Level indicator
        if let Some(current_id) = game.level_manager.current_id() {
            let level_num = game
                .level_manager
                .level_ids()
                .iter()
                .position(|x| x == current_id)
                .map_or(0, |p| p + 1);
            draw_text(
                &format!("Level {}/{}", level_num, game.level_manager.level_count()),
                10.0,
                180.0,
                16.0,
                DARKGRAY,
            );
        }

        // Entity counts
        let (enemy_count, item_count) = game.entity_manager.counts();
        draw_text(
            &format!(
                "Enemies: {} Items: {} Creatures: {}",
                enemy_count,
                item_count,
                game.creatures.len()
            ),
            10.0,
            200.0,
            16.0,
            DARKGRAY,
        );

        // Particle count
        draw_text(
            &format!("Particles: {}", game.particles.count()),
            10.0,
            220.0,
            16.0,
            DARKGRAY,
        );

        // Controls help
        draw_text(
            "Arrows: Move | Space: Jump | N: Next Level | ESC: Exit",
            10.0,
            screen_height() - 30.0,
            16.0,
            DARKGRAY,
        );

        // Screenshot prompt
        if game.screenshot.is_some() && !game.screenshot_taken {
            draw_text(
                &format!("Screenshot at frame {}", game.screenshot_at),
                10.0,
                240.0,
                16.0,
                BLUE,
            );
        }

        next_frame().await;

        // Take screenshot after buffer swap (next_frame completes the swap)
        if game.take_screenshot() {
            if let Some(ref path) = game.screenshot {
                // Get screen contents
                let _screenshot_data = get_screen_data();
                // Note: Macroquad doesn't have direct screenshot export
                // User can use browser screenshot or OS tools
                if game.debug {
                    draw_text(
                        &format!("Screenshot frame reached: {}", path),
                        10.0,
                        240.0,
                        16.0,
                        RED,
                    );
                }
            }
        }

        game.frame_count += 1;

        if game.should_exit() {
            break;
        }
    }
}

/// Draw text centered horizontally
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
