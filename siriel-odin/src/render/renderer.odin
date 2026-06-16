/*
	Siriel Odin - Rendering
	Tilemap and sprite rendering utilities
*/

package render

import "../assets"
import "../core"
import "core:mem"
import "core:testing"
import "core:c"
import rl "vendor:raylib"

/*
	Clear screen with background color
*/
clear_screen :: proc(color: rl.Color) {
	rl.ClearBackground(color)
}

/*
	Draw tile at position
*/
draw_tile :: proc(tilemap: assets.Tilemap, tile_index: int, pos: core.Point) {
	if !tilemap.loaded {
		return
	}

	if tile_index < 0 || tile_index >= tilemap.tile_count {
		return
	}

	// Calculate frame position from tile index
	tile_w := core.TILE_SIZE
	tile_h := core.TILE_SIZE
	tiles_per_row := int(tilemap.texture.width) / tile_w

	frame_x := (tile_index % tiles_per_row) * tile_w
	frame_y := (tile_index / tiles_per_row) * tile_h

	src_rect := rl.Rectangle{
		x = f32(frame_x),
		y = f32(frame_y),
		width = f32(tile_w),
		height = f32(tile_h),
	}

	dst_rect := rl.Rectangle{
		x = f32(pos.x),
		y = f32(pos.y),
		width = f32(tile_w),
		height = f32(tile_h),
	}

	rl.DrawTexturePro(tilemap.texture, src_rect, dst_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
}

/*
	Draw sprite frame at position
*/
draw_sprite :: proc(sheet: assets.Spritesheet, frame_index: int, pos: core.Point) {
	if !sheet.loaded {
		return
	}

	frame := assets.get_frame(sheet, frame_index)
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
	Draw filled rectangle
*/
draw_rect :: proc(rect: core.Rect, color: rl.Color) {
	rl.DrawRectangle(i32(rect.x), i32(rect.y), i32(rect.width), i32(rect.height), color)
}

/*
	Draw text at position
*/
draw_text :: proc(text: string, pos: core.Point, size: int, color: rl.Color) {
	// Convert to cstring for Raylib
	cstr := make([]u8, len(text) + 1)
	defer delete(cstr)
	mem.copy(raw_data(cstr), raw_data(text), len(text))
	cstr[len(text)] = 0

	rl.DrawText(cast(cstring) &cstr[0], i32(pos.x), i32(pos.y), i32(size), color)
}

/*
	Draw text centered
*/
draw_text_centered :: proc(text: string, rect: core.Rect, size: int, color: rl.Color) {
	cstr := make([]u8, len(text) + 1)
	defer delete(cstr)
	mem.copy(raw_data(cstr), raw_data(text), len(text))
	cstr[len(text)] = 0

	text_width := rl.MeasureText(cast(cstring) &cstr[0], i32(size))
	text_height := size

	x := rect.x + (rect.width - int(text_width)) / 2
	y := rect.y + (rect.height - text_height) / 2

	rl.DrawText(cast(cstring) &cstr[0], i32(x), i32(y), i32(size), color)
}

/*
	Begin frame rendering
*/
begin_frame :: proc() {
	rl.BeginDrawing()
}

/*
	End frame rendering
*/
end_frame :: proc() {
	rl.EndDrawing()
}

/*
	Get screen dimensions
*/
get_screen_size :: proc() -> (int, int) {
	return core.SCREEN_WIDTH, core.SCREEN_HEIGHT
}

/*
	Tests
*/
@(test)
test_clear_screen_stub :: proc(t: ^testing.T) {
	// Stub test - cannot render without window
	assert(true)
}

@(test)
test_draw_rect_stub :: proc(t: ^testing.T) {
	// Stub test - cannot render without window
	rect := core.Rect {
		x      = 10,
		y      = 10,
		width  = 100,
		height = 100,
	}
	assert(rect.x == 10)
	assert(rect.width == 100)
}

@(test)
test_screen_size :: proc(t: ^testing.T) {
	w, h := get_screen_size()
	assert(w == core.SCREEN_WIDTH)
	assert(h == core.SCREEN_HEIGHT)
}
