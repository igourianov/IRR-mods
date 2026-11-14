-- inventory.lua : inventory reads shared by the consumable binds, the quick slots and the inventory tiles.
-- Holds no UObject between calls.

local util = require("util")

local M = {}

local LIBRARY_CDO = "/Script/Test_C.Default__InventoryFunctionLibrary"
local INPUT_LIB   = "/Script/Engine.Default__KismetInputLibrary"
local USES_TAG    = "Inventory.Stats.Durability"

--- The uses stat's config class. Its tag, USES_TAG, is shared with weapon and armor durability, so a definition's stats are told apart by this class.
M.USES_CONFIG = "U_Content_C"

--- The inventory component of pc, which holds the main containers and the quick slots, or nil outside a level with a player.
function M.player_component(pc)
	local library = StaticFindObject(LIBRARY_CDO)
	local comp = util.valid(pc) and util.valid(library) and library:GetPlayerInventoryComponent(pc) or nil
	return util.valid(comp) and comp or nil
end

--- The main container's items sorted by sub-grid ascending, then by slot descending.
--- ContainerItems is not kept in grid order, so walking it as is picks an item seemingly at random.
local function grid_order(container)
	local sorted = {}
	local items = container.ContainerItems
	for i = 1, #items do sorted[i] = items[i] end
	table.sort(sorted, function(a, b)
		local a_grid, b_grid = a.ContainerIndex, b.ContainerIndex
		if a_grid ~= b_grid then return a_grid < b_grid end
		return a.SlotIndex > b.SlotIndex
	end)
	return sorted
end

--- Every item of comp, nested storage included: `for item in inventory.items(comp, grid)`.
--- MainContainers is flat and holds each container item's storage as its own entry. With grid, each container's items come in grid order, else in ContainerItems order.
--- The items are the ones read from the property, so they can be passed to a use context. A ContainerItem returned by one UFunction crashes the game when passed to another, still on UE4SS 1217, and UE4SS before 1217 crashes converting a returned ContainerItem to Lua.
function M.items(comp, grid)
	local containers = comp.MainContainers
	local container_count = #containers
	local i, j, item_count = 0, 0, 0
	local items = nil
	return function()
		while j >= item_count do
			i = i + 1
			if i > container_count then return nil end
			items = grid and grid_order(containers[i]) or containers[i].ContainerItems
			j, item_count = 0, #items
		end
		j = j + 1
		return items[j]
	end
end

--- The item's CurrentStats value under tag, or nil.
function M.stat(item, tag)
	local stats = item.CurrentStats
	for i = 1, #stats do
		local s = stats[i]
		if s.Tag.TagName:ToString() == tag then return s.Value end
	end
	return nil
end

--- The item's uses left, or math.huge for an item that doesn't count uses.
function M.uses_left(item)
	return M.stat(item, USES_TAG) or math.huge
end

--- The definition's ItemStats entry whose config is of class, or nil.
function M.config_stat(definition, class)
	local stats = definition.ItemStats
	for i = 1, #stats do
		local stat = stats[i]
		local config = stat.StatItemConfig
		if util.valid(config) and config:GetClass():GetFName():ToString() == class then return stat end
	end
	return nil
end

--- For a left click on an item tile, { shift, ctrl, alt }, each whether it is held, or nil for another button. Only callable while the click handler runs, when mouse_event is readable.
--- UE4SS won't pass the click's PointerEvent as the InputEvent InputEvent_IsShiftDown takes, so the state comes from Slate's current modifier state.
--- The mask's bits are engine-internal, so the library decodes it, from a fresh struct rather than the returned one (docs/solutions/hideout-quick-sell.md).
function M.left_click_modifiers(mouse_event)
	local input = StaticFindObject(INPUT_LIB)
	if input:PointerEvent_GetEffectingButton(mouse_event:get()).KeyName:ToString() ~= "LeftMouseButton" then return nil end
	local keys = { ModifierKeysStateMask = input:GetModifierKeysState().ModifierKeysStateMask }
	return { shift = input:ModifierKeysState_IsShiftDown(keys), ctrl = input:ModifierKeysState_IsControlDown(keys), alt = input:ModifierKeysState_IsAltDown(keys) }
end

return M
