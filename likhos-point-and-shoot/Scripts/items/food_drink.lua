-- items/food_drink.lua : the Consume Food/Drink key uses the first usable food or drink item in the inventory (docs/solutions/eat-food-bind.md).
--
-- Every game name here comes from docs/solutions/eat-food-bind.md (Recon).
-- Only reads game state to pick the item. The one call that changes anything is the item's own use.
-- Holds no UObject between calls.

local log       = require("lib.log")
local util      = require("lib.util")
local player    = require("core.player")
local inventory = require("items.inventory")
local actions   = require("core.actions")

local M = {}

local USE_CONTEXT = "U_UseInventoryItem_C"
-- ItemIdentifier tag prefixes. Medical items sit under Inventory.Items.Medical.
local PREFIXES = { "Inventory.Items.Provisions.Food.", "Inventory.Items.Provisions.Drinks." }

---@return UObject?
local function use_context(definition)
	local contexts = definition.ItemContexts
	for i = 1, #contexts do
		local context = contexts[i]
		if util.valid(context) and util.class_name(context) == USE_CONTEXT then return context end
	end
	return nil
end

--- The Consume Food/Drink key's press. Game thread.
local function press()
	local pawn = player.pawn()
	local comp = pawn and player.inventory()
	if not comp then
		log.debug("ConsumeFoodDrink: no pawn or inventory component")
		return
	end

	for item in inventory.usable(comp, PREFIXES) do
		local definition = item.ItemDefinition
		local context = use_context(definition)
		-- No item widget: the bind has none, unlike the context menu.
		if context and context:IsValidContext(pawn, nil, item) then
			log.debug("ConsumeFoodDrink: using %s", definition:GetFullName())
			context:Execute(pawn, nil, item)
			return
		end
	end
	log.debug("ConsumeFoodDrink: no usable food or drink")
end

--- Define the ConsumeFoodDrink action.
function M.install()
	actions.define("ConsumeFoodDrink", {
		press = press,
	})
end

return M
