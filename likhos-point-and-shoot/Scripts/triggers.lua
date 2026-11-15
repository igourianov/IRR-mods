-- triggers.lua : press, hold and release state per bind.
--
-- Binds are polled by input.lua, which reports the real press and release.
-- Press starts the action, tick() runs its held side every tick while the key is down and release ends it.
-- A key still down once tap_ms has passed is a hold: `hold` fires once from the tick, and release then fires `hold_release`. A key released earlier fires `tap` on release.

local log     = require("log")
local actions = require("actions")
local config  = require("config")

local M = {}

--- A press released within this window is a tap, milliseconds.
local TAP_MS = config.tap_ms or 250

-- bind.id -> { at, hold } while the key is held. at is os.clock() at press, wall time on Windows (docs/solutions/point-aim-bind.md, Recon, Enhanced Input injection). hold is whether `hold` has fired.
local holding = {}

--- Called from the game thread when the bound key goes down.
function M.on_press(bind)
	holding[bind.id] = { at = os.clock(), hold = false }
	actions.invoke(bind.action, "press")
end

--- Called from the game thread when the bound key goes up, or when the context gate starts blocking while it is held.
--- No-op unless a hold is active.
function M.on_release(bind)
	local state = holding[bind.id]
	if not state then return end
	holding[bind.id] = nil
	actions.invoke(bind.action, "release")
	actions.invoke(bind.action, state.hold and "hold_release" or "tap")
end

--- Called every frame from the game thread.
function M.tick(binds)
	for _, bind in ipairs(binds) do
		local state = bind.enabled and holding[bind.id]
		if state then
			actions.invoke(bind.action, "held")
			if not state.hold and (os.clock() - state.at) * 1000 >= TAP_MS then
				state.hold = true
				actions.invoke(bind.action, "hold")
			end
		end
	end
end

--- Drop all hold state. Call on level load, since a hold from the previous raid must not survive into the next one.
function M.reset()
	holding = {}
	log.debug("trigger state reset")
end

return M
