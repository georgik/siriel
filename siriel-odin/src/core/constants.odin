/*
	Siriel Odin - Core Constants
	Game-wide constant values
*/

package core

import "core:testing"

// Display (original Siriel 3.5 resolution)
SCREEN_WIDTH :: 640
SCREEN_HEIGHT :: 480

// Tile system (CRITICAL: 8px tiles, NOT 16px)
// Map dimensions from original: mie_x = 38, mie_y = 26
TILE_SIZE :: 8

// Actual map size in tiles (from original Pascal: mie_x, mie_y)
MAP_WIDTH_TILES :: 38
MAP_HEIGHT_TILES :: 26

// Game area in pixels
GAME_AREA_WIDTH :: MAP_WIDTH_TILES * TILE_SIZE  // 38 * 8 = 304
GAME_AREA_HEIGHT :: MAP_HEIGHT_TILES * TILE_SIZE // 26 * 8 = 208

// Legacy computed values (DO NOT USE - kept for compatibility)
TILES_W :: SCREEN_WIDTH / TILE_SIZE // 80 (not actual map size)
TILES_H :: SCREEN_HEIGHT / TILE_SIZE // 60 (not actual map size)

// Movement
MOVE_STEP :: 8 // 8px per step (half tile)

// Timing
TARGET_FPS :: 20
FRAME_TIME_MS :: 1000 / TARGET_FPS // 50ms

// Physics
GRAVITY :: 1 // Gravity per frame
JUMP_FORCE :: 8 // Jump velocity
TERMINAL_VELOCITY :: 16

// Animation
ANIMATION_SPEED :: 5 // Frames per animation state
MAX_ANIMATION :: 8 // Max animation index

// Assets
ASSET_PATH :: "assets/"
SPRITE_SCALE :: 1

// Collision
COLLISION_MARGIN :: 2

// Direction
DIR_RIGHT :: 0
DIR_LEFT :: 1

/*
	Tests
*/
@(test)
test_constants :: proc(t: ^testing.T) {
	assert(SCREEN_WIDTH == 640)
	assert(SCREEN_HEIGHT == 480)
	assert(TILE_SIZE == 8)  // CRITICAL: 8px tiles, not 16px
	assert(MAP_WIDTH_TILES == 38)  // From original: mie_x
	assert(MAP_HEIGHT_TILES == 26) // From original: mie_y
	assert(MOVE_STEP == 8)
	assert(TARGET_FPS == 20)
	assert(ASSET_PATH == "assets/")
}
