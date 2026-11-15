-- hold_breath.lua : the vanilla Hold Breath key toggles on a tap and holds breath only while held on a hold (docs/solutions/hold-breath-hold.md).
--
-- The vanilla key toggles the ability on its own press, so the mod acts only on a release past the tap window.
-- Holds no UObject between calls.

local util    = require("util")
local player  = require("player")
local actions = require("actions")

local IA_HOLD_BREATH = "/Game/Blueprints/InputSystem/InputActions/IA_HoldBreath.IA_HoldBreath"
local SGA_HOLD_BREATH = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_HoldBreath.SGA_HoldBreath_C"

local function active(pawn)
	local comp = pawn:GetAbilityComponent()
	local cls = StaticFindObject(SGA_HOLD_BREATH)
	if not (util.valid(comp) and util.valid(cls)) then return false end
	local found = false
	comp.ActiveAbilities:ForEach(function(_, elem)
		local ability = elem:get()
		if util.valid(ability) and ability:IsA(cls) then
			found = true
			return true
		end
	end)
	return found
end

local function hold_release()
	local pawn = player.pawn()
	-- Ended by itself (stamina, an interrupting ability), toggled off by the press or never started: the injected press would toggle a new one on.
	if not (pawn and active(pawn)) then return end
	player.inject_press(IA_HOLD_BREATH)
end

actions.define("HoldBreath", {
	hold_release = hold_release,
})
