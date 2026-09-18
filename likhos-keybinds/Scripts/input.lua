-- input.lua : key registration, PlayerController lifecycle, IMC interception.

local log      = require("log")
local util     = require("util")
local triggers = require("triggers")
local context  = require("context")

local M = {}

local registered = {}   -- bind.id -> true
local player_controller = nil

--------------------------------------------------------------------------
-- PlayerController lifecycle
--------------------------------------------------------------------------

--- The PlayerController survives respawns; the pawn does not. Bind here.
function M.watch_player_controller(on_ready)
    -- The callback receives the UObject itself, not a RemoteUnrealParam. No :get().
    -- It also fires for each Blueprint subclass's class default object as the class loads.
    -- Those are templates, not live controllers, so skip them by name.
    NotifyOnNewObject("/Script/Engine.PlayerController", function(pc)
        if not util.valid(pc) then return end
        if pc:GetFName():ToString():find("^Default__") then return end

        player_controller = pc
        context.set_player_controller(pc)
        triggers.reset()

        log.info("PlayerController acquired: %s", pc:GetFullName())
        if on_ready then util.safe("on_ready", on_ready, pc) end
    end)
end

function M.get_player_controller()
    if util.valid(player_controller) then return player_controller end
    local pc = FindFirstOf("PlayerController")
    if util.valid(pc) then
        player_controller = pc
        context.set_player_controller(pc)
        return pc
    end
    return nil
end

--------------------------------------------------------------------------
-- Key registration
--------------------------------------------------------------------------

local function resolve_key(name)
    local k = Key[name]
    if k == nil then
        log.error("unknown key name '%s' - check the UE4SS Key table", name)
    end
    return k
end

local function resolve_modifiers(names)
    if not names or #names == 0 then return nil end
    local out = {}
    for _, n in ipairs(names) do
        local m = ModifierKey[n]
        if m == nil then
            log.error("unknown modifier '%s'", n)
            return nil
        end
        table.insert(out, m)
    end
    return out
end

--- Register one bind. Returns true on success.
function M.register(bind)
    if registered[bind.id] then return true end

    local key = resolve_key(bind.key)
    if not key then return false end

    local mods = resolve_modifiers(bind.modifiers)

    local handler = function()
        -- IMPORTANT: RegisterKeyBind callbacks run on UE4SS's own thread.
        -- Touching UObjects from here will crash. Hop to the game thread.
        ExecuteInGameThread(function()
            if not context.allows(bind) then
                log.debug("bind '%s' suppressed by context gate", bind.id)
                return
            end
            util.safe("trigger " .. bind.id, triggers.on_press, bind)
        end)
    end

    local ok
    if mods then
        ok = util.safe("RegisterKeyBind " .. bind.id,
                       RegisterKeyBind, key, mods, handler)
    else
        ok = util.safe("RegisterKeyBind " .. bind.id,
                       RegisterKeyBind, key, handler)
    end

    if ok then
        registered[bind.id] = true
        log.info("registered bind '%s' on %s (%s)", bind.id, bind.key, bind.mode)
    end
    return ok
end

--------------------------------------------------------------------------
-- Enhanced Input interception  (OPTIONAL - requires recon)
--------------------------------------------------------------------------
--
-- Problem: RegisterKeyBind does NOT consume the keystroke. The game's own
-- binding still fires, so a naive toggle double-fires.
--
-- Fix: walk the active InputMappingContext, find the FEnhancedActionKeyMapping
-- entries bound to our key, and repoint them at an unused key. We then own
-- the real key outright.
--
-- Everything below is inert until docs/01-recon.md confirms:
--   * EnhancedInputLocalPlayerSubsystem exists
--   * the IMC asset path(s) in use
--   * the property names on FEnhancedActionKeyMapping in this build

function M.get_enhanced_input_subsystem()
    local pc = M.get_player_controller()
    if not pc then return nil end

    local ok, subsys = pcall(function()
        local lp = pc.Player
        if not util.valid(lp) then return nil end
        -- RECON: confirm the accessor. In some builds this is reachable via
        -- USubsystemBlueprintLibrary; in others FindFirstOf works directly.
        return FindFirstOf("EnhancedInputLocalPlayerSubsystem")
    end)

    if not ok or not util.valid(subsys) then
        log.warn("EnhancedInputLocalPlayerSubsystem not found - " ..
                 "IMC interception unavailable")
        return nil
    end
    return subsys
end

--- Dump every loaded InputMappingContext and its mappings to the console.
--- This is a RECON TOOL, not part of normal operation. Call it from the
--- UE4SS console: require("input").dump_mapping_contexts()
function M.dump_mapping_contexts()
    local contexts = FindAllOf("InputMappingContext")
    if not contexts then
        log.warn("no InputMappingContext objects loaded")
        return
    end

    for _, imc in ipairs(contexts) do
        if util.valid(imc) then
            log.info("IMC: %s", imc:GetFullName())
            local ok = pcall(function()
                imc.Mappings:ForEach(function(idx, elem)
                    local m = elem:get()
                    local action = m.Action
                    local key    = m.Key
                    log.info("  [%d] action=%s key=%s",
                             idx,
                             util.valid(action) and action:GetFullName() or "?",
                             tostring(key.KeyName))
                end)
            end)
            if not ok then
                log.warn("  could not enumerate Mappings on this IMC")
            end
        end
    end
end

--- Repoint a mapping away from our key so the vanilla binding stops firing.
--- NOT SAFE until recon confirms the property layout. Guarded by
--- config.intercept_via_imc.
function M.steal_key(imc_name, key_name, park_key_name)
    log.warn("steal_key is a stub - implement after recon (see docs/01-recon.md)")
    return false
end

return M
