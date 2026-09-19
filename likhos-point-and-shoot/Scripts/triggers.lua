-- triggers.lua : hold state per bind.
--
-- Binds are polled by input.lua, which reports the real press and release.
-- Press starts the action, tick() runs its held side every tick while the key is down and release ends it.

local log     = require("log")
local actions = require("actions")

local M = {}

local holding = {}   -- bind.id -> true while the key is held

--- Called from the game thread when the bound key goes down.
function M.on_press(bind)
    holding[bind.id] = true
    actions.invoke(bind.action, "press")
end

--- Called from the game thread when the bound key goes up, or when the context gate starts blocking while it is held.
--- No-op unless a hold is active.
function M.on_release(bind)
    if not holding[bind.id] then return end
    holding[bind.id] = nil
    actions.invoke(bind.action, "release")
end

--- Called every tick_ms from the game thread.
function M.tick(binds)
    for _, bind in ipairs(binds) do
        if bind.enabled and holding[bind.id] then
            actions.invoke(bind.action, "held")
        end
    end
end

--- Drop all hold state. Call on level load, since a hold from the previous raid must not survive into the next one.
function M.reset()
    holding = {}
    log.debug("trigger state reset")
end

return M
