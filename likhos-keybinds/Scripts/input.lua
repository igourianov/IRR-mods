-- input.lua : key registration, PlayerController lifecycle, IMC dump.

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
            if not context.allows(bind, M.get_player_controller()) then
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
-- Recon
--------------------------------------------------------------------------

--- Dump every loaded InputMappingContext and its mappings to the console.
--- Used to find the action behind a vanilla key. Console: kb_dump_imc
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

return M
