-- consume.lua : the Consume Food/Drink key uses the first usable food or drink item in the inventory (docs/solutions/eat-food-bind.md).
--
-- Every game name here comes from docs/solutions/eat-food-bind.md (Recon).
-- Only reads game state to pick the item. The one call that changes anything is the item's own use.
-- Holds no UObject between calls.

local log       = require("log")
local util      = require("util")
local inventory = require("inventory")

local M = {}

local USE_CONTEXT = "U_UseInventoryItem_C"
-- ItemIdentifier tag prefixes. Medical items sit under Inventory.Items.Medical.
local PREFIXES = { "Inventory.Items.Provisions.Food.", "Inventory.Items.Provisions.Drinks." }

local function is_provision(definition)
	local tag = definition.ItemIdentifier.TagName:ToString()
	for _, prefix in ipairs(PREFIXES) do
		if tag:sub(1, #prefix) == prefix then return true end
	end
	return false
end

--- The definition's use context, or nil.
local function use_context(definition)
	local contexts = definition.ItemContexts
	for i = 1, #contexts do
		local context = contexts[i]
		if util.valid(context) and context:GetClass():GetFName():ToString() == USE_CONTEXT then return context end
	end
	return nil
end

--- The Consume Food/Drink key's press. Game thread.
function M.press()
	local pc = FindFirstOf("PlayerController")
	local pawn = util.valid(pc) and pc.Pawn or nil
	local comp = util.valid(pawn) and inventory.player_component(pc) or nil
	if not comp then
		log.debug("ConsumeFoodDrink: no pawn or inventory component")
		return
	end

	for item in inventory.items(comp, true) do
		local definition = item.ItemDefinition
		if util.valid(definition) and is_provision(definition) and inventory.uses_left(item) > 0 then
			local context = use_context(definition)
			-- No item widget: the bind has none, unlike the context menu.
			if context and context:IsValidContext(pawn, nil, item) then
				log.debug("ConsumeFoodDrink: using %s", definition:GetFullName())
				context:Execute(pawn, nil, item)
				return
			end
		end
	end
	log.debug("ConsumeFoodDrink: no usable food or drink")
end

return M
