/*
	Siriel Odin - Tilemap Renderer
	Renders map tiles from spritesheet
*/

package tilemap

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"
import "../assets"

/*
	Tilemap Constants
*/

TILE_SIZE :: 8  // Map uses 8px tiles
TILESET_WIDTH :: assets.TILE_SIZE  // Spritesheet tiles are 16px
TILESET_HEIGHT :: assets.TILE_SIZE

// Default spritesheet
DEFAULT_TILESET :: "texture-basic.png"

/*
	Tilesheet structure
*/

Tilesheet :: struct {
	texture: rl.Texture2D,
	tile_width: int,
	tile_height: int,
	columns: int,
	rows: int,
	tile_count: int,
}

/*
	Load tilesheet from PNG file
*/

load_tilesheet :: proc(file_path: string = DEFAULT_TILESET) -> Tilesheet {
	sheet := Tilesheet{}

	// Build full path
	builder := strings.builder_make_none()
	strings.write_string(&builder, "assets/sprites/")
	strings.write_string(&builder, file_path)
	full_path := strings.to_string(builder)
	cstr := strings.clone_to_cstring(full_path)

	// Load texture
	sheet.texture = rl.LoadTexture(cstr)
	strings.builder_destroy(&builder)

	if sheet.texture.id == 0 {
		fmt.printf("Failed to load tilesheet: %s\n", file_path)
		return sheet
	}

	sheet.tile_width = TILESET_WIDTH
	sheet.tile_height = TILESET_HEIGHT

	// Calculate grid dimensions
	sheet.columns = int(sheet.texture.width) / sheet.tile_width
	sheet.rows = int(sheet.texture.height) / sheet.tile_height
	sheet.tile_count = sheet.columns * sheet.rows

	fmt.printf("Loaded tilesheet: %s (%dx%d, %dx%d grid = %d tiles)\n",
		file_path, sheet.texture.width, sheet.texture.height,
		sheet.columns, sheet.rows, sheet.tile_count)

	return sheet
}

/*
	Get source rectangle for tile index
*/

get_tile_rect :: proc(sheet: Tilesheet, tile_index: int) -> rl.Rectangle {
	if sheet.texture.id == 0 do return rl.Rectangle{0, 0, 0, 0}

	// Check bounds
	if tile_index < 0 || tile_index >= sheet.tile_count {
		// Return empty rect for invalid tile
		return rl.Rectangle{0, 0, 0, 0}
	}

	col := tile_index % sheet.columns
	row := tile_index / sheet.columns

	return rl.Rectangle {
		f32(col * sheet.tile_width),
		f32(row * sheet.tile_height),
		f32(sheet.tile_width),
		f32(sheet.tile_height),
	}
}

/*
	Draw single tile at screen position
*/

draw_tile :: proc(sheet: Tilesheet, tile_index: int, x: i32, y: i32, tint: rl.Color) {
	if sheet.texture.id == 0 do return

	src := get_tile_rect(sheet, tile_index)
	if src.width == 0 do return  // Invalid tile

	// Destination: scale down from 16px to 8px
	dst := rl.Rectangle {
		f32(x),
		f32(y),
		f32(TILE_SIZE),
		f32(TILE_SIZE),
	}

	// Debug: Draw rectangle to verify position
	rl.DrawRectangle(x, y, TILE_SIZE, TILE_SIZE, rl.GREEN)

	// Try simpler draw call
	rl.DrawTextureRec(sheet.texture, src, rl.Vector2{f32(x), f32(y)}, tint)
}

/*
	Draw placeholder for missing tiles
*/

draw_missing_tile :: proc(x: i32, y: i32) {
	rl.DrawRectangle(x, y, TILE_SIZE, TILE_SIZE, rl.PURPLE)
	rl.DrawRectangleLines(x, y, TILE_SIZE, TILE_SIZE, rl.WHITE)
}

/*
	Draw tilemap layer
*/

draw_tilemap :: proc(
	sheet: Tilesheet,
	tilemap: [][42]int,
	offset_x: i32,
	offset_y: i32,
) {
	if sheet.texture.id == 0 do return

	height := len(tilemap)
	if height == 0 do return

	tiles_drawn := 0

	for y in 0..<height {
		for x in 0..<42 {
			tile := tilemap[y][x]

			// Skip empty tiles (0 is usually empty)
			if tile == 0 do continue

			screen_x := offset_x + i32(x) * TILE_SIZE
			screen_y := offset_y + i32(y) * TILE_SIZE

			// Check if tile is available in spritesheet
			if tile >= sheet.tile_count {
				// Draw placeholder for missing tiles
				draw_missing_tile(screen_x, screen_y)
			} else {
				draw_tile(sheet, tile, screen_x, screen_y, rl.WHITE)
			}
		}
	}

	// Debug: Large red rectangle if tiles were drawn
	if tiles_drawn > 0 {
		rl.DrawRectangle(100, 100, 50, 50, rl.RED)
	}
}

/*
	Unload tilesheet
*/

unload_tilesheet :: proc(sheet: Tilesheet) {
	if sheet.texture.id != 0 {
		rl.UnloadTexture(sheet.texture)
	}
}
