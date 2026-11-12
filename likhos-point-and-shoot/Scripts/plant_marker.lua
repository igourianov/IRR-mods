-- plant_marker.lua : the markers of quest objectives (placement spots, mission phones, quest item pickups and mission boxes) have a ring in a color that stands out and show from farther away.
-- Design: docs/solutions/plant-spot-marker.md, reworked for quest pickups and range by docs/solutions/objective-marker-range.md.
--
-- Every game name here comes from those two docs.
-- Holds no UObject between calls. Targets are passed by path.

local log    = require("log")
local util   = require("util")
local hook   = require("hook")
local config = require("config")

local M = {}

local hooks = hook.new("objective marker", "objective markers stay vanilla")

local TARGET_CLASS = "/Script/Test_C.InteractionTarget"
local PICKUP_CLASS = "/Script/Test_C.PickUpActor"

-- The gear icon of placement spots and mission phones.
local PLANT_ICON  = "T_IRR_Interaction_ItemInteractionIcon"
local QUEST_ITEM  = "Inventory.Items.Quest."
-- Spawned by a mission with its items inside. Its icon is the one every loot container shows, so it is told apart by class.
local MISSION_BOX = "BP_MissionBox_C"
-- Every display setting of an option, so the ring keeps the color while held, repeated or waiting.
local DISPLAY_SETTINGS = { "DefaultDisplaySetting", "HoldDisplaySetting", "RepeatDisplaySetting", "WaitDisplaySetting" }

-- A target is constructed before its owner sets it up, and a pickup gets its item after it spawns. Read 2 s later, both are in place.
local CLASSIFY_DELAY_MS = 2000

-- Linear color parsed from config.plant_marker_color and outer radius in cm from config.plant_marker_range, set by install().
local tint, range = nil, 0

-- The spawn watch is registered once. A hot reload only rescans.
local watching = false

local function srgb_to_linear(byte)
	local c = byte / 255
	if c <= 0.04045 then return c / 12.92 end
	return ((c + 0.055) / 1.055) ^ 2.4
end

local function parse_color(hex)
	local r, g, b = tostring(hex):match("^#?(%x%x)(%x%x)(%x%x)$")
	if not r then return nil end
	return { R = srgb_to_linear(tonumber(r, 16)), G = srgb_to_linear(tonumber(g, 16)), B = srgb_to_linear(tonumber(b, 16)) }
end

local function shows_plant_icon(options)
	for i = 1, #options do
		local option = options[i]
		if util.valid(option) then
			local texture = option.DefaultDisplaySetting.MarkerSetting.Texture
			if util.valid(texture) and texture:GetFName():ToString() == PLANT_ICON then return true end
		end
	end
	return false
end

local function is_objective(target)
	if shows_plant_icon(target.InteractionOptions) then return true end
	local owner = target:GetOwner()
	if not util.valid(owner) then return false end
	if owner:GetClass():GetFName():ToString() == MISSION_BOX then return true end
	local pickup_class = StaticFindObject(PICKUP_CLASS)
	if not (util.valid(pickup_class) and owner:IsA(pickup_class)) then return false end
	local inventory = owner.InventoryComponent
	local definition = util.valid(inventory) and inventory.PickUpContainerItem.ContainerItem.ItemDefinition or nil
	return util.valid(definition) and definition.ItemIdentifier.TagName:ToString():sub(1, #QUEST_ITEM) == QUEST_ITEM
end

-- Options are per-target subobjects (probed 2026-11-11), so the color reaches this target's marker only. Vanilla tints the ring with BorderColor on every marker update.
local function decorate(path)
	local target = StaticFindObject(path)
	if not (util.valid(target) and is_objective(target)) then return end
	if target.OuterInteractionRadius < range then target.OuterInteractionRadius = range end
	-- Some targets have no sphere of their own, and the outer radius alone sets the distance.
	local sphere = target.SphereComponent
	if util.valid(sphere) and sphere.SphereRadius < range then sphere:SetSphereRadius(range, true) end
	local options = target.InteractionOptions
	for i = 1, #options do
		local option = options[i]
		if util.valid(option) then
			for _, name in ipairs(DISPLAY_SETTINGS) do
				local marker_setting = option[name].MarkerSetting
				marker_setting.BorderColor = { SpecifiedColor = { R = tint.R, G = tint.G, B = tint.B, A = marker_setting.BorderColor.SpecifiedColor.A }, ColorUseRule = 0 }
			end
		end
	end
	log.debug("objective marker: decorated %s, outer %.0f", path, target.OuterInteractionRadius)
end

local function scan()
	-- FindAllOf may match the exact class only, so both the native class and its Blueprint subclass are listed.
	local seen = {}
	for _, class_name in ipairs({ "InteractionTarget", "BP_InteractionTarget_C" }) do
		for _, target in ipairs(FindAllOf(class_name) or {}) do
			local path = util.path(target)
			if not seen[path] then
				seen[path] = true
				decorate(path)
			end
		end
	end
end

--- Decorate objective targets as they spawn, and the ones already there for a hot reload.
function M.install()
	tint = parse_color(config.plant_marker_color)
	if not tint then
		log.error("objective marker: plant_marker_color '%s' is not a #RRGGBB color, objective markers stay vanilla", tostring(config.plant_marker_color))
		return
	end
	range = (tonumber(config.plant_marker_range) or 0) * 100
	if not watching then
		watching = true
		NotifyOnNewObject(TARGET_CLASS, function(target)
			local path = util.path(target)
			ExecuteInGameThreadWithDelay(CLASSIFY_DELAY_MS, hooks.guard(function() decorate(path) end))
		end)
		log.info("objective marker: watching %s", TARGET_CLASS)
	end
	ExecuteInGameThread(hooks.guard(scan))
end

return M
