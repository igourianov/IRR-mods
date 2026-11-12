-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).
--
-- The key is set in the game's controls menu on the mapping's row, the mod's own or a vanilla one, and polled every tick, so the action gets a real press and release.
-- What the action does with them is its own: PointAim runs from press until release, Flashlight tells a tap from a hold.
--
-- mapping: a key profile row name, one of the mod's own from keymap.lua or a vanilla one.
-- action:  a key into the ACTIONS table in actions.lua.

return {
	-- "error" | "warn" | "info" | "debug"
	log_level = "info",

	-- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
	enabled = true,

	-- How long a tap/hold key may be held and still count as a tap, milliseconds.
	-- Flashlight: released inside this window, the light it turned on stays on until the next press. Held past it, the light goes off on release.
	-- Combat Heal: released inside this window, it treats the most pressing problem. Held past it, it starts an IV at once.
	-- Hold Breath: released inside this window, the breath stays held until the next press. Held past it, breath is let out on release.
	tap_ms = 250,

	-- The zoom input folds and unfolds the magnifier on a hybrid sight: scroll forward unfolds, scroll back folds.
	-- Set false for vanilla zoom.
	magnifier_zoom = true,

	-- Low ready is the weapon's resting position: the gun lowers as soon as aiming, sprinting, firing or any other action ends.
	-- Works only with auto low ready turned on in the gameplay settings. Set false for the game's own auto low ready.
	low_ready_default = true,
	-- How long after a run ends the gun lowers, milliseconds. Shorter makes the gun dip as the run ends.
	low_ready_run_delay_ms = 150,

	-- The marker on a quest objective has a bright blue ring, a color rare in the game, so it stands out: a placement spot where a bomb or bug is planted, a mission phone, a quest item to pick up and a mission box.
	-- Set false for the vanilla pale markers.
	plant_marker = true,
	-- The ring's color, "#RRGGBB" as in an image editor.
	plant_marker_color = "#33B5FF",
	-- Distance in meters where the marker first shows, for an objective whose vanilla distance is shorter. 0 keeps vanilla.
	plant_marker_range = 10,

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
			-- Set enabled = false for the vanilla toggle.
			id      = "hold_breath",
			enabled = true,
			mapping = "IA_HoldBreath",   -- Settings > Controls > Hold Breath (vanilla key)
			action  = "HoldBreath",   -- tap to toggle as in vanilla, hold to hold breath only while held
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
			mapping = "LikhosCombatHeal",   -- Settings > Controls > Combat Heal (Tap/Hold)
			action  = "CombatHeal",     -- tap: painkiller, heavy bleed, bleed or fracture, the fastest item first. Hold: an IV
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
