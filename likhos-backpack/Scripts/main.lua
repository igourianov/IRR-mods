-- likhos-backpack : inventory handling improvements for Incursion Red River.
--
-- Entry point. UE4SS loads this once at startup for every enabled mod.
-- Hot reload (Ctrl+R in the UE4SS console) re-runs this file, so keep it idempotent: no duplicate registrations.

local log  = require("log")
local util = require("util")
local whole_uses = require("whole_uses")
local quick_sell = require("quick_sell")
local quick_slots = require("quick_slots")

local config = require("config")

local function init()
	log.setup("Backpack", config.log_level)
	log.info("loading")

	if not config.enabled then
		log.warn("config.enabled is false - loaded inert")
		return
	end

	if config.whole_uses then whole_uses.install() end
	if config.quick_sell then quick_sell.install() end
	if config.quick_slot_refill then quick_slots.install() end

	log.info("ready")
end

util.safe("init", init)
