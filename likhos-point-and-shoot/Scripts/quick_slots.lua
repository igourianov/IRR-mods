-- quick_slots.lua : a quick slot binds an item definition. Once its item leaves the inventory it rebinds to another item of the same definition from the inventory (docs/solutions/quick-slot-refill.md, docs/solutions/quick-slot-whole-inventory.md, docs/solutions/quick-slot-type-bind.md).
-- A quick slot naming an item that is no longer in the inventory, with none of its definition left, is cleared (docs/solutions/quick-slot-left-inventory.md).
-- A bare left click on a quick slot's tile clears the slot (docs/solutions/quick-slot-click-clear.md).
--
-- Every game name here comes from those docs.
-- Items leave the inventory through several paths, some native, and the quick slot widgets exist only in the inventory screen, so the slots are polled rather than hooked.
-- Holds no UObject between polls: records keep UIDs and paths only.

local log  = require("log")
local util = require("util")
local hook = require("hook")
local inventory = require("inventory")

local M = {}

local hooks = hook.new("quick slot clear", "a click on a quick slot stays vanilla")

local TILE_CLASS   = "/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C"
local SLOT_COUNT   = 4
-- Short so a slot refills right after its item leaves.
local POLL_MS      = 50
-- The tile count walks every item tile, so it runs on every COUNT_EVERY-th poll only.
local COUNT_EVERY  = 5
local SLOT_WIDGET  = "W_QuickSlotContainer_C"
local TILE_WIDGET  = "W_InventoryItem_C"

-- ESlateVisibility
local COLLAPSED          = 1
local HIDDEN             = 2
local HIT_TEST_INVISIBLE = 3

local function guid_str(g)
	return string.format("%08x%08x%08x%08x", g.A & 0xffffffff, g.B & 0xffffffff, g.C & 0xffffffff, g.D & 0xffffffff)
end

local function is_zero(g)
	return g.A == 0 and g.B == 0 and g.C == 0 and g.D == 0
end

--- Whether comp holds an item with uid.
local function holds(comp, uid)
	for item in inventory.items(comp) do
		if util.same_guid(item.ItemUID, uid) then return true end
	end
	return false
end

--- For each slot index of wanted (index -> uid), the item of comp with that uid. One pass over the inventory.
local function locate(comp, wanted)
	local found = {}
	if next(wanted) == nil then return found end
	for item in inventory.items(comp) do
		local uid = item.ItemUID
		for index, w in pairs(wanted) do
			if util.same_guid(uid, w) then found[index] = item end
		end
	end
	return found
end

--- The definition path of item when it has uses left, or nil.
--- A spent item can sit at 0 uses: briefly before the game removes it, or for good when saved that way by an older version of this mod.
local function usable_def(item)
	local definition = item.ItemDefinition
	if not util.valid(definition) or inventory.uses_left(item) <= 0 then return nil end
	return definition:GetFullName()
end

--- Whether items of definition are used up in one use: a uses stat of 1, or no uses stat and no stacking (grenades).
local function single_use(definition)
	if not util.valid(definition) then return false end
	local stat = inventory.config_stat(definition, inventory.USES_CONFIG)
	if stat then return stat.Value == 1 end
	return not definition.ItemProperties.CanStack
end

-- slot index -> { uid, def, single }, the last live binding of each slot. single is whether its definition is single use.
local records = {}
-- Path of the inventory component the records came from.
local records_comp = nil

-- The item UpdateQuickSlot takes to clear a slot.
local EMPTY_ITEM = { ItemUID = { A = 0, B = 0, C = 0, D = 0 } }

--- The player's inventory component, which holds the quick slots, or nil outside a level with a player.
local function player_inventory()
	return inventory.player_component(FindFirstOf("PlayerController"))
end

