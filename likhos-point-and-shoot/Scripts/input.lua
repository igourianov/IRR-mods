-- input.lua : mapped key polling.

local log      = require("log")
local util     = require("util")
local player   = require("player")
local triggers = require("triggers")
local keymap   = require("keymap")

local M = {}

local key_down = {}     -- bind.id -> key state seen on the previous poll

--- Whether bind may fire right now: a block_in_ui bind is blocked while the mouse cursor is shown, which is taken to mean a menu is open.
--- The failure this prevents: a bind firing while a menu is open or a text field has focus. If the state can't be determined, the bind is allowed rather than silently broken.
--- Unverified: bShowMouseCursor is not confirmed to change with a menu open or a text field focused.
local function allowed(bind, pc)
	if not bind.block_in_ui then return true end

	local ok, shown = pcall(function() return util.valid(pc) and pc.bShowMouseCursor end)
	if not ok then
		log.debug("context check errored; allowing bind '%s'", bind.id)
		return true
	end
	return shown ~= true
end

--- Turn key state changes of binds into press and release events. Game thread, every tick.
--- Keys are read every tick, so a rebind in the controls menu applies at once. No key mapped: never down.
function M.poll(binds)
	local pc = player.controller()
	if not pc then return end

	local profile = keymap.profile()
	for _, bind in ipairs(binds) do
		local down = false
		for _, key in ipairs(keymap.keys(bind.mapping, profile)) do
			if pc:IsInputKeyDown(key) then down = true end
		end
		local was = key_down[bind.id]
		key_down[bind.id] = down

		if down and not was then
			if allowed(bind, pc) then
				triggers.on_press(bind)
			else
				log.debug("bind '%s' suppressed by context gate", bind.id)
			end
		elseif not down and was then
			triggers.on_release(bind)
		elseif down and not allowed(bind, pc) then
			-- A menu opened mid-hold. Release now; the next press starts a fresh hold.
			triggers.on_release(bind)
		end
	end
end

return M
