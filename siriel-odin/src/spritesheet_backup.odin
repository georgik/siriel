/*
	Siriel Odin - Flexible Spritesheet System
	Supports both linear and grid layouts for sprite animations
*/

package spritesheet

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

/*
	Layout Types
*/

Layout_Mode :: enum {
	Linear,  // Frames 0-N in sequence (original Siriel)
	Grid,    // Rows × Columns grid
}

/*
	Loop Modes
*/

Loop_Mode :: enum {
	Once,
	Loop,
	PingPong,
}

/*
	Animation Definition
*/

Animation_Def :: struct {
	name: string,
	start_frame: int,
	frame_count: int,
	duration: f32,  // Seconds per frame
	loop_mode: Loop_Mode,
}

/*
	Spritesheet
*/

Spritesheet :: struct {
	name: string,
	texture: rl.Texture2D,
	tile_width: int,
	tile_height: int,
	layout: Layout_Mode,

	// Grid layout parameters
	grid_width: int,
	grid_height: int,

	// Linear layout parameters
	linear_frames: int,

	// Animations
	animations: map[string]Animation_Def,
}

/*
	Animation State
*/

Anim_State :: struct {
	current_anim: string,
	frame_index: int,
	timer: f32,
	playing: bool,
}

/*
	Load Spritesheet (Linear Layout)
*/

load_linear :: proc(name: string, image_path: string, tile_width: int, tile_height: int, frame_count: int) -> ^Spritesheet {
	sheet := new(Spritesheet)
	sheet.name = name
	sheet.tile_width = tile_width
	sheet.tile_height = tile_height
	sheet.layout = .Linear
	sheet.linear_frames = frame_count

	// Load texture
	full_path := "assets/" + image_path
	builder := strings.builder_make_none()
	strings.write_string(&builder, full_path)
	cstr := strings.clone_to_cstring(strings.to_string(builder))
	sheet.texture = rl.LoadTexture(cstr)
	strings.builder_destroy(&builder)

	if sheet.texture.id == 0 {
		fmt.printf("Failed to load texture: %s\n", full_path)
		return nil
	}

	fmt.printf("Loaded spritesheet: %s (%dx%d, %d linear frames)\n",
		name, sheet.texture.width, sheet.texture.height, frame_count)

	return sheet
}

/*
	Load Spritesheet (Grid Layout)
*/

load_grid :: proc(name: string, image_path: string, tile_width: int, tile_height: int, grid_width: int, grid_height: int) -> ^Spritesheet {
	sheet := new(Spritesheet)
	sheet.name = name
	sheet.tile_width = tile_width
	sheet.tile_height = tile_height
	sheet.layout = .Grid
	sheet.grid_width = grid_width
	sheet.grid_height = grid_height

	// Load texture
	full_path := "assets/" + image_path
	builder := strings.builder_make_none()
	strings.write_string(&builder, full_path)
	cstr := strings.clone_to_cstring(strings.to_string(builder))
	sheet.texture = rl.LoadTexture(cstr)
	strings.builder_destroy(&builder)

	if sheet.texture.id == 0 {
		fmt.printf("Failed to load texture: %s\n", full_path)
		return nil
	}

	fmt.printf("Loaded spritesheet: %s (%dx%d, %dx%d grid)\n",
		name, sheet.texture.width, sheet.texture.height, grid_width, grid_height)

	return sheet
}

/*
	Get Frame Rectangle
*/

get_frame_rect :: proc(sheet: ^Spritesheet, frame_index: int) -> rl.Rectangle {
	if sheet == nil do return rl.Rectangle{0, 0, 0, 0}

	switch sheet.layout {
	case .Linear:
		frames_per_row := sheet.texture.width / sheet.tile_width
		row := frame_index / frames_per_row
		col := frame_index % frames_per_row

		return rl.Rectangle {
			f32(col * sheet.tile_width),
			f32(row * sheet.tile_height),
			f32(sheet.tile_width),
			f32(sheet.tile_height),
		}

	case .Grid:
		row := frame_index / sheet.grid_width
		col := frame_index % sheet.grid_width

		return rl.Rectangle {
			f32(col * sheet.tile_width),
			f32(row * sheet.tile_height),
			f32(sheet.tile_width),
			f32(sheet.tile_height),
		}
	}

	return rl.Rectangle{0, 0, 0, 0}
}

/*
	Draw Frame
*/

