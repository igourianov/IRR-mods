-- items/quick_sell.lua : Shift+Click on an item in the hideout sells it, as Sell from its context menu does (docs/solutions/hideout-quick-sell.md).
--
-- Every game name here comes from that solution doc.
-- Shift+Click goes through vanilla's Sell context, which is not offered in raid, so Shift+Click there stays vanilla's drop.
-- Holds no UObject between calls.

local log  = require("lib.log")
local util = require("lib.util")
local hook = require("lib.hook")
local item_tile = require("items.item_tile")

local M = {}

local hooks = hook.new("quick sell", "Shift+Click stays vanilla")

local SELL_CONTEXT  = "U_Sell_C"

local function item_str(item)
	return item.ItemDefinition:GetFName():ToString() .. " " .. util.guid_str(item.ItemUID)
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

-- The sale waits a tick, since it removes the clicked tile.
local function on_click(tile, mods)
	if not mods.shift then return end
	local path = util.path(tile)
	local uid = util.guid(tile.ContainerItem.ItemUID)
	ExecuteInGameThreadWithDelay(1, hooks.guard(function() sell(path, uid) end))
end

--- Handle Shift+Click on inventory tiles.
function M.install()
	item_tile.on_click("quick sell", hooks.guard(on_click))
end

return M
