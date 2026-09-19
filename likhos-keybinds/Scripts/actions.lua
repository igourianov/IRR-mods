-- actions.lua : action name -> how to invoke it on the pawn / controller.
--
-- Every game name here comes from docs/solutions/findings.md. Nothing is guessed from the real game.
--
-- Design rule: resolve lazily, per call, and never cache a UObject across a
-- level load. Caching the *name* is fine; caching the object is what crashes.

local log  = require("log")
local util = require("util")

local M = {}

--------------------------------------------------------------------------
-- PointAim: hold to aim straight into point sight (docs/solutions/point-aim-bind.md)
--------------------------------------------------------------------------

local IA_AIM = "/Game/Blueprints/InputSystem/InputActions/IA_Aim.IA_Aim"
local AIM_VALUE = { X = 1.0, Y = 0.0, Z = 0.0 }

-- Non-nil while a PointAim hold is live. Plain values only, no UObjects.
--   flipped : the mode was regular on press and this action switched it to point
--   weapon  : full name of the weapon component the mode was flipped on
local point_aim = nil

--- Aiming subobject and the equipped weapon's WeaponComponent, or nil.
local function resolve_aim_objects()
    local pc = FindFirstOf("PlayerController")
    if not util.valid(pc) then return nil end
    local pawn = pc.Pawn
    if not util.valid(pawn) then return nil end

    local core_lib = StaticFindObject("/Script/Test_C.Default__FirstPersonCoreFunctionLibrary")
    local inv_lib  = StaticFindObject("/Script/Test_C.Default__InventoryFunctionLibrary")
    local ads_cls  = StaticFindObject("/Script/Test_C.FirstPersonWeaponADS")
    local wc_cls   = StaticFindObject("/Script/Test_C.WeaponComponent")
    if not (util.valid(core_lib) and util.valid(inv_lib) and util.valid(ads_cls) and util.valid(wc_cls)) then return nil end

    local ads = core_lib:GetFirstPersonCoreSubObject(pawn, ads_cls)
    local weapon = inv_lib:GetEquippedWeapon(pawn)
    if not (util.valid(ads) and util.valid(weapon)) then return nil end
    local wc = weapon:GetComponentByClass(wc_cls)
    if not util.valid(wc) then return nil end
    return ads, wc
end

-- A one-frame IA_Aim press. IA_Aim has a Released trigger, so aim holds only while this repeats every tick.
-- Continuous injection can't be used: its FInputActionValue parameter can't be built from UE4SS Lua.
local function inject_aim()
    local subsystem = FindFirstOf("EnhancedInputLocalPlayerSubsystem")
    local ia = StaticFindObject(IA_AIM)
    if not (util.valid(subsystem) and util.valid(ia)) then return end
    subsystem:InjectInputVectorForAction(ia, AIM_VALUE, {}, {})
end

local function point_aim_press()
    local ads, wc = resolve_aim_objects()
    if not ads then
        log.debug("PointAim: no pawn, aiming subobject or weapon right now")
        return
    end
    -- The sticky mode lives on the weapon component. The aiming subobject's own bIsPointSight doesn't track it.
    -- TriggerPointSight works while not aimed, so aim comes up already in point sight.
    local flipped = not wc.bIsPointSight
    if flipped then ads:TriggerPointSight() end
    point_aim = { flipped = flipped, weapon = wc:GetFullName() }
    inject_aim()
end

local function point_aim_held()
    if point_aim then inject_aim() end
end

local function point_aim_release()
    -- Injection has already stopped, so the game sees the aim input released and ends aim itself.
    local state = point_aim
    point_aim = nil
    if not (state and state.flipped) then return end

    local ads, wc = resolve_aim_objects()
    if not ads then return end
    if wc:GetFullName() ~= state.weapon then
        log.debug("PointAim: weapon changed during hold, mode not restored")
        return
    end
    -- The user may have switched the mode back themselves mid-hold.
    if wc.bIsPointSight then ads:TriggerPointSight() end
end

--- Each entry describes one logical action. Two kinds:
---
--- UFunction entry:
---   class   : object class to search for at call time ("PlayerController",
---             the pawn class, whatever owns the handler).
---   press   : UFunction name to call on press.
---   release : UFunction name to call on release. nil for fire-and-forget.
---   args    : optional function returning the argument table for the call.
---
--- Scripted entry: press, held and release are Lua functions. held runs every tick while a hold bind is down.
M.ACTIONS = {
    ["PointAim"] = {
        press   = point_aim_press,
        held    = point_aim_held,
        release = point_aim_release,
    },
}

--- Track which actions have been permanently disabled this session so we log
--- the failure once rather than every keypress.
local disabled = {}

--- Invoke one side of an action. `phase` is "press", "held" or "release".
--- MUST be called from the game thread - see input.lua.
function M.invoke(name, phase)
    if disabled[name] then return false end

    local spec = M.ACTIONS[name]
    if not spec then
        log.error("action '%s' is not defined in actions.lua - bind disabled", name)
        disabled[name] = true
        return false
    end

    local fn_name = spec[phase]
    if not fn_name then
        -- Legitimately nothing to do on this phase.
        return true
    end
    if type(fn_name) == "function" then
        return util.safe(("action %s:%s"):format(name, phase), fn_name)
    end

    local owner = FindFirstOf(spec.class)
    if not util.valid(owner) then
        log.debug("action '%s': no live '%s' right now", name, spec.class)
        return false
    end

    local fn = owner[fn_name]
    if fn == nil then
        log.error("action '%s': '%s' has no function '%s' - bind disabled " ..
                  "(likely renamed by a game patch)", name, spec.class, fn_name)
        disabled[name] = true
        return false
    end

    local args = spec.args and spec.args() or nil
    return util.safe(("action %s:%s"):format(name, phase), function()
        if args then fn(owner, table.unpack(args))
        else fn(owner) end
    end)
end

--- Clear the permanent-disable list and per-hold state. Called on level load so a transient
--- failure does not kill a bind for the rest of the session.
function M.reset()
    disabled = {}
    point_aim = nil
end

--- Sanity check used at startup: report which configured actions are missing
--- a definition, without touching the game.
function M.audit(binds)
    local missing = {}
    for _, b in ipairs(binds) do
        for _, key in ipairs({ "action", "action_tap", "action_hold" }) do
            local a = b[key]
            if a and not M.ACTIONS[a] then
                missing[a] = true
            end
        end
    end
    return missing
end

return M
