-- keymap.lua : the mod's player-mappable keys, stored in the game's Enhanced Input user settings.
--
-- Each mapping is a runtime InputAction in a mod InputMappingContext, registered with EnhancedInputUserSettings and
-- active at the lowest priority. Nothing listens to the actions. The controls menu row (menu.lua) rebinds a key and the
-- game saves it. input.lua reads the key and polls it.
-- See docs/05-point-aim-keybind-menu.md.

local log  = require("log")
local util = require("util")

local M = {}

-- UE4SS has no GetPathName on UObject, so the mod's objects live directly in /Engine/Transient and are found by path.
local OUTER = "/Engine/Transient"
local IMC_NAME = "IMC_LikhosKeybinds"
local STACK_PRIORITY = -1000

M.MAPPINGS = {
    LikhosPointShootingDirect = { display = "Point Shooting (Direct)" },
}

local function action_name(mapping)
    return "IA_" .. mapping
end

local function find(name)
    local obj = StaticFindObject(OUTER .. "." .. name)
    if util.valid(obj) then return obj end
    return nil
end

local function construct(class_path, outer, name)
    return StaticConstructObject(StaticFindObject(class_path), outer, FName(name))
end

local function user_settings()
    local subsystem = FindFirstOf("EnhancedInputLocalPlayerSubsystem")
    if not util.valid(subsystem) then return nil end
    local settings = subsystem:GetUserSettings()
    if not util.valid(settings) then return nil end
    return settings, subsystem
end

--- The mod's InputAction for a mapping, or nil before register() has built it.
function M.action(mapping)
    return find(action_name(mapping))
end

--- Build the mod's actions and context if missing, register the context with user settings and activate it.
--- Registration also restores the user's saved keys. Game thread. Safe to repeat.
function M.register()
    local settings, subsystem = user_settings()
    if not settings then
        log.debug("keymap: no Enhanced Input user settings yet")
        return
    end

    local imc = find(IMC_NAME)
    if not imc then
        local transient = StaticFindObject(OUTER)
        imc = construct("/Script/EnhancedInput.InputMappingContext", transient, IMC_NAME)
        for mapping, spec in pairs(M.MAPPINGS) do
            local ia = construct("/Script/EnhancedInput.InputAction", transient, action_name(mapping))
            local pmks = construct("/Script/EnhancedInput.PlayerMappableKeySettings", ia, "PlayerMappableKeySettings")
            pmks.Name = FName(mapping)
            pmks.DisplayName = FText(spec.display)
            ia.PlayerMappableKeySettings = pmks
            -- Unbound by default. The mapping inherits the action's mappable settings.
            imc:MapKey(ia, { KeyName = FName("None") })
        end
        log.info("keymap: built %s", imc:GetFullName())
    end

    if settings:RegisterInputMappingContext(imc) then
        log.info("keymap: registered %s with user settings", IMC_NAME)
    end

    -- The controls menu shows a row's key only if its context is active (FindInputActionKey reads QueryKeysMappedToAction).
    -- Below every vanilla context it can't consume their keys. Adding it again only resets its priority.
    subsystem:AddMappingContext(imc, STACK_PRIORITY, {})
end

--- FKey tables for the keys currently bound to a mapping. Empty when unbound.
function M.keys(mapping)
    local out = {}
    local settings = user_settings()
    if not settings then return out end
    local profile = settings:GetActiveKeyProfile()
    if not util.valid(profile) then return out end

    local found = {}
    profile:GetMappedKeysInRow(FName(mapping), found)
    for _, k in ipairs(found) do
        -- The out array holds struct wrappers. An unbound row reports one key, None.
        local name = k:get().KeyName
        if name:ToString() ~= "None" then
            table.insert(out, { KeyName = name })
        end
    end
    return out
end

--- Human-readable keys for kb_status.
function M.describe(mapping)
    local names = {}
    for _, k in ipairs(M.keys(mapping)) do table.insert(names, k.KeyName:ToString()) end
    return #names > 0 and table.concat(names, ", ") or "unbound"
end

return M
