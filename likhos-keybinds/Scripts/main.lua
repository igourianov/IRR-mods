-- likhos-keybinds : keybinding behaviour overhaul for Incursion Red River.
--
-- Entry point. UE4SS loads this once at startup for every enabled mod.
-- Hot reload (Ctrl+R in the UE4SS console) re-runs this file, so keep it
-- idempotent: no duplicate key registrations, no duplicate loops.

local log      = require("log")
local util     = require("util")
local input    = require("input")
local triggers = require("triggers")
local actions  = require("actions")

local config = require("config")

--------------------------------------------------------------------------

local function validate()
    local missing = actions.audit(config.binds)
    local names = {}
    for name in pairs(missing) do table.insert(names, name) end

    if #names > 0 then
        table.sort(names)
        log.warn("%d action(s) referenced by config.lua but not defined in " ..
                 "actions.lua: %s", #names, table.concat(names, ", "))
        log.warn("Fill these in from recon before enabling those binds. " ..
                 "See docs/01-recon.md.")
    end
end

local function register_binds()
    local count = 0
    for _, bind in ipairs(config.binds) do
        if bind.enabled then
            if input.register(bind) then count = count + 1 end
        else
            log.debug("bind '%s' disabled in config", bind.id)
        end
    end
    log.info("%d of %d bind(s) active", count, #config.binds)
    return count
end

local loop_started = false

local function start_tick_loop()
    if loop_started then return end
    loop_started = true

    local tick_ms = config.tick_ms or 16
    -- LoopAsync runs its callback on UE4SS's async thread. Calling ExecuteInGameThread from there every tick corrupted the Lua state (random crashes inside UE4SS's Lua runtime).
    -- This timer runs on the game thread only.
    LoopInGameThreadWithDelay(tick_ms, function()
        util.safe("tick", function()
            input.poll(config.binds)
            triggers.tick(config.binds)
        end)
    end)
    log.debug("tick loop started at %dms", tick_ms)
end

--------------------------------------------------------------------------

local function init()
    log.set_level(config.log_level)
    log.info("loading")

    if not config.enabled then
        log.warn("config.enabled is false - loaded inert")
        return
    end

    validate()

    input.watch_player_controller(function()
        -- A patch may rename a handler; clear the per-session disable list
        -- on every level load so one bad raid does not kill a bind forever.
        actions.reset()
    end)

    -- The tick loop runs Lua every tick_ms. Skip it when nothing can use it.
    if register_binds() > 0 then start_tick_loop() end

    RegisterConsoleCommandHandler("kb_dump_imc", function()
        input.dump_mapping_contexts()
        return true
    end)

    RegisterConsoleCommandHandler("kb_status", function()
        log.info("player controller: %s",
                 input.get_player_controller() and "acquired" or "none")
        for _, b in ipairs(config.binds) do
            log.info("  %-28s %-12s %-6s %s",
                     b.id, b.key or b.engine_key, b.mode, b.enabled and "on" or "off")
        end
        return true
    end)

    log.info("ready. console commands: kb_status, kb_dump_imc")
end

util.safe("init", init)
