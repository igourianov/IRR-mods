-- weapon/point_aim.lua : hold to aim straight into point sight, with the laser that suits the player's vision on (docs/solutions/point-aim-bind.md).
--
-- Every game name here comes from docs/solutions/point-aim-bind.md (Recon).
-- Holds no UObject between calls.

local log     = require("lib.log")
local util    = require("lib.util")
local player  = require("core.player")
local devices = require("weapon.devices")
local actions = require("core.actions")

-- IA_Aim has a Released trigger, so aim holds only while its one-frame press repeats every tick.
local IA_AIM = "/Game/Blueprints/InputSystem/InputActions/IA_Aim.IA_Aim"

-- Non-nil while a PointAim hold is live. Plain values only, no UObjects.
--   flipped : the mode was regular on press and this action switched it to point
--   weapon  : full name of the weapon component the mode was flipped on
--   device  : full name of the laser this hold turned on, nil when it turned none on
local hold = nil

--- Aiming subobject and the equipped weapon's WeaponComponent, or nil.
local function resolve_aim_objects()
	local pawn = player.pawn()
	if not pawn then return nil end
	local wc = player.weapon_component()
	if not wc then return nil end

	local core_lib = StaticFindObject("/Script/Test_C.Default__FirstPersonCoreFunctionLibrary")
	local ads_cls  = StaticFindObject("/Script/Test_C.FirstPersonWeaponADS")
	if not (util.valid(core_lib) and util.valid(ads_cls)) then return nil end

	local ads = core_lib:GetFirstPersonCoreSubObject(pawn, ads_cls)
	if not util.valid(ads) then return nil end
	return ads, wc
end

--- Turn on the laser that suits the player's vision and return its full name.
--- Nil when the weapon has none or it was already on: a laser this action didn't light is never put out.
local function laser_on(wc)
	local dev = devices.pick(wc, "laser")
	if not dev or devices.is_on(dev) then return nil end
	devices.set(dev, true)
	return dev:GetFullName()
end

local function press()
	local ads, wc = resolve_aim_objects()
	if not ads then
		log.debug("PointAim: no pawn, aiming subobject or weapon right now")
		return
	end
	-- The sticky mode lives on the weapon component. The aiming subobject's own bIsPointSight doesn't track it.
	-- TriggerPointSight works while not aimed, so aim comes up already in point sight.
	local flipped = not wc.bIsPointSight
	if flipped then ads:TriggerPointSight() end
	hold = { flipped = flipped, weapon = wc:GetFullName(), device = devices.try(laser_on, wc) }
	player.inject_press(IA_AIM)
end

local function held()
	if hold then player.inject_press(IA_AIM) end
end

local function release()
	-- Injection has already stopped, so the game sees the aim input released and ends aim itself.
	local state = hold
	hold = nil
	if not (state and (state.flipped or state.device)) then return end

	local ads, wc = resolve_aim_objects()
	if not ads then return end
	if wc:GetFullName() ~= state.weapon then
		log.debug("PointAim: weapon changed during hold, mode and laser not restored")
		return
	end
	-- The user may have switched the mode back themselves mid-hold.
	if state.flipped and wc.bIsPointSight then ads:TriggerPointSight() end
	if state.device then devices.try(devices.off, wc, state.device) end
end

actions.define("PointAim", {
	press   = press,
	held    = held,
	release = release,
	reset   = function() hold = nil end,
})
