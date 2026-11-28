-- world/clock.lua : every in-game clock shows 24 hour time (docs/solutions/military-time.md).
--
-- Every game name here comes from docs/solutions/military-time.md.
-- The game's widgets format every clock through one native function that takes a 24 hour flag. Forcing the flag covers them all, the deploy screen's insertion times included.
-- Holds no state and no UObject.

local log  = require("lib.log")
local hook = require("lib.hook")

local M = {}

local hooks = hook.new("24 hour clock", "clocks stay in 12 hour time")

local HOOK_FN = "/Script/IRRMissionSystem.IRRMissionSystemFunctionLibrary:DayTimeToString"

-- A native function's params read correctly only in the pre callback, so the flag is written here.
local function on_format(_, _, b24_hour)
	b24_hour:set(true)
	log.debug("clock: forced 24 hour format")
end

--- Hook the game's day time formatter. The class is native.
function M.install()
	hooks.install(HOOK_FN, nil, on_format)
end

return M
