/*
	Siriel Odin - Level Package
	Loaded from converted .MIE files
*/

package level

import "core:fmt"

/*
	Level Constants
*/

MAP_WIDTH :: 38
MAP_HEIGHT :: 26

/*
	Point structure
*/

Point :: struct {
	x: int,
	y: int,
}

/*
	Map structure
*/

Map :: struct {
	width:  int,
	height: int,
	tiles:  [MAP_HEIGHT][MAP_WIDTH]int,
}

/*
	Object Types
*/

Object_Type :: enum {
	Static,         // V-type - decorative
	Collectible,    // Z-type - picked up by walking
	Trigger,        // Y-type - immediate trigger
	Interactable,   // X-type - requires action key
	Walker,         // W-type - takeable/inventory
}

/*
	Function types (funk)
*/

Funk_Type :: enum {
	Default,
	Teleport,
	PlatformX,
	PlatformY,
	PatrolX,
	PatrolY,
	TextureChange,
	ShowItems,
	HideItems,
	LevelComplete,
	AddLife,
	MazeVisibility,
	RandomMove,
	SwapRoomVisibility,
	TransferToStage,
	Fireball,
	Enemy,
	SoundEmitter,
	FireballWithSound,
	Powerup,
}

/*
	Animation type
*/

Anim_Type :: enum {
	Static,
	Animated,
}

/*
	Group (room)
*/

Group :: enum {
	A, B, C, D, E, F, G,
}

/*
	Direction
*/

Direction :: enum {
	Backward,
	Forward,
}

/*
	Game Object
*/

Object :: struct {
	id:       string,
	type:     Object_Type,
	sprite:   int,
	position: Point,
	funk:     Funk_Type,
	// Type-specific fields
	points:    int,         // For collectibles
	anim:      Anim_Type,   // Animation type
	group:     Group,       // Room/group
	// Funk-specific fields
	destination: Point,     // For Teleport
	bounds:     Bounds,     // For Platform
	speed:      int,        // For Platform/Patrol
	dir:        Direction,  // Movement direction
	show_exit:  bool,       // For LevelComplete
	// Additional params
	params: [7]int,         // inf1-inf7
}

/*
	Bounds structure
*/

Bounds :: struct {
	min: int,
	max: int,
}

/*
	Level structure
*/

Level :: struct {
	name:           string,
	music:          string,
	start_position: Point,
	objects:        [dynamic]Object,
	tilemap:            Map,
}

/*
	Get level by name
*/

get_level :: proc(name: string) -> ^Level {
	// For now, return pointer to default level
	// TODO: Implement level registry
	return nil
}
