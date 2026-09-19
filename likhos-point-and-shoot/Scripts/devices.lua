-- devices.lua : which tactical devices a PointAim hold turns on (docs/solutions/point-aim-devices.md).
--
-- Every game name here comes from docs/solutions/findings.md (Tactical devices, Night vision).
-- Works on a WeaponComponent handed in by the caller and holds no UObject between calls.
-- A missing game name raises. The caller decides what a failure means.

local util = require("util")

local M = {}

local LASER_CLASS = "/Script/Test_C.LaserComponent"
local LIGHT_CLASS = "/Script/Test_C.FlashlightComponent"
local NVG_SUBSYSTEM = "IRRNightVision_Subsystem"
local DEVICE_OFF, DEVICE_ON = 0, 1   -- EIRRTacticalDeviceState

-- The infrared flags read false on IR lasers. Visible and IR lasers differ only in their default laser material.
-- A laser with any other material is neither class and is never chosen.
local LASER_MATERIALS = {
    ["/Game/ThirdParty/SKGShooterFramework/Assets/Firearm/FirearmParts/LightLaser/Materials/Red/MI_LaserRed.MI_LaserRed"] = "vis_laser",
    ["/Game/ThirdParty/SKGShooterFramework/Assets/Firearm/FirearmParts/LightLaser/Materials/Green/MI_LaserGreen.MI_LaserGreen"] = "ir_laser",
}

--- "vis_laser", "ir_laser", "vis_light", "ir_light" or nil.
local function classify(dev, laser_cls, light_cls)
    -- On lights, unlike lasers, bHasInfraredMode marks the IR one. The PEQ-15's light is the only IR light and it is IR only.
    if dev:IsA(light_cls) then return dev.bHasInfraredMode and "ir_light" or "vis_light" end
    if not dev:IsA(laser_cls) then return nil end
    local mat = dev.LaserSettings.DefaultLaserMaterial.Laser
    if not util.valid(mat) then return nil end
    return LASER_MATERIALS[mat:GetFullName():match("^%S+ (.+)$")]
end

local function nvg_on()
    -- A per-level object, so it is looked up on every call.
    local nvg = FindFirstOf(NVG_SUBSYSTEM)
    if not util.valid(nvg) then error(NVG_SUBSYSTEM .. " not found") end
    return nvg:IsInfraredModeEnabledOnPlayer()
end

--- Turn on the devices that suit the player's vision and return the full names of those it switched on.
--- A chosen device already on is left alone and not returned. Classes are picked by presence, not state.
function M.activate(wc)
    local laser_cls = StaticFindObject(LASER_CLASS)
    local light_cls = StaticFindObject(LIGHT_CLASS)
    if not util.valid(laser_cls) then error(LASER_CLASS .. " not found") end
    if not util.valid(light_cls) then error(LIGHT_CLASS .. " not found") end

    local first = {}
    wc.TacticalAttachments:ForEach(function(_, elem)
        local dev = elem:get()
        if not util.valid(dev) then return end
        local class = classify(dev, laser_cls, light_cls)
        if class and not first[class] then first[class] = dev end
    end)

    local picks
    if nvg_on() then
        -- A visible flashlight is never used under NVG.
        picks = (first.ir_laser or first.ir_light) and { first.ir_laser, first.ir_light } or { first.vis_laser }
    else
        picks = { first.vis_laser or first.vis_light }
    end

    local switched = {}
    for _, dev in pairs(picks) do
        if dev.DeviceState ~= DEVICE_ON then
            dev:SetDeviceState(DEVICE_ON)
            table.insert(switched, dev:GetFullName())
        end
    end
    return switched
end

--- Turn off each device named in `names`, a list from activate, that is still on.
function M.deactivate(wc, names)
    local wanted = {}
    for _, name in ipairs(names) do wanted[name] = true end
    wc.TacticalAttachments:ForEach(function(_, elem)
        local dev = elem:get()
        if util.valid(dev) and wanted[dev:GetFullName()] and dev.DeviceState ~= DEVICE_OFF then dev:SetDeviceState(DEVICE_OFF) end
    end)
end

return M
