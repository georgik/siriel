/*
	Siriel Odin - HUD System

	Displays score, lives, timer as in original Siriel 3.5
*/

package hud_odin  // Avoid name conflict with Raylib's hud

import "core:fmt"
import "core:strings"
import "core:strconv"

import "core:rl"
import "core:raylib"

import "../src/core"

/*
	HUD State
*/

HUD_State :: struct {
	score: int,
	lives: int,
	timer: int,  // Countdown in seconds
	show_timer: bool,
}

// Global HUD state
hud_state: HUD_State

/*
	Constants from original
*/

HUD_Y_POSITION :: 460  // vypisy = 460 in original
LIFE_ICON_X_START :: 508  // Starting X position for life icons
LIFE_ICON_SPACING :: 16   // 16px between life icons
LIFE_ICON_SIZE :: 16      // 16×16 pixel life icons

SCORE_X_POSITION :: 10    // Left side of screen
SCORE_Y_POSITION :: 450   // Near bottom

TIMER_X_POSITION :: 320   // Center of screen
TIMER_Y_POSITION :: 450   // Near bottom

/*
	Initialization
*/

init :: proc() {
	hud_state.score = 0
	hud_state.lives = core.DEFAULT_LIVES
	hud_state.timer = 0
	hud_state.show_timer = false
}

/*
	Update Functions
*/

set_score :: proc(score: int) {
	hud_state.score = score
}

add_score :: proc(points: int) {
	hud_state.score += points
}

set_lives :: proc(lives: int) {
	hud_state.lives = lives
}

lose_life :: proc() {
	if hud_state.lives > 0 {
		hud_state.lives -= 1
	}
}

set_timer :: proc(seconds: int) {
	hud_state.timer = seconds
	hud_state.show_timer = seconds > 0
}

update_timer :: proc(delta_seconds: float64) {
	if hud_state.show_timer && hud_state.timer > 0 {
		hud_state.timer -= 1
		if hud_state.timer < 0 {
			hud_state.timer = 0
		}
	}
}

/*
	Rendering
*/

draw :: proc() {
	// Draw score (top-left)
	draw_score()

	// Draw lives (bottom-right, life icons)
	draw_lives()

	// Draw timer (if enabled)
	if hud_state.show_timer {
		draw_timer()
	}
}

draw_score :: proc() {
	score_str := strconv.itoa_buf(hud_state.score)

	// Draw score text
	// TODO: Load proper font and render
	// For now, use Raylib's text drawing
	rl.DrawText(score_str, SCORE_X_POSITION, SCORE_Y_POSITION, 20, rl.WHITE)
}

draw_lives :: proc() {
	// Draw life icons at bottom-right
	for i in 0..<hud_state.lives {
		x := LIFE_ICON_X_START + i * LIFE_ICON_SPACING
		y := HUD_Y_POSITION - 9

		// TODO: Draw actual life icon sprite
		// For now, draw a red circle as placeholder
		rl.DrawCircle(i32(x) + 8, i32(y) + 8, 6, rl.RED)
	}
}

draw_timer :: proc() {
	if hud_state.timer <= 0 do return

	// Format timer as MM:SS
	minutes := hud_state.timer / 60
	seconds := hud_state.timer % 60

	timer_str := fmt.tprintf("%02d:%02d", minutes, seconds)

	// Draw centered timer
	text_width := rl.MeasureText(timer_str, 20)
	x := TIMER_X_POSITION - text_width / 2

	// Color changes based on time remaining
	color := rl.WHITE
	if hud_state.timer < 30 {
		color = rl.YELLOW
	}
	if hud_state.timer < 10 {
		color = rl.RED
	}

	rl.DrawText(timer_str, i32(x), TIMER_Y_POSITION, 20, color)
}

/*
	Getters
*/

get_score :: proc() -> int {
	return hud_state.score
}

get_lives :: proc() -> int {
	return hud_state.lives
}

get_timer :: proc() -> int {
	return hud_state.timer
}

is_game_over :: proc() -> bool {
	return hud_state.lives <= 0
}

is_time_up :: proc() -> bool {
	return hud_state.show_timer && hud_state.timer <= 0
}
