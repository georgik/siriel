/*
	Siriel Odin - Input System

	Keyboard input handling
*/

package input

import "vendor:raylib"

/*
	Key Codes
*/

Key_Code :: enum {
	UNKNOWN,
	BACK,
	SPACE,
	ESCAPE,
	ENTER,
	TAB,

	// Arrow keys
	UP,
	DOWN,
	LEFT,
	RIGHT,

	// Letters
	A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,

	// Numbers
	NUM_0, NUM_1, NUM_2, NUM_3, NUM_4, NUM_5, NUM_6, NUM_7, NUM_8, NUM_9,

	COUNT,
}

/*
	Input State
*/

Input_State :: struct {
	current: [Key_Code.COUNT]bool,
	previous: [Key_Code.COUNT]bool,
}

/*
	Initialization
*/

input_new :: proc() -> Input_State {
	state: Input_State
	for &key in state.current {
		key = false
	}
	for &key in state.previous {
		key = false
	}
	return state
}

/*
	Update
*/

input_update :: proc(state: ^Input_State) {
	// Copy current to previous
	for i in 0..<Key_Code.COUNT {
		state.previous[i] = state.current[i]
	}

	// Update current state from Raylib
	state.current[Key_Code.UP] = rl.IsKeyDown(rl.KeyboardKey.KEY_UP)
	state.current[Key_Code.DOWN] = rl.IsKeyDown(rl.KeyboardKey.KEY_DOWN)
	state.current[Key_Code.LEFT] = rl.IsKeyDown(rl.KeyboardKey.KEY_LEFT)
	state.current[Key_Code.RIGHT] = rl.IsKeyDown(rl.KeyboardKey.KEY_RIGHT)

	state.current[Key_Code.SPACE] = rl.IsKeyDown(rl.KeyboardKey.KEY_SPACE)
	state.current[Key_Code.ENTER] = rl.IsKeyDown(rl.KeyboardKey.KEY_ENTER)
	state.current[Key_Code.ESCAPE] = rl.IsKeyDown(rl.KeyboardKey.KEY_ESCAPE)
	state.current[Key_Code.TAB] = rl.IsKeyDown(rl.KeyboardKey.KEY_TAB)
	state.current[Key_Code.BACK] = rl.IsKeyDown(rl.KeyboardKey.KEY_BACKSPACE)

	// Letters
	state.current[Key_Code.A] = rl.IsKeyDown(rl.KeyboardKey.KEY_A)
	state.current[Key_Code.B] = rl.IsKeyDown(rl.KeyboardKey.KEY_B)
	state.current[Key_Code.C] = rl.IsKeyDown(rl.KeyboardKey.KEY_C)
	state.current[Key_Code.D] = rl.IsKeyDown(rl.KeyboardKey.KEY_D)
	state.current[Key_Code.E] = rl.IsKeyDown(rl.KeyboardKey.KEY_E)
	state.current[Key_Code.F] = rl.IsKeyDown(rl.KeyboardKey.KEY_F)
	state.current[Key_Code.G] = rl.IsKeyDown(rl.KeyboardKey.KEY_G)
	state.current[Key_Code.H] = rl.IsKeyDown(rl.KeyboardKey.KEY_H)
	state.current[Key_Code.I] = rl.IsKeyDown(rl.KeyboardKey.KEY_I)
	state.current[Key_Code.J] = rl.IsKeyDown(rl.KeyboardKey.KEY_J)
	state.current[Key_Code.K] = rl.IsKeyDown(rl.KeyboardKey.KEY_K)
	state.current[Key_Code.L] = rl.IsKeyDown(rl.KeyboardKey.KEY_L)
	state.current[Key_Code.M] = rl.IsKeyDown(rl.KeyboardKey.KEY_M)
	state.current[Key_Code.N] = rl.IsKeyDown(rl.KeyboardKey.KEY_N)
	state.current[Key_Code.O] = rl.IsKeyDown(rl.KeyboardKey.KEY_O)
	state.current[Key_Code.P] = rl.IsKeyDown(rl.KeyboardKey.KEY_P)
	state.current[Key_Code.Q] = rl.IsKeyDown(rl.KeyboardKey.KEY_Q)
	state.current[Key_Code.R] = rl.IsKeyDown(rl.KeyboardKey.KEY_R)
	state.current[Key_Code.S] = rl.IsKeyDown(rl.KeyboardKey.KEY_S)
	state.current[Key_Code.T] = rl.IsKeyDown(rl.KeyboardKey.KEY_T)
	state.current[Key_Code.U] = rl.IsKeyDown(rl.KeyboardKey.KEY_U)
	state.current[Key_Code.V] = rl.IsKeyDown(rl.KeyboardKey.KEY_V)
	state.current[Key_Code.W] = rl.IsKeyDown(rl.KeyboardKey.KEY_W)
	state.current[Key_Code.X] = rl.IsKeyDown(rl.KeyboardKey.KEY_X)
	state.current[Key_Code.Y] = rl.IsKeyDown(rl.KeyboardKey.KEY_Y)
	state.current[Key_Code.Z] = rl.IsKeyDown(rl.KeyboardKey.KEY_Z)

	// Numbers
	state.current[Key_Code.NUM_0] = rl.IsKeyDown(rl.KeyboardKey.KEY_ZERO)
	state.current[Key_Code.NUM_1] = rl.IsKeyDown(rl.KeyboardKey.KEY_ONE)
	state.current[Key_Code.NUM_2] = rl.IsKeyDown(rl.KeyboardKey.KEY_TWO)
	state.current[Key_Code.NUM_3] = rl.IsKeyDown(rl.KeyboardKey.KEY_THREE)
	state.current[Key_Code.NUM_4] = rl.IsKeyDown(rl.KeyboardKey.KEY_FOUR)
	state.current[Key_Code.NUM_5] = rl.IsKeyDown(rl.KeyboardKey.KEY_FIVE)
	state.current[Key_Code.NUM_6] = rl.IsKeyDown(rl.KeyboardKey.KEY_SIX)
	state.current[Key_Code.NUM_7] = rl.IsKeyDown(rl.KeyboardKey.KEY_SEVEN)
	state.current[Key_Code.NUM_8] = rl.IsKeyDown(rl.KeyboardKey.KEY_EIGHT)
	state.current[Key_Code.NUM_9] = rl.IsKeyDown(rl.KeyboardKey.KEY_NINE)
}

/*
	Query Functions
*/

is_key_down :: proc(state: Input_State, key: Key_Code) -> bool {
	return state.current[key]
}

is_key_pressed :: proc(state: Input_State, key: Key_Code) -> bool {
	return state.current[key] && !state.previous[key]
}

is_key_released :: proc(state: Input_State, key: Key_Code) -> bool {
	return !state.current[key] && state.previous[key]
}

is_key_up :: proc(state: Input_State, key: Key_Code) -> bool {
	return !state.current[key]
}
