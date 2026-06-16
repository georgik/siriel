/*
	Siriel Odin - Main Game Loop
	Phase 4: Engine Implementation with HUD

	Raylib 5.5/macOS bug: fmt.println crashes after InitWindow()
	All prints must be before window init or use Raylib text only
*/

package main

import "core"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:time"
import rl "vendor:raylib"

import "player"
import "test_level"
import "level"
import "tilemap"

DEFAULT_LIVES :: 3

// Spritesheet System
Sprite_Layout_Mode :: enum { Linear, Grid }
Sprite_Loop_Mode :: enum { Once, Loop, PingPong }

Sprite_Animation_Def :: struct {
	name: string,
	start_frame: int,
	frame_count: int,
	duration: f32,
	loop_mode: Sprite_Loop_Mode,
}

Sprite_Spritesheet :: struct {
	name: string,
	texture: rl.Texture2D,
	tile_width: int,
	tile_height: int,
	layout: Sprite_Layout_Mode,
	grid_width: int,
	grid_height: int,
	linear_frames: int,
	animations: map[string]Sprite_Animation_Def,
}

Sprite_Anim_State :: struct {
	current_anim: string,
	frame_index: int,
	timer: f32,
	playing: bool,
}

// Global state
player_spritesheet: ^Sprite_Spritesheet
player_anim: Sprite_Anim_State
player_physics: player.Physics_State
current_tilemap: [26][42]int
map_tilesheet: tilemap.Tilesheet

// Game state
Game_State :: struct {
	running: bool,
	frame_count: i32,
	timeout: i32,
	debug: bool,
	last_time: time.Time,
	delta_time: f32,
	screenshot_path: string,
	screenshot_at: i32,
}

game: Game_State

// HUD state
HUD_State :: struct {
	score: int,
	lives: int,
	timer: int,
}

hud_state: HUD_State

// CLI args
Args :: struct {
	timeout:       int,
	debug:         bool,
	level:         string,
	screenshot:    string,  // Save screenshot path
	screenshot_at: int,     // Frame to take screenshot (default: same as timeout)
}

parse_args :: proc() -> Args {
	args := Args{timeout = 0, debug = false, level = "test", screenshot = "", screenshot_at = 0}
	raw_args := os.args
	i := 1
	for i < len(raw_args) {
		arg := strings.clone(raw_args[i])
		if arg == "--timeout" || arg == "-t" {
			if i + 1 < len(raw_args) {
				val, ok := strconv.parse_int(raw_args[i + 1])
				if ok { args.timeout = val }
				i += 1
			}
		} else if arg == "--debug" || arg == "-d" {
			args.debug = true
		} else if arg == "--level" || arg == "-l" {
			if i + 1 < len(raw_args) {
				args.level = raw_args[i + 1]
				i += 1
			}
		} else if arg == "--screenshot" || arg == "-s" {
			if i + 1 < len(raw_args) {
				args.screenshot = raw_args[i + 1]
				i += 1
			}
		} else if arg == "--screenshot-at" || arg == "-sa" {
			if i + 1 < len(raw_args) {
				val, ok := strconv.parse_int(raw_args[i + 1])
				if ok { args.screenshot_at = val }
				i += 1
			}
		} else if arg == "--help" || arg == "-h" {
			fmt.println("Siriel Odin - Phase 4")
			fmt.println("Usage: siriel [options]")
			fmt.println("  -t, --timeout N          Auto-exit after N frames")
			fmt.println("  -d, --debug              Enable debug output")
			fmt.println("  -l, --level NAME         Load specific level (default: test)")
			fmt.println("  -s, --screenshot PATH    Save screenshot to path")
			fmt.println("  -sa, --screenshot-at N   Frame to capture (default: timeout value)")
			os.exit(0)
		}
		delete(arg)
		i += 1
	}
	// Default screenshot_at to timeout if not set
	if args.screenshot != "" && args.screenshot_at == 0 {
		args.screenshot_at = args.timeout
	}
	return args
}

// Spritesheet functions
sprite_load_grid :: proc(name: string, image_path: string, tile_width: int, tile_height: int, grid_width: int, grid_height: int) -> ^Sprite_Spritesheet {
	sheet := new(Sprite_Spritesheet)
	sheet.name = name
	sheet.tile_width = tile_width
	sheet.tile_height = tile_height
	sheet.layout = .Grid
	sheet.grid_width = grid_width
	sheet.grid_height = grid_height

	builder := strings.builder_make_none()
	strings.write_string(&builder, "assets/")
	strings.write_string(&builder, image_path)
	full_path := strings.to_string(builder)
	cstr := strings.clone_to_cstring(full_path)
	sheet.texture = rl.LoadTexture(cstr)
	strings.builder_destroy(&builder)

	if sheet.texture.id == 0 {
		return nil
	}

	return sheet
}

