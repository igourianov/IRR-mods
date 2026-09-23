-- context.lua : should a bind be allowed to fire right now?
--
-- The failure this prevents: a bind firing while a menu is open or a text field has focus.
-- If the state can't be determined, the bind is allowed rather than silently broken.

local log  = require("log")
local util = require("util")

local M = {}

--- True when the mouse cursor is shown, which is taken to mean a menu is open.
--- Unverified: bShowMouseCursor is not confirmed to change with a menu open or a text field focused.
local function ui_has_focus(pc)
    if not util.valid(pc) then return false end

    local ok, shown = pcall(function() return pc.bShowMouseCursor end)
    if ok and shown ~= nil then
        return shown == true
    end

    return false
end

function M.allows(bind, pc)
    if not bind.block_in_ui then return true end

    local ok, blocked = pcall(ui_has_focus, pc)
    if not ok then
        log.debug("context check errored; allowing bind '%s'", bind.id)
        return true
    end
    return not blocked
end

return M
