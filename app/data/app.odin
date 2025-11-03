package data

import "../../framework/property"
import sg "../../sokol/gfx"

App :: struct {
	some_number:     int,
	reactive_number: property.Property(f32),
	sub:             property.Subscription,
	pass_action:     sg.Pass_Action,
}

