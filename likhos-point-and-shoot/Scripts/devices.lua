-- devices.lua : which tactical device suits the player's vision (docs/solutions/flashlight-bind.md).
--
-- Every game name here comes from the Recon sections of docs/solutions/point-aim-auto-laser.md (lasers) and docs/solutions/point-aim-devices.md (lights, night vision).
-- Works on a WeaponComponent handed in by the caller and holds no UObject between calls.
-- A missing game name raises. The caller decides what a failure means.

local util = require("util")

local M = {}

local NVG_SUBSYSTEM = "IRRNightVision_Subsystem"
local DEVICE_OFF, DEVICE_ON = 0, 1   -- EIRRTacticalDeviceState

-- The infrared flags read false on IR lasers. Visible and IR lasers differ only in their default laser material.
-- A laser with any other material is neither class and is never chosen.
local LASER_MATERIALS = {
    ["/Game/ThirdParty/SKGShooterFramework/Assets/Firearm/FirearmParts/LightLaser/Materials/Red/MI_LaserRed.MI_LaserRed"] = "visible",
    ["/Game/ThirdParty/SKGShooterFramework/Assets/Firearm/FirearmParts/LightLaser/Materials/Green/MI_LaserGreen.MI_LaserGreen"] = "ir",
}

--- One kind of device: the component class that marks it and how to read "visible" or "ir" off one.
local KINDS = {
    laser = {
        class = "/Script/Test_C.LaserComponent",
        vision = function(dev)
            local mat = dev.LaserSettings.DefaultLaserMaterial.Laser
            if not util.valid(mat) then return nil end
            return LASER_MATERIALS[mat:GetFullName():match("^%S+ (.+)$")]
        end,
    },
    -- Lights are BP_FlashlightComponent_C, matched through their native parent.
    light = {
        class = "/Script/Test_C.FlashlightComponent",
        -- Unlike on lasers, the flag is meaningful on lights: true only on the PEQ-15's IR illuminator.
        vision = function(dev) return dev.bHasInfraredMode and "ir" or "visible" end,
    },
}

local function nvg_on()
    -- A per-level object, so it is looked up on every call.
    local nvg = FindFirstOf(NVG_SUBSYSTEM)
    if not util.valid(nvg) then error(NVG_SUBSYSTEM .. " not found") end
    return nvg:IsInfraredModeEnabledOnPlayer()
end

--- The device of `kind` ("laser" or "light") that suits the player's vision, or nil when the weapon has none.
--- Selection is by presence, not by state: an already-on device still counts as the pick.
function M.pick(wc, kind)
    local spec = KINDS[kind]
    local cls = StaticFindObject(spec.class)
    if not util.valid(cls) then error(spec.class .. " not found") end

    local first = {}
    wc.TacticalAttachments:ForEach(function(_, elem)
        local dev = elem:get()
        if util.valid(dev) and dev:IsA(cls) then
            local vision = spec.vision(dev)
            if vision and not first[vision] then first[vision] = dev end
        end
    end)

    -- Under NVG with no IR device of this kind this falls through to the visible one.
    if nvg_on() then return first.ir or first.visible end
    return first.visible
end

--- The device on `wc` with this full name, or nil. Lets a caller reach a device it recorded earlier without holding it.
function M.find(wc, name)
    local found = nil
    wc.TacticalAttachments:ForEach(function(_, elem)
        local dev = elem:get()
        if util.valid(dev) and dev:GetFullName() == name then found = dev end
    end)
    return found
end

function M.is_on(dev)
    return dev.DeviceState == DEVICE_ON
end

function M.set(dev, on)
    dev:SetDeviceState(on and DEVICE_ON or DEVICE_OFF)
end

return M
