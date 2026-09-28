-- likhos-backpack : inventory handling improvements for Incursion Red River.
--
-- Entry point. UE4SS loads this once at startup for every enabled mod.
-- Hot reload (Ctrl+R in the UE4SS console) re-runs this file, so keep it idempotent: no duplicate registrations.

local log  = require("log")
local util = require("util")
local inventory_swap = require("inventory_swap")

local config = require("config")

local function init()
    log.set_level(config.log_level)
    log.info("loading")

    if not config.enabled then
        log.warn("config.enabled is false - loaded inert")
        return
    end

    if config.inventory_swap then inventory_swap.install() end

    log.info("ready")
end

util.safe("init", init)
