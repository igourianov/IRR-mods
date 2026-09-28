-- quick_sell.lua : Shift+Click on an item in the hideout sells it, as Sell from its context menu does (docs/solutions/hideout-quick-sell.md).
--
-- Every game name here comes from docs/solutions/hideout-quick-sell.md.
-- The sell goes through vanilla's Sell context, which is not offered in raid, so Shift+Click there stays vanilla's drop.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")
local hook = require("hook")

local M = {}

local hooks = hook.new("quick sell", "Shift+Click stays vanilla")

local TILE_CLASS = "/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C"
local HOOK_FN    = TILE_CLASS .. ":OnMouseButtonDown"
local SELL_CLASS = "U_Sell_C"
local INPUT_LIB  = "/Script/Engine.Default__KismetInputLibrary"

-- TEMP recon: what vanilla's context menu passes as Owner when Sell is picked there. Remove once confirmed.
local SELL_EXECUTE_FN = "/Game/Blueprints/InventorySystem/Objects/ItemContexts/U_Sell.U_Sell_C:Execute"

local function item_str(item)
    return string.format("%s %08x", item.ItemDefinition:GetFName():ToString(), item.ItemUID.A & 0xffffffff)
end

local function same_guid(a, b)
    return a.A == b.A and a.B == b.B and a.C == b.C and a.D == b.D
end

local function sell(path, uid)
    local tile = StaticFindObject(path)
    if not util.valid(tile) or not same_guid(tile.ContainerItem.ItemUID, uid) then
        log.debug("quick sell: the clicked tile is gone or shows another item")
        return
    end
    local item = tile.ContainerItem
    local owner = tile:GetOwningPlayer()
    local context = FindFirstOf(SELL_CLASS)
    if not util.valid(context) then error("no " .. SELL_CLASS .. " instance") end
    if not context:ShouldAddToContextList(owner, tile, item) or not context:IsValidContext(owner, tile, item) then
        log.debug("quick sell: sell not offered for %s", item_str(item))
        return
    end
    context:Execute(owner, tile, item)
    log.debug("quick sell: sold %s", item_str(item))
end

--- Whether Shift is held, from Slate's current modifier state.
--- UE4SS won't pass the click's PointerEvent as the InputEvent InputEvent_IsShiftDown takes. The mask's bits are engine-internal, so the library decodes it, from a fresh struct rather than the returned one.
local function shift_down(input)
    local mask = input:GetModifierKeysState().ModifierKeysStateMask
    return input:ModifierKeysState_IsShiftDown({ ModifierKeysStateMask = mask })
end

-- The mouse event is only readable while the handler runs. The sell waits a tick, since it removes the clicked tile.
local function on_mouse_down(context, _, mouse_event)
    local input = StaticFindObject(INPUT_LIB)
    if input:PointerEvent_GetEffectingButton(mouse_event:get()).KeyName:ToString() ~= "LeftMouseButton" then return end
    if not shift_down(input) then return end

    local tile = context:get()
    local path = util.path(tile)
    local id = tile.ContainerItem.ItemUID
    local uid = { A = id.A, B = id.B, C = id.C, D = id.D }
    ExecuteInGameThreadWithDelay(1, hooks.guard(function() sell(path, uid) end))
end

-- TEMP recon, see SELL_EXECUTE_FN.
local function on_sell_execute(context, owner)
    local o = owner:get()
    log.debug("quick sell recon: Sell executed on %s, owner %s", context:get():GetFullName(), util.valid(o) and o:GetFullName() or "invalid")
end

--- Hook the inventory tile's click handler once its Blueprint class is loaded.
function M.install()
    hooks.install(HOOK_FN, TILE_CLASS, on_mouse_down)
    hooks.install(SELL_EXECUTE_FN, "/Game/Blueprints/InventorySystem/Objects/ItemContexts/U_Sell.U_Sell_C", on_sell_execute)
end

return M
