/*
	Siriel Odin - Core Types
	Fundamental data structures
*/

package core

import "core:math"
import "core:testing"

// 2D Point
Point :: struct {
	x: int,
	y: int,
}

// Rectangle
Rect :: struct {
	x:      int,
	y:      int,
	width:  int,
	height: int,
}

// Tile data
Tile :: struct {
	index:  u16, // Tile index (0-65535)
	solid:  bool, // Collision flag
	usable: bool, // Usable (walkable)
}

// Animation state
Animation_State :: enum {
	Idle,
	Walking,
	Jumping,
	Falling,
}

// Direction enum
Direction :: enum {
	Right,
	Left,
}

// Object type
Object_Type :: enum {
	Player,
	Creature,
	Pickup,
	Teleporter,
	Trigger,
}

// Sprite frame
Frame :: struct {
	x:      int,
	y:      int,
	width:  int,
	height: int,
}

/*
	Helpers
*/

point_add :: proc(a: Point, b: Point) -> Point {
	return Point{a.x + b.x, a.y + b.y}
}

point_equal :: proc(a: Point, b: Point) -> bool {
	return a.x == b.x && a.y == b.y
}

rect_contains :: proc(r: Rect, p: Point) -> bool {
	return p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height
}

rect_overlap :: proc(a: Rect, b: Rect) -> bool {
	return(
		a.x < b.x + b.width &&
		a.x + a.width > b.x &&
		a.y < b.y + b.height &&
		a.y + a.height > b.y \
	)
}

/*
	Tests
*/
@(test)
test_point :: proc(t: ^testing.T) {
	p1 := Point{10, 20}
	assert(p1.x == 10)
	assert(p1.y == 20)

	p2 := point_add(p1, Point{5, 5})
	assert(p2.x == 15)
	assert(p2.y == 25)

	assert(point_equal(Point{1, 1}, Point{1, 1}))
	assert(!point_equal(Point{1, 1}, Point{2, 2}))
}

@(test)
test_rect :: proc(t: ^testing.T) {
	r := Rect{0, 0, 100, 100}

	assert(rect_contains(r, Point{50, 50}))
	assert(rect_contains(r, Point{0, 0}))
	assert(!rect_contains(r, Point{100, 100}))

	r2 := Rect{50, 50, 100, 100}
	assert(rect_overlap(r, r2))

	r3 := Rect{200, 200, 100, 100}
	assert(!rect_overlap(r, r3))
}

@(test)
test_tile :: proc(t: ^testing.T) {
	tile := Tile {
		index  = 42,
		solid  = true,
		usable = false,
	}
	assert(tile.index == 42)
	assert(tile.solid == true)
	assert(tile.usable == false)
}

@(test)
test_animation_state :: proc(t: ^testing.T) {
	state := Animation_State.Idle
	assert(state == Animation_State.Idle)

	state = Animation_State.Walking
	assert(state == Animation_State.Walking)
}
