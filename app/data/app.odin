package data

import sg "../../sokol/gfx"

App :: struct {
	models_gen: [dynamic]u32,
	models_ptr: [dynamic]rawptr,
	models_freelist: [dynamic]u32,

	observer_roots: [dynamic]^Subscription,
	
	some_number:     int,
	pass_action:     sg.Pass_Action,

	counter: Model(Counter),
	counter_dbl: Model(Counter),
}

