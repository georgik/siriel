package main
import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(800, 600, "Test")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	
	frames: i32 = 0
	for frames < 60 {
		if rl.WindowShouldClose() do break
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawText("Test", 10, 10, 20, rl.BLACK)
		rl.EndDrawing()
		frames += 1
	}
}
