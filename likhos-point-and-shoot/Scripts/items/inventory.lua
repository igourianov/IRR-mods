-- items/inventory.lua : item reads shared by the consumable binds, the quick slots and the inventory tiles.
-- Holds no UObject between calls.

local util = require("lib.util")

local M = {}

local USES_TAG    = "Inventory.Stats.Durability"

--- The uses stat's config class. Its tag, USES_TAG, is shared with weapon and armor durability, so a definition's stats are told apart by this class.
M.USES_CONFIG = "U_Content_C"

-- Settings classes of a slot's container: its own item grid, or a place for one equipped item.
local SPATIAL_SETTINGS = "InventorySpatialContainerSettings"
local EQUIP_SETTINGS   = "InventoryEquipToContainerSettings"

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

--- Every item of comp, nested storage included: `for item in inventory.items(comp, grid, only)`.
--- MainContainers is flat and holds each container item's storage as its own entry. With grid, each container's items come in grid order, else in ContainerItems order.
--- With only, a set from M.slot_storage, just the items directly in those containers.
--- The items are the ones read from the property, so they can be passed to a use context. A ContainerItem returned by one UFunction crashes the game when passed to another, still on UE4SS 1217, and UE4SS before 1217 crashes converting a returned ContainerItem to Lua.
function M.items(comp, grid, only)
	local containers = comp.MainContainers
	local container_count = #containers
	local i, j, item_count = 0, 0, 0
	local items = nil
	return function()
		while j >= item_count do
			i = i + 1
			if i > container_count then return nil end
			local container = containers[i]
			j, item_count = 0, 0
			if not only or only[util.guid_str(container.MainContainerUID)] then
				items = grid and grid_order(container) or container.ContainerItems
				item_count = #items
			end
		end
		j = j + 1
		return items[j]
	end
end

--- The main containers storing what the player's slots hold, as a set of util.guid_str UIDs for M.items and M.usable.
--- slots is a set of default container classes, like U_Rig_C. A slot with its own grid counts itself. A slot holding equipment counts the equipped item's storage, which is the main container under that item's UID.
---@return table<string, boolean>
function M.slot_storage(comp, slots)
	local ids = {}
	local containers = comp.MainContainers
	for i = 1, #containers do
		local container = containers[i]
		local elements = container.ContainerElements
		-- MainContainers interleaves each slot with the storage of what it holds, so a slot is told by its one element, whose settings are a subobject of the slot's default container.
		local settings = #elements == 1 and elements[1].ContainerSettings or nil
		local outer = util.valid(settings) and settings:GetOuter() or nil
		local kind = util.valid(outer) and slots[util.class_name(outer)] and util.class_name(settings) or nil
		if kind == SPATIAL_SETTINGS then
			ids[util.guid_str(container.MainContainerUID)] = true
		elseif kind == EQUIP_SETTINGS then
			local equipped = container.ContainerItems
			for j = 1, #equipped do ids[util.guid_str(equipped[j].ItemUID)] = true end
		end
	end
	return ids
end

function M.item_id(definition)
	return definition.ItemIdentifier.TagName:ToString()
end

function M.has_prefix(definition, prefix)
	return M.item_id(definition):sub(1, #prefix) == prefix
end

--- The items of comp in grid order whose ItemIdentifier starts with one of prefixes and that have uses left: `for item, uses in inventory.usable(comp, prefixes, only)`.
--- only limits them to the containers of a set from M.slot_storage.
function M.usable(comp, prefixes, only)
	local next_item = M.items(comp, true, only)
	return function()
		for item in next_item do
			local definition = item.ItemDefinition
			local id = util.valid(definition) and M.item_id(definition) or ""
			for _, prefix in ipairs(prefixes) do
				if id:sub(1, #prefix) == prefix then
					local uses = M.uses_left(item)
					if uses > 0 then return item, uses end
					break
				end
			end
		end
		return nil
	end
end

---@return number?
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

---@return StructValue? # the ItemStats entry whose config is of class
function M.config_stat(definition, class)
	local stats = definition.ItemStats
	for i = 1, #stats do
		local stat = stats[i]
		local config = stat.StatItemConfig
		if util.valid(config) and util.class_name(config) == class then return stat end
	end
	return nil
end

return M
