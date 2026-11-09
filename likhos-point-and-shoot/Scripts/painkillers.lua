-- painkillers.lua : the Use Morphine/Painkillers key takes the fastest painkiller anywhere on the player (docs/solutions/painkillers-bind.md).
--
-- A painkiller is any medical item with a use context that applies the Painkiller buff: Morphine Injector, MFAK Inject, Painkiller.
-- Every game name here comes from docs/solutions/painkillers-bind.md (Recon).
-- Only reads game state to pick the item. The one call that changes anything is the item's own use.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")

local M = {}

local LIBRARY_CDO  = "/Script/Test_C.Default__InventoryFunctionLibrary"
local MEDICAL      = "Inventory.Items.Medical."
local PAIN_DEBUFF  = "Inventory.Stats.Pain Debuff"
local USES_TAG     = "Inventory.Stats.Durability"
local USE_TIME_TAG = "Inventory.Stats.Usage Time"
local BUFF_TAG     = "Character.Buffs.Medic.Painkiller"
local MIN_MISSING  = 5

--- The item's CurrentStats value under tag, or nil.
local function stat(item, tag)
	local stats = item.CurrentStats
	for i = 1, #stats do
		local s = stats[i]
		if s.Tag.TagName:ToString() == tag then return s.Value end
	end
	return nil
end

local function has_tag(container, tag)
	local tags = container.GameplayTags
	for i = 1, #tags do
		if tags[i].TagName:ToString() == tag then return true end
	end
	return false
end

--- The definition's context with an action applying the Painkiller buff, or nil.
local function painkiller_context(definition)
	local contexts = definition.ItemContexts
	for i = 1, #contexts do
		local context = contexts[i]
		if util.valid(context) then
			local actions = context.ToTriggerActions
			for j = 1, #actions do
				local action = actions[j]
				if util.valid(action) and has_tag(action.EffectStatTags, PAIN_DEBUFF) then return context end
			end
		end
	end
	return nil
end

local function dose_active(health)
	local buffs = health.Buffs
	for i = 1, #buffs do
		if buffs[i].Tag.TagName:ToString() == BUFF_TAG then return true end
	end
	return false
end

--- The Use Morphine/Painkillers key's press. Game thread.
function M.press()
	local pc = FindFirstOf("PlayerController")
	local library = StaticFindObject(LIBRARY_CDO)
	local pawn = util.valid(pc) and pc.Pawn or nil
	if not (util.valid(pawn) and util.valid(library)) then
		log.debug("UsePainkillers: no pawn or inventory library")
		return
	end
	local health_comp = pawn:GetHealthComponent()
	local health = util.valid(health_comp) and health_comp.Health or nil
	local comp = library:GetPlayerInventoryComponent(pc)
	if not (util.valid(health) and util.valid(comp)) then
		log.debug("UsePainkillers: no health attribute or inventory component")
		return
	end

	local active = dose_active(health)
	local missing = health:GetCurrentMaxValue() - health:GetBaseValue()
	log.debug("UsePainkillers: real %.1f current %.1f max %.1f, dose %s", health:GetBaseValue(), health:GetCurrentValue(), health:GetCurrentMaxValue(), tostring(active))
	if active then
		log.debug("UsePainkillers: dose still active")
		return
	end
	if missing <= MIN_MISSING then
		log.debug("UsePainkillers: only %.1f health missing", missing)
		return
	end

	-- Every main container, nested storage included: MainContainers is flat and holds each container item's storage as its own entry.
	-- Items are passed to the context as read from the MainContainers property. A ContainerItem returned by one UFunction crashes the game when passed to another.
	local containers = comp.MainContainers
	local best, best_context, best_time = nil, nil, math.huge
	for i = 1, #containers do
		local items = containers[i].ContainerItems
		for j = 1, #items do
			local item = items[j]
			local definition = item.ItemDefinition
			if util.valid(definition) and definition.ItemIdentifier.TagName:ToString():sub(1, #MEDICAL) == MEDICAL and (stat(item, USES_TAG) or math.huge) > 0 then
				local time = stat(item, USE_TIME_TAG) or math.huge
				local context = time < best_time and painkiller_context(definition)
				-- No item widget: the bind has none, unlike the context menu.
				if context and context:IsValidContext(pawn, nil, item) then
					best, best_context, best_time = item, context, time
				end
			end
		end
	end
	if not best then
		log.debug("UsePainkillers: no usable painkiller carried")
		return
	end
	log.debug("UsePainkillers: using %s (%.1f s)", best.ItemDefinition:GetFullName(), best_time)
	best_context:Execute(pawn, nil, best)
end

return M
