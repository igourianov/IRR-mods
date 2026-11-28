-- inventory/tile_counts.lua : an inventory tile's count text, as whole use counts or a percentage (docs/solutions/weapon-condition-display.md).
--
-- Every game name here comes from docs/solutions/medic-uses-display.md, docs/solutions/usb-uses-display.md and docs/solutions/weapon-condition-display.md.
-- The native ItemWidget writes the uses, a float stat, into the tile with decimals. This rewrites that text once the game has drawn it.
-- Holds no UObject between calls.

local util = require("lib.util")
local hook = require("lib.hook")
local inventory = require("inventory.inventory")
local item_tile = require("inventory.item_tile")

local M = {}

local hooks = hook.new("tile counts", "tile counts keep decimals")

local HOOK_FN = item_tile.CLASS .. ":K2_UpdateItemCount"

-- U_Battery_C is the USB hacking devices' use count, U_Durability_C the condition of weapons and some gadgets.
-- Both start at a maximum of 100, so the value itself is shown with %.
-- A repair lowers a weapon's maximum, so a ratio to the drawn maximum would hide that wear behind 100%.
local BATTERY_CONFIG = "U_Battery_C"
local CONDITION_CONFIG = "U_Durability_C"

local function uses_format(tile)
	local definition = tile.ContainerItem.ItemDefinition
	if not util.valid(definition) then return nil end
	if inventory.config_stat(definition, inventory.USES_CONFIG) then return "whole" end
	if inventory.config_stat(definition, BATTERY_CONFIG) then return "percent" end
	-- A tile in an equipment slot shows condition as a bar, left vanilla.
	if not tile.bEquipped and inventory.config_stat(definition, CONDITION_CONFIG) then return "percent" end
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

-- Finds no number in the maximum text of a tile it already rewrote, as that is then empty, so a repeat single use rewrite is a no-op.
local function block_number(block)
	if not util.valid(block) then return nil end
	local number = block:GetText():ToString():match("%d+[%.,]?%d*")
	return number and to_number(number)
end

local function rewrite_tile(path, format)
	local tile = StaticFindObject(path)
	if not util.valid(tile) then return end
	if format == "percent" then
		-- A repeat call reads back the whole number it wrote, so writes the same text.
		local value = block_number(tile.ItemCapacity)
		if value then
			tile.ItemCapacity:SetText(FText(round(value) .. "%"))
			tile.ItemMaxCapacity:SetText(FText(""))
		end
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
	hooks.install(HOOK_FN, item_tile.CLASS, on_update)
end

return M
