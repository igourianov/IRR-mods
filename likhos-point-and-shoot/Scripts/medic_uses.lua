-- medic_uses.lua : a medical item's inventory tile shows its uses as whole numbers (docs/solutions/medic-uses-display.md).
--
-- Every game name here comes from docs/solutions/medic-uses-display.md.
-- The native ItemWidget writes the uses, a float stat, into the tile with decimals. This rewrites that text once the game has drawn it.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")
local hook = require("hook")

local M = {}

local hooks = hook.new("medic uses", "medical item tiles keep decimals")

local TILE_CLASS = "/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C"
local HOOK_FN    = TILE_CLASS .. ":K2_UpdateItemCount"

local MEDICAL_TAG = "Inventory.Items.Medical"

local function is_medical(tile)
    local definition = tile.ContainerItem.ItemDefinition
    if not util.valid(definition) then return false end
    local tag = definition.ItemIdentifier.TagName:ToString()
    log.debug("medic uses: tile update for %s", tag)
    return tag == MEDICAL_TAG or tag:sub(1, #MEDICAL_TAG + 1) == MEDICAL_TAG .. "."
end

-- The text is rewritten from what the game drew rather than from the stat, so it can't disagree with the tile. Either decimal separator, since the game formats per culture.
local function round_numbers(block)
    if not util.valid(block) then return end
    local text = block:GetText():ToString()
    local whole = text:gsub("%d+[%.,]%d+", function(number)
        return tostring(math.floor(tonumber((number:gsub(",", "."))) + 0.5))
    end)
    if whole ~= text then block:SetText(FText(whole)) end
    log.debug("medic uses: %s '%s' -> '%s', reads '%s'", block:GetFName():ToString(), text, whole, block:GetText():ToString())
end

local function round_tile(path)
    local tile = StaticFindObject(path)
    if not util.valid(tile) then return end
    round_numbers(tile.ItemCapacity)
    round_numbers(tile.ItemMaxCapacity)
end

-- ItemWidget writes the count texts after it sends this event, so they are rewritten a tick later. The tile is passed by path, not held.
local function on_update(context)
    local tile = context:get()
    if not is_medical(tile) then return end
    local path = util.path(tile)
    ExecuteInGameThreadWithDelay(1, hooks.guard(function() round_tile(path) end))
end

--- Hook the inventory tile once its Blueprint class is loaded.
function M.install()
    hooks.install(HOOK_FN, TILE_CLASS, on_update)
end

return M
