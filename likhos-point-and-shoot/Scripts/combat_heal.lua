-- combat_heal.lua : the Combat Heal key treats the most pressing problem with the fastest item carried (docs/solutions/combat-heal.md).
-- The Use Adrenaline key shares its item search with a single stamina step (docs/solutions/adrenaline-bind.md).
--
-- Steps in order: painkiller below 90% with no dose active, heavy bleed, bleed, fracture, heal below max.
-- An item treats a step through a use context whose actions carry the step's stat tag, so the tag decides, not the item's name.
-- Every game name here comes from docs/solutions/combat-heal.md (Recon).
-- Only reads game state to pick the item. The one call that changes anything is the item's own use.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")

local M = {}

local LIBRARY_CDO   = "/Script/Test_C.Default__InventoryFunctionLibrary"
local MEDICAL       = "Inventory.Items.Medical."
local USES_TAG      = "Inventory.Stats.Durability"
local USE_TIME_TAG  = "Inventory.Stats.Usage Time"
local DOSE_BUFF     = "Character.Buffs.Medic.Painkiller"
local PAINKILLER_AT = 0.9

--- Action stat tag -> the treatment it gives. Both heal tags are one treatment.
local TREATMENTS = {
	["Inventory.Stats.Pain Debuff"]      = "painkiller",
	["Inventory.Stats.Stop Heavy Wound"] = "heavy_bleed",
	["Inventory.Stats.Stop Wound"]       = "bleed",
	["Inventory.Stats.Stop Fracture"]    = "fracture",
	["Inventory.Stats.Heal Instant"]     = "heal",
	["Inventory.Stats.Heal Over Time"]   = "heal",
	-- Use Adrenaline only (docs/solutions/adrenaline-bind.md). Food carries it too but is never a candidate.
	["Inventory.Stats.Stamina Boost"]    = "stamina",
}

--- Condition steps, in order, between the painkiller and heal steps: the pawn's owned tag that makes the step apply.
local CONDITIONS = {
	{ treatment = "heavy_bleed", tag = "Character.Effects.Heavy Wounded" },
	{ treatment = "bleed",       tag = "Character.Effects.Wounded" },
	{ treatment = "fracture",    tag = "Character.Effects.Fractured" },
}

--- The item's CurrentStats value under tag, or nil.
local function stat(item, tag)
	local stats = item.CurrentStats
	for i = 1, #stats do
		local s = stats[i]
		if s.Tag.TagName:ToString() == tag then return s.Value end
	end
	return nil
end

--- The container's tag names as a set.
local function tag_set(container)
	local set = {}
	local tags = container.GameplayTags
	for i = 1, #tags do set[tags[i].TagName:ToString()] = true end
	return set
end

local function dose_active(health)
	local buffs = health.Buffs
	for i = 1, #buffs do
		if buffs[i].Tag.TagName:ToString() == DOSE_BUFF then return true end
	end
	return false
end

--- Treatment -> { context, tag } for the first context giving it, and the number of distinct treatments.
local function item_treatments(definition)
	local by_treatment, count = {}, 0
	local contexts = definition.ItemContexts
	for i = 1, #contexts do
		local context = contexts[i]
		if util.valid(context) then
			local actions = context.ToTriggerActions
			for j = 1, #actions do
				local action = actions[j]
				if util.valid(action) then
					for tag in pairs(tag_set(action.EffectStatTags)) do
						local treatment = TREATMENTS[tag]
						if treatment and not by_treatment[treatment] then
							by_treatment[treatment] = { context = context, tag = tag }
							count = count + 1
						end
					end
				end
			end
		end
	end
	return by_treatment, count
end

--- True when rank a sorts before rank b. Ranks are arrays compared element by element.
local function ranks_before(a, b)
	for i = 1, #a do
		if a[i] ~= b[i] then return a[i] < b[i] end
	end
	return false
end

