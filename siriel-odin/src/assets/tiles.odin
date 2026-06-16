/*
	Siriel Odin - Tile Loading
	Tilemap loading from texture files
*/

package assets

import "../core"
import "core:mem"
import "core:os"
import "core:testing"
import rl "vendor:raylib"

// Tilemap data
Tilemap :: struct {
	texture:    rl.Texture2D,
	width:      int,
	height:     int,
	tile_count: int,
	tiles:      []core.Tile,
	loaded:     bool,
}

/*
	Create empty tilemap
*/
tilemap_new :: proc() -> Tilemap {
	return Tilemap{texture = {}, width = 0, height = 0, tile_count = 0, tiles = {}, loaded = false}
}

/*
	Load tilemap from image file (16x16 tiles)
	Returns loaded tilemap
*/
load_tilemap :: proc(filename: string) -> Tilemap {
	texture := load_texture(filename)

	if texture.id == 0 {
		return Tilemap{loaded = false}
	}

	img := rl.LoadImageFromTexture(texture)
	if img.data == nil {
		unload_texture(texture)
		return Tilemap{loaded = false}
	}

	tile_w := img.width / core.TILE_SIZE
	tile_h := img.height / core.TILE_SIZE
	count := tile_w * tile_h

	tiles := make([]core.Tile, count)

	// Parse tiles (placeholder - actual parsing needs pixel data)
	for i in 0 ..< count {
		tiles[i] = core.Tile {
			index  = u16(i),
			solid  = false,
			usable = true,
		}
	}

	rl.UnloadImage(img)

	return Tilemap {
		texture = texture,
		width = int(tile_w),
		height = int(tile_h),
		tile_count = int(count),
		tiles = tiles,
		loaded = true,
	}
}

/*
	Unload tilemap resources
*/
unload_tilemap :: proc(tilemap: ^Tilemap) {
	if tilemap.loaded {
		unload_texture(tilemap.texture)
		tilemap.loaded = false
	}
	delete(tilemap.tiles)
}

/*
	Get tile at index
*/
get_tile :: proc(tilemap: Tilemap, index: int) -> core.Tile {
	if index < 0 || index >= tilemap.tile_count {
		return core.Tile{}
	}
	return tilemap.tiles[index]
}

/*
	Calculate tile count from dimensions
*/
calculate_tile_count :: proc(width: int, height: int, tile_size: int) -> int {
	return (width / tile_size) * (height / tile_size)
}

/*
	Tests
*/
@(test)
test_tilemap_new :: proc(t: ^testing.T) {
	tm := tilemap_new()
	assert(tm.loaded == false)
	assert(tm.tile_count == 0)
	assert(len(tm.tiles) == 0)
}

@(test)
test_calculate_tile_count :: proc(t: ^testing.T) {
	// 640x480 with 16x16 tiles = 40x30 = 1200 tiles
	count := calculate_tile_count(640, 480, 16)
	assert(count == 1200)

	// 320x240 with 16x16 tiles = 20x15 = 300 tiles
	count = calculate_tile_count(320, 240, 16)
	assert(count == 300)
}

@(test)
test_get_tile :: proc(t: ^testing.T) {
	tm := tilemap_new()
	tm.tiles = make([]core.Tile, 10)
	defer delete(tm.tiles)
	tm.tile_count = 10

	// Set tile at index 5
	tm.tiles[5] = core.Tile {
		index = 100,
		solid = true,
	}

	tile := get_tile(tm, 5)
	assert(tile.index == 100)
	assert(tile.solid == true)

	// Out of bounds returns empty tile
	tile = get_tile(tm, 20)
	assert(tile.index == 0)
}
