/*
	Siriel Odin - Collision Detection System
	Tile-based collision from original Siriel 3.5
*/

package collision

import "core:fmt"

import "../core"

/*
	Tile-based collision (8px tiles)
*/

is_solid_tile :: proc(tile: int) -> bool {
	// Tiles >= 24 are solid (platforms, walls)
	return tile >= 24
}

/*
	Get tile at position
*/

get_tile :: proc(tilemap: [][]int, x: int, y: int) -> int {
	if x < 0 || x >= core.MAP_WIDTH_TILES do return 0
	if y < 0 || y >= core.MAP_HEIGHT_TILES do return 0

	return tilemap[y][x]
}

/*
	Convert pixel to tile coordinates
*/

pixel_to_tile :: proc(pixel: int) -> int {
	return pixel / core.TILE_SIZE
}

/*
	Check tile collision at position
*/

check_tile :: proc(tilemap: [][]int, x: int, y: int) -> bool {
	tile_x := pixel_to_tile(x)
	tile_y := pixel_to_tile(y)
	tile := get_tile(tilemap, tile_x, tile_y)

	return is_solid_tile(tile)
}

/*
	Rectangle collision (for objects)
*/

Rect :: struct {
	x: int,
	y: int,
	width: int,
	height: int,
}

rect_intersect :: proc(a: Rect, b: Rect) -> bool {
	return a.x < b.x + b.width &&
	       a.x + a.width > b.x &&
	       a.y < b.y + b.height &&
	       a.y + a.height > b.y
}

/*
	Point collision
*/

point_in_rect :: proc(px: int, py: int, r: Rect) -> bool {
	return px >= r.x && px < r.x + r.width &&
	       py >= r.y && py < r.y + r.height
}

/*
	Player collision check (with ground)
*/

check_ground :: proc(tilemap: [][]int, x: int, y: int, width: int, height: int) -> bool {
	// Check bottom edge for ground
	feet_y := y + height
	tile_y := pixel_to_tile(feet_y)

	// Check tiles under player's feet
	for i in 0..<(width / core.TILE_SIZE) {
		tile_x := pixel_to_tile(x + i * core.TILE_SIZE)
		if check_tile(tilemap, tile_x * core.TILE_SIZE, tile_y * core.TILE_SIZE) {
			return true
		}
	}

	return false
}

/*
	Wall collision check
*/

check_wall_left :: proc(tilemap: [][]int, x: int, y: int, height: int) -> bool {
	// Check left edge
	tile_x := pixel_to_tile(x)
	tile_y_start := pixel_to_tile(y)
	tile_y_end := pixel_to_tile(y + height)

	for ty in tile_y_start..=tile_y_end {
		if check_tile(tilemap, tile_x * core.TILE_SIZE, ty * core.TILE_SIZE) {
			return true
		}
	}

	return false
}

check_wall_right :: proc(tilemap: [][]int, x: int, y: int, width: int, height: int) -> bool {
	// Check right edge
	right_x := x + width
	tile_x := pixel_to_tile(right_x - 1)
	tile_y_start := pixel_to_tile(y)
	tile_y_end := pixel_to_tile(y + height)

	for ty in tile_y_start..=tile_y_end {
		if check_tile(tilemap, tile_x * core.TILE_SIZE, ty * core.TILE_SIZE) {
			return true
		}
	}

	return false
}

/*
	Ceiling collision
*/

check_ceiling :: proc(tilemap: [][]int, x: int, y: int, width: int) -> bool {
	// Check top edge
	tile_y := pixel_to_tile(y)
	tile_x_start := pixel_to_tile(x)
	tile_x_end := pixel_to_tile(x + width)

	for tx in tile_x_start..=tile_x_end {
		if check_tile(tilemap, tx * core.TILE_SIZE, tile_y * core.TILE_SIZE) {
			return true
		}
	}

	return false
}
