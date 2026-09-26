-- medic.lua : a bandage or painkiller pack with no uses left drops on the floor, like a used health injector (docs/solutions/medic-drop.md).
--
-- Every game name here comes from docs/solutions/medic-drop.md.
-- The injector drops through a Drop notify in its montage, handled by SGA_UseMedic_C:ExecuteNotify. These items' montages have none, so the mod sends it.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")
local hook = require("hook")

local M = {}

local hooks = hook.new("medic drop", "medical items stay vanilla")

local ABILITY_CLASS = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_UseMedic.SGA_UseMedic_C"
local HOOK_FN       = ABILITY_CLASS .. ":ExecuteNotify"

-- Abilities whose montage has a Use notify but no Drop. The injector and revive syringe drop on their own.
local ITEMS = {
    SGA_UseMedic_Bandage_C     = true,
    SGA_UseMedic_Painkillers_C = true,
}

local USES_TAG = "Inventory.Stats.Durability"

-- The injector's Drop notify fires this long before its montage ends, in montage seconds.
local DROP_BEFORE_END = 0.17

-- Bumped on level load, so a drop scheduled before it does nothing.
local generation = 0

local function uses_left(ability)
    local stats = ability.Item.CurrentStats
    for i = 1, #stats do
        local stat = stats[i]
        if stat.Tag.TagName:ToString() == USES_TAG then return stat.Value end
    end
    return nil
end

--- The anim instance playing the ability's first person montage, and that montage. Nil when either is missing.
local function montage_of(ability)
    local character = ability.Instigator
    if not util.valid(character) then return nil end
    local arms = character.FirstPerson_Arms
    if not util.valid(arms) then return nil end
    local anim = arms:GetAnimInstance()
    local montage = ability["Medic Character Montage"].FP_Animation
    if not (util.valid(anim) and util.valid(montage)) then return nil end
    return anim, montage
end

local function drop(path, gen)
    if gen ~= generation then return end
    local ability = StaticFindObject(path)
    if not util.valid(ability) or not ability:IsAbilityActive() then
        log.debug("medic drop: %s ended before the drop point, item kept", path)
        return
    end
    local anim, montage = montage_of(ability)
    if not (anim and anim:Montage_IsPlaying(montage)) then
        log.debug("medic drop: %s montage stopped before the drop point, item kept", path)
        return
    end
    ability:ExecuteNotify(FName("Drop"))
    log.debug("medic drop: dropped the item of %s", path)
end

-- Full name of the ability whose Use notify is running, set by the pre callback for the post callback of the same call.
local using = nil

-- The notify name is read here only. Post callback parameter values are unreliable (docs/solutions/magnifier-zoom.md).
local function on_pre(context, name)
    using = nil
    if name:get():ToString() ~= "Use" then return end
    local ability = context:get()
    if not ITEMS[ability:GetClass():GetFName():ToString()] then return end
    using = util.path(ability)
end

-- Runs after the Use branch has spent the use.
local function on_post(context)
    local path = using
    using = nil
    if not path then return end

    local ability = context:get()
    local uses = uses_left(ability)
    if uses == nil or uses > 0 then
        log.debug("medic drop: %s used, %s uses left", path, tostring(uses))
        return
    end

    local anim, montage = montage_of(ability)
    if not anim then
        log.debug("medic drop: %s has no playing montage, item kept", path)
        return
    end
    local position = anim:Montage_GetPosition(montage)
    local rate = anim:Montage_GetPlayRate(montage)
    local length = montage:GetPlayLength()
    local delay_ms = math.max(1, math.floor((length - DROP_BEFORE_END - position) / rate * 1000))
    log.debug("medic drop: %s spent at %.2f of %.2f s, rate %.2f, drop in %d ms", path, position, length, rate, delay_ms)

    local gen = generation
    ExecuteInGameThreadWithDelay(delay_ms, hooks.guard(function() drop(path, gen) end))
end

--- Hook the medic ability once its Blueprint class is loaded.
function M.install()
    hooks.install(HOOK_FN, ABILITY_CLASS, on_pre, on_post)
end

--- Cancel a scheduled drop. Called on level load.
function M.reset()
    generation = generation + 1
    using = nil
end

return M
