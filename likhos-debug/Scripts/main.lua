-- likhos-debug : read-only recon console commands for Incursion Red River. Dev only, not published.
--
-- Every game name here comes from docs/solutions/debug-weapon-probe.md (Recon).
-- No UFunction gets a struct argument: on UE4SS 1217 a struct returned by one UFunction crashes the game when passed into another.
-- Hot reload re-runs this file. Re-registering a console command replaces the handler.

local log    = require("log")
local util   = require("util")
local config = require("config")

local LIBRARY = "/Script/Test_C.Default__InventoryFunctionLibrary"
local WEAPON_COMPONENT = "BP_WeaponComponent_C"
local SLOT_PREFIX = "Inventory.Equipment Slots."
local WEAPON_SLOTS = { "Primary", "Secondary", "Pistol" }
local ZERO_KEY = "00000000-00000000-00000000-00000000"

local function guid_key(g)
	return string.format("%08x-%08x-%08x-%08x", g.A & 0xffffffff, g.B & 0xffffffff, g.C & 0xffffffff, g.D & 0xffffffff)
end

local function tag_name(tag)
	return tag.TagName:ToString()
end

local function object_name(obj)
	return util.valid(obj) and obj:GetFName():ToString() or "?"
end

--- Stat config class without its U_ prefix and _C suffix: U_Recoil_C reads Recoil.
local function stat_name(stat_config)
	return (object_name(util.valid(stat_config) and stat_config:GetClass() or nil):gsub("^U_", ""):gsub("_C$", ""))
end

--- The definition's ItemStats as stat name -> value, plus the names in definition order.
local function base_stats(definition)
	local values, order = {}, {}
	if not util.valid(definition) then return values, order end
	local stats = definition.ItemStats
	for i = 1, #stats do
		local name = stat_name(stats[i].StatItemConfig)
		if values[name] == nil then order[#order + 1] = name end
		values[name] = stats[i].Value
	end
	return values, order
end

local function format_stats(values, order)
	local parts = {}
	for _, name in ipairs(order) do parts[#parts + 1] = string.format("%s %g", name, values[name]) end
	return table.concat(parts, ", ")
end

--- Item UID key -> equipment slot tag, read from the equipment component's properties.
local function equipped_slots(equipment)
	local slots = {}
	local function add(data)
		local key = guid_key(data.Item.ItemUID)
		if key ~= ZERO_KEY then slots[key] = tag_name(data.Slot) end
	end
	for _, list in ipairs({ equipment.LocEquipmentData, equipment.RepEquipmentData }) do
		for i = 1, #list do add(list[i]) end
	end
	add(equipment.LocEquippedItem)
	return slots
end

--- Slot tag -> { wc, root } for every live weapon component whose root item sits in an equipment slot.
--- The hideout spawns weapon actors for racks and vendors too, so components are matched to slots by item UID.
local function slot_weapons(slots)
	local found = {}
	for _, wc in ipairs(FindAllOf(WEAPON_COMPONENT) or {}) do
		if util.valid(wc) then
			local root = wc:GetContainerItem()
			local slot = slots[guid_key(root.ItemUID)]
			if slot then found[slot] = { wc = wc, root = root } end
		end
	end
	return found
end

--- One getter result for the summary, or the error text when the call fails.
local function call(wc, fn, ...)
	local ok, res = pcall(function(...) return wc[fn](wc, ...) end, ...)
	if not ok then return "err" end
	if type(res) == "number" then return string.format("%.2f", res) end
	return tostring(res)
end

local function dump_weapon(slot, wc, root, lib)
	local definition = root.ItemDefinition
	log.info("[%s] %s  %s", slot, object_name(definition), util.valid(definition) and util.path(definition) or "")
	local class_ok, class_tag = pcall(function() return tag_name(lib:GetWeaponClassTag(wc)) end)
	log.info("  class %s, suppressed %s", class_ok and class_tag or "err", call(wc, "IsSuppressed"))
	log.info("  game: recoil %s (x%s), ergonomics %s (x%s), weight %s (x%s), spread %s, fire rate %s",
		call(wc, "GetRecoil"), call(wc, "GetRecoilMultiplier"),
		call(wc, "GetErgonomics"), call(wc, "GetErgonomicsMultiplier"),
		call(wc, "GetWeight"), call(wc, "GetWeightMultiplier"),
		call(wc, "GetSpread"), call(wc, "GetFireRate"))

	-- Parts as a tree: each item's MotherUID is its parent's ItemUID.
	-- A Lua table of LocalUnrealParam wrappers. Each struct reads through :get().
	local items = wc:GetAttachments(true)
	local root_key = guid_key(root.ItemUID)
	local children = {}
	for i = 1, #items do
		local item = items[i]:get()
		local key = guid_key(item.ItemUID)
		local parent = key == root_key and "" or guid_key(item.MotherUID)
		children[parent] = children[parent] or {}
		table.insert(children[parent], item)
	end

	local sum = { Recoil = 0, Ergonomics = 0 }
	local count = 0
	local function walk(parent, depth)
		for _, item in ipairs(children[parent] or {}) do
			local values, order = base_stats(item.ItemDefinition)
			for name in pairs(sum) do sum[name] = sum[name] + (values[name] or 0) end
			count = count + 1
			log.info("  %s%-48s %s", string.rep("  ", depth), object_name(item.ItemDefinition), format_stats(values, order))
			walk(guid_key(item.ItemUID), depth + 1)
		end
	end
	walk("", 0)
	if count < #items then log.warn("  %d of %d parts are not under the root", #items - count, #items) end
	log.info("  sum of definition stats: recoil %g, ergonomics %g (%d parts)", sum.Recoil, sum.Ergonomics, count)

	local current = {}
	local stats = root.CurrentStats
	for i = 1, #stats do
		-- Returned with the struct from GetContainerItem, so it may hold LocalUnrealParam wrappers too.
		local ok, unwrapped = pcall(function() return stats[i]:get() end)
		local stat = ok and unwrapped or stats[i]
		current[#current + 1] = string.format("%s %g/%g", tag_name(stat.Tag), stat.Value, stat.MaxValue)
	end
	log.info("  current stats: %s", table.concat(current, ", "))
end

local function dump_weapons()
	local pc = FindFirstOf("PlayerController")
	local pawn = util.valid(pc) and pc.Pawn or nil
	local lib = StaticFindObject(LIBRARY)
	if not (util.valid(pawn) and util.valid(lib)) then
		log.warn("no player pawn")
		return
	end
	local equipment = lib:GetEquipmentComponent(pawn)
	if not util.valid(equipment) then
		log.warn("no equipment component")
		return
	end

	local slots = equipped_slots(equipment)
	for key, slot in pairs(slots) do log.debug("equipped %s %s", slot, key) end
	local weapons = slot_weapons(slots)
	for _, name in ipairs(WEAPON_SLOTS) do
		local slot = SLOT_PREFIX .. name
		local weapon = weapons[slot]
		if weapon then
			util.safe("dump " .. name, dump_weapon, name, weapon.wc, weapon.root, lib)
		else
			log.info("[%s] no live weapon", name)
		end
	end
end

local function init()
	log.setup("Debug", config.log_level)

	RegisterConsoleCommandHandler("dbg_weapons", function()
		ExecuteInGameThread(function() util.safe("dbg_weapons", dump_weapons) end)
		return true
	end)

	log.info("ready. console command: dbg_weapons")
end

util.safe("init", init)
