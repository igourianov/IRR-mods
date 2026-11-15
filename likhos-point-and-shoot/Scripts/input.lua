-- input.lua : mapped key polling.

local log      = require("log")
local player   = require("player")
local triggers = require("triggers")
local context  = require("context")
local keymap   = require("keymap")

local M = {}

local registered = {}   -- bind.id -> true
local key_down = {}     -- bind.id -> key state seen on the previous poll

--------------------------------------------------------------------------
-- Bind registration
--------------------------------------------------------------------------

--- Binds take their keys from the controls menu (keymap.lua) and are polled from the tick loop (M.poll), so they get a release event.
function M.register(bind)
	if not bind.mapping then
		log.error("bind '%s' has no mapping - ignoring", bind.id)
		return false
	end
	registered[bind.id] = true
	log.info("registered bind '%s' on mapping %s (polled)", bind.id, bind.mapping)
	return true
end

--- Turn key state changes into press and release events. Game thread, every tick.
function M.poll(binds)
	local pc = player.controller()
	if not pc then return end

	local profile = keymap.profile()
	for _, bind in ipairs(binds) do
		if registered[bind.id] then
			-- Keys are read every tick, so a rebind in the controls menu applies at once. No key mapped: never down.
			local down = false
			for _, key in ipairs(keymap.keys(bind.mapping, profile)) do
				if pc:IsInputKeyDown(key) then down = true end
			end
			local was = key_down[bind.id]
			key_down[bind.id] = down

			if down and not was then
				if context.allows(bind, pc) then
					triggers.on_press(bind)
				else
					log.debug("bind '%s' suppressed by context gate", bind.id)
				end
			elseif not down and was then
				triggers.on_release(bind)
			elseif down and not context.allows(bind, pc) then
				-- A menu opened mid-hold. Release now; the next press starts a fresh hold.
				triggers.on_release(bind)
			end
		end
	end
end

return M
