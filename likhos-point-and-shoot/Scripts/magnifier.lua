-- magnifier.lua : the zoom input folds and unfolds a hybrid sight's magnifier (docs/solutions/magnifier-zoom.md).
--
-- Every game name here comes from docs/solutions/magnifier-zoom.md.
-- Scroll forward at the zoom's end stop unfolds, scroll back folds. The vanilla Toggle Magnifier input does the flip.
-- Holds no UObject between calls.

local log     = require("log")
local util    = require("util")
local actions = require("actions")

local M = {}

local HOOK_FN = "/Script/Test_C.SightComponent:TrySwitchMagnificationLevel"
local IA_TOGGLE_MAGNIFIER = "/Game/Blueprints/InputSystem/InputActions/IA_ToggleMagnifier.IA_ToggleMagnifier"

-- SightModeKey values on a hybrid sight. A sight without a Folded mode has no magnifier.
local UNFOLDED, FOLDED = "Default", "Folded"

-- The mode changes within a tick of the injected press. Past this the flip is taken as refused and a new notch may try again.
local PENDING_TIMEOUT_MS = 500

-- Failures log once per session, so a renamed game name doesn't flood the log on every notch.
local error_logged = false

-- Set by the pre callback for the post callback of the same call. Plain values only.
--   sight     : full name of the sight
--   increment : the call's direction, true for zoom in
--   index     : MagnificationIndex before the call
local call = nil

-- Non-nil while a flip the mod requested hasn't reached the sight. Plain values only.
--   sight  : full name of the sight
--   target : the SightModeKey the flip goes to
--   at     : os.clock() at injection
local pending = nil

local function has_folded_mode(sight)
    local found = false
    sight.SightModes:ForEach(function(key)
        if key:get():ToString() == FOLDED then
            found = true
            return true
        end
    end)
    return found
end

local function is_current_sight(name)
    local wc = actions.equipped_weapon_component()
    if not wc then return false end
    local current = wc:GetCurrentSightComponent()
    return util.valid(current) and current:GetFullName() == name
end

-- bIncrement reads correctly here only. By the post callback the parameter holds unrelated values.
local function on_pre(context, increment)
    local sight = context:get()
    call = { sight = sight:GetFullName(), increment = increment:get(), index = sight.MagnificationIndex }
end

local function on_post(context)
    local before = call
    call = nil
    if not before then return end

    local sight = context:get()
    local name = sight:GetFullName()
    -- A moved index means the notch zoomed. The magnifier flips only at the end stop.
    if name ~= before.sight or sight.MagnificationIndex ~= before.index then return end
    if not has_folded_mode(sight) then return end

    local mode = sight.SightModeKey:ToString()
    if pending then
        local elapsed = (os.clock() - pending.at) * 1000
        -- Notches arriving before the game has handled the injected press would otherwise send a second toggle that undoes the first.
        if mode ~= pending.target and name == pending.sight and elapsed < PENDING_TIMEOUT_MS then return end
        pending = nil
    end

    local target = before.increment and UNFOLDED or FOLDED
    if mode == target or not is_current_sight(name) then return end

    actions.inject_press(IA_TOGGLE_MAGNIFIER)
    pending = { sight = name, target = target, at = os.clock() }
    log.debug("magnifier: flipping %s to %s", name, target)
end

local function guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and not error_logged then
            error_logged = true
            log.error("magnifier zoom failed, zoom stays vanilla: %s", tostring(err))
        end
    end
end

--- Hook the sight's magnification call. The class is native, so it is loaded before any mod runs.
function M.install()
    local ok, err = pcall(RegisterHook, HOOK_FN, guarded(on_pre), guarded(on_post))
    if not ok then
        log.error("magnifier: could not hook %s, magnifier zoom is off: %s", HOOK_FN, tostring(err))
        return
    end
    log.info("magnifier: hooked %s", HOOK_FN)
end

--- Drop per-call and pending flip state. Called on level load.
function M.reset()
    call = nil
    pending = nil
end

return M
