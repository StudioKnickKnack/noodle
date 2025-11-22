package data

import "../../framework/property"
import sg "../../sokol/gfx"

App :: struct {
	models_gen: [dynamic]u32,
	models_ptr: [dynamic]rawptr,
	models_freelist: [dynamic]u32,

	some_number:     int,
	reactive_number: property.Property(f32),
	sub:             property.Subscription,
	pass_action:     sg.Pass_Action,
}

