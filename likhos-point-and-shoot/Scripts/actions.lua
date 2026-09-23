-- actions.lua : action name -> how to invoke it on the pawn / controller.
--
-- Every game name here comes from docs/solutions/point-aim-bind.md (Recon). Nothing is guessed from the real game.
--
-- Design rule: resolve lazily, per call and never cache a UObject across a level load.
-- Caching the *name* is fine. Caching the object is what crashes.

local log     = require("log")
local util    = require("util")
local devices = require("devices")
local config  = require("config")

local M = {}

--- A press released within this window is a tap, which leaves the device it turned on alone.
local TAP_MS = config.tap_ms or 250

--------------------------------------------------------------------------
-- Shared resolution and device handling
--------------------------------------------------------------------------

--- Device failures log once per session, so a renamed game name doesn't flood the log every press.
local device_error_logged = false

--- The local player's pawn, or nil.
local function resolve_pawn()
    local pc = FindFirstOf("PlayerController")
    if not util.valid(pc) then return nil end
    local pawn = pc.Pawn
    if util.valid(pawn) then return pawn end
    return nil
end

--- The equipped weapon's WeaponComponent, or nil.
local function resolve_weapon_component(pawn)
    local inv_lib = StaticFindObject("/Script/Test_C.Default__InventoryFunctionLibrary")
    local wc_cls  = StaticFindObject("/Script/Test_C.WeaponComponent")
    if not (util.valid(inv_lib) and util.valid(wc_cls)) then return nil end

    local weapon = inv_lib:GetEquippedWeapon(pawn)
    if not util.valid(weapon) then return nil end
    local wc = weapon:GetComponentByClass(wc_cls)
    if util.valid(wc) then return wc end
    return nil
end

--- The local player's equipped weapon's WeaponComponent, or nil.
function M.equipped_weapon_component()
    local pawn = resolve_pawn()
    return pawn and resolve_weapon_component(pawn)
end

--- Call a devices.lua function without ever failing the caller, so a broken device lookup still leaves the rest of the action working.
local function try_devices(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    if not device_error_logged then
        device_error_logged = true
        log.error("device handling failed, the action continues without it: %s", tostring(res))
    end
    return nil
end

--- Turn off the device a press recorded, if it is still on this weapon.
local function device_off(wc, name)
    local dev = devices.find(wc, name)
    if dev and devices.is_on(dev) then devices.set(dev, false) end
end

--- Milliseconds since `at`. os.clock is wall time on Windows (docs/solutions/point-aim-bind.md, Recon, Enhanced Input injection).
local function elapsed_ms(at)
    return (os.clock() - at) * 1000
end

local PRESS_VALUE = { X = 1.0, Y = 0.0, Z = 0.0 }

--- A one-frame press of the input action at `path`, as if its key went down for one frame.
--- Continuous injection can't be used: its FInputActionValue parameter can't be built from UE4SS Lua.
function M.inject_press(path)
    local subsystem = FindFirstOf("EnhancedInputLocalPlayerSubsystem")
    local ia = StaticFindObject(path)
    if not (util.valid(subsystem) and util.valid(ia)) then return end
    subsystem:InjectInputVectorForAction(ia, PRESS_VALUE, {}, {})
end

--------------------------------------------------------------------------
-- PointAim: hold to aim straight into point sight (docs/solutions/point-aim-bind.md)
--------------------------------------------------------------------------

-- IA_Aim has a Released trigger, so aim holds only while its one-frame press repeats every tick.
local IA_AIM = "/Game/Blueprints/InputSystem/InputActions/IA_Aim.IA_Aim"

-- Non-nil while a PointAim hold is live. Plain values only, no UObjects.
--   flipped : the mode was regular on press and this action switched it to point
--   weapon  : full name of the weapon component the mode was flipped on
--   device  : full name of the laser this hold turned on, nil when it turned none on
local point_aim = nil

--- Aiming subobject and the equipped weapon's WeaponComponent, or nil.
local function resolve_aim_objects()
    local pawn = resolve_pawn()
    if not pawn then return nil end
    local wc = resolve_weapon_component(pawn)
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
    point_aim = { flipped = flipped, weapon = wc:GetFullName(), device = try_devices(laser_on, wc) }
    M.inject_press(IA_AIM)
end

local function point_aim_held()
    if point_aim then M.inject_press(IA_AIM) end
end

local function point_aim_release()
    -- Injection has already stopped, so the game sees the aim input released and ends aim itself.
    local state = point_aim
    point_aim = nil
    if not (state and (state.flipped or state.device)) then return end

    local ads, wc = resolve_aim_objects()
    if not ads then return end
    if wc:GetFullName() ~= state.weapon then
        log.debug("PointAim: weapon changed during hold, mode and laser not restored")
        return
    end
    -- The user may have switched the mode back themselves mid-hold.
    if state.flipped and wc.bIsPointSight then ads:TriggerPointSight() end
    if state.device then try_devices(device_off, wc, state.device) end
end

--------------------------------------------------------------------------
-- Flashlight: tap to leave the light on, hold to light while held (docs/solutions/flashlight-bind.md)
--------------------------------------------------------------------------

-- Non-nil while a Flashlight hold is live. Plain values only, no UObjects.
--   device : full name of the light the press turned on, nil when the press turned one off or found none
--   weapon : full name of the weapon component that light is on
--   at     : os.clock() at press, to tell a tap from a hold
local flashlight = nil

--- Turn the light that suits the player's vision on, or off when it is already on, whoever turned it on.
--- Returns its full name only when this call turned it on, so release knows there is something to put out.
local function light_toggle(wc)
    local dev = devices.pick(wc, "light")
    if not dev then return nil end
    if devices.is_on(dev) then
        devices.set(dev, false)
        return nil
    end
    devices.set(dev, true)
    return dev:GetFullName()
end

local function flashlight_press()
    flashlight = nil
    local wc = M.equipped_weapon_component()
    if not wc then
        log.debug("Flashlight: no pawn or equipped weapon right now")
        return
    end
    flashlight = { device = try_devices(light_toggle, wc), weapon = wc:GetFullName(), at = os.clock() }
end

local function flashlight_release()
    local state = flashlight
    flashlight = nil
    -- Nothing to put out when the press turned a light off or found none, and a tap leaves the light on until the next press.
    if not (state and state.device) then return end
    if elapsed_ms(state.at) < TAP_MS then return end

    local wc = M.equipped_weapon_component()
    if not wc then return end
    if wc:GetFullName() ~= state.weapon then
        log.debug("Flashlight: weapon changed during hold, light left on")
        return
    end
    try_devices(device_off, wc, state.device)
end

--------------------------------------------------------------------------

--- Each entry describes one logical action. press, held and release are Lua functions.
--- held runs every tick while a hold bind is down.
M.ACTIONS = {
    ["PointAim"] = {
        press   = point_aim_press,
        held    = point_aim_held,
        release = point_aim_release,
    },
    ["Flashlight"] = {
        press   = flashlight_press,
        release = flashlight_release,
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
    flashlight = nil
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
