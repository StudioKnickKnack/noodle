package app

import "data"
import "ui/fonts"
import "base:runtime"
import "core:log"
import imgui "packages:imgui"
import simgui "packages:sokol_imgui"
import sapp "packages:sokol/app"
import sg "packages:sokol/gfx"
import sglue "packages:sokol/glue"
import slog "packages:sokol/log"


g_context: runtime.Context
g_app: ^data.App
g_force_reset: bool
g_default_style: data.Style = {
	bg_color = sg.Color{0.1215, 0.1215, 0.1568, 1.0},
}

@(export)
app_event :: proc "c" (e: ^sapp.Event) {
	context = g_context

	#partial switch e.type {
	case .KEY_DOWN:
		if e.key_code == .F6 {
			g_force_reset = true
			return
		}
	}

	simgui.handle_event(e)	
}

update :: proc() {
	simgui.new_frame({
		width = sapp.width(),
		height = sapp.height(),
		delta_time = sapp.frame_duration(),
		dpi_scale = sapp.dpi_scale(),
	})
}

draw :: proc() {
	imgui.SetNextWindowDockID(simgui.main_dock_id(), .FirstUseEver)
	if imgui.Begin("Test") {
		imgui.Text("Hello")
	}
	imgui.End()
	
	action := sg.Pass_Action {
		colors = {
			0 = {
				load_action = .CLEAR,
				clear_value = g_app.style.bg_color,
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
}

@(export)
app_init_window :: proc() {
}

@(export)
app_init :: proc "c" () {
	g_context = runtime.default_context()
	context = g_context
	g_context.logger = log.create_console_logger()

	g_app = new(data.App)
	g_app^ = data.App {
		style = g_default_style,
	}

	env := sglue.environment()
	sg.setup({environment = env, logger = {func = slog.func}})

	simgui.setup(
		&g_app.imgui,
		{ .DockingEnable, .ViewportsEnable },
		{ rawptr(&fonts.GEIST_MEDIUM_compressed_data[0]), uint(fonts.GEIST_MEDIUM_compressed_size) },
	)
	
	app_hot_reloaded(g_app)
}

@(export)
app_shutdown :: proc "c" () {
	context = g_context
	log.destroy_console_logger(context.logger)

	simgui.shutdown()
	sg.shutdown()

	free(g_app)
}

@(export)
app_shutdown_window :: proc() {
}

@(export)
app_memory :: proc() -> rawptr {
	free_all(context.temp_allocator)
	return g_app
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(data.App)
}

@(export)
app_hot_reloaded :: proc(mem: rawptr) {
	if context != g_context {
		g_context = runtime.default_context()
		context = g_context
		g_context.logger = log.create_console_logger()
	}
	
	g_app = (^data.App)(mem)
	simgui.hot_reloaded(&g_app.imgui)
}

@(export)
app_force_restart :: proc() -> bool {
	return g_force_reset
}

