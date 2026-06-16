/*
	Siriel Avatar Animation Atlas
	siriel-avatar.png: 512x48 pixels, 32x3 frames (16x16 each)
*/

package assets

AVATAR_WIDTH :: 512
AVATAR_HEIGHT :: 48
AVATAR_GRID_COLUMNS :: 32
AVATAR_GRID_ROWS :: 3
AVATAR_TOTAL_FRAMES :: AVATAR_GRID_COLUMNS * AVATAR_GRID_ROWS  // 96

// Animation loop modes
Animation_Loop :: enum {
	Once,
	Loop,
	PingPong,
}

// Animation definition
Avatar_Animation :: struct {
	frames:    []int,  // Frame indices
	duration:  f32,    // Duration per frame (seconds)
	loop_mode: Animation_Loop,
}

// Named animation constants
Avatar_Anim_Name :: enum {
	IdleDown = 0,
	Idle,
	WalkLeft,
	WalkRight,
	JumpUp,
	Parachute,
	JumpLeft,
	WalkUp,
	JumpRight,
	Stars,
	Fall,
}

// Animation registry (populated at runtime)
avatar_animations: map[string]Avatar_Animation

// Initialize avatar animations
init_avatar_animations :: proc() {
	avatar_animations = make(map[string]Avatar_Animation)

	// Row 1: Idle/Down animations (frames 0-3)
	avatar_animations["idle_down"] = Avatar_Animation {
		frames    = []int{0, 1, 2, 3},
		duration  = 0.3,
		loop_mode = .Loop,
	}
	avatar_animations["idle"] = avatar_animations["idle_down"]  // alias

	// Row 1: Left movement (frames 4-7)
	avatar_animations["walk_left"] = Avatar_Animation {
		frames    = []int{4, 5, 6, 7},
		duration  = 0.2,
		loop_mode = .Loop,
	}

	// Row 1: Right movement (frames 8-11)
	avatar_animations["walk_right"] = Avatar_Animation {
		frames    = []int{8, 9, 10, 11},
		duration  = 0.2,
		loop_mode = .Loop,
	}

	// Row 2: Jump up animation (frames 32-39)
	avatar_animations["jump_up"] = Avatar_Animation {
		frames    = []int{32, 33, 34, 35, 36, 37, 38, 39},
		duration  = 0.1,
		loop_mode = .Once,
	}

	// Row 2: Parachute animation (frames 40-42)
	avatar_animations["parachute"] = Avatar_Animation {
		frames    = []int{40, 41, 42},
		duration  = 0.4,
		loop_mode = .Once,
	}

	// Row 3: Jump left (frames 64-71)
	avatar_animations["jump_left"] = Avatar_Animation {
		frames    = []int{64, 65, 66, 67, 68, 69, 70, 71},
		duration  = 0.1,
		loop_mode = .Once,
	}

	// Row 3: Walk up (frames 72-75)
	avatar_animations["walk_up"] = Avatar_Animation {
		frames    = []int{72, 73, 74, 75},
		duration  = 0.2,
		loop_mode = .Loop,
	}

	// Row 3: Jump right (frames 76-83)
	avatar_animations["jump_right"] = Avatar_Animation {
		frames    = []int{76, 77, 78, 79, 80, 81, 82, 83},
		duration  = 0.1,
		loop_mode = .Once,
	}

	// Row 3: Stars (frames 84-87)
	avatar_animations["stars"] = Avatar_Animation {
		frames    = []int{84, 85, 86, 87},
		duration  = 0.2,
		loop_mode = .Loop,
	}

	// Generic movement
	avatar_animations["fall"] = Avatar_Animation {
		frames    = []int{36, 37},  // Last frames of jump_up
		duration  = 0.2,
		loop_mode = .Loop,
	}
}

// Get animation by name
get_avatar_animation :: proc(name: string) -> (Avatar_Animation, bool) {
	anim, ok := avatar_animations[name]
	return anim, ok
}

// Player state mapping
Player_State :: enum {
	PlayerIdle,
	PlayerWalk,
	PlayerWalkLeft,
	PlayerWalkRight,
	PlayerWalkUp,
	PlayerWalkDown,
	PlayerJump,
	PlayerJumpLeft,
	PlayerJumpRight,
	PlayerFall,
	PlayerParachute,
	PlayerStars,
}

// Map player state to animation name
player_state_to_animation :: proc(state: Player_State) -> string {
	switch state {
	case .PlayerIdle, .PlayerWalkDown: return "idle"
	case .PlayerWalk, .PlayerWalkRight: return "walk_right"
	case .PlayerWalkLeft: return "walk_left"
	case .PlayerWalkUp: return "walk_up"
	case .PlayerJump: return "jump_up"
	case .PlayerJumpLeft: return "jump_left"
	case .PlayerJumpRight: return "jump_right"
	case .PlayerFall: return "fall"
	case .PlayerParachute: return "parachute"
	case .PlayerStars: return "stars"
	}
	return "idle"
}
