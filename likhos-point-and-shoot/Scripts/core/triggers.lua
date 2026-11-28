-- core/triggers.lua : press, hold and release state per bind.
--
-- Binds are polled by core/input.lua, which reports the real press and release.
-- Press starts the action, tick() runs its held side every tick while the key is down and release ends it.
-- A key still down once tap_ms has passed is a hold: `hold` fires once from the tick, and release then fires `hold_release`. A key released earlier fires `tap` on release.
-- An action defining `double_tap` has its `tap` wait out the double tap window after the release. A press inside the window fires `double_tap` instead, and that press makes no `tap` or `hold`.

local log      = require("lib.log")
local registry = require("core.registry")
local config   = require("config")

local M = {}

--- A press released within this window is a tap, milliseconds.
local TAP_MS = config.tap_ms or 250
--- A second press within this window after a tap's release is a double tap, milliseconds.
local DOUBLE_TAP_MS = config.double_tap_ms or 200

-- bind.name -> { at, hold, double } while the key is held. at is os.clock() at press, wall time on Windows (docs/solutions/point-aim-bind.md, Recon, Enhanced Input injection). hold is whether `hold` has fired. double is whether this press was a double tap.
local holding = {}
-- bind.name -> os.clock() at the release of a tap waiting out its double tap window.
local pending_tap = {}

--- Called from the game thread when the bound key goes down.
function M.on_press(bind)
	local double = pending_tap[bind.name] ~= nil
	pending_tap[bind.name] = nil
	holding[bind.name] = { at = os.clock(), hold = false, double = double }
	registry.invoke(bind.name, "press")
	if double then registry.invoke(bind.name, "double_tap") end
end

--- Called from the game thread when the bound key goes up, or when the context gate starts blocking while it is held.
--- No-op unless a hold is active.
function M.on_release(bind)
	local state = holding[bind.name]
	if not state then return end
	holding[bind.name] = nil
	registry.invoke(bind.name, "release")
	if state.double then return end
	if state.hold then
		registry.invoke(bind.name, "hold_release")
		return
	end
	if registry.defines(bind.name, "double_tap") then
		pending_tap[bind.name] = os.clock()
		return
	end
	registry.invoke(bind.name, "tap")
end

--- Whether bind has a tap waiting out its double tap window.
function M.tap_pending(bind)
	return pending_tap[bind.name] ~= nil
end

--- Forget bind's waiting tap.
function M.drop_tap(bind)
	pending_tap[bind.name] = nil
end

--- Called every frame from the game thread.
function M.tick(binds)
	for _, bind in ipairs(binds) do
		local state = holding[bind.name]
		if state then
			registry.invoke(bind.name, "held")
			if not state.hold and not state.double and (os.clock() - state.at) * 1000 >= TAP_MS then
				state.hold = true
				registry.invoke(bind.name, "hold")
			end
		end
		local released_at = pending_tap[bind.name]
		if released_at and (os.clock() - released_at) * 1000 >= DOUBLE_TAP_MS then
			pending_tap[bind.name] = nil
			registry.invoke(bind.name, "tap")
		end
	end
end

--- Drop all hold state. Call on level load, since a hold from the previous raid must not survive into the next one.
function M.reset()
	holding = {}
	pending_tap = {}
	log.debug("trigger state reset")
end

return M
