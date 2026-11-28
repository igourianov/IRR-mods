-- inventory/item_tile.lua : the inventory item tile, W_InventoryItem_C, shared by quick sell, the quick slots and whole use counts.
-- Owns the tile's one click hook and hands each left click to the features registered for it.
-- Holds no UObject between calls.

local util = require("lib.util")
local hook = require("lib.hook")

local M = {}

M.CLASS = "/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C"

local hooks = hook.new("item tile click", "clicks on item tiles stay vanilla")

local INPUT_LIB   = "/Script/Engine.Default__KismetInputLibrary"
local SLOT_WIDGET = "W_QuickSlotContainer_C"

-- name -> handler(tile, mods), as passed to M.on_click.
local handlers = {}

--- For a left click on an item tile, whether each modifier key is held. Only callable while the click handler runs, when mouse_event is readable.
---@return { shift: boolean, ctrl: boolean, alt: boolean }? # nil for another button
--- UE4SS won't pass the click's PointerEvent as the InputEvent InputEvent_IsShiftDown takes, so the state comes from Slate's current modifier state.
--- The mask's bits are engine-internal, so the library decodes it, from a fresh struct rather than the returned one (docs/solutions/hideout-quick-sell.md).
local function left_click_modifiers(mouse_event)
	local input = StaticFindObject(INPUT_LIB)
	if input:PointerEvent_GetEffectingButton(mouse_event:get()).KeyName:ToString() ~= "LeftMouseButton" then return nil end
	local keys = { ModifierKeysStateMask = input:GetModifierKeysState().ModifierKeysStateMask }
	return { shift = input:ModifierKeysState_IsShiftDown(keys), ctrl = input:ModifierKeysState_IsControlDown(keys), alt = input:ModifierKeysState_IsAltDown(keys) }
end

local function on_mouse_down(context, _, mouse_event)
	local mods = left_click_modifiers(mouse_event)
	if not mods then return end
	local tile = context:get()
	for _, handler in pairs(handlers) do handler(tile, mods) end
end

--- Call handler(tile, mods) on every left click on an item tile, mods being { shift, ctrl, alt }, each whether it is held.
--- The click's tile is removed by any change to its slot, so a handler that makes one waits a tick.
--- Registered by name, so a hot reload replaces a handler rather than adding it twice.
function M.on_click(name, handler)
	handlers[name] = handler
	hooks.install(M.CLASS .. ":OnMouseButtonDown", M.CLASS, on_mouse_down)
end

---@return integer? # nil when tile is not in a quick slot
--- A tile's BaseContainerElementRef is the container element it was created for, here the quick slot widget.
function M.quick_slot_index(tile)
	local element = tile.BaseContainerElementRef
	if not (util.valid(element) and util.class_name(element) == SLOT_WIDGET) then return nil end
	return element.QuickSlotIndex
end

return M
