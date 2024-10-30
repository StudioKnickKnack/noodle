// This file is compiled as part of the `odin.dll` file. It contains the
// procs that `game_hot_reload.exe` will call, such as:
//
// game_init: Sets up the game state
// game_update: Run once per frame
// game_shutdown: Shuts down game and frees memory
// game_memory: Run just before a hot reload, so game.exe has a pointer to the
//		game's memory.
// game_hot_reloaded: Run after a hot reload so that the `g_mem` global variable
//		can be set to whatever pointer it was in the old DLL.
//
// Note: When compiled as part of the release executable this whole package is imported as a normal
// odin package instead of a DLL.

package game

import "base:runtime"
//import "core:math/linalg"
import sg "../sokol/gfx"
import slog "../sokol/log"
import sglue "../sokol/glue"
import rl "vendor:raylib"

PIXEL_WINDOW_HEIGHT :: 180

Game_Memory :: struct {
	some_number: int,
	pass_action: sg.Pass_Action,
}

g_mem: ^Game_Memory

update :: proc() {
	/*input: rl.Vector2

	if rl.IsKeyDown(.UP) || rl.IsKeyDown(.W) {
		input.y -= 1
	}
	if rl.IsKeyDown(.DOWN) || rl.IsKeyDown(.S) {
		input.y += 1
	}
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		input.x -= 1
	}
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		input.x += 1
	}

	input = linalg.normalize0(input)
	g_mem.player_pos += input * rl.GetFrameTime() * 100*/
	g_mem.some_number += 1

	g := g_mem.pass_action.colors[0].clear_value.g + 0.01
	g_mem.pass_action.colors[0].clear_value.g = g > 1.0 ? 0.0 : g
}

draw :: proc() {

	sg.begin_pass({action = g_mem.pass_action, swapchain = sglue.swapchain()})
	sg.end_pass()
	sg.commit()
}

@(export)
game_update :: proc "c" () {
	context = runtime.default_context()
	update()
	draw()
	//return !rl.WindowShouldClose()
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)
}

@(export)
game_init :: proc "c" () {
	context = runtime.default_context()

	sg.setup({environment = sglue.environment(), logger = {func = slog.func}})

	g_mem = new(Game_Memory)
	g_mem^ = Game_Memory {
		some_number = 100,
	}
	g_mem.pass_action.colors[0] = { load_action = .CLEAR, clear_value = {1.0, 0.0, 0.0, 1.0}}

	game_hot_reloaded(g_mem)
}

@(export)
game_shutdown :: proc "c" () {
	context = runtime.default_context()
	sg.shutdown()
	free(g_mem)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^Game_Memory)(mem)
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}
