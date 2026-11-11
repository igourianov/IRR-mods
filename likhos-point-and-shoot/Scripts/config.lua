-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).
--
-- The key is set in the game's controls menu under the mapping's name (keymap.lua) and polled every tick, so the action gets a real press and release.
-- What the action does with them is its own: PointAim runs from press until release, Flashlight tells a tap from a hold.
--
-- mapping: a player-mappable key name from keymap.lua.
-- action:  a key into the ACTIONS table in actions.lua.

return {
	-- "error" | "warn" | "info" | "debug"
	log_level = "info",

	-- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
	enabled = true,

	-- How long a hold-or-toggle key may be held and still count as a tap, milliseconds.
	-- Released inside this window, the light it turned on stays on until the next press. Held past it, the light goes off on release.
	tap_ms = 250,

	-- The zoom input folds and unfolds the magnifier on a hybrid sight: scroll forward unfolds, scroll back folds.
	-- Set false for vanilla zoom.
	magnifier_zoom = true,

	-- Low ready is the weapon's resting position: the gun lowers as soon as aiming, sprinting, firing or any other action ends.
	-- Works only with auto low ready turned on in the gameplay settings. Set false for the game's own auto low ready.
	low_ready_default = true,
	-- How long after a run ends the gun lowers, milliseconds. Shorter makes the gun dip as the run ends.
	low_ready_run_delay_ms = 150,

	-- The marker on a quest placement spot, where a bomb or bug is planted, is drawn in bright blue, a color rare in the game, so it stands out.
	-- Set false for the vanilla pale marker.
	plant_marker = true,
	-- The marker's color, "#RRGGBB" as in an image editor.
	plant_marker_color = "#33B5FF",
	-- Opacity of the marker while you are out of reach, from 0 to 1. Vanilla is 0.2. 0 keeps vanilla.
	plant_marker_min_opacity = 0.4,

	binds = {
		{
			id      = "point_aim",
			enabled = true,
			mapping = "LikhosPointShootingDirect",   -- Settings > Controls > Point Shooting + Laser (Hold)
			action  = "PointAim",     -- hold to aim straight into point sight
			block_in_ui = true,
		},
		{
			id      = "flashlight",
			enabled = true,
			mapping = "LikhosFlashlight",   -- Settings > Controls > Flashlight (Hold/Toggle)
			action  = "Flashlight",   -- tap to leave the light on, hold to light it while held
			block_in_ui = true,
		},
		{
			id      = "quick_use",
			enabled = true,
			mapping = "LikhosInteractInstant",   -- Settings > Controls > Interact (Instant)
			action  = "QuickUse",     -- tap to use what F would, holds completing at once
			block_in_ui = true,
		},
		{
			id      = "consume",
			enabled = true,
			mapping = "LikhosConsumeFoodDrink",   -- Settings > Controls > Consume Food/Drink
			action  = "ConsumeFoodDrink",     -- use the first usable food or drink item in the inventory
			block_in_ui = true,
		},
		{
			id      = "combat_heal",
			enabled = true,
			mapping = "LikhosCombatHeal",   -- Settings > Controls > Combat Heal
			action  = "CombatHeal",     -- painkiller, heavy bleed, bleed, fracture or heal, the fastest item first
			block_in_ui = true,
		},
		{
			id      = "adrenaline",
			enabled = true,
			mapping = "LikhosUseAdrenaline",   -- Settings > Controls > Use Adrenaline
			action  = "UseAdrenaline",     -- inject an Adrenaline Injector from anywhere in the inventory
			block_in_ui = true,
		},
	},
}
