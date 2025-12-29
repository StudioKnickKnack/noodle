package app

import "core:log"
import "data"
import "sim"
import imgui "../imgui"
import simgui "../sokol_imgui"
import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import slog "../sokol/log"
import "base:runtime"
import "core:fmt"

g_context: runtime.Context
g_app: ^data.App
g_force_reset: bool

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
	
	g_app.some_number += 1

	if g_app.some_number % 100 == 0 {
		if g_app.some_number % 200 == 0 {
			if g_app.counter_dbl_sub != nil {
				sim.model_unsubscribe(g_app.counter, g_app.counter_dbl_sub)
			}
			g_app.counter_dbl_sub = nil
		} else{
			g_app.counter_dbl_sub = sim.model_observe(g_app.counter_dbl, g_app.counter, proc(observer: ^data.Counter, mdl: data.Model(data.Counter), observed: data.Counter) {
				observer.value = observed.value * 2
				sim.model_notify(mdl)
			})
		}
	}

	sim.model_update(g_app.counter, proc(c: ^data.Counter, mdl: data.Model(data.Counter)) {
		c.value += 1
		sim.model_notify(mdl)
	})
}

draw :: proc() {
	// show_demo_window := true
	// imgui.ShowDemoWindow(&show_demo_window)

	imgui.SetNextWindowDockID(simgui.main_dock_id(), .FirstUseEver)
	imgui.SetNextWindowSize({ 300, 200 })
	if imgui.Begin("Test") {
		imgui.Text(g_app.counter_dbl_sub != nil ? "ON" : "OFF")
		_ = fmt.ctprintf("test test: %v\n", g_app)
		sim.model_get(g_app.counter, proc(c: data.Counter) {
			_ = fmt.ctprintf("test test: %v\n", g_app)
			imgui.Text(fmt.ctprintf("Counter: %v", c.value))
		})
		sim.model_get(g_app.counter_dbl, proc(c: data.Counter) {
			imgui.Text(fmt.ctprintf("Double-Counter: %v", c.value))
		})
	}
	imgui.End()
	
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
	_ = fmt.ctprintf("test test: %v\n", g_app)
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
		some_number = 100,
		clear_color = {0.0, 0.0, 1.0, 1.0},
	}

	env := sglue.environment()
	sg.setup({environment = env, logger = {func = slog.func}})

	simgui.setup(&g_app.imgui, {.DockingEnable, .ViewportsEnable})
	
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

	g_app.counter = sim.model_new(g_app, data.Counter)
	g_app.counter_dbl = sim.model_new(g_app, data.Counter)
	// sim.model_observe(g_app.counter_dbl, proc(c: data.Counter) {
	// 	log.infof("dbl counter is now: %v", c.value)
	// })

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
	free_all(context.temp_allocator)

	fmt.println("[Hot Reload] App about to hot reload, storing state..")
	return g_app
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(data.App)
}

@(export)
app_hot_reloaded :: proc(mem: rawptr) {
	fmt.println("[Hot Reload] App hot reloaded, restoring state")

	if context != g_context {
		fmt.println("[Hot Reload] App hot reloaded, restoring context")
		g_context = runtime.default_context()
		context = g_context
		g_context.logger = log.create_console_logger()
	}
	
	g_app = (^data.App)(mem)
	simgui.hot_reloaded(&g_app.imgui)

	_ = fmt.ctprintf("test test: %v\n", g_app)
}

@(export)
app_force_restart :: proc() -> bool {
	return g_force_reset
}

