-- whole_uses.lua : an item that counts uses shows them as whole numbers on its inventory tile (docs/solutions/medic-uses-display.md).
--
-- Every game name here comes from docs/solutions/medic-uses-display.md and docs/solutions/usb-uses-display.md.
-- The native ItemWidget writes the uses, a float stat, into the tile with decimals. This rewrites that text once the game has drawn it.
-- Holds no UObject between calls.

local util = require("util")
local hook = require("hook")
local inventory = require("inventory")

local M = {}

local hooks = hook.new("whole uses", "use counts keep decimals")

local TILE_CLASS = "/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C"
local HOOK_FN    = TILE_CLASS .. ":K2_UpdateItemCount"

-- U_Battery_C is the USB hacking devices' use count, shown as the remaining percentage.
local BATTERY_CONFIG = "U_Battery_C"

local function uses_format(tile)
	local definition = tile.ContainerItem.ItemDefinition
	if not util.valid(definition) then return nil end
	if inventory.config_stat(definition, inventory.USES_CONFIG) then return "whole" end
	if inventory.config_stat(definition, BATTERY_CONFIG) then return "percent" end
	return nil
end

local function round(value)
	return math.floor(value + 0.5)
end

-- Either decimal separator, since the game formats per culture.
local function to_number(text)
	return tonumber((text:gsub(",", ".")))
end

-- The text is rewritten from what the game drew rather than from the stat, so it can't disagree with the tile.
local function round_numbers(block)
	if not util.valid(block) then return end
	local text = block:GetText():ToString()
	local whole = text:gsub("%d+[%.,]%d+", function(number) return tostring(round(to_number(number))) end)
	if whole == text then return end
	block:SetText(FText(whole))
end

-- Finds no number in a tile it already rewrote, as the maximum text is then empty, so a repeat call is a no-op.
local function block_number(block)
	if not util.valid(block) then return nil end
	local number = block:GetText():ToString():match("%d+[%.,]?%d*")
	return number and to_number(number)
end

local function show_percent(tile)
	local remaining = block_number(tile.ItemCapacity)
	local max = block_number(tile.ItemMaxCapacity)
	if not remaining or not max or max <= 0 then return end
	tile.ItemCapacity:SetText(FText(round(remaining / max * 100) .. "%"))
	tile.ItemMaxCapacity:SetText(FText(""))
end

local function rewrite_tile(path, format)
	local tile = StaticFindObject(path)
	if not util.valid(tile) then return end
	if format == "percent" then
		show_percent(tile)
	elseif block_number(tile.ItemMaxCapacity) == 1 then
		-- A single use item still unused shows no count. A spent one shows ~ instead of 0/1.
		tile.ItemCapacity:SetText(FText((block_number(tile.ItemCapacity) or 0) > 0 and "" or "~"))
		tile.ItemMaxCapacity:SetText(FText(""))
	else
		round_numbers(tile.ItemCapacity)
		round_numbers(tile.ItemMaxCapacity)
	end
end

-- Tile path to format, for the tiles waiting for the next flush.
local pending = {}
-- os.clock() when the pending flush was scheduled, nil when none is.
local flush_at = nil

local function flush()
	flush_at = nil
	local batch = pending
	pending = {}
	for path, format in pairs(batch) do hooks.guard(rewrite_tile)(path, format) end
end

-- ItemWidget writes the count texts after it sends this event, so they are rewritten a tick later. The tile is passed by path, not held.
-- UE4SS sometimes runs one of several callbacks delayed in the same frame twice and drops another, so a single flush serves every tile updated in the frame.
-- A flush still pending after half a second was dropped the same way and is scheduled again.
local function on_update(context)
	local tile = context:get()
	local format = uses_format(tile)
	if not format then return end
	pending[util.path(tile)] = format
	if flush_at and os.clock() - flush_at < 0.5 then return end
	flush_at = os.clock()
	ExecuteInGameThreadWithDelay(1, hooks.guard(flush))
end

--- Hook the inventory tile once its Blueprint class is loaded.
function M.install()
	hooks.install(HOOK_FN, TILE_CLASS, on_update)
end

return M
