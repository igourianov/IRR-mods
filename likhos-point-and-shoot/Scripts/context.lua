-- context.lua : should a bind be allowed to fire right now?
--
-- The failure this prevents: a bind firing while a menu is open or a text field has focus.
-- If the state can't be determined, the bind is allowed rather than silently broken.

local log  = require("log")
local util = require("util")

local M = {}

--- A block_in_ui bind is blocked while the mouse cursor is shown, which is taken to mean a menu is open.
--- Unverified: bShowMouseCursor is not confirmed to change with a menu open or a text field focused.
function M.allows(bind, pc)
	if not bind.block_in_ui then return true end

	local ok, shown = pcall(function() return util.valid(pc) and pc.bShowMouseCursor end)
	if not ok then
		log.debug("context check errored; allowing bind '%s'", bind.id)
		return true
	end
	return shown ~= true
end

return M
