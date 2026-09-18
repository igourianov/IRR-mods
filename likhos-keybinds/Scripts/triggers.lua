-- triggers.lua : per-bind state machine.
--
-- UE4SS RegisterKeyBind only gives us a press event - no release, no repeat.
-- So "is the key still down?" has to be inferred. Two consequences:
--
--   * "hold" mode needs a real key-down/key-up source. Until recon confirms
--     one (hooking UPlayerInput::InputKey, or reading the IMC), hold mode is
--     approximated: the press starts the action and a timeout ends it.
--   * Everything time-based runs off tick(), not off the press callback.
--
-- States: idle -> pending -> active -> idle

local log  = require("log")
local util = require("util")
local actions = require("actions")

local M = {}

local state = {}   -- bind.id -> { phase, since, latched }

local function get(bind)
    local s = state[bind.id]
    if not s then
        s = { phase = "idle", since = 0, latched = false }
        state[bind.id] = s
    end
    return s
end

--- Called from the game thread when the bound key is pressed.
function M.on_press(bind)
    local s   = get(bind)
    local now = util.now_ms()

    if bind.mode == "passthrough" then
        actions.invoke(bind.action, "press")
        actions.invoke(bind.action, "release")

    elseif bind.mode == "toggle" then
        s.latched = not s.latched
        actions.invoke(bind.action, s.latched and "press" or "release")
        log.debug("bind '%s' toggled -> %s", bind.id, tostring(s.latched))

    elseif bind.mode == "hold" then
        s.phase = "active"
        s.since = now
        actions.invoke(bind.action, "press")

    elseif bind.mode == "double_tap" then
        local window = bind.double_tap_window_ms or 250
        if s.phase == "pending" and (now - s.since) <= window then
            s.phase = "idle"
            actions.invoke(bind.action, "press")
            actions.invoke(bind.action, "release")
            log.debug("bind '%s' double-tap fired", bind.id)
        else
            s.phase = "pending"
            s.since = now
        end

    elseif bind.mode == "tap_hold" then
        s.phase = "pending"
        s.since = now

    else
        log.error("bind '%s' has unknown mode '%s' - ignoring",
                  bind.id, tostring(bind.mode))
    end
end

--- Called every tick_ms from the game thread. Resolves timeouts.
function M.tick(binds)
    local now = util.now_ms()

    for _, bind in ipairs(binds) do
        if bind.enabled then
            local s = state[bind.id]
            if s and s.phase ~= "idle" then
                local elapsed = now - s.since

                if bind.mode == "double_tap" and s.phase == "pending" then
                    if elapsed > (bind.double_tap_window_ms or 250) then
                        -- Second tap never arrived. Nothing fires; a
                        -- double-tap bind deliberately has no single-tap
                        -- behaviour, otherwise it would double-fire with
                        -- the game's own binding.
                        s.phase = "idle"
                    end

                elseif bind.mode == "tap_hold" and s.phase == "pending" then
                    if elapsed >= (bind.hold_threshold_ms or 300) then
                        s.phase = "active"
                        actions.invoke(bind.action_hold, "press")
                        log.debug("bind '%s' -> hold", bind.id)
                    end

                elseif bind.mode == "hold" and s.phase == "active" then
                    -- Approximation: see header note. Ends the action after
                    -- the threshold since we cannot observe key release yet.
                    if elapsed >= (bind.hold_release_ms or 150) then
                        s.phase = "idle"
                        actions.invoke(bind.action, "release")
                    end
                end
            end
        end
    end
end

--- Drop all latched state. Call on level load - a toggle latched in the
--- previous raid must not survive into the next one.
function M.reset()
    state = {}
    log.debug("trigger state reset")
end

return M
