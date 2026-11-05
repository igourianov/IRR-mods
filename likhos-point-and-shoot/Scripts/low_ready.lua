-- low_ready.lua : low ready is the weapon's resting position (docs/solutions/low-ready-default.md).
--
-- Every game name here comes from docs/solutions/low-ready-default.md.
-- The game's own auto low ready does the lowering. This only shortens its idle delay on the core component's live settings, so the saved settings keep the player's values.
-- The menu's auto low ready toggle stays the player's switch for it.
-- Holds no UObject between calls.

local log    = require("log")
local hook   = require("hook")
local config = require("config")

local M = {}

local hooks = hook.new("low ready default", "auto low ready keeps its menu delay")

local HOOK_FN = "/Script/Test_C.FirstPersonAutoLowReady:OnAbilityEnded"

-- An engine timer with a zero rate never fires, so the delay stays above zero.
local DELAY_S = math.max(config.low_ready_delay_ms or 100, 10) / 1000

-- The native code reads the delay from the core component's live settings, not from the settings it is handed.
-- The live settings are reloaded from the save on every menu apply and a new character starts from the save, so the delay is written before every call.
local function on_pre(context)
    local settings = context:get().FirstPersonCoreComponent.ControllerSettings
    log.debug("low ready: ability ended, auto %s, delay %s", tostring(settings.bAutoLowReadyOnIdle), tostring(settings.AutoLowReadyIdleDelay))
    settings.AutoLowReadyIdleDelay = DELAY_S
end

--- Hook the auto low ready's ability end handler. The class is native.
function M.install()
    hooks.install(HOOK_FN, nil, on_pre)
end

return M
