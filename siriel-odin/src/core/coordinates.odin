/*
	Siriel Odin - Coordinate Utilities
	Pixel ↔ Tile conversion helpers
*/

package core

import "core:testing"

// Use package constants (same package)

/*
	Convert pixel coordinates to tile coordinates
*/
pixel_to_tile :: proc(pixel: int) -> int {
	return pixel / TILE_SIZE
}

/*
	Convert tile coordinates to pixel coordinates
*/
tile_to_pixel :: proc(tile: int) -> int {
	return tile * TILE_SIZE
}

/*
	Check if point is on tile boundary
*/
on_tile_boundary :: proc(pixel: int) -> bool {
	return pixel % TILE_SIZE == 0
}

/*
	Snap pixel to nearest tile boundary
*/
snap_to_tile :: proc(pixel: int) -> int {
	return (pixel / TILE_SIZE) * TILE_SIZE
}

/*
	Get tile index from Point
*/
point_to_tile_index :: proc(p: Point) -> int {
	return (p.y / TILE_SIZE) * TILES_W + (p.x / TILE_SIZE)
}

/*
	Convert tile index to Point
*/
tile_index_to_point :: proc(index: int) -> Point {
	tile_x := index % TILES_W
	tile_y := index / TILES_W
	return Point{x = tile_x * TILE_SIZE, y = tile_y * TILE_SIZE}
}

/*
	Align point to grid
*/
align_point :: proc(p: Point) -> Point {
	return Point{x = snap_to_tile(p.x), y = snap_to_tile(p.y)}
}

/*
	Tests
*/
@(test)
test_pixel_to_tile :: proc(t: ^testing.T) {
	assert(pixel_to_tile(0) == 0)
	assert(pixel_to_tile(7) == 0)
	assert(pixel_to_tile(8) == 1)
	assert(pixel_to_tile(15) == 1)
	assert(pixel_to_tile(16) == 2)
}

@(test)
test_tile_to_pixel :: proc(t: ^testing.T) {
	assert(tile_to_pixel(0) == 0)
	assert(tile_to_pixel(1) == 8)
	assert(tile_to_pixel(2) == 16)
	assert(tile_to_pixel(10) == 80)
}

@(test)
test_on_tile_boundary :: proc(t: ^testing.T) {
	assert(on_tile_boundary(0) == true)
	assert(on_tile_boundary(8) == true)
	assert(on_tile_boundary(16) == true)
	assert(on_tile_boundary(4) == false)
	assert(on_tile_boundary(12) == false)
}

@(test)
test_snap_to_tile :: proc(t: ^testing.T) {
	assert(snap_to_tile(0) == 0)
	assert(snap_to_tile(7) == 0)
	assert(snap_to_tile(8) == 8)
	assert(snap_to_tile(15) == 8)
	assert(snap_to_tile(16) == 16)
}

@(test)
test_point_to_tile_index :: proc(t: ^testing.T) {
	// Origin (0,0) → tile 0
	assert(point_to_tile_index(Point{0, 0}) == 0)

	// First row
	assert(point_to_tile_index(Point{8, 0}) == 1)
	assert(point_to_tile_index(Point{16, 0}) == 2)

	// Second row (80 tiles per row with TILES_W, but actual map is 38)
	assert(point_to_tile_index(Point{0, 8}) == 80)
	assert(point_to_tile_index(Point{8, 8}) == 81)
}

@(test)
test_tile_index_to_point :: proc(t: ^testing.T) {
	// Tile 0 → (0,0)
	p := tile_index_to_point(0)
	assert(p.x == 0 && p.y == 0)

	// Tile 1 → (8,0)
	p = tile_index_to_point(1)
	assert(p.x == 8 && p.y == 0)

	// Tile 80 → (0,8) - start of second row
	p = tile_index_to_point(80)
	assert(p.x == 0 && p.y == 8)
}

@(test)
test_align_point :: proc(t: ^testing.T) {
	// Already aligned
	p := Point{8, 16}
	result := align_point(p)
	assert(result.x == 8 && result.y == 16)

	// Needs alignment
	p = Point{10, 18}
	result = align_point(p)
	assert(result.x == 8 && result.y == 16)
}
