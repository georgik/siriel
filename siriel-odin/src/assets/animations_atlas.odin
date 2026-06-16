/*
	Siriel Animations Atlas
	animations-basic.png: 320x32 pixels, 20x2 frames (16x16 each)
	Game object animations (teleports, pickups, effects)
*/

package assets

ANIMATIONS_WIDTH :: 320
ANIMATIONS_HEIGHT :: 32
ANIMATIONS_GRID_COLUMNS :: 20
ANIMATIONS_GRID_ROWS :: 2
ANIMATIONS_TOTAL_FRAMES :: ANIMATIONS_GRID_COLUMNS * ANIMATIONS_GRID_ROWS  // 40

// Animation loop modes (reused from avatar_atlas)
// Animation_Loop :: enum { Once, Loop, PingPong }

// Game object animation
Object_Animation :: struct {
	frames:    []int,
	duration:  f32,
	loop_mode: Animation_Loop,
}

// Animation registry
object_animations: map[string]Object_Animation

// Initialize game object animations
init_object_animations :: proc() {
	object_animations = make(map[string]Object_Animation)

	// Row 0
	object_animations["teleport"] = Object_Animation {
		frames    = []int{0, 1, 2, 3},
		duration  = 0.2,
		loop_mode = .Loop,
	}
	object_animations["pear"] = Object_Animation {
		frames    = []int{4, 5, 6, 7},
		duration  = 0.2,
		loop_mode = .Loop,
	}
	object_animations["cherry"] = Object_Animation {
		frames    = []int{8, 9, 10, 11},
		duration  = 0.2,
		loop_mode = .Loop,
	}
	object_animations["stop_sign"] = Object_Animation {
		frames    = []int{12, 13, 14, 15},
		duration  = 0.2,
		loop_mode = .Loop,
	}
	object_animations["teleport2"] = Object_Animation {
		frames    = []int{16, 17, 18, 19},
		duration  = 0.2,
		loop_mode = .Loop,
	}

	// Row 1
	object_animations["water"] = Object_Animation {
		frames    = []int{20, 21, 22, 23},
		duration  = 0.24,
		loop_mode = .Loop,
	}
	object_animations["coin"] = Object_Animation {
		frames    = []int{24, 25, 26, 27},
		duration  = 0.16,
		loop_mode = .Loop,
	}
	object_animations["heart"] = Object_Animation {
		frames    = []int{28, 29, 30, 31},
		duration  = 0.2,
		loop_mode = .Loop,
	}
	object_animations["pacman"] = Object_Animation {
		frames    = []int{32, 33, 34, 35},
		duration  = 0.2,
		loop_mode = .Loop,
	}
	object_animations["monster"] = Object_Animation {
		frames    = []int{36, 37, 38, 39},
		duration  = 0.2,
		loop_mode = .Loop,
	}
}

// Get object animation by name
get_object_animation :: proc(name: string) -> (Object_Animation, bool) {
	anim, ok := object_animations[name]
	return anim, ok
}
