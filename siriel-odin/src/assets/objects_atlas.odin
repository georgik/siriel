/*
	Siriel Objects Atlas
	objects-basic.png: 320x16 pixels, 20x1 objects (16x16 each)
	Static collectible objects and interactive items
*/

package assets

OBJECTS_WIDTH :: 320
OBJECTS_HEIGHT :: 16
OBJECTS_TILE_WIDTH :: 16
OBJECTS_TILE_HEIGHT :: 16
OBJECTS_GRID_COLUMNS :: 20
OBJECTS_GRID_ROWS :: 1
OBJECTS_TOTAL :: OBJECTS_GRID_COLUMNS * OBJECTS_GRID_ROWS  // 20

// Named object tile indices (0-based)
Object_ID :: enum {
	Teleport        = 0,  // Teleport pad
	Pear            = 1,  // Pear fruit collectible
	Cherry          = 2,  // Cherry fruit collectible
	StopSign        = 3,  // Stop sign
	Teleport2       = 4,  // Alternative teleport
	Water           = 5,  // Water/potion
	Coin            = 6,  // Coin collectible
	Heart           = 7,  // Heart/life
	Pacman          = 8,  // Pacman reference
	Monster         = 9,  // Monster/enemy
	Exit            = 10, // Exit door
	GoldPiece       = 11, // Gold piece
	Lollipop        = 12, // Lollipop
	IceCream        = 13, // Ice cream
	Apple           = 14, // Apple fruit
	Orange          = 15, // Orange fruit
	BankNote        = 16, // Bank note/money
	Gold            = 17, // Gold bar
	Switch          = 18, // Switch/button
	TeleportMarker  = 19, // Teleport marker
}

// Object metadata
Object_Info :: struct {
	name:         string,
	tile_index:   int,
	pickupable:   bool,
	value:        int,
	sprite_sheet: string,
}

// Object registry
object_registry: map[int]Object_Info

// Initialize object registry
init_objects_registry :: proc() {
	object_registry = make(map[int]Object_Info)

	// Collectible items (pickupable, has value)
	object_registry[int(Object_ID.Pear)] = Object_Info{"pear", 1, true, 3, "objects-basic"}
	object_registry[int(Object_ID.Cherry)] = Object_Info{"cherry", 2, true, 5, "objects-basic"}
	object_registry[int(Object_ID.Water)] = Object_Info{"water", 5, true, 10, "objects-basic"}
	object_registry[int(Object_ID.Coin)] = Object_Info{"coin", 6, true, 1, "objects-basic"}
	object_registry[int(Object_ID.Heart)] = Object_Info{"heart", 7, true, 100, "objects-basic"}  // 1 life
	object_registry[int(Object_ID.GoldPiece)] = Object_Info{"gold_piece", 11, true, 10, "objects-basic"}
	object_registry[int(Object_ID.Lollipop)] = Object_Info{"lollipop", 12, true, 15, "objects-basic"}
	object_registry[int(Object_ID.IceCream)] = Object_Info{"ice_cream", 13, true, 20, "objects-basic"}
	object_registry[int(Object_ID.Apple)] = Object_Info{"apple", 14, true, 8, "objects-basic"}
	object_registry[int(Object_ID.Orange)] = Object_Info{"orange", 15, true, 12, "objects-basic"}
	object_registry[int(Object_ID.BankNote)] = Object_Info{"bank_note", 16, true, 50, "objects-basic"}
	object_registry[int(Object_ID.Gold)] = Object_Info{"gold", 17, true, 100, "objects-basic"}

	// Interactive objects (not pickupable, or special behavior)
	object_registry[int(Object_ID.Teleport)] = Object_Info{"teleport", 0, false, 0, "objects-basic"}
	object_registry[int(Object_ID.Teleport2)] = Object_Info{"teleport2", 4, false, 0, "objects-basic"}
	object_registry[int(Object_ID.StopSign)] = Object_Info{"stop_sign", 3, false, 0, "objects-basic"}
	object_registry[int(Object_ID.Exit)] = Object_Info{"exit", 10, false, 0, "objects-basic"}
	object_registry[int(Object_ID.Switch)] = Object_Info{"switch", 18, false, 0, "objects-basic"}
	object_registry[int(Object_ID.TeleportMarker)] = Object_Info{"teleport_marker", 19, false, 0, "objects-basic"}

	// Enemies (special behavior)
	object_registry[int(Object_ID.Monster)] = Object_Info{"monster", 9, false, 0, "objects-basic"}
	object_registry[int(Object_ID.Pacman)] = Object_Info{"pacman", 8, false, 0, "objects-basic"}
}

// Get object info by tile index
get_object_info :: proc(tile_index: int) -> (Object_Info, bool) {
	info, ok := object_registry[tile_index]
	return info, ok
}

// Check if object is pickupable
is_object_pickupable :: proc(tile_index: int) -> bool {
	info, ok := object_registry[tile_index]
	return ok && info.pickupable
}

// Get pickup value
get_object_value :: proc(tile_index: int) -> int {
	info, ok := object_registry[tile_index]
	if ok {
		return info.value
	}
	return 0
}
