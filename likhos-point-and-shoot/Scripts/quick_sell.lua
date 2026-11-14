-- quick_sell.lua : Shift+Click on an item in the hideout sells it, as Sell from its context menu does (docs/solutions/hideout-quick-sell.md).
--
-- Every game name here comes from that solution doc.
-- Shift+Click goes through vanilla's Sell context, which is not offered in raid, so Shift+Click there stays vanilla's drop.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")
local hook = require("hook")
local inventory = require("inventory")

local M = {}

local hooks = hook.new("quick sell", "Shift+Click stays vanilla")

local TILE_CLASS    = "/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C"
local HOOK_FN       = TILE_CLASS .. ":OnMouseButtonDown"
local SELL_CONTEXT  = "U_Sell_C"

local function item_str(item)
	return string.format("%s %08x", item.ItemDefinition:GetFName():ToString(), item.ItemUID.A & 0xffffffff)
end

local function sell(path, uid)
	local tile = StaticFindObject(path)
	if not util.valid(tile) or not util.same_guid(tile.ContainerItem.ItemUID, uid) then
		log.debug("quick sell: the clicked tile is gone or shows another item")
		return
	end
	local item = tile.ContainerItem
	local owner = tile:GetOwningPlayer()
	local context = FindFirstOf(SELL_CONTEXT)
	if not util.valid(context) then error("no " .. SELL_CONTEXT .. " instance") end
	if not (context:ShouldAddToContextList(owner, tile, item) and context:IsValidContext(owner, tile, item)) then
		log.debug("quick sell: sell not offered for %s", item_str(item))
		return
	end
	context:Execute(owner, tile, item)
	log.debug("quick sell: sold %s", item_str(item))
end

-- The mouse event is only readable while the handler runs. The sale waits a tick, since it removes the clicked tile.
local function on_mouse_down(context, _, mouse_event)
	local mods = inventory.left_click_modifiers(mouse_event)
	if not (mods and mods.shift) then return end

	local tile = context:get()
	local path = util.path(tile)
	local uid = util.guid(tile.ContainerItem.ItemUID)
	ExecuteInGameThreadWithDelay(1, hooks.guard(function() sell(path, uid) end))
end

--- Hook the inventory tile's click handler once its Blueprint class is loaded.
function M.install()
	hooks.install(HOOK_FN, TILE_CLASS, on_mouse_down)
end

return M
