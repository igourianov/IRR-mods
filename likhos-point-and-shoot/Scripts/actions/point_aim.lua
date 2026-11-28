-- actions/point_aim.lua : hold to aim straight into point sight, with the laser that suits the player's vision on, in either vanilla aim mode (docs/solutions/point-aim-bind.md).
--
-- Aim goes through the vanilla aim input, so it combines with the vanilla aim key as a second key bound to it would.
-- Every game name here comes from docs/solutions/point-aim-bind.md (Recon), the UE4SS object dump and debug logging of the controller settings.
-- Holds no UObject between calls.

local log      = require("lib.log")
local util     = require("lib.util")
local player   = require("core.player")
local devices  = require("actions.devices")
local registry = require("core.registry")

local M = {}

-- IA_Aim has a Released trigger. In hold mode aim holds only while its one-frame press repeats every tick. In toggle mode each press toggles aim.
local IA_AIM = "/Game/Blueprints/InputSystem/InputActions/IA_Aim.IA_Aim"
-- The aim ability. Its TagToTriggerAbility, Character.Abilities.Active.Aiming, is also the aim mode's key in the controller settings' Toggles map.
local SGA_AIM_CDO = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_Aim.Default__SGA_Aim_C"
-- Holds the player's ControllerSettings.
local CORE_COMP = "/Script/Test_C.FirstPersonCoreComponent"

-- Non-nil while a PointAim hold is live. Plain values only, no UObjects.
--   flipped : the mode was regular on press and this action switched it to point
--   weapon  : full name of the weapon component the mode was flipped on
--   device  : full name of the laser this hold turned on, nil when it turned none on
--   inject  : "hold" presses the aim input every tick, "toggle" on press and release, nil not at all
local hold = nil

--- Aiming subobject, the equipped weapon's WeaponComponent and the pawn.
---@return UObject? ads # nil, with the rest, when any is missing
---@return UObject? wc
---@return UObject? pawn
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
	return ads, wc, pawn
end

local function aim_tag()
	local cdo = StaticFindObject(SGA_AIM_CDO)
	return util.valid(cdo) and cdo.TagToTriggerAbility or nil
end

--- Whether the vanilla aim mode setting is toggle.
local function toggle_mode(pawn, tag)
	local core = util.component(pawn, CORE_COMP)
	if not core then return false end
	local name = tag.TagName:ToString()
	local on = false
	core.ControllerSettings.Toggles:ForEach(function(key, value)
		if key:get().TagName:ToString() == name then on = value:get() end
	end)
	return on
end

local function aim_active(pawn, tag)
	local abilities = pawn:GetAbilityComponent()
	return util.valid(abilities) and abilities:IsAbilityActiveByTag(tag)
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
	local ads, wc, pawn = resolve_aim_objects()
	local tag = aim_tag()
	if not (ads and tag) then
		log.debug("PointAim: no pawn, aiming subobject, weapon or aim ability right now")
		return
	end
	local inject = "hold"
	-- Vanilla aim toggled on already stays on, and this action only switches it to point sight while held.
	if toggle_mode(pawn, tag) then inject = not aim_active(pawn, tag) and "toggle" or nil end
	-- The sticky mode lives on the weapon component. The aiming subobject's own bIsPointSight doesn't track it.
	-- TriggerPointSight works while not aimed, so aim comes up already in point sight.
	local flipped = not wc.bIsPointSight
	if flipped then ads:TriggerPointSight() end
	hold = { flipped = flipped, weapon = wc:GetFullName(), device = devices.try(laser_on, wc), inject = inject }
	if inject then player.inject_press(IA_AIM) end
end

local function held()
	if hold and hold.inject == "hold" then player.inject_press(IA_AIM) end
end

local function release()
	local state = hold
	hold = nil
	if not state then return end
	local ads, wc, pawn = resolve_aim_objects()
	if not ads then return end

	-- Hold mode: injection has already stopped, so the game sees the aim input released and ends aim itself, unless the vanilla aim key still holds it.
	-- Toggle mode: one more press toggles aim off, unless the vanilla aim key's own toggle already did.
	if state.inject == "toggle" then
		local tag = aim_tag()
		if tag and aim_active(pawn, tag) then player.inject_press(IA_AIM) end
	end
	if wc:GetFullName() ~= state.weapon then
		log.debug("PointAim: weapon changed during hold, mode and laser not restored")
		return
	end
	-- The user may have switched the mode back themselves mid-hold.
	if state.flipped and wc.bIsPointSight then ads:TriggerPointSight() end
	if state.device then devices.try(devices.off, wc, state.device) end
end

--- Define the Point Aim action.
function M.install()
	registry.define("LikhosPointShootingDirect", {
		press   = press,
		held    = held,
		release = release,
		reset   = function() hold = nil end,
	})
end

return M
