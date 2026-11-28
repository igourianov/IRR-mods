-- core/actions.lua : action name -> the functions that run its phases.
-- Each bind feature defines its own actions when it is loaded, so this module knows none of them.

local log  = require("lib.log")
local util = require("lib.util")

local M = {}

-- name -> phases, as passed to M.define.
local defined = {}

--- Define action `name` with a Lua function per phase it acts on (core/triggers.lua), and optionally reset, which drops its state on level load.
--- press and release run on the key's press and release, held every tick while it is down.
--- hold runs once when the key is still down past tap_ms. On release, hold_release runs after a hold, tap otherwise.
--- double_tap runs on a second press inside double_tap_ms of a tap's release. Defining it delays that action's tap until the window has passed.
function M.define(name, phases)
	defined[name] = phases
end

--- Whether action `name` is defined, and with phase given, whether it has a function for it.
function M.defines(name, phase)
	local spec = defined[name]
	return spec ~= nil and (phase == nil or spec[phase] ~= nil)
end

--- Actions found undefined this session, so the error logs once rather than every tick.
local disabled = {}

--- MUST be called from the game thread (see core/input.lua).
function M.invoke(name, phase)
	if disabled[name] then return false end

	local spec = defined[name]
	if not spec then
		log.error("action '%s' is not defined - bind disabled", name)
		disabled[name] = true
		return false
	end

	local fn = spec[phase]
	-- A phase without a function is not a failure.
	if not fn then return true end
	return util.safe(("action %s:%s"):format(name, phase), fn)
end

--- Clear the disabled list and every action's state. Called on level load.
function M.reset()
	disabled = {}
	for name, spec in pairs(defined) do
		if spec.reset then util.safe(("action %s:reset"):format(name), spec.reset) end
	end
end

return M
