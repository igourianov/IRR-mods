-- low_ready.lua : low ready is the weapon's resting position (docs/solutions/low-ready-default.md).
--
-- Every game name here comes from docs/solutions/low-ready-default.md.
-- Starts low ready itself after every ability end, since the game's own auto low ready never lowers the gun while the character moves.
-- The menu's auto low ready toggle stays the player's switch for it.
-- Holds no UObject between ability ends.

local log    = require("log")
local hook   = require("hook")
local config = require("config")
local util   = require("util")

local M = {}

local hooks = hook.new("low ready default", "the game's own auto low ready stays")

local HOOK_FN = "/Script/Test_C.FirstPersonAutoLowReady:OnAbilityEnded"
local RUN_TAG = "Character.Abilities.Active.Running.Wants To Run"
local HOLSTERING_TAG = { TagName = FName("Character.Abilities.Active.Holstering") }

-- Counts ability ends, so a start still pending from an earlier end skips itself.
local pending = 0

local function try_low_ready(auto, id)
    if id ~= pending or not util.valid(auto) then return end
    if not auto.FirstPersonCoreComponent.ControllerSettings.bAutoLowReadyOnIdle then return end
    local abilities = auto.GameplayAbilityComponent
    local low_ready = auto.LowReadyAbilityTag
    -- The start check allows low ready while it is already active, and also during holstering.
    if abilities:IsAbilityActiveByTag(low_ready) or abilities:IsAbilityActiveByTag(HOLSTERING_TAG) then return end
    if not abilities:CanStartAbilityByTag(low_ready, false) then return end
    abilities:TryStartAbilitiesByTag(low_ready)
end

local function on_ability_ended(context, ability_tag)
    local auto = context:get()
    pending = pending + 1
    local id = pending
    local start = hooks.guard(function() try_low_ready(auto, id) end)
    -- One frame is the earliest the start check allows. A later start shows the raised pose first.
    -- After a run, a one frame start dips the gun through the run to walk transition.
    if ability_tag:get().TagName:ToString() == RUN_TAG then
        ExecuteInGameThreadWithDelay(config.low_ready_run_delay_ms, start)
    else
        ExecuteInGameThreadAfterFrames(1, start)
    end
end

--- Hook the auto low ready's ability end handler. The class is native.
function M.install()
    hooks.install(HOOK_FN, nil, function() end, on_ability_ended)
end

return M
