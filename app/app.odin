// This file is compiled as part of the `odin.dll` file. It contains the
// procs that `app_hot_reload.exe` will call, such as:
//
// app_init: Sets up the app state
// app_update: Run once per frame
// app_shutdown: Shuts down app and frees memory
// app_memory: Run just before a hot reload, so app.exe has a pointer to the
//		app's memory.
// app_hot_reloaded: Run after a hot reload so that the `g_app` global variable
//		can be set to whatever pointer it was in the old DLL.
//
// Note: When compiled as part of the release executable this whole package is imported as a normal
// odin package instead of a DLL.

package app

import "core:log"
import "data"
import "sim"
import imgui "../imgui"
import simgui "../sokol_imgui"
//import "core:math/linalg"
// import im "../imgui"
// import "../imgui/imgui_impl_metal"
// import mtl "vendor:darwin/Metal"
//import "../imgui/imgui_impl_sokol"
import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import slog "../sokol/log"
import "base:runtime"

PIXEL_WINDOW_HEIGHT :: 180

g_context: runtime.Context
g_app: ^data.App
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
	simgui.new_frame({
		width = sapp.width(),
		height = sapp.height(),
		delta_time = sapp.frame_duration(),
		dpi_scale = sapp.dpi_scale(),
	})
	
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
	g_app.player_pos += input * rl.GetFrameTime() * 100*/
	g_app.some_number += 1

	if g_app.some_number % 100 == 0 {
		if g_app.some_number % 200 == 0 {
			log.info("--- OFF ---")
		} else{
			log.info("--- ON ---")
			sim.model_observe(g_app.counter_dbl, g_app.counter, proc(observer: ^data.Counter, mdl: data.Model(data.Counter), observed: data.Counter) {
				observer.value = observed.value * 2 // should be good
				sim.model_notify(mdl)
			})
		}
	}

	// g := g_app.clear_color[1] - 0.01
	// g_app.clear_color[1] = g < 0.0 ? 1.0 : g

	sim.model_update(g_app.counter, proc(c: ^data.Counter, mdl: data.Model(data.Counter)) {
		c.value += 1
		sim.model_notify(mdl)
	})
}

draw :: proc() {
	show_demo_window := true
	imgui.ShowDemoWindow(&show_demo_window)

	action := sg.Pass_Action {
		colors = {
			0 = {
				load_action = .CLEAR,
				clear_value = {g_app.clear_color[0], g_app.clear_color[1], g_app.clear_color[2], g_app.clear_color[3]},
			},
		},
	}
	sg.begin_pass({action = action, swapchain = sglue.swapchain()})
	simgui.render()
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

	env := sglue.environment()
	sg.setup({environment = env, logger = {func = slog.func}})

	simgui.setup()
	
	// im.CHECKVERSION()
	// im.CreateContext()
	// defer im.DestroyContext()
	// io := im.GetIO()
	// io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad, .DockingEnable, .ViewportsEnable}
	// style := im.GetStyle()
	// style.WindowRounding = 0
	// style.Colors[im.Col.WindowBg].w = 1
	// im.StyleColorsDark()

	// device := (^mtl.Device)(sg.mtl_device())
	// imgui_impl_metal.Init(device)
	// defer imgui_impl_metal.Shutdown()

	g_app = new(data.App)
	g_app^ = data.App {
		some_number = 100,
		clear_color = {0.0, 0.0, 1.0, 1.0},
	}

	g_app.counter = sim.model_new(g_app, data.Counter)
	g_app.counter_dbl = sim.model_new(g_app, data.Counter)
	sim.model_observe(g_app.counter_dbl, proc(c: data.Counter) {
		log.infof("dbl counter is now: %v", c.value)
	})

	app_hot_reloaded(g_app)
}

@(export)
app_shutdown :: proc "c" () {
	context = g_context
	log.destroy_console_logger(context.logger)

	simgui.shutdown()
	sg.shutdown()

	sim.model_delete(g_app.counter)
	sim.model_delete(g_app.counter_dbl)
	free(g_app)
}

@(export)
app_shutdown_window :: proc() {
	//rl.CloseWindow()
}

@(export)
app_memory :: proc() -> rawptr {
	return g_app
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(data.App)
}

@(export)
app_hot_reloaded :: proc(mem: rawptr) {
	g_app = (^data.App)(mem)
}

@(export)
app_force_restart :: proc() -> bool {
	return g_force_reset
}

