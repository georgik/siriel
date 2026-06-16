package main
import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
	fmt.println("Before window")
	fmt.flush()
	
	rl.InitWindow(800, 600, "Test")
	defer rl.CloseWindow()
	
	// Try to restore stdout
	fmt.println("After window")
	fmt.flush()
	
	rl.SetTargetFPS(60)
	
	frames: i32 = 0
	for frames < 10 {
		if rl.WindowShouldClose() do break
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawText("Test", 10, 10, 20, rl.BLACK)
		rl.EndDrawing()
		frames += 1
	}
	fmt.println("Done")
}
