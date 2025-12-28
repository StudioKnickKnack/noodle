package data

App :: struct {
	models_gen: [dynamic]u32,
	models_ptr: [dynamic]rawptr,
	models_freelist: [dynamic]u32,

	observer_roots: [dynamic]^Subscription,
	
	some_number: int,
	clear_color: [4]f32,

	counter: Model(Counter),
	counter_dbl: Model(Counter),
	counter_dbl_sub: ^Subscription,
}

