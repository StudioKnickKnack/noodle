// Development app exe. Loads app.dll and reloads it whenever it changes.

package main

import sapp "packages:sokol/app"
import slog "packages:sokol/log"
import "base:runtime"
import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:mem"
import "core:os"

when ODIN_OS == .Windows {
	DLL_EXT :: ".dll"
} else when ODIN_OS == .Darwin {
	DLL_EXT :: ".dylib"
} else {
	DLL_EXT :: ".so"
}

// We copy the DLL because using it directly would lock it, which would prevent
// the compiler from writing to it.
copy_dll :: proc(to: string) -> bool {
	exit: i32
	when ODIN_OS == .Windows {
		exit = libc.system(fmt.ctprintf("copy app.dll {0}", to))
	} else {
		exit = libc.system(fmt.ctprintf("cp app" + DLL_EXT + " {0}", to))
	}

	if exit != 0 {
		fmt.printfln("Failed to copy app" + DLL_EXT + " to {0}", to)
		return false
	}

	return true
}

App_API :: struct {
	lib:                dynlib.Library,
	init:               proc "c" (),
	update:             proc "c" (),
	event:              proc "c" (^sapp.Event),
	shutdown:           proc "c" (),
	memory:             proc() -> rawptr,
	memory_size:        proc() -> int,
	hot_reloaded:       proc(mem: rawptr),
	force_restart:      proc() -> bool,
	modification_time:  os.File_Time,
	api_version:        int,
	default_allocator:  mem.Allocator,
	tracking_allocator: mem.Tracking_Allocator,
	old_app_apis:       [dynamic]App_API,
}

load_app_api :: proc(api_version: int) -> (api: App_API, ok: bool) {
	mod_time, mod_time_error := os.last_write_time_by_name("app" + DLL_EXT)
	if mod_time_error != os.ERROR_NONE {
		fmt.printfln(
			"Failed getting last write time of app" + DLL_EXT + ", error code: {1}",
			mod_time_error,
		)
		return
	}

	// NOTE: this needs to be a relative path for Linux to work.
	app_dll_name := fmt.tprintf(
		"{0}app_{1}" + DLL_EXT,
		"./" when ODIN_OS != .Windows else "",
		api_version,
	)
	copy_dll(app_dll_name) or_return

	fmt.printfln("[Hot Reload] Loading and initializing %v", app_dll_name)

	// This proc matches the names of the fields in App_API to symbols in the
	// app DLL. It actually looks for symbols starting with `app_`, which is
	// why the argument `"app_"` is there.
	_, ok = dynlib.initialize_symbols(&api, app_dll_name, "app_", "lib")
	if !ok {
		fmt.printfln("Failed initializing symbols: {0}", dynlib.last_error())
	}

	api.api_version = api_version
	api.modification_time = mod_time
	ok = true

	return
}

unload_app_api :: proc(api: ^App_API) {
	if api.lib != nil {
		fmt.printfln("[Hot Reload] Unloading lib %v", api.lib)
		if !dynlib.unload_library(api.lib) {
			fmt.printfln("Failed unloading lib: {0}", dynlib.last_error())
		}
	}

	fmt.printfln("[Hot Reload] Removing file %v", api.lib)
	if os.remove(fmt.tprintf("app_{0}" + DLL_EXT, api.api_version)) != nil {
		fmt.printfln("Failed to remove app_{0}" + DLL_EXT + " copy", api.api_version)
	}
}

init :: proc "c" (userdata: rawptr) {
	context = runtime.default_context()

	app_api := cast(^App_API)userdata
	app_api.init()

	app_api.default_allocator = context.allocator
	mem.tracking_allocator_init(&app_api.tracking_allocator, app_api.default_allocator)
	context.allocator = mem.tracking_allocator(&app_api.tracking_allocator)
	app_api.old_app_apis = make([dynamic]App_API, context.allocator)
}

update :: proc "c" (userdata: rawptr) {
	context = runtime.default_context()

	app_api := cast(^App_API)userdata
	app_api.update()

	app_dll_mod, app_dll_mod_err := os.last_write_time_by_name("app" + DLL_EXT)

	force_restart := app_api.force_restart()
	if force_restart {
		fmt.printfln("Force restart: {0}", force_restart)
	}
	reload := force_restart
	if app_dll_mod_err == os.ERROR_NONE && app_api.modification_time != app_dll_mod {
		reload = true
	}

	if reload {
		new_app_api, new_app_api_ok := load_app_api(app_api.api_version + 1)
		if new_app_api_ok {
			force_restart = force_restart || app_api.memory_size() != new_app_api.memory_size()
			if !force_restart {
				append(&app_api.old_app_apis, app_api^)
				app_memory := app_api.memory()
				app_api^ = new_app_api
				app_api.hot_reloaded(app_memory)
			} else {
				app_api.shutdown()
				reset_tracking_allocator(&app_api.tracking_allocator)

				for &g in app_api.old_app_apis {
					unload_app_api(&g)
				}

				clear(&app_api.old_app_apis)
				unload_app_api(app_api)
				new_app_api.default_allocator = app_api.default_allocator
				new_app_api.tracking_allocator = app_api.tracking_allocator
				app_api = &new_app_api
				app_api.init()
			}
		}
	}

	if len(app_api.tracking_allocator.bad_free_array) > 0 {
		// for b in app_api.tracking_allocator.bad_free_array {
		// 	log.errorf("Bad free at: %v", b.location)
		// }
	}

	free_all(context.temp_allocator)
}

event :: proc "c" (e: ^sapp.Event, userdata: rawptr) {
	context = runtime.default_context()

	app_api := cast(^App_API)userdata
	app_api.event(e)
}

shutdown :: proc "c" (userdata: rawptr) {
	context = runtime.default_context()

	free_all(context.temp_allocator)

	app_api := cast(^App_API)userdata
	app_api.shutdown()

	reset_tracking_allocator(&app_api.tracking_allocator)

	for &g in app_api.old_app_apis {
		unload_app_api(&g)
	}

	delete(app_api.old_app_apis)

	unload_app_api(app_api)
	mem.tracking_allocator_destroy(&app_api.tracking_allocator)
}

reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
	err := false

	for _, value in a.allocation_map {
		fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
		err = true
	}

	mem.tracking_allocator_clear(a)
	return err
}

main :: proc() {
	app_api, app_api_ok := load_app_api(0)

	if !app_api_ok {
		fmt.println("Failed to load App API")
		return
	}

	sapp.run(
		{
			user_data = &app_api,
			init_userdata_cb = init,
			frame_userdata_cb = update,
			cleanup_userdata_cb = shutdown,
			event_userdata_cb = event,
			width = 1280,
			height = 720,
			window_title = "noodle",
			icon = {sokol_default = true},
			logger = {func = slog.func},
		},
	)
}

// Make app use good GPU on laptops.

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1
