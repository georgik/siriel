/*
	Siriel Odin - Test Level
	Simple level for collision testing
*/

#+feature global-context
package test_level

import "../core"

// Simple test level - all zeros (empty), will be filled programmatically
test_tilemap : [26][42]int

// Initialize test level with some platforms
init_test_level :: proc() {
	// Clear all to zero (empty space)
	for y in 0..<26 {
		for x in 0..<42 {
			test_tilemap[y][x] = 0
		}
	}

	// Add ground at bottom (tiles >= 24 are solid)
	for x in 0..<42 {
		test_tilemap[25][x] = 24
	}

	// Add some platforms
	for x in 10..<20 {
		test_tilemap[20][x] = 24
	}

	for x in 5..<15 {
		test_tilemap[15][x] = 24
	}
}

@(init)
init :: proc() {
	init_test_level()
}

// Function to get the tilemap
get_test_tilemap :: proc() -> [26][42]int {
	return test_tilemap
}