sprite_get_frame_rect :: proc(sheet: ^Sprite_Spritesheet, frame_index: int) -> rl.Rectangle {
	if sheet == nil do return rl.Rectangle{0, 0, 0, 0}
	row := frame_index / sheet.grid_width
	col := frame_index % sheet.grid_width
	return rl.Rectangle {
		f32(col * sheet.tile_width),
		f32(row * sheet.tile_height),
		f32(sheet.tile_width),
		f32(sheet.tile_height),
	}
}

sprite_draw_frame :: proc(sheet: ^Sprite_Spritesheet, frame_index: int, x: i32, y: i32, tint: rl.Color) {
	if sheet == nil do return
	src := sprite_get_frame_rect(sheet, frame_index)
	dst := rl.Rectangle{f32(x), f32(y), f32(sheet.tile_width), f32(sheet.tile_height)}
	rl.DrawTexturePro(sheet.texture, src, dst, rl.Vector2{0, 0}, 0, tint)
}

sprite_add_animation :: proc(sheet: ^Sprite_Spritesheet, def: Sprite_Animation_Def) {
	if sheet == nil do return
	if sheet.animations == nil {
		sheet.animations = make(map[string]Sprite_Animation_Def)
	}
	sheet.animations[def.name] = def
}

sprite_create_anim_state :: proc(anim_name: string) -> Sprite_Anim_State {
	return Sprite_Anim_State{current_anim = anim_name, frame_index = 0, timer = 0, playing = true}
}

sprite_update_anim :: proc(state: ^Sprite_Anim_State, sheet: ^Sprite_Spritesheet, delta_time: f32) {
	if !state.playing || sheet == nil do return
	def, ok := sheet.animations[state.current_anim]
	if !ok || def.frame_count == 0 do return

	state.timer += delta_time
	if state.timer >= def.duration {
		state.timer = 0
		switch def.loop_mode {
		case .Once:
			if state.frame_index < def.frame_count - 1 { state.frame_index += 1 }
			else { state.playing = false }
		case .Loop:
			state.frame_index = (state.frame_index + 1) % def.frame_count
		case .PingPong:
			state.frame_index = (state.frame_index + 1) % def.frame_count
		}
	}
}

sprite_set_anim :: proc(state: ^Sprite_Anim_State, anim_name: string) {
	if state.current_anim != anim_name {
		state.current_anim = anim_name
		state.frame_index = 0
		state.timer = 0
		state.playing = true
	}
}

sprite_get_current_frame :: proc(state: Sprite_Anim_State, sheet: ^Sprite_Spritesheet) -> int {
	if sheet == nil do return 0
	def, ok := sheet.animations[state.current_anim]
	if !ok || def.frame_count == 0 do return 0
	return def.start_frame + state.frame_index
}

sprite_setup_player_animations :: proc(sheet: ^Sprite_Spritesheet) {
	if sheet == nil do return
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "idle_down", start_frame = 0, frame_count = 4, duration = 0.25, loop_mode = .Loop})
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "left", start_frame = 4, frame_count = 4, duration = 0.1, loop_mode = .Loop})
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "right", start_frame = 8, frame_count = 4, duration = 0.1, loop_mode = .Loop})
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "jump_up", start_frame = 12, frame_count = 8, duration = 0.1, loop_mode = .Once})
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "parachute", start_frame = 20, frame_count = 3, duration = 0.15, loop_mode = .Loop})
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "jump_left_up", start_frame = 23, frame_count = 8, duration = 0.1, loop_mode = .Once})
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "up", start_frame = 31, frame_count = 4, duration = 0.1, loop_mode = .Loop})
	sprite_add_animation(sheet, Sprite_Animation_Def{name = "jump_right", start_frame = 35, frame_count = 8, duration = 0.1, loop_mode = .Once})
}

// HUD
init_hud :: proc() {
	hud_state.score = 0
	hud_state.lives = DEFAULT_LIVES
	hud_state.timer = 0
}

draw_hud :: proc() {
	score_text: cstring = "SCORE: 0"
	rl.DrawText(score_text, 10, core.SCREEN_HEIGHT - 30, 20, rl.BLACK)

	lives_text: cstring = "LIVES: 3"
	text_width := rl.MeasureText(lives_text, 20)
	rl.DrawText(lives_text, core.SCREEN_WIDTH - text_width - 10, core.SCREEN_HEIGHT - 30, 20, rl.RED)
}