draw_frame :: proc(sheet: ^Spritesheet, frame_index: int, x: i32, y: i32, tint: rl.Color) {
	if sheet == nil do return

	src := get_frame_rect(sheet, frame_index)
	dst := rl.Rectangle {
		f32(x),
		f32(y),
		f32(sheet.tile_width),
		f32(sheet.tile_height),
	}

	rl.DrawTexturePro(sheet.texture, src, dst, rl.Vector2{0, 0}, 0, tint)
}

/*
	Add Animation Definition
*/

add_animation :: proc(sheet: ^Spritesheet, def: Animation_Def) {
	if sheet == nil do return

	if sheet.animations == nil {
		sheet.animations = make(map[string]Animation_Def)
	}

	sheet.animations[def.name] = def
}

/*
	Create Animation State
*/

create_anim_state :: proc(anim_name: string) -> Anim_State {
	return Anim_State {
		current_anim = anim_name,
		frame_index = 0,
		timer = 0,
		playing = true,
	}
}

/*
	Update Animation
*/

update_anim :: proc(state: ^Anim_State, sheet: ^Spritesheet, delta_time: f32) {
	if !state.playing || sheet == nil do return

	def, ok := sheet.animations[state.current_anim]
	if !ok || def.frame_count == 0 do return

	state.timer += delta_time

	if state.timer >= def.duration {
		state.timer = 0

		switch def.loop_mode {
		case .Once:
			if state.frame_index < def.frame_count - 1 {
				state.frame_index += 1
			} else {
				state.playing = false
			}

		case .Loop:
			state.frame_index = (state.frame_index + 1) % def.frame_count

		case .PingPong:
			state.frame_index = (state.frame_index + 1) % def.frame_count
		}
	}
}

/*
	Set Animation
*/

set_anim :: proc(state: ^Anim_State, anim_name: string) {
	if state.current_anim != anim_name {
		state.current_anim = anim_name
		state.frame_index = 0
		state.timer = 0
		state.playing = true
	}
}

/*
	Get Current Frame
*/

get_current_frame :: proc(state: Anim_State, sheet: ^Spritesheet) -> int {
	if sheet == nil do return 0

	def, ok := sheet.animations[state.current_anim]
	if !ok || def.frame_count == 0 do return 0

	actual_frame := def.start_frame + state.frame_index

	return actual_frame
}

/*
	Setup Player Animations (Linear Layout from siriel-go)
*/

setup_player_animations :: proc(sheet: ^Spritesheet) {
	if sheet == nil do return

	// From siriel-go: 48 frames total (0-47)
	// 6 frames per animation state

	add_animation(sheet, Animation_Def {
		name = "idle_left",
		start_frame = 0,
		frame_count = 6,
		duration = 0.25,  // 4 FPS for idle
		loop_mode = .Loop,
	})

	add_animation(sheet, Animation_Def {
		name = "idle_right",
		start_frame = 6,
		frame_count = 6,
		duration = 0.25,
		loop_mode = .Loop,
	})

	add_animation(sheet, Animation_Def {
		name = "walk_left",
		start_frame = 12,
		frame_count = 6,
		duration = 0.1,  // 10 FPS for walk
		loop_mode = .Loop,
	})

	add_animation(sheet, Animation_Def {
		name = "walk_right",
		start_frame = 18,
		frame_count = 6,
		duration = 0.1,
		loop_mode = .Loop,
	})

	add_animation(sheet, Animation_Def {
		name = "jump_left",
		start_frame = 24,
		frame_count = 6,
		duration = 0.1,
		loop_mode = .Once,
	})

	add_animation(sheet, Animation_Def {
		name = "jump_right",
		start_frame = 30,
		frame_count = 6,
		duration = 0.1,
		loop_mode = .Once,
	})

	add_animation(sheet, Animation_Def {
		name = "fall_left",
		start_frame = 36,
		frame_count = 6,
		duration = 0.1,
		loop_mode = .Loop,
	})

	add_animation(sheet, Animation_Def {
		name = "fall_right",
		start_frame = 42,
		frame_count = 6,
		duration = 0.1,
		loop_mode = .Loop,
	})

	fmt.println("Player animations configured (8 animations, 48 frames)")
}

/*
	Unload Spritesheet
*/

unload :: proc(sheet: ^Spritesheet) {
	if sheet != nil && sheet.texture.id != 0 {
		rl.UnloadTexture(sheet.texture)
	}
}
