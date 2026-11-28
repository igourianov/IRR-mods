-- core/input.lua : mapped key polling.

local log      = require("lib.log")
local util     = require("lib.util")
local player   = require("core.player")
local triggers = require("core.triggers")
local keymap   = require("controls.keymap")

local M = {}

local key_down = {}     -- bind.name -> key state seen on the previous poll

--- Whether bind may fire right now: a bind is blocked while the mouse cursor is shown, which is taken to mean a menu is open.
--- The failure this prevents: a bind firing while a menu is open or a text field has focus. If the state can't be determined, the bind is allowed rather than silently broken.
--- Unverified: bShowMouseCursor is not confirmed to change with a menu open or a text field focused.
local function allowed(bind, pc)
	local ok, shown = pcall(function() return util.valid(pc) and pc.bShowMouseCursor end)
	if not ok then
		log.debug("context check errored; allowing bind '%s'", bind.name)
		return true
	end
	return shown ~= true
end

--- Game thread, every tick.
--- Keys are read every tick, so a rebind in the controls menu applies at once. No key mapped: never down.
function M.poll(binds)
	local pc = player.controller()
	if not pc then return end

	local profile = keymap.profile()
	for _, bind in ipairs(binds) do
		local down = false
		for _, key in ipairs(keymap.keys(bind.name, profile)) do
			if pc:IsInputKeyDown(key) then down = true end
		end
		local was = key_down[bind.name]
		key_down[bind.name] = down

		if down and not was then
			if allowed(bind, pc) then
				triggers.on_press(bind)
			else
				log.debug("bind '%s' suppressed by context gate", bind.name)
			end
		elseif not down and was then
			triggers.on_release(bind)
		elseif down and not allowed(bind, pc) then
			-- A menu opened mid-hold. Release now; the next press starts a fresh hold.
			triggers.on_release(bind)
		end

		-- A tap waiting out its double tap window must not fire into a menu opened meanwhile.
		if triggers.tap_pending(bind) and not allowed(bind, pc) then triggers.drop_tap(bind) end
	end
end

return M
