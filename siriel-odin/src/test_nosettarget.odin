package main
import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
	fmt.println("Before window")
	rl.InitWindow(800, 600, "Test")
	defer rl.CloseWindow()
	fmt.println("After window")
	// NO SetTargetFPS call
	fmt.println("After (no SetTargetFPS)")
	
	frames: i32 = 0
	for frames < 10 {
		if rl.WindowShouldClose() do break
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.EndDrawing()
		frames += 1
	}
	fmt.println("Done")
}