--- Track the live binding of slot index, refill the slot once its recorded item has left the inventory, or clear it while it names an item outside the inventory.
--- uid is the slot's QuickSlots entry, or nil. item is that item from locate, or nil when the entry is stale.
local function check_slot(comp, index, uid, item)
	local record = records[index]
	if item then
		if record and util.same_guid(record.uid, uid) then return end
		local definition = item.ItemDefinition
		local def = util.valid(definition) and definition:GetFullName() or nil
		local single = single_use(definition)
		records[index] = { uid = uid, def = def, single = single }
		log.debug("quick slot %d bound to %s %s, single use %s", index, tostring(def), guid_str(uid), tostring(single))
		return
	end

	records[index] = nil
	-- The recorded item left the inventory: used up, dropped, discarded, sold, stashed or carried out by its container. The game deletes the slot's entry in all but the last case.
	-- Otherwise the slot was cleared by hand with its item still in the inventory, and stays empty.
	local left = record and record.def and not holds(comp, record.uid)
	-- Fewest uses left first, so partly used items are finished before fresh ones. Ties keep container order.
	local refill, refill_uses
	if left then
		for candidate in inventory.items(comp) do
			if usable_def(candidate) == record.def then
				local uses = inventory.uses_left(candidate)
				if not refill or uses < refill_uses then refill, refill_uses = candidate, uses end
			end
		end
	end
	if refill then
		local new_uid = util.guid(refill.ItemUID)
		comp:UpdateQuickSlot(index, refill)
		records[index] = { uid = new_uid, def = record.def, single = record.single }
		log.debug("quick slot %d refilled with %s %s", index, record.def, guid_str(new_uid))
		return
	end
	if left then log.debug("quick slot %d empty: no %s left", index, record.def) end
	-- An entry naming an item outside the inventory, with nothing to refill it: the item sat in a container moved to another inventory, like the stash or the floor, and the game leaves the slot bound then.
	if not uid then return end
	comp:UpdateQuickSlot(index, EMPTY_ITEM)
	log.debug("quick slot %d cleared: %s is not in the inventory", index, guid_str(uid))
end

--- Show count on a quick slot tile in place of its uses.
--- Only texts and a hidden ItemCapacity change, which the game's own redraw sets again for the next item the tile shows.
local function show_count(tile, count)
	local capacity, max = tile.ItemCapacity, tile.ItemMaxCapacity
	if not (util.valid(capacity) and util.valid(max)) then return end
	local text = tostring(count)
	local shown, max_shown = capacity:GetText():ToString(), max:GetText():ToString()
	local visibility = capacity:GetVisibility()
	local hidden = visibility == COLLAPSED or visibility == HIDDEN
	if shown == text and max_shown == "" and not hidden then return end
	capacity:SetText(FText(text))
	max:SetText(FText(""))
	if hidden then capacity:SetVisibility(HIT_TEST_INVISIBLE) end
end

-- Polls run since load, to pace the tile count.
local polls = 0

