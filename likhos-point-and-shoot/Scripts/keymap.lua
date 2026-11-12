-- keymap.lua : the mod's player-mappable keys, stored in the game's Enhanced Input user settings.
--
-- Each mapping is a runtime InputAction in a mod InputMappingContext, registered with EnhancedInputUserSettings and active at the lowest priority.
-- Nothing listens to the actions.
-- The controls menu row (menu.lua) rebinds a key and the game saves it. input.lua reads the key and polls it.
-- See docs/solutions/point-aim-keybind-menu.md.

local log  = require("log")
local util = require("util")

local M = {}

-- UE4SS has no GetPathName on UObject, so the mod's objects live directly in /Engine/Transient and are found by path.
local OUTER = "/Engine/Transient"
local IMC_NAME = "IMC_LikhosKeybinds"
local STACK_PRIORITY = -1000

M.MAPPINGS = {
	LikhosPointShootingDirect = { display = "Point Shooting + Laser (Hold)" },
	LikhosFlashlight          = { display = "Flashlight (Hold/Toggle)" },
	LikhosInteractInstant     = { display = "Interact (Instant)" },
	LikhosConsumeFoodDrink    = { display = "Consume Food/Drink" },
	LikhosCombatHeal          = { display = "Use Medical (Tap/Hold)" },
	LikhosUseAdrenaline       = { display = "Use Adrenaline" },
}

local function action_name(mapping)
	return "IA_" .. mapping
end

local function find(name)
	local obj = StaticFindObject(OUTER .. "." .. name)
	if util.valid(obj) then return obj end
	return nil
end

local function construct(class_path, outer, name)
	return StaticConstructObject(StaticFindObject(class_path), outer, FName(name))
end

local function user_settings()
	local subsystem = FindFirstOf("EnhancedInputLocalPlayerSubsystem")
	if not util.valid(subsystem) then return nil end
	local settings = subsystem:GetUserSettings()
	if not util.valid(settings) then return nil end
	return settings, subsystem
end

--- The mod's InputAction for a mapping, or nil before register() has built it.
function M.action(mapping)
	return find(action_name(mapping))
end

--- Build the mod's actions and context if missing, register the context with user settings and activate it.
--- Registration also restores the user's saved keys. The context is live on return. Game thread. Safe to repeat.
function M.register()
	local settings, subsystem = user_settings()
	if not settings then
		log.debug("keymap: no Enhanced Input user settings yet")
		return
	end

	local imc = find(IMC_NAME)
	if not imc then
		local transient = StaticFindObject(OUTER)
		imc = construct("/Script/EnhancedInput.InputMappingContext", transient, IMC_NAME)
		for mapping, spec in pairs(M.MAPPINGS) do
			local ia = construct("/Script/EnhancedInput.InputAction", transient, action_name(mapping))
			local pmks = construct("/Script/EnhancedInput.PlayerMappableKeySettings", ia, "PlayerMappableKeySettings")
			pmks.Name = FName(mapping)
			pmks.DisplayName = FText(spec.display)
			ia.PlayerMappableKeySettings = pmks
			-- Unbound by default. The mapping inherits the action's mappable settings.
			imc:MapKey(ia, { KeyName = FName("None") })
		end
		log.info("keymap: built %s", imc:GetFullName())
	end

	if settings:RegisterInputMappingContext(imc) then
		log.info("keymap: registered %s with user settings", IMC_NAME)
	end

	-- The controls menu shows a row's key only if its context is active (FindInputActionKey reads QueryKeysMappedToAction).
	-- Below every vanilla context it can't consume their keys. Adding it again only resets its priority.
	-- A row reads its key once, when built during a level load. A deferred stack rebuild left rows built in the meantime showing None.
	subsystem:AddMappingContext(imc, STACK_PRIORITY, { bForceImmediately = true })
end

--- The active key profile, or nil before Enhanced Input user settings exist.
--- Looked up per call: the user settings belong to the local player.
function M.profile()
	local settings = user_settings()
	if not settings then return nil end
	local profile = settings:GetActiveKeyProfile()
	return util.valid(profile) and profile or nil
end

-- mapping -> its row FName, built once. An FName is a plain value, not a UObject.
local row_names = {}

--- FKey tables for the keys bound to a mapping in profile. Empty when unbound or without a profile.
function M.keys(mapping, profile)
	local out = {}
	if not profile then return out end

	local row = row_names[mapping]
	if not row then
		row = FName(mapping)
		row_names[mapping] = row
	end
	local found = {}
	profile:GetMappedKeysInRow(row, found)
	for _, k in ipairs(found) do
		-- The out array holds struct wrappers. An unbound row reports one key, None.
		local name = k:get().KeyName
		if name:ToString() ~= "None" then
			table.insert(out, { KeyName = name })
		end
	end
	return out
end

--- Human-readable keys for kb_status.
function M.describe(mapping)
	local names = {}
	for _, k in ipairs(M.keys(mapping, M.profile())) do table.insert(names, k.KeyName:ToString()) end
	return #names > 0 and table.concat(names, ", ") or "unbound"
end

return M
