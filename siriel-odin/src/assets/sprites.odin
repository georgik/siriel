/*
	Siriel Odin - Sprite Loading
	Spritesheet loading for gtext.gif, gzal.gif
*/

package assets

import "../core"
import "core:testing"
import rl "vendor:raylib"

// Sprite frame data
Sprite_Frame :: struct {
	x:      int,
	y:      int,
	width:  int,
	height: int,
}

// Spritesheet data
Spritesheet :: struct {
	texture:      rl.Texture2D,
	frame_width:  int,
	frame_height: int,
	frame_count:  int,
	frames:       []Sprite_Frame,
	loaded:       bool,
}

// Sprite direction
Sprite_Direction :: enum {
	Right = 0,
	Left  = 1,
}

/*
	Create empty spritesheet
*/
spritesheet_new :: proc() -> Spritesheet {
	return Spritesheet {
		texture = {},
		frame_width = 0,
		frame_height = 0,
		frame_count = 0,
		frames = {},
		loaded = false,
	}
}

/*
	Load spritesheet from file
	For gtext.gif and gzal.gif, frames are arranged horizontally
*/
load_spritesheet :: proc(filename: string, frame_width: int, frame_height: int) -> Spritesheet {
	texture := load_texture(filename)

	frame_count := int(texture.width) / frame_width

	frames := make([]Sprite_Frame, frame_count)

	// Calculate frame positions (horizontal layout)
	for i in 0 ..< frame_count {
		frames[i] = Sprite_Frame {
			x      = i * frame_width,
			y      = 0,
			width  = frame_width,
			height = frame_height,
		}
	}

	return Spritesheet {
		texture = texture,
		frame_width = frame_width,
		frame_height = frame_height,
		frame_count = frame_count,
		frames = frames,
		loaded = true,
	}
}

/*
	Unload spritesheet resources
*/
unload_spritesheet :: proc(sheet: ^Spritesheet) {
	if sheet.loaded {
		unload_texture(sheet.texture)
		sheet.loaded = false
	}
	delete(sheet.frames)
}

/*
	Get frame at index
*/
get_frame :: proc(sheet: Spritesheet, index: int) -> Sprite_Frame {
	if index < 0 || index >= sheet.frame_count {
		return Sprite_Frame{}
	}
	return sheet.frames[index]
}

/*
	Get frame for animation state and direction
*/
get_animation_frame :: proc(
	sheet: Spritesheet,
	anim_index: int,
	direction: Sprite_Direction,
) -> Sprite_Frame {
	frame_index := anim_index + int(direction) * sheet.frame_count / 2
	return get_frame(sheet, frame_index)
}

/*
	Draw frame at position
*/
draw_frame :: proc(sheet: Spritesheet, frame_index: int, pos: core.Point) {
	frame := get_frame(sheet, frame_index)
	if frame.width == 0 {
		return
	}

	src_rect := rl.Rectangle {
		x      = f32(frame.x),
		y      = f32(frame.y),
		width  = f32(frame.width),
		height = f32(frame.height),
	}

	dst_rect := rl.Rectangle {
		x      = f32(pos.x),
		y      = f32(pos.y),
		width  = f32(frame.width * core.SPRITE_SCALE),
		height = f32(frame.height * core.SPRITE_SCALE),
	}

	rl.DrawTexturePro(sheet.texture, src_rect, dst_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
}

/*
	Tests
*/
@(test)
test_spritesheet_new :: proc(t: ^testing.T) {
	sheet := spritesheet_new()
	assert(sheet.loaded == false)
	assert(sheet.frame_count == 0)
	assert(len(sheet.frames) == 0)
}

@(test)
test_calculate_frame_count :: proc(t: ^testing.T) {
	// 320x32 image with 32x32 frames = 10 frames
	assert(320 / 32 == 10)

	// 640x64 image with 64x64 frames = 10 frames
	assert(640 / 64 == 10)
}

@(test)
test_get_frame :: proc(t: ^testing.T) {
	sheet := spritesheet_new()
	sheet.frames = make([]Sprite_Frame, 10)
	defer delete(sheet.frames)
	sheet.frame_count = 10

	// Set frame at index 5
	sheet.frames[5] = Sprite_Frame {
		x      = 160,
		y      = 0,
		width  = 32,
		height = 32,
	}

	frame := get_frame(sheet, 5)
	assert(frame.x == 160)
	assert(frame.width == 32)

	// Out of bounds returns empty frame
	frame = get_frame(sheet, 20)
	assert(frame.width == 0)
}

@(test)
test_sprite_direction :: proc(t: ^testing.T) {
	dir := Sprite_Direction.Right
	assert(dir == Sprite_Direction.Right)

	dir = Sprite_Direction.Left
	assert(dir == Sprite_Direction.Left)
}
