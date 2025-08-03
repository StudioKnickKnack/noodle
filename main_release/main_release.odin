// For making a release exe that does not use hot reload.

package main_release

import sapp "../sokol/app"
import slog "../sokol/log"

import app "../app"

main :: proc() {
	sapp.run(
		{
			init_cb = app.app_init,
			frame_cb = app.app_update,
			cleanup_cb = app.app_shutdown,
			event_cb = app.app_event,
			width = 1280,
			height = 720,
			window_title = "Odin + Sokol",
			icon = {sokol_default = true},
			logger = {func = slog.func},
		},
	)

	// todo
	// - put tracking allocator checks into app_shutdown
	// - put logger shutdown into app shutdown
}

// make app use good GPU on laptops etc

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1