--- The step's best candidate and its context, or nil.
--- rank(candidate, entry) gives the waste part of the rank: speed comes before it, uses left after it.
local function pick(candidates, treatment, pawn, rank)
	local best, best_context, best_rank = nil, nil, nil
	for _, candidate in ipairs(candidates) do
		local entry = candidate.treatments[treatment]
		if entry then
			local r = { candidate.time }
			for _, v in ipairs(rank(candidate, entry)) do r[#r + 1] = v end
			r[#r + 1] = candidate.uses
			-- No item widget: the bind has none, unlike the context menu.
			if (not best_rank or ranks_before(r, best_rank)) and entry.context:IsValidContext(pawn, nil, candidate.item) then
				best, best_context, best_rank = candidate, entry.context, r
			end
		end
	end
	return best, best_context
end

local function by_treatments(candidate)
	return { candidate.count }
end

--- The pawn and the player's inventory component, or nil. bind names the bind in log lines.
local function resolve(bind)
	local pc = FindFirstOf("PlayerController")
	local library = StaticFindObject(LIBRARY_CDO)
	local pawn = util.valid(pc) and pc.Pawn or nil
	local comp = util.valid(pawn) and util.valid(library) and library:GetPlayerInventoryComponent(pc) or nil
	if not util.valid(comp) then
		log.debug("%s: no pawn, inventory library or inventory component", bind)
		return nil
	end
	return pawn, comp
end

--- Every medical item with uses left that gives at least one treatment.
local function collect(comp)
	-- Every main container, nested storage included: MainContainers is flat and holds each container item's storage as its own entry.
	-- Items are passed to the context as read from the MainContainers property. A ContainerItem returned by one UFunction crashes the game when passed to another.
	local candidates = {}
	local containers = comp.MainContainers
	for i = 1, #containers do
		local items = containers[i].ContainerItems
		for j = 1, #items do
			local item = items[j]
			local definition = item.ItemDefinition
			if util.valid(definition) and definition.ItemIdentifier.TagName:ToString():sub(1, #MEDICAL) == MEDICAL then
				local uses = stat(item, USES_TAG) or math.huge
				if uses > 0 then
					local treatments, count = item_treatments(definition)
					if count > 0 then
						candidates[#candidates + 1] = { item = item, time = stat(item, USE_TIME_TAG) or math.huge, uses = uses, treatments = treatments, count = count }
					end
				end
			end
		end
	end
	return candidates
end

--- Execute the pick of the first step with a usable candidate.
local function run(bind, steps, candidates, pawn)
	for _, step in ipairs(steps) do
		local best, context = pick(candidates, step.treatment, pawn, step.rank)
		if best then
			log.debug("%s: %s: using %s (%.1f s)", bind, step.treatment, best.item.ItemDefinition:GetFullName(), best.time)
			context:Execute(pawn, nil, best.item)
			return
		end
		log.debug("%s: %s: no usable item carried", bind, step.treatment)
	end
	log.debug("%s: nothing to treat", bind)
end

--- The Combat Heal key's press. Game thread.
function M.press()
	local pawn, comp = resolve("CombatHeal")
	if not pawn then return end
	local health_comp = pawn:GetHealthComponent()
	local health = util.valid(health_comp) and health_comp.Health or nil
	local ability = pawn:GetAbilityComponent()
	local tags_comp = util.valid(ability) and ability.GameplayTagsComponent or nil
	if not (util.valid(health) and util.valid(tags_comp)) then
		log.debug("CombatHeal: no health attribute or tags component")
		return
	end

	local real, max = health:GetBaseValue(), health:GetCurrentMaxValue()
	local missing = max - real
	local active = dose_active(health)
	local owned = tag_set(tags_comp.OwnedGameplayTags)
	local names = {}
	for name in pairs(owned) do names[#names + 1] = name end
	log.debug("CombatHeal: real %.1f max %.1f, dose %s, tags [%s]", real, max, tostring(active), table.concat(names, ", "))

	local steps = {}
	if real < max * PAINKILLER_AT and not active then
		steps[#steps + 1] = { treatment = "painkiller", rank = by_treatments }
	end
	for _, condition in ipairs(CONDITIONS) do
		if owned[condition.tag] then steps[#steps + 1] = { treatment = condition.treatment, rank = by_treatments } end
	end
	if missing > 0 then
		-- A heal covering all missing health beats one falling short. Least overheal among covering heals, least shortfall among short ones.
		steps[#steps + 1] = { treatment = "heal", rank = function(candidate, entry)
			local heal = stat(candidate.item, entry.tag) or 0
			if heal >= missing then return { 0, heal - missing } end
			return { 1, missing - heal }
		end }
	end

	run("CombatHeal", steps, collect(comp), pawn)
end

--- The Use Adrenaline key's press. Game thread.
--- The injector's effect replaces an active one, so a press during a boost restarts it.
function M.use_adrenaline()
	local pawn, comp = resolve("UseAdrenaline")
	if not pawn then return end
	run("UseAdrenaline", { { treatment = "stamina", rank = by_treatments } }, collect(comp), pawn)
end

return M
