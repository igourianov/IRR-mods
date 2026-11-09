-- quick_slots.lua : a quick slot whose item is used up rebinds to another item of the same definition from the same equipment (docs/solutions/quick-slot-refill.md).
-- A quick slot naming an item that is no longer in the inventory is cleared (docs/solutions/quick-slot-left-inventory.md).
--
-- Every game name here comes from those two docs.
-- Items leave the inventory through several paths, some native, and the quick slot widgets exist only in the inventory screen, so the slots are polled rather than hooked.
-- Holds no UObject between polls: records keep UIDs and paths only.

local log  = require("log")
local util = require("util")

local M = {}

local LIBRARY_CDO  = "/Script/Test_C.Default__InventoryFunctionLibrary"
local ABILITY_COMP = "/Script/Test_C.GameplayAbilityComponent"
local SLOT_COUNT   = 4
-- A used item sits at 0 uses for about 270 ms before it leaves, which a 250 ms poll sometimes missed.
local POLL_MS      = 50
-- The root refresh walks the inventory once per bound slot and the tile count walks every item tile, so both run on every SLOW_EVERY-th poll only.
local SLOW_EVERY   = 5
local USES_TAG     = "Inventory.Stats.Durability"
-- The uses stat's config class. Its tag, USES_TAG, is shared with weapon and armor durability, so a definition's stats are told apart by this class.
local USES_CONFIG  = "U_Content_C"
local SLOT_WIDGET  = "W_QuickSlotContainer_C"
local TILE_WIDGET  = "W_InventoryItem_C"

-- ESlateVisibility
local COLLAPSED          = 1
local HIDDEN             = 2
local HIT_TEST_INVISIBLE = 3

-- Abilities that take an item out of the inventory by using it. A drop, discard or sale runs none of them.
-- They cover items without a uses stat (grenades). A used injector leaves the inventory after its use ability has ended, so items with a uses stat are told used up by reaching 0 uses instead.
local USE_ABILITIES = {
	"/Script/Test_C.SimpleGameplayAbility_UseQuickSlot",
	"/Script/Test_C.SimpleGameplayAbility_UseItem",
	"/Script/Test_C.SimpleGameplayAbility_ThrowGrenade",
	"/Script/Test_C.SimpleGameplayAbility_QuickHeal",
	"/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_UseMedic.SGA_UseMedic_C",
}

-- EContainerType: EquipTo = 0. Equipment and attachment slots are EquipTo.
local EQUIP_TO = 0

-- Containers nest a few levels deep. The cap only guards against a cycle in bad data.
local MAX_DEPTH = 16

local function guid_str(g)
	return string.format("%08x%08x%08x%08x", g.A & 0xffffffff, g.B & 0xffffffff, g.C & 0xffffffff, g.D & 0xffffffff)
end

local function is_zero(g)
	return g.A == 0 and g.B == 0 and g.C == 0 and g.D == 0
end

--- Every item of comp with the main container holding it, in container order: `for item, main in inventory_items(comp)`.
local function inventory_items(comp)
	local containers = comp.MainContainers
	local container_count = #containers
	local i, j, item_count = 0, 0, 0
	local container, items = nil, nil
	return function()
		while j >= item_count do
			i = i + 1
			if i > container_count then return nil end
			container = containers[i]
			items = container.ContainerItems
			j, item_count = 0, #items
		end
		j = j + 1
		return items[j], container
	end
end

--- The item of comp with uid and the main container holding it, or nil.
--- Read from comp.MainContainers rather than GetContainerItemByUID. A struct returned by a UFunction call crashes the game when passed to another one, still on UE4SS 1217, and UE4SS before 1217 crashes converting a returned ContainerItem to Lua. One read from a property passes fine.
local function find_item(comp, uid)
	for item, main in inventory_items(comp) do
		if util.same_guid(item.ItemUID, uid) then return item, main end
	end
	return nil
end

--- For each slot index of wanted (index -> uid), the item of comp with that uid and its main container. One pass over the inventory.
local function locate(comp, wanted)
	local found = {}
	if next(wanted) == nil then return found end
	for item, main in inventory_items(comp) do
		local uid = item.ItemUID
		for index, w in pairs(wanted) do
			if util.same_guid(uid, w) then found[index] = { item = item, main = main } end
		end
	end
	return found
