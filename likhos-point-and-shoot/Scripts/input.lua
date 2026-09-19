-- input.lua : PlayerController lifecycle, mapped key polling, IMC dump.

local log      = require("log")
local util     = require("util")
local triggers = require("triggers")
local context  = require("context")
local keymap   = require("keymap")

local M = {}

local registered = {}   -- bind.id -> true
local key_down = {}     -- bind.id -> key state seen on the previous poll
local player_controller = nil

--------------------------------------------------------------------------
-- PlayerController lifecycle
--------------------------------------------------------------------------

--- The PlayerController survives respawns and the pawn does not.
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
-- Bind registration
--------------------------------------------------------------------------

--- Binds take their keys from the controls menu (keymap.lua) and are polled from the tick loop (M.poll), so they get a release event.
function M.register(bind)
    if not bind.mapping then
        log.error("bind '%s' has no mapping - ignoring", bind.id)
        return false
    end
    registered[bind.id] = true
    log.info("registered bind '%s' on mapping %s (polled)", bind.id, bind.mapping)
    return true
end

--- Turn key state changes into press and release events. Game thread, every tick.
function M.poll(binds)
    local pc = M.get_player_controller()
    if not pc then return end

    for _, bind in ipairs(binds) do
        if registered[bind.id] then
            -- Keys are read every tick, so a rebind in the controls menu applies at once. No key mapped: never down.
            local down = false
            for _, key in ipairs(keymap.keys(bind.mapping)) do
                if pc:IsInputKeyDown(key) then down = true end
            end
            local was = key_down[bind.id]
            key_down[bind.id] = down

            if down and not was then
                if context.allows(bind, pc) then
                    triggers.on_press(bind)
                else
                    log.debug("bind '%s' suppressed by context gate", bind.id)
                end
            elseif not down and was then
                triggers.on_release(bind)
            elseif down and not context.allows(bind, pc) then
                -- A menu opened mid-hold. Release now; the next press starts a fresh hold.
                triggers.on_release(bind)
            end
        end
    end
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
