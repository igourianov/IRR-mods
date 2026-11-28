-- keybinds/map.lua : the mod's binds and its player-mappable keys, stored in the game's Enhanced Input user settings.
--
-- Each mod mapping is a runtime InputAction in a mod InputMappingContext, registered with EnhancedInputUserSettings and active at the lowest priority.
-- Nothing listens to the actions.
-- The controls menu row (keybinds/menu.lua) rebinds a key and the game saves it. core/input.lua reads the key and polls it.
-- See docs/solutions/point-aim-keybind-menu.md.

local log    = require("lib.log")
local util   = require("lib.util")
local player = require("core.player")

local M = {}

-- UE4SS has no GetPathName on UObject, so the mod's objects live directly in /Engine/Transient and are found by path.
local OUTER = "/Engine/Transient"
local IMC_NAME = "IMC_LikhosKeybinds"
local STACK_PRIORITY = -1000

-- A vanilla action in the game's gameplay contexts. Its having any mapping, None included, means those contexts are in the live stack.
-- On a raid load the controls page refreshes its vanilla rows once, when the stack first gets mappings. If the mod's context lands first, the rows refresh without their keys and show None for the rest of the raid.
local VANILLA_ACTION = "IA_Fire"
local RETRY_MS = 100
local RETRY_LIMIT = 300