end

--- Whether item sits in an equipment or attachment slot of main rather than a grid.
local function is_equipped(main, item)
	local settings = main.ContainerElements[item.ContainerIndex + 1].ContainerSettings
	return util.valid(settings) and settings:GetContainerType() == EQUIP_TO
end

--- A key naming the equipment item sits in: the equipped item whose grids hold it at any depth, or the character grid holding it.
--- A container item's own grids are main containers whose MainContainerUID is its ItemUID.
local function root_key(comp, item, main)
	for _ = 1, MAX_DEPTH do
		if is_equipped(main, item) then return guid_str(item.ItemUID) end
		local parent, parent_main = find_item(comp, main.MainContainerUID)
		if not parent then return guid_str(main.MainContainerUID) .. ":" .. item.ContainerIndex end
		item, main = parent, parent_main
	end
	return nil
end

local function uses_left(item)
	local stats = item.CurrentStats
	for i = 1, #stats do
		local stat = stats[i]
		if stat.Tag.TagName:ToString() == USES_TAG then return stat.Value end
	end
	return math.huge
end

--- The items of comp with definition path def under root and uses left, in container order.
--- A spent item can sit at 0 uses: briefly before the game removes it, or for good when saved that way by an older version of this mod.
local function matching(comp, def, root)
	local found = {}
	for item, main in inventory_items(comp) do
		local definition = item.ItemDefinition
		if util.valid(definition) and definition:GetFullName() == def and uses_left(item) > 0 and root_key(comp, item, main) == root then found[#found + 1] = item end
	end
	return found
end

--- Whether items of definition are used up in one use: a uses stat of 1, or no uses stat and no stacking (grenades).
local function single_use(definition)
	if not util.valid(definition) then return false end
	local stats = definition.ItemStats
	for i = 1, #stats do
		local stat = stats[i]
		local config = stat.StatItemConfig
		if util.valid(config) and config:GetClass():GetFName():ToString() == USES_CONFIG then return stat.Value == 1 end
	end
	return not definition.ItemProperties.CanStack
end

--- Whether one of the player's active abilities uses an item.
local function using_item(pc)
	local comp = util.component(pc.Pawn, ABILITY_COMP)
	if not comp then return false end
	-- The Blueprint class is found only once loaded, and an unloaded class has no instance to match.
	local classes = {}
	for _, path in ipairs(USE_ABILITIES) do
		local class = StaticFindObject(path)
		if util.valid(class) then classes[#classes + 1] = class end
	end
	local using = false
	comp.ActiveAbilities:ForEach(function(_, elem)
		local ability = elem:get()
		if not util.valid(ability) then return end
		for _, class in ipairs(classes) do
			if ability:IsA(class) then
				using = true
				return true
			end
		end
	end)
	return using
end

-- slot index -> { uid, def, root, single, uses }, the last live binding of each slot. single is whether its definition is single use.
-- uses is the item's uses left at the last poll. A used item lingers in the inventory at 0 uses before the game removes it.
local records = {}
-- Path of the inventory component the records came from.
local records_comp = nil

-- The item UpdateQuickSlot takes to clear a slot.
local EMPTY_ITEM = { ItemUID = { A = 0, B = 0, C = 0, D = 0 } }

--- Track the live binding of slot index, refill the slot once its recorded item has been used up, or clear it while it names an item outside the inventory.
--- uid is the slot's QuickSlots entry, or nil. found is that item and its main container from locate, or nil when the entry is stale.
--- refresh rereads the root of a tracked binding.
local function check_slot(pc, comp, index, uid, found, refresh)
	local record = records[index]
	if found then
		local uses = uses_left(found.item)
		if record and util.same_guid(record.uid, uid) then
			record.uses = uses
			-- The bound item, or a container holding it, can move to other equipment with the slot still bound, e.g. from the pockets to the backpack.
			if not refresh then return end
			local root = root_key(comp, found.item, found.main)
			if root == record.root then return end
			log.debug("quick slot %d item %s moved from %s to %s", index, guid_str(uid), tostring(record.root), tostring(root))
			record.root = root
			return
		end
		local definition = found.item.ItemDefinition
		local def = util.valid(definition) and definition:GetFullName() or nil
		local root = root_key(comp, found.item, found.main)
		local single = single_use(definition)
		records[index] = { uid = uid, def = def, root = root, single = single, uses = uses }
		log.debug("quick slot %d bound to %s %s in %s, single use %s", index, tostring(def), guid_str(uid), tostring(root), tostring(single))
		return
	end

	records[index] = nil
	-- Used up: left the inventory after a poll saw it at 0 uses, or while a use ran.
	-- Otherwise the slot was cleared by hand with its item still in the inventory, or the item was dropped, discarded or sold.
	local used = record and not find_item(comp, record.uid) and (record.uses <= 0 or using_item(pc))
	-- Fewest uses left first, so partly used items are finished before fresh ones. Ties keep container order.
	local item, item_uses
	for _, candidate in ipairs(used and record.root and record.def and matching(comp, record.def, record.root) or {}) do
		local uses = uses_left(candidate)
		if not item or uses < item_uses then item, item_uses = candidate, uses end
	end
	if item then
		local new_uid = util.guid(item.ItemUID)
		comp:UpdateQuickSlot(index, item)
		records[index] = { uid = new_uid, def = record.def, root = record.root, single = record.single, uses = item_uses }
		log.debug("quick slot %d refilled with %s %s from %s", index, record.def, guid_str(new_uid), record.root)
		return
	end
	if used then log.debug("quick slot %d empty: no %s left in %s", index, tostring(record.def), tostring(record.root)) end
	-- An entry naming an item outside the inventory: the item sat in a container moved to another inventory, like the stash or the floor, and the game leaves the slot bound then.
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

-- Polls run since load, to pace the root refresh and the tile count.
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

--- For each slot index key of slots, how many items of comp match its record as matching does. One pass over the inventory.
local function count_matching(comp, slots)
	local counts = {}
	for index in pairs(slots) do counts[index] = 0 end
	for item, main in inventory_items(comp) do
		local definition = item.ItemDefinition
		local def = util.valid(definition) and definition:GetFullName()
		-- false once read: the item is spent or has no root, so it matches no record.
		local root = nil
		for index in pairs(slots) do
			local record = records[index]
			if def == record.def then
				if root == nil then root = uses_left(item) > 0 and root_key(comp, item, main) or false end
				if root == record.root then counts[index] = counts[index] + 1 end
			end
		end
	end
	return counts
end

local function poll()
	local pc = FindFirstOf("PlayerController")
	local library = StaticFindObject(LIBRARY_CDO)
	local comp = util.valid(pc) and util.valid(library) and library:GetPlayerInventoryComponent(pc) or nil
	local path = util.valid(comp) and util.path(comp) or nil
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
	polls = polls + 1
	local slow = polls % SLOW_EVERY == 0
	local found = locate(comp, wanted)
	for index = 0, SLOT_COUNT - 1 do check_slot(pc, comp, index, wanted[index], found[index], slow) end

	if not slow then return end
	-- The component's inventory screen, W_PlayerInventory_C, which holds the quick slot widgets.
	local screen = comp.InventoryWidgetRef
	if not util.valid(screen) then return end
	local screen_path = util.path(screen)
	local tiles
	-- slot index -> its tile, for the slots that show a count
	local counted = {}
	for index = 0, SLOT_COUNT - 1 do
		local record = records[index]
		if record and record.single and record.root then
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
	for index, tile in pairs(counted) do show_count(tile, counts[index]) end
end

local loop_handle = nil

--- Start the poll. UE4SS cancels the mod's delayed actions on unload, so a hot reload needs no explicit cancel.
function M.install()
	if loop_handle then return end
	loop_handle = LoopInGameThreadWithDelay(POLL_MS, function()
		util.safe("quick slot poll", poll)
	end)
	log.info("quick slot refill: polling every %d ms", POLL_MS)
end

return M
