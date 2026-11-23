-- likhos-point-and-shoot : tactical shortcuts, control and inventory tweaks for Incursion Red River.
--
-- Entry point. UE4SS loads this once at startup for every enabled mod.
-- Hot reload (Ctrl+R in the UE4SS console) re-runs this file, so keep it idempotent: no duplicate registrations, no duplicate loops.

local log      = require("lib.log")
local util     = require("lib.util")
local player   = require("core.player")
local input    = require("core.input")
local triggers = require("core.triggers")
local actions  = require("core.actions")
local keymap   = require("controls.keymap")
local magnifier = require("weapon.magnifier")
local config   = require("config")

--- The binds of config that are enabled and have a mapping. Binds take their keys from the controls menu (controls/keymap.lua) and are polled from the tick loop, so they get a release event.
local function active_binds()
	local active = {}
	for _, bind in ipairs(config.binds) do
		if not bind.enabled then
			log.debug("bind '%s' disabled in config", bind.id)
		elseif not bind.mapping then
			log.error("bind '%s' has no mapping - ignoring", bind.id)
		else
			active[#active + 1] = bind
			log.info("registered bind '%s' on mapping %s (polled)", bind.id, bind.mapping)
		end
	end
	log.info("%d of %d bind(s) active", #active, #config.binds)
	return active
end

local loop_handle = nil

local function start_tick_loop(binds)
	if loop_handle then return end

	-- LoopAsync runs its callback on UE4SS's async thread. Calling ExecuteInGameThread from there every tick corrupted the Lua state (random crashes inside UE4SS's Lua runtime).
	-- This timer runs on the game thread only.
	-- It runs every frame because PointAim holds IA_Aim with a one-frame press, and a frame without one reads as releasing aim. A fixed-delay loop jittered aim above 60 fps.
	-- UE4SS cancels the mod's delayed actions on unload, so a hot reload needs no explicit cancel. This build has no ModRef:OnUnload despite Types.lua declaring it.
	loop_handle = LoopInGameThreadAfterFrames(1, function()
		util.safe("tick", function()
			input.poll(binds)
			triggers.tick(binds)
		end)
	end)
	log.debug("tick loop started, every frame")
end

local function init()
	log.setup("PointAndShoot", config.log_level)
	log.info("loading")

	if not config.enabled then
		log.warn("config.enabled is false - loaded inert")
		return
	end

	player.watch(function()
		triggers.reset()
		actions.reset()
		magnifier.reset()
		-- This callback runs inside the PlayerController's construction. Build and register the mod's input objects a tick later.
		-- A hot reload needs no call: the registration lives in the engine's user settings, not in Lua.
		ExecuteInGameThreadWithDelay(1, function() util.safe("keymap register", keymap.when_live, "controller") end)
	end)
	require("controls.menu").install()
	require("weapon.point_aim").install()
	require("weapon.flashlight").install()
	require("weapon.hold_breath").install()
	require("weapon.fire_mode").install()
	require("items.food_drink").install()
	require("items.smart_heal").install()
	require("world.instant_interact").install()
	if config.magnifier_zoom then magnifier.install() end
	if config.low_ready_default then require("weapon.low_ready").install() end
	if config.sprint_cancels_crouch then require("movement.sprint_stand").install() end
	if config.plant_marker then require("world.objective_marker").install() end
	if config.whole_uses then require("items.tile_counts").install() end
	if config.quick_sell then require("items.quick_sell").install() end
	if config.quick_slot_refill then require("items.quick_slots").install() end

	local binds = active_binds()
	if #binds > 0 then start_tick_loop(binds) end

	RegisterConsoleCommandHandler("kb_status", function()
		log.info("player controller: %s", player.controller() and "acquired" or "none")
		for _, b in ipairs(config.binds) do
			log.info("  %-28s %-12s %s", b.id, keymap.describe(b.mapping), b.enabled and "on" or "off")
		end
		return true
	end)

	log.info("ready. console command: kb_status")
end

-- On Ctrl+R UE4SS runs this file off the game thread while the game thread keeps running the mod's hooks and queued actions against the same Lua state, which corrupts it.
-- Init runs as one game-thread action, so nothing of the mod's runs on the game thread until it returns.
ExecuteInGameThread(function() util.safe("init", init) end)
