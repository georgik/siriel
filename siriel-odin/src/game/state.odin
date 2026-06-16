/*
	Siriel Odin - Game State

	Core game state management
*/

package game

import "core:strings"

import "../src/core"

/*
	Game State Enum
*/

Game_State :: enum {
	Menu,           // Main menu
	Playing,        // Active gameplay
	Paused,         // Game paused
	LevelComplete,  // Level finished
	GameOver,       // Player died
	Transition,     // Room/level transition
}

/*
	Player State
*/

Player_State :: struct {
	x: int,           // Tile X coordinate
	y: int,           // Tile Y coordinate
	pixel_x: f32,     // Screen X position (pixels)
	pixel_y: f32,     // Screen Y position (pixels)
	vel_x: f32,       // Velocity X
	vel_y: f32,       // Velocity Y
	facing: int,      // Direction (0=right, 1=left)
	jumping: bool,
	on_ground: bool,
	anim_frame: int,  // Animation frame (0-3)
	anim_timer: f32,  // Animation timer
	invincible: f32,  // Invincibility timer
}

/*
	Object Instance
*/

Object_Instance :: struct {
	id: string,
	type: ObjectType,
	sprite: int,
	x: int,           // Tile X
	y: int,           // Tile Y
	pixel_x: f32,
	pixel_y: f32,
	funk: FunkType,
	visible: bool,
	group: Group,     // A-G for visibility
	collected: bool,  // For collectibles

	// Funk-specific data
	points: int,      // For collectibles
	anim: Animation,  // Animation type
	destination: ^Point,  // For teleport (optional)
	target_room: Group,    // For teleport
	bounds: ^Bounds,  // For platforms (optional)
	speed: int,       // For platforms/enemies
	dir: Direction,   // For platforms
	show_exit: bool,  // For level complete

	// Runtime state
	timer: f32,       // For timed behaviors
	frame: int,       // Animation frame
}

/*
	Group Visibility
*/

Group_Visibility :: struct {
	a: bool,
	b: bool,
	c: bool,
	d: bool,
	e: bool,
	f: bool,
	g: bool,
}

/*
	Level Data
*/

Level :: struct {
	name: string,
	music: string,
	start_x: int,
	start_y: int,
	objects: [dynamic]Object_Instance,
	group_visibility: Group_Visibility,
}

/*
	Main Game State
*/

State :: struct {
	current_state: Game_State,
	current_level: ^Level,
	player: Player_State,
	frames: int,     // Frame counter
	delta_time: f32,  // Delta time
}

// Global game state
game_state: State

/*
	Enums (from format spec)
*/

ObjectType :: enum {
	Collectible,
	Trigger,
	Interactable,
	Walker,
	Static,
}

FunkType :: enum {
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

Animation :: enum {
	Static,
	Animated,
	Special,
	Dangerous,
}

Direction :: enum {
	Forward,
	Backward,
}

Group :: enum {
	A, B, C, D, E, F, G,
}

/*
	Point structures
*/

Point :: struct {
	x: int,
	y: int,
}

Bounds :: struct {
	min: int,
	max: int,
}

/*
	Initialization
*/

init :: proc() {
	game_state.current_state = .Menu
	game_state.current_level = nil
	game_state.frames = 0
	game_state.delta_time = 0

	// Initialize player
	reset_player()
}

reset_player :: proc() {
	game_state.player.x = 88  // Default start
	game_state.player.y = 88
	game_state.player.pixel_x = f32(88 * core.TILE_SIZE)
	game_state.player.pixel_y = f32(88 * core.TILE_SIZE)
	game_state.player.vel_x = 0
	game_state.player.vel_y = 0
	game_state.player.facing = 0
	game_state.player.jumping = false
	game_state.player.on_ground = false
	game_state.player.anim_frame = 0
	game_state.player.anim_timer = 0
	game_state.player.invincible = 0
}

/*
	State Management
*/

set_state :: proc(state: Game_State) {
	game_state.current_state = state
}

get_state :: proc() -> Game_State {
	return game_state.current_state
}

load_level :: proc(level: ^Level) {
	game_state.current_level = level

	// Set player position from level start
	if level != nil {
		game_state.player.x = level.start_x
		game_state.player.y = level.start_y
		game_state.player.pixel_x = f32(level.start_x * core.TILE_SIZE)
		game_state.player.pixel_y = f32(level.start_y * core.TILE_SIZE)

		// Initialize group visibility (all visible by default)
		level.group_visibility.a = true
		level.group_visibility.b = true
		level.group_visibility.c = true
		level.group_visibility.d = true
		level.group_visibility.e = true
		level.group_visibility.f = true
		level.group_visibility.g = true
	}

	set_state(.Playing)
}

/*
	Group Visibility
*/

set_group_visible :: proc(group: Group, visible: bool) {
	if game_state.current_level == nil do return

	lvl := game_state.current_level
	switch group {
		case .A: lvl.group_visibility.a = visible
		case .B: lvl.group_visibility.b = visible
		case .C: lvl.group_visibility.c = visible
		case .D: lvl.group_visibility.d = visible
		case .E: lvl.group_visibility.e = visible
		case .F: lvl.group_visibility.f = visible
		case .G: lvl.group_visibility.g = visible
	}

	// Update object visibility based on group
	for &obj in lvl.objects {
		if obj.group == group {
			obj.visible = visible
		}
	}
}

is_group_visible :: proc(group: Group) -> bool {
	if game_state.current_level == nil do return true

	lvl := game_state.current_level
	switch group {
		case .A: return lvl.group_visibility.a
		case .B: return lvl.group_visibility.b
		case .C: return lvl.group_visibility.c
		case .D: return lvl.group_visibility.d
		case .E: return lvl.group_visibility.e
		case .F: return lvl.group_visibility.f
		case .G: return lvl.group_visibility.g
	}
}
