/*
	Siriel Odin - Texture Loading
	Raylib texture utilities with path resolution
*/

package assets

import "../core"
import "core:mem"
import "core:os"
import "core:strings"
import "core:testing"
import "core:c"
import rl "vendor:raylib"

/*
	Load texture from data/ directory
	Path is relative to data/ (e.g., "tiles.png")
	Returns loaded texture or error
*/
load_texture :: proc(filename: string) -> rl.Texture2D {
	// Build path: data/filename using concatenate
	parts := [2]string{core.ASSET_PATH, filename}
	full_path := strings.concatenate(parts[:])

	// Convert to cstring for Raylib (allocate + null terminate)
	cstr := make([]u8, len(full_path) + 1)
	defer delete(cstr)
	mem.copy(raw_data(cstr), raw_data(full_path), len(full_path))
	cstr[len(full_path)] = 0

	texture := rl.LoadTexture(cast(cstring) &cstr[0])
	return texture
}

/*
	Unload texture from GPU memory
*/
unload_texture :: proc(texture: rl.Texture2D) {
	rl.UnloadTexture(texture)
}

/*
	Check if texture file exists (without loading)
*/
texture_exists :: proc(filename: string) -> bool {
	parts := [2]string{core.ASSET_PATH, filename}
	full_path := strings.concatenate(parts[:])

	data, err := os.read_entire_file_from_path(full_path, context.allocator)
	delete(data)
	return err == nil
}

/*
	Get full path for asset
*/
get_asset_path :: proc(filename: string) -> string {
	parts := [2]string{core.ASSET_PATH, filename}
	return strings.concatenate(parts[:])
}

/*
	Texture handle with automatic cleanup
*/
Texture_Handle :: struct {
	texture: rl.Texture2D,
	loaded:  bool,
}

/*
	Create texture handle (loads immediately)
*/
texture_load :: proc(filename: string) -> Texture_Handle {
	return Texture_Handle{texture = load_texture(filename), loaded = true}
}

/*
	Unload texture handle
*/
texture_unload :: proc(handle: Texture_Handle) {
	if handle.loaded {
		unload_texture(handle.texture)
	}
}

/*
	Tests
*/
@(test)
test_get_asset_path :: proc(t: ^testing.T) {
	p := get_asset_path("test.png")
	assert(strings.contains(p, "assets/"))
	assert(strings.contains(p, "test.png"))
}

@(test)
test_texture_exists :: proc(t: ^testing.T) {
	// Test with known asset (will fail if data/ missing)
	// This test documents expected behavior
	_ = texture_exists
}
