-- items/smart_grenade.lua : the Smart Grenade key equips a grenade by category from the rig or pockets: tap for frag, hold for smoke, double tap for flashbang (docs/solutions/smart-grenade.md).
--
-- Every game name here comes from docs/solutions/smart-grenade.md (Recon).
-- A gesture for the category already in hand does nothing.
-- Only reads game state to pick the item. The one call that changes anything is the item's own use, which equips it. Throwing stays the game's own action.
-- Holds no UObject between calls.

local log       = require("lib.log")
local util      = require("lib.util")
local player    = require("core.player")
local inventory = require("items.inventory")
local actions   = require("core.actions")

local M = {}

local USE_CONTEXT = "U_UseGadget_C"
local GRENADES    = { "Inventory.Items.Grenades." }
-- The default containers grenades are taken from: the rig, armored or not, and the pockets.
local SLOTS       = { U_Rig_C = true, U_Belt_C = true }

--- Category -> ItemIdentifier tags, most expensive first by the vendor table's default market price.
local CATEGORIES = {
	frag = {
		"Inventory.Items.Grenades.RGO Grenade",
		"Inventory.Items.Grenades.F-1 Hand Grenade",
		"Inventory.Items.Grenades.M67 Hand Grenade",
	},
	smoke = {
		"Inventory.Items.Grenades.RGR Gas Grenade",
		"Inventory.Items.Grenades.RGD_Smoke_Grenade",
	},
	flashbang = {
		"Inventory.Items.Grenades.Zarya Flash Grenade",
	},
}

--- ItemIdentifier -> its category.
local CATEGORY_OF = {}
for category, ids in pairs(CATEGORIES) do
	for _, id in ipairs(ids) do CATEGORY_OF[id] = category end
end

---@return UObject?
local function use_context(definition)
	local contexts = definition.ItemContexts
	for i = 1, #contexts do
		local context = contexts[i]
		if util.valid(context) and util.class_name(context) == USE_CONTEXT then return context end
	end
	return nil
end

--- Equip the most expensive usable grenade of category, unless one of that category is already in hand. Game thread.
local function equip(category)
	local pawn = player.pawn()
	local comp = pawn and player.inventory()
	local equipment = pawn and pawn:GetEquipmentComponent()
	if not (comp and util.valid(equipment)) then
		log.debug("SmartGrenade: no pawn, inventory or equipment component")
		return
	end

	-- Repeating the use with this category in hand put a frag in hand instead (seen in game 2026-11-23).
	-- Read from the property: UE4SS before 1217 crashes converting a ContainerItem returned by GetEquippedItem.
	local held = equipment.LocEquippedItem.Item.ItemDefinition
	if util.valid(held) and CATEGORY_OF[inventory.item_id(held)] == category then
		log.debug("SmartGrenade: %s: already in hand", category)
		return
	end

	local by_id = {}
	for item in inventory.usable(comp, GRENADES, inventory.slot_storage(comp, SLOTS)) do
		local id = inventory.item_id(item.ItemDefinition)
		local same = by_id[id]
		if same then same[#same + 1] = item else by_id[id] = { item } end
	end

	for _, id in ipairs(CATEGORIES[category]) do
		for _, item in ipairs(by_id[id] or {}) do
			local context = use_context(item.ItemDefinition)
			-- No item widget: the bind has none, unlike the context menu.
			if context and context:IsValidContext(pawn, nil, item) then
				log.debug("SmartGrenade: %s: equipping %s", category, id)
				context:Execute(pawn, nil, item)
				return
			end
		end
	end
	log.debug("SmartGrenade: %s: none usable in the rig or pockets", category)
end

--- Define the SmartGrenade action.
function M.install()
	actions.define("SmartGrenade", {
		tap        = function() equip("frag") end,
		hold       = function() equip("smoke") end,
		double_tap = function() equip("flashbang") end,
	})
end

return M
