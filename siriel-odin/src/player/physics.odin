/*
	Siriel Odin - Player Physics with Collision
	Handles movement with proper collision detection
*/

package player

import "core:fmt"
import rl "vendor:raylib"

import "../core"
import "../collision"

/*
	Enhanced Player State with collision
*/

Physics_State :: struct {
	x: f32,
	y: f32,
	vel_x: f32,
	vel_y: f32,
	facing: int,
	anim: string,
	jumping: bool,
	on_ground: bool,
	width: int,
	height: int,
}

/*
	Create physics player
*/

create_physics :: proc(start_x: int, start_y: int) -> Physics_State {
	return Physics_State {
		x = f32(start_x),
		y = f32(start_y),
		vel_x = 0,
		vel_y = 0,
		facing = 0,
		anim = "idle_down",
		jumping = false,
		on_ground = false,
		width = 16,
		height = 16,
	}
}

/*
	Update with collision detection
*/

update_physics :: proc(player: ^Physics_State, input: Input, tilemap: [][]int) {
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
			if player.on_ground {
				player.anim = "idle_down"
			}
		}
	}

	// Vertical movement (up/down for climbing/ladders)
	if input.up {
		// TODO: Check for ladder
		player.y -= MOVE_SPEED
		player.anim = "up"
	} else if input.down {
		player.y += MOVE_SPEED
		if player.on_ground {
			player.anim = "idle_down"
		}
	}

	// Jump
	if input.jump && player.on_ground {
		player.vel_y = JUMP_FORCE
		player.jumping = true
		player.on_ground = false

		if player.facing == 0 {
			player.anim = "jump_right"
		} else {
			player.anim = "jump_left_up"
		}
	}

	// Apply gravity
	if !player.on_ground {
		player.vel_y += GRAVITY

		if player.vel_y > MAX_FALL {
			player.vel_y = MAX_FALL
		}

		if player.vel_y > 2.0 {
			player.anim = "parachute"
		}
	}

	// Move and check collisions
	new_x := player.x + player.vel_x
	new_y := player.y + player.vel_y

	// Horizontal collision
	if player.vel_x < 0 {  // Moving left
		if collision.check_wall_left(tilemap, int(new_x), int(player.y), player.height) {
			new_x = player.x
			player.vel_x = 0
		}
	} else if player.vel_x > 0 {  // Moving right
		if collision.check_wall_right(tilemap, int(new_x), int(player.y), player.width, player.height) {
			new_x = player.x
			player.vel_x = 0
		}
	}

	// Vertical collision
	if player.vel_y < 0 {  // Moving up (jump)
		if collision.check_ceiling(tilemap, int(new_x), int(new_y), player.width) {
			new_y = player.y
			player.vel_y = 0
		}
	} else if player.vel_y > 0 {  // Falling
		if collision.check_ground(tilemap, int(new_x), int(new_y + f32(player.height)), player.width, player.height) {
			// Landed on ground
			tile_y := int(new_y) / core.TILE_SIZE
			new_y = f32(tile_y * core.TILE_SIZE - player.height)
			player.vel_y = 0
			player.jumping = false
			player.on_ground = true

			// Update animation when landing
			if player.vel_x == 0 {
				player.anim = "idle_down"
			} else if player.facing == 0 {
				player.anim = "right"
			} else {
				player.anim = "left"
			}
		}
	}

	// Update position
	player.x = new_x
	player.y = new_y

	// Screen bounds
	if player.x < 0 {
		player.x = 0
		player.vel_x = 0
	}
	if player.x > f32(core.SCREEN_WIDTH - player.width) {
		player.x = f32(core.SCREEN_WIDTH - player.width)
		player.vel_x = 0
	}
	if player.y < 0 {
		player.y = 0
		player.vel_y = 0
	}
}

/*
	Get position
*/

get_position_physics :: proc(player: Physics_State) -> (int, int) {
	return int(player.x), int(player.y)
}

/*
	Get animation
*/

get_animation_physics :: proc(player: Physics_State) -> string {
	return player.anim
}
