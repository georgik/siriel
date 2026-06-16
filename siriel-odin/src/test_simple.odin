package main

import "core:fmt"
import "core:time"
import rl "vendor:raylib"

main :: proc() {
	fmt.println("Starting...")
	
	rl.InitWindow(800, 600, "Test")
	defer rl.CloseWindow()
	fmt.println("Window initialized")
	
	rl.SetTargetFPS(60)
	fmt.println("FPS set")
	
	fmt.println("About to enter loop")
	
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
