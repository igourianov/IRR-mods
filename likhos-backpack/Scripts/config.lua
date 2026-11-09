-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).

return {
	-- "error" | "warn" | "info" | "debug"
	log_level = "info",

	-- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
	enabled = true,

	-- Items that count uses, like medical items and keys, show them as whole numbers on inventory tiles.
	-- Single use items show no count until used. USB hacking devices show their remaining uses as a percentage.
	-- Set false for the vanilla decimals.
	whole_uses = true,

	-- Shift+Click on an item in the hideout sells it, like Sell from its context menu. A mission item is delivered instead, like Deliver.
	-- Set false for the vanilla behavior, where it does nothing.
	quick_sell = true,

	-- A quick slot whose item leaves the inventory, used up or otherwise, rebinds to another item of the same type from the inventory, partly used ones first.
	-- A click on a quick slot in the inventory screen clears it.
	-- A quick slot of a single use item, like an injector or a grenade, shows how many of its type the inventory holds.
	-- Set false for the vanilla behavior, where the slot empties after one use.
	quick_slot_refill = true,
}