// Game initialization
init_game :: proc(args: Args) {
	init_hud()

	// Load map tilesheet
	map_tilesheet = tilemap.load_tilesheet()  // Uses default texture-basic.png

	player_spritesheet = sprite_load_grid("avatar-animation", "sprites/siriel-avatar.png", 16, 16, 14, 4)
	if player_spritesheet != nil {
		sprite_setup_player_animations(player_spritesheet)
		player_anim = sprite_create_anim_state("idle_down")
	}

	player_physics = player.create_physics(88, 88)

	// Load level - check if level param is a file
	level_path := args.level
	if strings.contains(level_path, ".odin") || strings.contains(level_path, "/") {
		// Try to load as file
		loaded_level, ok := level.load_level_file(level_path)
		if ok {
			// Use loaded level's tilemap
			for y in 0..<26 {
				for x in 0..<42 {
					if x < level.MAP_WIDTH && y < level.MAP_HEIGHT {
						current_tilemap[y][x] = loaded_level.tilemap.tiles[y][x]
					}
				}
			}
			// Set player position from level
			if loaded_level.start_position.x != 0 || loaded_level.start_position.y != 0 {
				player_physics = player.create_physics(loaded_level.start_position.x, loaded_level.start_position.y)
			}
		} else {
			// Fallback to test level
			current_tilemap = test_level.get_test_tilemap()
		}
	} else {
		// Use built-in test level
		current_tilemap = test_level.get_test_tilemap()
	}

	game.running = true
	game.frame_count = 0
	game.timeout = i32(args.timeout)
	game.debug = args.debug
	game.screenshot_path = args.screenshot
	game.screenshot_at = i32(args.screenshot_at)
	game.last_time = time.now()
	game.delta_time = 0
}

// Input
handle_input :: proc() {
	if rl.IsKeyDown(rl.KeyboardKey.ESCAPE) {
		game.running = false
	}
}

// Update
update :: proc() {
	game.frame_count += 1
	game.delta_time = 1.0 / f32(core.TARGET_FPS)

	input := player.get_input()

	tilemap_slice := make([][]int, 26)
	for i in 0..<26 {
		tilemap_slice[i] = make([]int, 42)
		for j in 0..<42 {
			tilemap_slice[i][j] = current_tilemap[i][j]
		}
	}

	player.update_physics(&player_physics, input, tilemap_slice)
	player_anim_name := player.get_animation_physics(player_physics)
	sprite_set_anim(&player_anim, player_anim_name)

	if game.timeout > 0 && game.frame_count >= game.timeout {
		game.running = false
	}
}

// Render
render :: proc() {
	rl.BeginDrawing()

	rl.ClearBackground(rl.RAYWHITE)

	game_area_x := (core.SCREEN_WIDTH - core.GAME_AREA_WIDTH) / 2
	game_area_y := (core.SCREEN_HEIGHT - core.GAME_AREA_HEIGHT) / 2 + 20

	rl.DrawRectangle(i32(game_area_x), i32(game_area_y), core.GAME_AREA_WIDTH, core.GAME_AREA_HEIGHT, rl.DARKGRAY)
	rl.DrawRectangleLines(i32(game_area_x), i32(game_area_y), core.GAME_AREA_WIDTH, core.GAME_AREA_HEIGHT, rl.BLACK)

	player_x, player_y := player.get_position_physics(player_physics)

	// Draw tilemap (before player so player appears on top)
	tilemap.draw_tilemap(map_tilesheet, current_tilemap[:], i32(game_area_x), i32(game_area_y))

	if player_spritesheet != nil {
		sprite_update_anim(&player_anim, player_spritesheet, game.delta_time)
		frame := sprite_get_current_frame(player_anim, player_spritesheet)
		sprite_draw_frame(player_spritesheet, frame, i32(player_x), i32(player_y), rl.WHITE)
	} else {
		rl.DrawRectangle(i32(player_x), i32(player_y), 16, 16, rl.RED)
	}

	draw_hud()
	rl.DrawText("SIRIEL ODIN - PHASE 4", 10, 10, 20, rl.DARKGRAY)

	rl.EndDrawing()

	// Save screenshot if requested and at screenshot frame (after buffer swap)
	if game.screenshot_path != "" && game.frame_count >= game.screenshot_at {
		img := rl.LoadImageFromScreen()
		cstr := strings.clone_to_cstring(game.screenshot_path)
		rl.ExportImage(img, cstr)
		rl.UnloadImage(img)
		delete(cstr)
		game.screenshot_path = ""  // Clear to avoid duplicate saves
	}
}

// Main entry - ALL PRINTS BEFORE WINDOW INIT
main :: proc() {
	args := parse_args()

	if args.timeout > 0 {
		fmt.printf("Timeout set: %d frames\n", args.timeout)
	}

	fmt.println("Initializing Siriel Odin Phase 4...")
	fmt.println("Loading spritesheet...")
	fmt.println("Loading player physics...")
	fmt.printf("Loading level: %s\n", args.level)
	fmt.println("Starting game loop...")

	rl.InitWindow(core.SCREEN_WIDTH, core.SCREEN_HEIGHT, "Siriel Odin - Phase 4")
	defer rl.CloseWindow()

	rl.SetTargetFPS(core.TARGET_FPS)

	// Initialize game (no more prints after here)
	init_game(args)

	for !rl.WindowShouldClose() && game.running {
		handle_input()
		update()
		render()
	}
}