-- Mod mappings in the order of their rows on the controls page.
-- name: the key profile row name. The saved key is stored under it, so renaming it drops the user's key.
-- It also names the action a feature module defines through registry.define. A bind whose action is not defined is not polled.
-- display: the row label. description: shown in the controls page's setting info panel when the row is hovered. Plain text, the panel is a rich text block.
-- vanilla: the row is the game's own, so the mod builds no InputAction or row for it.
M.BINDS = {
	{
		name = "LikhosPointShootingDirect",
		display = "Point Shooting + Laser (Hold)",
		description = [[
Hold to go straight into the point shooting pose bypassing aim.

Activates the first laser on the gun. Uses IR laser when present and NVG is on.]],
	},
	{
		name = "LikhosFlashlight",
		display = "Flashlight (Hold/Toggle)",
		description = "Activate the first flashlight on the gun (contextual to NVG). Hold for momentary activation. Tap to toggle.",
	},
	{
		name = "LikhosSwitchFireMode",
		display = "Switch Fire Mode (Tap/Hold)",
		description = [[
Replaces vanilla Switch Fire Mode. Unbind the vanilla key.

Tap: switch to the next fire mode.

Hold: show the selected fire mode without switching.]],
	},
	{
		name = "LikhosSmartFireMode",
		display = "Smart Fire Mode (Tap/Hold/Double Tap)",
		description = [[
Switch straight to a fire mode instead of cycling. Shows the selected mode either way.

Tap: semi.

Double tap: burst.

Hold: auto.]],
	},
	{
		name = "LikhosSmartGrenade",
		display = "Smart Grenade (Tap/Hold/Double Tap)",
		description = [[
Smarter alternative to Grenade Equip. Predictable grenade type selection.

Tap: frag grenade.

Hold: smoke or gas.

Double tap: flashbang.]],
	},
	{
		name = "LikhosCombatHeal",
		display = "Smart Heal (Tap/Hold)",
		description = [[
Smarter alternative to Quick Heal. Predictable under pressure. Minimizes waste.

Tap: consume pain medication (fastest first).

Hold: treat bleed/fracture conditions, otherwise consume IV if HP is missing.]],
	},
	{
		-- Named before food joined it on hold. Kept so the saved key carries over.
		name = "LikhosUseAdrenaline",
		display = "Adrenaline/Food (Tap/Hold)",
		description = [[
Uses items from anywhere in player's inventory.

Tap: consume Adrenaline.

Hold: consume food/drink.]],
	},
	{
		name = "LikhosInteractInstant",
		display = "Interact (Instant)",
		description = "Interact without holding down the button. Locked containers still take time to unlock.",
	},
	{
		name = "IA_HoldBreath",
		vanilla = true,
	},
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
	local subsystem = player.input_subsystem()
	if not subsystem then return nil end
	local settings = subsystem:GetUserSettings()
	if not util.valid(settings) then return nil end
	return settings, subsystem
end

---@return UObject? # nil before register() has built it
function M.action(mapping)
	return find(action_name(mapping))
end

-- VANILLA_ACTION's path, resolved once. A path, not the UObject, so nothing is held across a level load.
local vanilla_path = nil

---@return UObject? # nil while the action isn't loaded
local function vanilla_action()
	local ia = vanilla_path and StaticFindObject(vanilla_path)
	if util.valid(ia) then return ia end
	vanilla_path = nil
	for _, obj in ipairs(FindAllOf("InputAction") or {}) do
		if util.valid(obj) and obj:GetFName():ToString() == VANILLA_ACTION then
			vanilla_path = util.path(obj)
			return obj
		end
	end
	return nil
end

local function game_contexts_live(subsystem)
	local ia = vanilla_action()
	if not ia then return false end
	local keys = subsystem:QueryKeysMappedToAction(ia)
	return type(keys) == "table" and #keys > 0
end

--- Build the mod's actions and context if missing, register the context with user settings and, once the game's contexts are live, activate it.
--- Registration also restores the user's saved keys. Game thread. Safe to repeat.
---@return boolean # whether the mod's context is live on return
function M.register()
	local settings, subsystem = user_settings()
	if not settings then
		log.debug("keymap: no Enhanced Input user settings yet")
		return false
	end

	local imc = find(IMC_NAME)
	if not imc then
		local transient = StaticFindObject(OUTER)
		imc = construct("/Script/EnhancedInput.InputMappingContext", transient, IMC_NAME)
		for _, mapping in ipairs(M.BINDS) do
			if not mapping.vanilla then
				local ia = construct("/Script/EnhancedInput.InputAction", transient, action_name(mapping.name))
				local pmks = construct("/Script/EnhancedInput.PlayerMappableKeySettings", ia, "PlayerMappableKeySettings")
				pmks.Name = FName(mapping.name)
				pmks.DisplayName = FText(mapping.display)
				ia.PlayerMappableKeySettings = pmks
				-- Unbound by default. The mapping inherits the action's mappable settings.
				imc:MapKey(ia, { KeyName = FName("None") })
			end
		end
		log.info("keymap: built %s", imc:GetFullName())
	end

	if settings:RegisterInputMappingContext(imc) then
		log.info("keymap: registered %s with user settings", IMC_NAME)
	end

	if not game_contexts_live(subsystem) then return false end

	-- The controls menu shows a row's key only if its context is active (FindInputActionKey reads QueryKeysMappedToAction).
	-- Below every vanilla context it can't consume their keys. Adding it again only resets its priority.
	-- A row reads its key once, when built during a level load. A deferred stack rebuild left rows built in the meantime showing None.
	subsystem:AddMappingContext(imc, STACK_PRIORITY, { bForceImmediately = true })
	return true
end

-- request key -> generation of its latest request
local pending = {}

--- Call register() until the mod's context is live, then on_live(). Game thread.
--- A newer request under the same key cancels the older one's retries. The retries give up after RETRY_LIMIT, which is expected in a level without the game's gameplay contexts, like the lobby.
function M.when_live(key, on_live)
	local gen = (pending[key] or 0) + 1
	pending[key] = gen
	local tries = 0
	local function attempt()
		if pending[key] ~= gen then return end
		if M.register() then
			pending[key] = nil
			if on_live then on_live() end
			return
		end
		tries = tries + 1
		if tries >= RETRY_LIMIT then
			pending[key] = nil
			log.debug("keymap: %s gave up waiting for the game's input contexts", key)
			return
		end
		ExecuteInGameThreadWithDelay(RETRY_MS, function() util.safe("keymap register", attempt) end)
	end
	attempt()
end

---@return UObject? # nil before Enhanced Input user settings exist
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

function M.describe(mapping)
	local names = {}
	for _, k in ipairs(M.keys(mapping, M.profile())) do table.insert(names, k.KeyName:ToString()) end
	return #names > 0 and table.concat(names, ", ") or "unbound"
end

return M
