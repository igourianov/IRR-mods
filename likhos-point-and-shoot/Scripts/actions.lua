-- actions.lua : action name -> how to invoke it on the pawn / controller.
--
-- Every game name here comes from docs/solutions/findings.md. Nothing is guessed from the real game.
--
-- Design rule: resolve lazily, per call and never cache a UObject across a level load.
-- Caching the *name* is fine. Caching the object is what crashes.

local log     = require("log")
local util    = require("util")
local devices = require("devices")

local M = {}

--------------------------------------------------------------------------
-- PointAim: hold to aim straight into point sight (docs/solutions/point-aim-bind.md)
--------------------------------------------------------------------------

local IA_AIM = "/Game/Blueprints/InputSystem/InputActions/IA_Aim.IA_Aim"
local AIM_VALUE = { X = 1.0, Y = 0.0, Z = 0.0 }

-- Non-nil while a PointAim hold is live. Plain values only, no UObjects.
--   flipped : the mode was regular on press and this action switched it to point
--   weapon  : full name of the weapon component the mode was flipped on
--   devices : full names of the tactical devices this hold turned on (docs/solutions/point-aim-devices.md)
local point_aim = nil

--- Device failures log once per session, so a renamed game name doesn't flood the log every press.
local device_error_logged = false

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

--- Call a devices.lua function without ever failing the caller, so a broken device lookup still leaves point aim working.
local function try_devices(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    if not device_error_logged then
        device_error_logged = true
        log.error("PointAim: device handling failed, point aim continues without it: %s", tostring(res))
    end
    return nil
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
    point_aim = { flipped = flipped, weapon = wc:GetFullName(), devices = try_devices(devices.activate, wc) or {} }
    inject_aim()
end

local function point_aim_held()
    if point_aim then inject_aim() end
end

local function point_aim_release()
    -- Injection has already stopped, so the game sees the aim input released and ends aim itself.
    local state = point_aim
    point_aim = nil
    if not (state and (state.flipped or #state.devices > 0)) then return end

    local ads, wc = resolve_aim_objects()
    if not ads then return end
    if wc:GetFullName() ~= state.weapon then
        log.debug("PointAim: weapon changed during hold, mode and devices not restored")
        return
    end
    -- The user may have switched the mode back themselves mid-hold.
    if state.flipped and wc.bIsPointSight then ads:TriggerPointSight() end
    if #state.devices > 0 then try_devices(devices.deactivate, wc, state.devices) end
end

--- Each entry describes one logical action. press, held and release are Lua functions.
--- held runs every tick while a hold bind is down.
M.ACTIONS = {
    ["PointAim"] = {
        press   = point_aim_press,
        held    = point_aim_held,
        release = point_aim_release,
    },
}

--- Actions found undefined this session, so the error logs once rather than every tick.
local disabled = {}

--- Invoke one side of an action. `phase` is "press", "held" or "release".
--- MUST be called from the game thread (see input.lua).
function M.invoke(name, phase)
    if disabled[name] then return false end

    local spec = M.ACTIONS[name]
    if not spec then
        log.error("action '%s' is not defined in actions.lua - bind disabled", name)
        disabled[name] = true
        return false
    end

    local fn = spec[phase]
    -- Legitimately nothing to do on a phase without a function.
    if not fn then return true end
    return util.safe(("action %s:%s"):format(name, phase), fn)
end

--- Clear the disabled list and per-hold state. Called on level load.
function M.reset()
    disabled = {}
    point_aim = nil
end

--- Startup check: report which configured actions are missing a definition, without touching the game.
function M.audit(binds)
    local missing = {}
    for _, b in ipairs(binds) do
        if b.action and not M.ACTIONS[b.action] then
            missing[b.action] = true
        end
    end
    return missing
end

return M
