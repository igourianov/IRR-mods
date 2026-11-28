-- weapon/hold_breath.lua : the vanilla Hold Breath key toggles on a tap and holds breath only while held on a hold (docs/solutions/hold-breath-hold.md).
--
-- The vanilla key toggles the ability on its own press, so the mod acts only on a release past the tap window.
-- Holds no UObject between calls.

local util    = require("lib.util")
local player  = require("core.player")
local actions = require("core.actions")

local M = {}

local IA_HOLD_BREATH = "/Game/Blueprints/InputSystem/InputActions/IA_HoldBreath.IA_HoldBreath"
local SGA_HOLD_BREATH = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_HoldBreath.SGA_HoldBreath_C"

local function active(pawn)
	local comp = pawn:GetAbilityComponent()
	local cls = StaticFindObject(SGA_HOLD_BREATH)
	if not (util.valid(comp) and util.valid(cls)) then return false end
	return util.find(comp.ActiveAbilities, function(ability) return ability:IsA(cls) end) ~= nil
end

local function hold_release()
	local pawn = player.pawn()
	-- Ended by itself (stamina, an interrupting ability), toggled off by the press or never started: the injected press would toggle a new one on.
	if not (pawn and active(pawn)) then return end
	player.inject_press(IA_HOLD_BREATH)
end

--- Define the Hold Breath action.
function M.install()
	actions.define("IA_HoldBreath", {
		hold_release = hold_release,
	})
end

return M
