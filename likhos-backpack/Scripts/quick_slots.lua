-- quick_slots.lua : a quick slot whose item is used up rebinds to another item of the same definition from the same equipment (docs/solutions/quick-slot-refill.md).
--
-- Every game name here comes from docs/solutions/quick-slot-refill.md.
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
-- The tile count walks every item tile, so it runs on every COUNT_EVERY-th poll only.
local COUNT_EVERY  = 5
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

--- The item of comp with uid and the main container holding it, or nil.
--- Read from comp.MainContainers rather than GetContainerItemByUID. A struct returned by a UFunction call crashes the game when passed to another one, still on UE4SS 1217, and UE4SS before 1217 crashes converting a returned ContainerItem to Lua. One read from a property passes fine.
local function find_item(comp, uid)
	local containers = comp.MainContainers
	for i = 1, #containers do
		local container = containers[i]
		local items = container.ContainerItems
		for j = 1, #items do
			if util.same_guid(items[j].ItemUID, uid) then return items[j], container end
		end
	end
	return nil
end

--- For each slot index of wanted (index -> uid), the item of comp with that uid and its main container. One pass over the inventory.
local function locate(comp, wanted)
	local found = {}
	if next(wanted) == nil then return found end
	local containers = comp.MainContainers
	for i = 1, #containers do
		local container = containers[i]
		local items = container.ContainerItems
		for j = 1, #items do
			local item = items[j]
			local uid = item.ItemUID
			for index, w in pairs(wanted) do
				if util.same_guid(uid, w) then found[index] = { item = item, main = container } end
			end
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
	local containers = comp.MainContainers
	for i = 1, #containers do
		local container = containers[i]
		local items = container.ContainerItems
		for j = 1, #items do
			local item = items[j]
			local definition = item.ItemDefinition
			if util.valid(definition) and definition:GetFullName() == def and uses_left(item) > 0 and root_key(comp, item, container) == root then found[#found + 1] = item end
		end
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

--- Track the live binding of slot index, or refill the slot once its recorded item has been used up.
--- uid is the slot's QuickSlots entry, or nil. found is that item and its main container from locate, or nil when the entry is stale.
local function check_slot(pc, comp, index, uid, found)
	local record = records[index]
	if found then
		local uses = uses_left(found.item)
		if record and util.same_guid(record.uid, uid) then
			record.uses = uses
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
	if not record then return end

	records[index] = nil
	-- Still in the inventory: the slot was cleared by hand.
	if find_item(comp, record.uid) then return end
	-- Left with uses left and no use running: dropped, discarded or sold.
	if not (record.uses <= 0 or using_item(pc)) then return end
	-- Fewest uses left first, so partly used items are finished before fresh ones. Ties keep container order.
	local item, item_uses
	for _, candidate in ipairs(record.root and record.def and matching(comp, record.def, record.root) or {}) do
		local uses = uses_left(candidate)
		if not item or uses < item_uses then item, item_uses = candidate, uses end
	end
	if not item then
		log.debug("quick slot %d empty: no %s left in %s", index, tostring(record.def), tostring(record.root))
		return
	end
	local new_uid = util.guid(item.ItemUID)
	comp:UpdateQuickSlot(index, item)
	records[index] = { uid = new_uid, def = record.def, root = record.root, single = record.single, uses = item_uses }
	log.debug("quick slot %d refilled with %s %s from %s", index, record.def, guid_str(new_uid), record.root)
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

--- The slot index of tile when it is a quick slot tile showing its slot's recorded item, or nil.
--- A tile's BaseContainerElementRef is the container element it was created for, here the quick slot widget.
--- Neither the quick slot widget's ItemRef nor its GetContainerItems() gives the tile: the widget overrides AddItem and GetContainerItems, and the call returns an empty array to Lua.
--- A quick slot bar of an earlier screen may still exist, so a tile counts only while it shows the bound item.
local function tile_slot(tile)
	local element = tile.BaseContainerElementRef
	if not (util.valid(element) and element:GetClass():GetFName():ToString() == SLOT_WIDGET) then return nil end
	local index = element.QuickSlotIndex
	local record = records[index]
	if record and util.same_guid(tile.ContainerItem.ItemUID, record.uid) then return index end
	return nil
end

local function quick_slot_tiles()
	local tiles = {}
	for _, tile in ipairs(FindAllOf(TILE_WIDGET) or {}) do
		local index = util.valid(tile) and tile_slot(tile) or nil
		if index then tiles[index] = tile end
	end
	return tiles
end

-- slot index -> path of the tile last found by quick_slot_tiles. Once the inventory screen has been opened its widgets stay, so without it every count pass would walk every item tile, stash included.
local tile_paths = {}

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
	local found = locate(comp, wanted)
	for index = 0, SLOT_COUNT - 1 do check_slot(pc, comp, index, wanted[index], found[index]) end

	polls = polls + 1
	if polls % COUNT_EVERY ~= 0 then return end
	-- The quick slot widgets exist only once the inventory screen has been opened.
	if not FindFirstOf(SLOT_WIDGET) then return end
	local tiles
	for index = 0, SLOT_COUNT - 1 do
		local record = records[index]
		if record and record.single and record.root then
			local cached = tile_paths[index] and StaticFindObject(tile_paths[index])
			local tile = util.valid(cached) and tile_slot(cached) == index and cached or nil
			if not tile then
				tiles = tiles or quick_slot_tiles()
				tile = tiles[index]
				tile_paths[index] = tile and util.path(tile) or nil
			end
			if tile then show_count(tile, #matching(comp, record.def, record.root)) end
		end
	end
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
