-- weapon/flashlight.lua : tap to leave the light that suits the player's vision on, hold to light it while held (docs/solutions/flashlight-bind.md).
--
-- Holds no UObject between calls.

local log     = require("lib.log")
local player  = require("core.player")
local devices = require("weapon.devices")
local actions = require("core.actions")

local M = {}

-- Set by a press, read by the release of a hold. Plain values only, no UObjects.
--   device : full name of the light the press turned on, nil when the press turned one off or found none
--   weapon : full name of the weapon component that light is on
local pressed = nil

--- Turn the light that suits the player's vision on, or off when it is already on, whoever turned it on.
--- Returns its full name only when this call turned it on, so release knows there is something to put out.
local function light_toggle(wc)
	local dev = devices.pick(wc, "light")
	if not dev then return nil end
	if devices.is_on(dev) then
		devices.set(dev, false)
		return nil
	end
	devices.set(dev, true)
	return dev:GetFullName()
end

local function press()
	pressed = nil
	local wc = player.weapon_component()
	if not wc then
		log.debug("Flashlight: no pawn or equipped weapon right now")
		return
	end
	pressed = { device = devices.try(light_toggle, wc), weapon = wc:GetFullName() }
end

-- A tap leaves the light on until the next press.
local function hold_release()
	local state = pressed
	pressed = nil
	-- Nothing to put out when the press turned a light off or found none.
	if not (state and state.device) then return end

	local wc = player.weapon_component()
	if not wc then return end
	if wc:GetFullName() ~= state.weapon then
		log.debug("Flashlight: weapon changed during hold, light left on")
		return
	end
	devices.try(devices.off, wc, state.device)
end

--- Define the Flashlight action.
function M.install()
	actions.define("Flashlight", {
		press        = press,
		hold_release = hold_release,
		reset        = function() pressed = nil end,
	})
end

return M
