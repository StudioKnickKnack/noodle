// For making a release exe that does not use hot reload.

package main_release

import sapp "../sokol/app"
import slog "../sokol/log"

import game "../game"

main :: proc() {
	sapp.run(
		{
			init_cb = game.game_init,
			frame_cb = game.game_update,
			cleanup_cb = game.game_shutdown,
			width = 1280,
			height = 720,
			window_title = "Odin + Sokol",
			icon = {sokol_default = true},
			logger = {func = slog.func},
		},
	)

	// todo
	// - put tracking allocator checks into game_shutdown
	// - put logger shutdown into game shutdown
}

// make game use good GPU on laptops etc

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1
