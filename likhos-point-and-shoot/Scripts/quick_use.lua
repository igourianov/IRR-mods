-- quick_use.lua : the Interact (Instant) key uses the targeted interactable at once, holds included (docs/solutions/tap-to-use.md).
--
-- Every game name here comes from docs/solutions/tap-to-use.md (Recon).
-- The key starts the same ability F does, with the target's hold settings zeroed for that one interaction, so F keeps its hold.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")
local hook = require("hook")

local M = {}

local hooks = hook.new("quick use", "the Interact (Instant) key does nothing")

local LIB_PATH     = "/Script/Test_C.Default__InteractionFunctionLibrary"
local ABILITY_COMP = "/Script/Test_C.GameplayAbilityComponent"
local SGA_INTERACT = "/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_Interact.SGA_Interact_C"
-- The only interaction end a Lua hook sees. The target and option finish functions run natively.
local FINISH_FN    = "/Script/Test_C.InteractionManager:FinishInteractionWithTarget"

-- EInteractionState
local ONGOING = 3

-- Non-nil while an override is outstanding. Plain values only.
--   target  : full name of the overridden InteractionTarget
--   options : option path -> { hold, use_exec } as they were before the override
local override = nil

--- Put the overridden options' hold settings back. Options gone with their level are skipped.
local function restore()
    local state = override
    override = nil
    if not state then return end
    for path, v in pairs(state.options) do
        local opt = StaticFindObject(path)
        if util.valid(opt) then
            local hs = opt.HoldInteractionSetting
            hs.HoldTime = v.hold
            hs.UseActionExecutionTime = v.use_exec
        end
    end
end

--- Record and zero the hold settings of every option on the target. The game reads them while the interaction runs.
local function zero_holds(target)
    local options = {}
    target.InteractionOptions:ForEach(function(_, elem)
        local opt = elem:get()
        if not util.valid(opt) then return end
        local hs = opt.HoldInteractionSetting
        options[util.path(opt)] = { hold = hs.HoldTime, use_exec = hs.UseActionExecutionTime }
        hs.HoldTime = 0
        hs.UseActionExecutionTime = false
    end)
    override = { target = target:GetFullName(), options = options }
end

--- Deactivate the interact ability if it is still active. F's release does this, and a quick use has no release.
local function release_ability(comp, sga_class)
    local ability = nil
    comp.ActiveAbilities:ForEach(function(_, elem)
        local a = elem:get()
        if util.valid(a) and a:IsA(sga_class) then ability = a end
    end)
    if ability then ability:DeactivateAbility() end
end

local function press()
    restore()

    local pc = FindFirstOf("PlayerController")
    local lib = StaticFindObject(LIB_PATH)
    local comp_class = StaticFindObject(ABILITY_COMP)
    local sga_class = StaticFindObject(SGA_INTERACT)
    if not (util.valid(pc) and util.valid(lib) and util.valid(comp_class) and util.valid(sga_class)) then
        log.debug("QuickUse: interaction classes not loaded")
        return
    end
    local pawn = pc.Pawn
    if not util.valid(pawn) then return end
    local comp = pawn:GetComponentByClass(comp_class)
    local manager = lib:GetLocalInteractionManager(pc)
    if not (util.valid(comp) and util.valid(manager)) then
        log.debug("QuickUse: no ability component or interaction manager")
        return
    end
    local target = manager.SelectedTarget
    if not util.valid(target) then return end

    zero_holds(target)
    -- The ability runs F's activation checks and requests the interaction synchronously.
    local ok, started = pcall(function() return comp:TryStartAbilityByClass(sga_class) end)
    if not ok then
        restore()
        error(started)
    end
    if started and target.InteractionState == ONGOING then return end

    -- Nothing is holding, so no finish will come to put the holds back.
    restore()
    if not started then
        log.debug("QuickUse: ability refused")
        return
    end
    -- A Tab interaction runs on a delayed start, and SGA_Interact stays active until a release, which only F sends. Left active, it refuses the next start from either key.
    -- Release as F does. F's release lands before the delayed start too, and doesn't cancel it.
    manager:StopInteraction()
    release_ability(comp, sga_class)
end

-- Read the target here only. By the post callback a parameter can hold unrelated values.
local function on_finish(_, target)
    if not override then return end
    local finished = target:get()
    if not (util.valid(finished) and finished:GetFullName() == override.target) then return end
    restore()
    -- A Wait interaction (key unlock) leaves the ability active after it finishes, which refuses the next start.
    local pc = FindFirstOf("PlayerController")
    local comp_class = StaticFindObject(ABILITY_COMP)
    local sga_class = StaticFindObject(SGA_INTERACT)
    if not (util.valid(pc) and util.valid(pc.Pawn) and util.valid(comp_class) and util.valid(sga_class)) then return end
    local comp = pc.Pawn:GetComponentByClass(comp_class)
    if util.valid(comp) then release_ability(comp, sga_class) end
end

--- The Interact (Instant) key's press. Game thread.
M.press = hooks.guard(press)

--- Hook the interaction end, which puts the zeroed holds back. The class is native.
function M.install()
    hooks.install(FINISH_FN, nil, on_finish)
end

--- Drop the override without writing. Called on level load, which takes its options with it.
function M.reset()
    override = nil
end

return M