--- The slot index of tile when it is a quick slot tile of the inventory screen at screen_path showing its slot's recorded item, or nil.
--- A tile's BaseContainerElementRef is the container element it was created for, here the quick slot widget.
--- Neither the quick slot widget's ItemRef nor its GetContainerItems() gives the tile: the widget overrides AddItem and GetContainerItems, and the call returns an empty array to Lua.
--- The inventory screen of an earlier level stays alive, its quick slot tiles showing the same bound items (seen in game 2026-11-09), so a tile counts only under the current screen.
--- A tile the slot has replaced keeps its slot and item until garbage collection, which can take a minute (seen in game 2026-11-09), so a tile counts only while it has a parent.
local function tile_slot(tile, screen_path)
	local element = tile.BaseContainerElementRef
	if not (util.valid(element) and element:GetClass():GetFName():ToString() == SLOT_WIDGET) then return nil end
	local index = element.QuickSlotIndex
	local record = records[index]
	if not (record and util.same_guid(tile.ContainerItem.ItemUID, record.uid) and util.valid(tile:GetParent())) then return nil end
	if util.path(tile):sub(1, #screen_path + 1) ~= screen_path .. "." then return nil end
	return index
end

local function quick_slot_tiles(screen_path)
	local tiles = {}
	for _, tile in ipairs(FindAllOf(TILE_WIDGET) or {}) do
		local index = util.valid(tile) and tile_slot(tile, screen_path) or nil
		if index then tiles[index] = tile end
	end
	return tiles
end

-- slot index -> path of the tile last found by quick_slot_tiles. Once the inventory screen has been opened its widgets stay, so without it every count pass would walk every item tile, stash included.
local tile_paths = {}

--- Definition path -> how many items of comp have it and uses left, for the definitions of the records of the slot index keys of slots. One pass over the inventory.
local function count_matching(comp, slots)
	local counts = {}
	for index in pairs(slots) do counts[records[index].def] = 0 end
	for item in inventory.items(comp) do
		local def = usable_def(item)
		local count = def and counts[def]
		if count then counts[def] = count + 1 end
	end
	return counts
end

local function poll()
	local comp = player_inventory()
	local path = comp and util.path(comp) or nil
	if path ~= records_comp then
		records, records_comp = {}, path
		return
	end
	if not path then return end

	-- Read from the QuickSlots property, not GetContainerItemByQuickSlotIndex. UE4SS before 1217 crashes converting that function's returned ContainerItem to Lua, at its SoftItemDefinition, and the mod still runs there.
	local wanted = {}
	local slots = comp.QuickSlots
	for i = 1, #slots do
		local slot = slots[i]
		local uid = util.guid(slot.ItemUID)
		if not is_zero(uid) then wanted[slot.Index] = uid end
	end
	local found = locate(comp, wanted)
	for index = 0, SLOT_COUNT - 1 do check_slot(comp, index, wanted[index], found[index]) end

	polls = polls + 1
	if polls % COUNT_EVERY ~= 0 then return end
	-- The component's inventory screen, W_PlayerInventory_C, which holds the quick slot widgets.
	local screen = comp.InventoryWidgetRef
	if not util.valid(screen) then return end
	local screen_path = util.path(screen)
	local tiles
	-- slot index -> its tile, for the slots that show a count
	local counted = {}
	for index = 0, SLOT_COUNT - 1 do
		local record = records[index]
		if record and record.single and record.def then
			local cached = tile_paths[index] and StaticFindObject(tile_paths[index])
			local tile = util.valid(cached) and tile_slot(cached, screen_path) == index and cached or nil
			if not tile then
				tiles = tiles or quick_slot_tiles(screen_path)
				tile = tiles[index]
				tile_paths[index] = tile and util.path(tile) or nil
			end
			counted[index] = tile
		end
	end
	if next(counted) == nil then return end
	local counts = count_matching(comp, counted)
	for index, tile in pairs(counted) do show_count(tile, counts[records[index].def]) end
end

--- Clear slot index of the player's inventory while it still names uid.
--- The poll then finds the slot empty with its item still in the inventory, and leaves it empty.
local function clear_clicked(index, uid)
	local comp = player_inventory()
	if not comp then return end
	local slots = comp.QuickSlots
	for i = 1, #slots do
		local slot = slots[i]
		if slot.Index == index and util.same_guid(slot.ItemUID, uid) then
			comp:UpdateQuickSlot(index, EMPTY_ITEM)
			log.debug("quick slot %d cleared by click", index)
			return
		end
	end
end

-- The mouse event is only readable while the handler runs. The clear waits a tick, since it removes the clicked tile.
-- The press also starts vanilla's drag detection, so a quick slot tile can no longer be dragged out.
local function on_mouse_down(context, _, mouse_event)
	local tile = context:get()
	local element = tile.BaseContainerElementRef
	if not (util.valid(element) and element:GetClass():GetFName():ToString() == SLOT_WIDGET) then return end
	-- Shift+Click sells or drops and Ctrl+Click moves the item, both vanilla.
	local mods = inventory.left_click_modifiers(mouse_event)
	if not mods or mods.shift or mods.ctrl or mods.alt then return end
	local index = element.QuickSlotIndex
	local uid = util.guid(tile.ContainerItem.ItemUID)
	ExecuteInGameThreadWithDelay(1, hooks.guard(function() clear_clicked(index, uid) end))
end

local loop_handle = nil

--- Start the poll and hook the tile click. UE4SS cancels the mod's delayed actions on unload, so a hot reload needs no explicit cancel.
function M.install()
	hooks.install(TILE_CLASS .. ":OnMouseButtonDown", TILE_CLASS, on_mouse_down)
	if loop_handle then return end
	loop_handle = LoopInGameThreadWithDelay(POLL_MS, function()
		util.safe("quick slot poll", poll)
	end)
	log.info("quick slot refill: polling every %d ms", POLL_MS)
end

return M
