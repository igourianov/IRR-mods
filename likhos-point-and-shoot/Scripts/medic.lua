-- medic.lua : a bandage or painkiller pack with no uses left drops on the floor, like a used health injector (docs/solutions/medic-drop.md).
--
-- Every game name here comes from docs/solutions/medic-drop.md.
-- The injector drops through a Drop notify in its montage, handled by SGA_UseMedic_C:ExecuteNotify. These items' montages have none, so the mod sends it when the montage ends.
-- Holds no state between calls.

local log  = require("log")
local util = require("util")
local hook = require("hook")

local M = {}

local hooks = hook.new("medic drop", "medical items stay vanilla")

local ABILITY_CLASS = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_UseMedic.SGA_UseMedic_C"
-- The montage proxy calls this when the montage plays to its end, and OnInterrupted instead when it is cut short. It runs before OnCompleted unequips the item.
local HOOK_FN       = ABILITY_CLASS .. ":OnBlendOut_BC5AE83245D2760642BF14BE4B42A1EF"

-- Abilities whose montage has a Use notify but no Drop. The injector and revive syringe drop on their own.
local ITEMS = {
    SGA_UseMedic_Bandage_C     = true,
    SGA_UseMedic_Painkillers_C = true,
}

local USES_TAG = "Inventory.Stats.Durability"

--- The item's uses before this use. The ability's Item is a copy taken when the use started, and the Use branch doesn't update it.
local function uses_before(ability)
    local stats = ability.Item.CurrentStats
    for i = 1, #stats do
        local stat = stats[i]
        if stat.Tag.TagName:ToString() == USES_TAG then return stat.Value end
    end
    return nil
end

local function on_blend_out(context)
    local ability = context:get()
    if not ITEMS[ability:GetClass():GetFName():ToString()] then return end

    local path = util.path(ability)
    -- The Use branch spends exactly one use.
    local uses = uses_before(ability)
    if uses == nil or uses > 1 then
        log.debug("medic drop: %s ended, %s uses before", path, tostring(uses))
        return
    end
    ability:ExecuteNotify(FName("Drop"))
    log.debug("medic drop: dropped the item of %s", path)
end

--- Hook the medic ability once its Blueprint class is loaded.
function M.install()
    hooks.install(HOOK_FN, ABILITY_CLASS, on_blend_out)
end

return M
