/*
	Siriel Odin - Player Movement System
	Handles keyboard input, velocity, and animation state
*/

package player

import "core:fmt"
import rl "vendor:raylib"

import "../core"

/*
	Player State
*/

State :: struct {
	x: f32,           // Position X
	y: f32,           // Position Y
	vel_x: f32,       // Velocity X
	vel_y: f32,       // Velocity Y
	facing: int,      // 0=right, 1=left
	anim: string,     // Current animation
	jumping: bool,
	on_ground: bool,
}

/*
	Movement Constants (from original Siriel)
*/

MOVE_SPEED :: 2.0     // pixels per frame
JUMP_FORCE :: -8.0    // upward velocity
GRAVITY :: 0.5        // downward acceleration per frame
FRICTION :: 0.8        // velocity damping
MAX_FALL :: 8.0        // terminal velocity

/*
	Input State
*/

Input :: struct {
	left: bool,
	right: bool,
	up: bool,
	down: bool,
	jump: bool,
}

/*
	Get Input from Raylib
*/

get_input :: proc() -> Input {
	return Input {
		left = rl.IsKeyDown(rl.KeyboardKey.LEFT),
		right = rl.IsKeyDown(rl.KeyboardKey.RIGHT),
		up = rl.IsKeyDown(rl.KeyboardKey.UP),
		down = rl.IsKeyDown(rl.KeyboardKey.DOWN),
		jump = rl.IsKeyDown(rl.KeyboardKey.SPACE),
	}
}

/*
	Create Player
*/

create :: proc(start_x: int, start_y: int) -> State {
	return State {
		x = f32(start_x),
		y = f32(start_y),
		vel_x = 0,
		vel_y = 0,
		facing = 0,  // facing right
		anim = "idle_down",
		jumping = false,
		on_ground = true,
	}
}

/*
	Update Movement
*/

update :: proc(player: ^State, input: Input) {
	// Horizontal movement
	if input.left {
		player.vel_x = -MOVE_SPEED
		player.facing = 1
		player.anim = "left"
	} else if input.right {
		player.vel_x = MOVE_SPEED
		player.facing = 0
		player.anim = "right"
	} else {
		// Apply friction
		player.vel_x *= FRICTION
		if abs(player.vel_x) < 0.1 {
			player.vel_x = 0
			if !player.jumping {
				player.anim = "idle_down"
			}
		}
	}

	// Vertical movement (up/down)
	if input.up {
		player.y -= MOVE_SPEED
		player.anim = "up"
	} else if input.down {
		player.y += MOVE_SPEED
		if !player.jumping {
			player.anim = "idle_down"
		}
	}

	// Jump
	if input.jump && player.on_ground {
		player.vel_y = JUMP_FORCE
		player.jumping = true
		player.on_ground = false

		// Set jump animation based on facing
		if player.facing == 0 {
			player.anim = "jump_right"
		} else {
			player.anim = "jump_left_up"
		}
	}

	// Apply gravity
	if !player.on_ground {
		player.vel_y += GRAVITY

		// Cap fall speed
		if player.vel_y > MAX_FALL {
			player.vel_y = MAX_FALL
		}

		// Switch to parachute when falling
		if player.vel_y > 2.0 {
			player.anim = "parachute"
		}
	}

	// Update position
	player.x += player.vel_x
	player.y += player.vel_y

	// Simple ground check (will be replaced with collision)
	if player.y > 400 {  // Temporary ground level
		player.y = 400
		player.vel_y = 0
		player.jumping = false
		player.on_ground = true

		// Return to idle animation when landing
		if player.vel_x == 0 {
			player.anim = "idle_down"
		}
	}

	// Screen bounds
	if player.x < 0 {
		player.x = 0
		player.vel_x = 0
	}
	if player.x > f32(core.SCREEN_WIDTH - 16) {
		player.x = f32(core.SCREEN_WIDTH - 16)
		player.vel_x = 0
	}
}

/*
	Get Animation Name
*/

get_animation :: proc(player: State) -> string {
	return player.anim
}

/*
	Get Position
*/

get_position :: proc(player: State) -> (int, int) {
	return int(player.x), int(player.y)
}
