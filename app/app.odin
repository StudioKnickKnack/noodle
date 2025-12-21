// This file is compiled as part of the `odin.dll` file. It contains the
// procs that `app_hot_reload.exe` will call, such as:
//
// app_init: Sets up the app state
// app_update: Run once per frame
// app_shutdown: Shuts down app and frees memory
// app_memory: Run just before a hot reload, so app.exe has a pointer to the
//		app's memory.
// app_hot_reloaded: Run after a hot reload so that the `g_mem` global variable
//		can be set to whatever pointer it was in the old DLL.
//
// Note: When compiled as part of the release executable this whole package is imported as a normal
// odin package instead of a DLL.

package app

import "core:log"
import "data"
import "sim"
//import "core:math/linalg"
import im "../imgui"
import "../imgui/imgui_impl_metal"
import mtl "vendor:darwin/Metal"
//import "../imgui/imgui_impl_sokol"
import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import slog "../sokol/log"
import "base:runtime"

PIXEL_WINDOW_HEIGHT :: 180

g_context: runtime.Context
g_mem: ^data.App
g_force_reset: bool

@(export)
app_event :: proc "c" (e: ^sapp.Event) {
	#partial switch e.type {
	case .KEY_DOWN:
		if e.key_code == .F6 {
			g_force_reset = true
		}
	}
}

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

	if g_mem.some_number % 100 == 0 {
		if g_mem.some_number % 200 == 0 {
			log.info("--- OFF ---")
		} else{
			log.info("--- ON ---")
			sim.model_observe(g_mem.counter_dbl, g_mem.counter, proc(observer: ^data.Counter, mdl: data.Model(data.Counter), observed: data.Counter) {
				observer.value = observed.value * 2 // should be good
				sim.model_notify(mdl)
			})
		}
	}

	b := g_mem.pass_action.colors[0].clear_value.b - 0.01
	g_mem.pass_action.colors[0].clear_value.b = b < 0.0 ? 1.0 : b

	sim.model_update(g_mem.counter, proc(c: ^data.Counter, mdl: data.Model(data.Counter)) {
		c.value += 1
		sim.model_notify(mdl)
	})
}

draw :: proc() {

	sg.begin_pass({action = g_mem.pass_action, swapchain = sglue.swapchain()})
	sg.end_pass()
	sg.commit()
}

@(export)
app_update :: proc "c" () {
	context = g_context
	update()
	draw()
	//return !rl.WindowShouldClose()
}

@(export)
app_init_window :: proc() {
	/*rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Odin + Raylib + Hot Reload template!")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(500)*/
}

@(export)
app_init :: proc "c" () {
	g_context = runtime.default_context()
	context = g_context
	g_context.logger = log.create_console_logger()
	log.info("this is info")
	log.error("this is error")

	sg.setup({environment = sglue.environment(), logger = {func = slog.func}})

	im.CHECKVERSION()
	im.CreateContext()
	defer im.DestroyContext()
	io := im.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad, .DockingEnable, .ViewportsEnable}
	style := im.GetStyle()
	style.WindowRounding = 0
	style.Colors[im.Col.WindowBg].w = 1
	im.StyleColorsDark()

	device := (^mtl.Device)(sg.mtl_device())

	imgui_impl_metal.Init(device)
	defer imgui_impl_metal.Shutdown()

	g_mem = new(data.App)
	g_mem^ = data.App {
		some_number = 100,
	}
	g_mem.pass_action.colors[0] = {
		load_action = .CLEAR,
		clear_value = {1.0, 0.0, 0.0, 1.0},
	}

	g_mem.counter = sim.app_new_model(g_mem, data.Counter)
	g_mem.counter_dbl = sim.app_new_model(g_mem, data.Counter)
	sim.model_observe(g_mem.counter_dbl, proc(c: data.Counter) {
		log.infof("dbl counter is now: %v", c.value)
	})

	app_hot_reloaded(g_mem)
}

@(export)
app_shutdown :: proc "c" () {
	context = g_context
	log.destroy_console_logger(context.logger)
	sg.shutdown()

	sim.app_delete_model(g_mem, g_mem.counter)
	sim.app_delete_model(g_mem, g_mem.counter_dbl)
	free(g_mem)
}

@(export)
app_shutdown_window :: proc() {
	//rl.CloseWindow()
}

@(export)
app_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(data.App)
}

@(export)
app_hot_reloaded :: proc(mem: rawptr) {
	g_mem = (^data.App)(mem)
}

@(export)
app_force_restart :: proc() -> bool {
	return g_force_reset
}

