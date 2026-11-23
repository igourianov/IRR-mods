-- movement/sprint_stand.lua : a double tap of Run while crouched ends the crouch and starts a sprint (docs/solutions/sprint-cancels-crouch.md).
--
-- Every game name here comes from docs/solutions/sprint-cancels-crouch.md.
-- The game detects the double tap only while standing, because a crouched Run ends on release without its grace time.
-- Holds no UObject between calls.

local log    = require("lib.log")
local hook   = require("lib.hook")
local util   = require("lib.util")
local player = require("core.player")

local M = {}

local hooks = hook.new("sprint cancels crouch", "sprint keeps the crouch as in vanilla")

local TAGS_FN = "/Script/Test_C.AdvancedMovementComponent:OnOwnedGameplayTagsUpdated"
local DOUBLE_TAP_TRIGGER = "/Game/Blueprints/InputSystem/InputActions/IA_Sprint.IA_Sprint:InputTrigger_DoubleTap_0"
local SGA_CROUCH = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_Crouch.SGA_Crouch_C"
local SPRINT_CDO = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_Sprint.Default__SGA_Sprint_C"
local RUN_NAME = "Character.Abilities.Active.Running.Wants To Run"
local IS_RUNNING_NAME = "Character.Abilities.Active.Running.Is Running"
local CROUCHING_NAME = "Character.Abilities.Active.Crouching"

local was_running = false
-- The game holds this tag only while the character really runs. Run held while standing still or out of stamina lacks it.
local is_running = false
-- os.clock() when a Run last ended while crouched, wall time on Windows.
local run_ended_at = nil

local function start_sprint()
	if not (was_running and is_running) then return end
	local pawn = player.pawn()
	if not pawn then return end
	local abilities = pawn:GetAbilityComponent()
	local tags = pawn:GetGameplayTagsComponent()
	local crouch_class = StaticFindObject(SGA_CROUCH)
	local sprint_cdo = StaticFindObject(SPRINT_CDO)
	if not (util.valid(abilities) and util.valid(tags) and util.valid(crouch_class) and util.valid(sprint_cdo)) then return end
	local crouch = util.find(abilities.ActiveAbilities, function(ability) return ability:IsA(crouch_class) end)
	if not crouch then return end
	-- StopAbilitiesByTag leaves an active crouch running.
	crouch:FinishAbility(true)
	-- A tag container built as a Lua table adds nothing. Sprint's defaults hold one with only its tag, and an empty one.
	tags:UpdateGameplayTags(sprint_cdo.GrantedAbilityTags, sprint_cdo.BlockAbilitiesWithTags)
	log.debug("crouched double tap: crouch finished, sprint requested")
end

local function on_tags_updated(context, tags)
	local pawn = player.pawn()
	-- NPC movement components run this too.
	if not pawn or context:get():GetOwner():GetAddress() ~= pawn:GetAddress() then return end

	local running, crouching = false, false
	is_running = false
	tags:get().GameplayTags:ForEach(function(_, elem)
		local name = elem:get().TagName:ToString()
		running = running or name == RUN_NAME
		crouching = crouching or name == CROUCHING_NAME
		is_running = is_running or name == IS_RUNNING_NAME
	end)

	if running == was_running then return end
	was_running = running
	if not running then
		-- A Run that ended while standing is no first tap. A standing Run released just before a crouch still counts, since its grace time keeps it active into the crouch.
		run_ended_at = crouching and os.clock() or nil
		return
	end
	if not (crouching and run_ended_at) then return end

	local trigger = StaticFindObject(DOUBLE_TAP_TRIGGER)
	if not util.valid(trigger) then return end
	if os.clock() - run_ended_at > trigger.Delay then return end
	-- A frame later, so the crouch doesn't end from inside the tag update that reported this Run, and the game has had its chance to add Is Running.
	ExecuteInGameThreadAfterFrames(1, hooks.guard(start_sprint))
end

--- Hook the movement component's tag update. The class is native.
function M.install()
	hooks.install(TAGS_FN, nil, on_tags_updated)
end

return M
