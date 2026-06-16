/*
	Siriel Odin - Spritesheet Descriptor
	texture-basic.png: 304x64 pixels, 19x4 tiles (16x16 each)
	Linear tile indexing: 0-based sequential indices from left to right, top to bottom
*/

package assets

TEXTURE_BASIC_WIDTH :: 304
TEXTURE_BASIC_HEIGHT :: 64
TILE_SIZE :: 16

// Grid dimensions
GRID_COLUMNS :: 19
GRID_ROWS :: 4
TOTAL_TILES :: GRID_COLUMNS * GRID_ROWS  // 76 tiles

// Row indices for reference
ROW_0 :: 0   // indices 0-18
ROW_1 :: 19  // indices 19-37
ROW_2 :: 38  // indices 38-56
ROW_3 :: 57  // indices 57-75

// Named tile constants (0-based indexing)
Tile_ID :: enum {
	EMPTY       = 0,   // First tile (top-left)
	WALL_CORNER = 25,  // Common solid tile
	WALL_TOP    = 26,  // Wall segment
	WALL_SIDE   = 27,  // Wall segment
	WALL_BOTTOM = 28,  // Wall segment
	PLATFORM    = 29,  // Platform tile
	GROUND      = 30,  // Ground tile
	SPECIAL     = 31,  // Special/door tile
}

/*
	Get source rectangle for tile index from texture-basic.png
	Linear layout: row-major order
*/
get_texture_basic_tile :: proc(tile_index: int) -> (x: int, y: int) {
	if tile_index < 0 || tile_index >= TOTAL_TILES {
		return -1, -1
	}

	col := tile_index % GRID_COLUMNS
	row := tile_index / GRID_COLUMNS

	return col * TILE_SIZE, row * TILE_SIZE
}

/*
	Spritesheet metadata
*/
Texture_Basic_Sheet :: struct {
	image_path: string,
	width: int,
	height: int,
	tile_width: int,
	tile_height: int,
	columns: int,
	rows: int,
	tile_count: int,
}

texture_basic_info :: Texture_Basic_Sheet {
	image_path  = "sprites/texture-basic.png",
	width       = TEXTURE_BASIC_WIDTH,
	height      = TEXTURE_BASIC_HEIGHT,
	tile_width  = TILE_SIZE,
	tile_height = TILE_SIZE,
	columns     = GRID_COLUMNS,
	rows        = GRID_ROWS,
	tile_count  = TOTAL_TILES,
}
