package data

import simgui "../../sokol_imgui"

App :: struct {
	models_gen: [dynamic]u32,
	models_ptr: [dynamic]rawptr,
	models_freelist: [dynamic]u32,

	observer_roots: [dynamic]^Subscription,
	
	imgui: simgui.State,
	
	style : Style,
}

