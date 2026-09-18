-- context.lua : should a bind be allowed to fire right now?
--
-- The failure this prevents: toggling crouch while typing in the stash
-- search box. UE4SS key binds do not respect game focus on their own.
--
-- All checks are defensive - if we cannot determine state, we ALLOW the
-- bind rather than silently breaking it, except where noted.

local log  = require("log")
local util = require("util")

local M = {}

--- True when the game has a UI element holding keyboard focus, or the input
--- mode is UI-only / game-and-UI.
---
--- RECON REQUIRED: confirm the property names below against the UHT dump.
--- UE exposes these differently across versions and games may wrap them.
local function ui_has_focus(pc)
    if not util.valid(pc) then return false end

    -- Most common: the controller tracks whether the mouse cursor is shown,
    -- which in practice tracks "a menu is open" for FPS games.
    local ok, shown = pcall(function() return pc.bShowMouseCursor end)
    if ok and shown ~= nil then
        return shown == true
    end

    return false
end

--- Returns true if the bind may fire.
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
