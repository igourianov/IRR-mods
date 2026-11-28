-- config.lua: user editable. Hot reloads with Ctrl+R in the UE4SS console.

return {
	-- "error" | "warn" | "info" | "debug"
	log_level = "info",

	-- Set false to load the mod inert, e.g. to bisect a crash after a game patch.
	enabled = true,

	-- Longest press that counts as a tap, milliseconds. A longer press is a hold.
	-- Used by Flashlight, Smart Heal, Hold Breath, Switch Fire Mode (Tap/Hold), Smart Grenade, Smart Fire Mode and Adrenaline/Food.
	tap_ms = 250,

	-- Longest gap after a tap for a second press to count as a double tap, milliseconds. Used by Smart Grenade and Smart Fire Mode.
	-- A single tap waits out this window, so a higher value delays every frag and every switch to semi.
	double_tap_ms = 200,

	-- The zoom input unfolds a hybrid sight's magnifier on scroll forward and folds it on scroll back.
	-- Set false for vanilla zoom.
	magnifier_zoom = true,

	-- The weapon returns to low ready as soon as aiming, sprinting, firing or any other action ends.
	-- Needs auto low ready on in the gameplay settings. Set false for the game's own auto low ready.
	low_ready_default = true,

	-- Sprint while crouched and moving stands up into a full sprint. Run keeps the crouch walk.
	-- Set false to stay crouched on Sprint.
	sprint_cancels_crouch = true,

	-- Quest objective markers get a colored ring: bomb and bug placement spots, mission phones, quest items, mission boxes and delivery boxes.
	-- Every interaction marker shows through walls within its range, and F reaches it through them.
	-- Set false for vanilla markers.
	plant_marker = true,
	-- Ring color, "#RRGGBB".
	plant_marker_color = "#33B5FF",
	-- Meters at which an objective marker first shows, where vanilla is shorter. 0 keeps vanilla.
	plant_marker_range = 10,

	-- Inventory tiles show uses as whole numbers and condition as a percentage.
	-- Single use items show no count until used. USB hacking devices show uses as a percentage. Equipment slots keep the vanilla bar.
	-- Set false for vanilla decimals.
	whole_uses = true,

	-- Shift+Click sells an item in the hideout.
	quick_sell = true,

	-- A quick slot whose item is gone rebinds to another item of the same type, partly used first.
	-- Clicking a quick slot in the inventory clears it. A single use item's slot shows how many the inventory holds.
	-- Set false for vanilla, where the slot empties after one use.
	quick_slot_refill = true,

	-- Every in-game clock shows 24 hour time, deploy screen included.
	clock_24h = true,

	-- Painkiller temporary health color on the HUD health bar, "#RRGGBB". The bar's overlay lightens it a little.
	-- Set false for the vanilla faint pink.
	temp_health_color = "#ffaa55",

	-- Holding the vanilla Hold Breath key holds breath until release. A tap still toggles.
	-- Set false for toggle only.
	hold_breath = true,

	-- The fire mode card shows in the magazine check card's place. Set false to keep it in the lower right.
	fire_mode_card = true,
}
