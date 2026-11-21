-- weapon/fire_mode.lua : the Switch Fire Mode (Tap/Hold) key switches the fire mode on a tap and shows the current one on a hold (docs/solutions/fire-mode-check.md).
-- The hold also takes the support hand off the weapon, with the open inventory's montages, until the release.
-- The fire mode card shows where the magazine check card does.
--
-- The switch is the vanilla one, sent as a one-frame press of the vanilla action.
-- Holds no UObject between calls.

local log     = require("lib.log")
local util    = require("lib.util")
local player  = require("core.player")
local actions = require("core.actions")
local hook    = require("lib.hook")
local config  = require("config")

local M = {}

local hooks = hook.new("fire mode card", "the fire mode card stays in the lower right")

local IA_SWITCH_FIRE_MODE = "/Game/Blueprints/InputSystem/InputActions/IA_SwitchFireMode.IA_SwitchFireMode"
local GENERAL_LIBRARY = "/Script/Test_C.Default__GeneralFunctionLibrary"
local CARD_WIDGET = "W_ShowFireMode_C"
local CARD_CLASS = "/Game/Blueprints/InventorySystem/Widgets/WeaponUI/W_ShowFireMode.W_ShowFireMode_C"
local WEAPON_UI = "W_WeaponUI_C"

-- EFireMode value from WeaponComponent:GetFireMode -> the GeneralSettings property holding its tag.
local MODE_TAGS = { [0] = "AutoFireModeTag", [1] = "SemiAutoFireModeTag", [2] = "BurstFireModeTag" }

-- The card hides on its own timer a few seconds after it is shown, also while the key is held. Showing it again within that keeps it up.
local REFRESH_MS = 1000

local PLAY_MONTAGE = "/Script/Test_C.Default__AsyncAction_PlayMontage"
-- The inventory ability waits for this linked anim graph to play no montage before taking the hand off.
local COMBAT_GRAPH = "Combat"

-- os.clock() of the last show while the key is held past the tap window, nil otherwise.
local shown_at = nil

-- The hands-off pose of this hold: nil, PENDING until it can start, STARTED once its montage plays. Plain values only.
local PENDING, STARTED = "pending", "started"
local pose = nil

local function switch()
	player.inject_press(IA_SWITCH_FIRE_MODE)
end

--- Play one of the weapon's NoMagMontageSet montage sets the way SGA_OpenInventory_C does.
local function play_montages(pawn, wc, data, set, stop_previous)
	local factory = StaticFindObject(PLAY_MONTAGE)
	local weapon = wc:GetOwner()
	if not (util.valid(factory) and util.valid(weapon)) then return end
	local montages = { TP_Animation = set.TP_Animation, FP_Animation = set.FP_Animation, Weapon_Animation = set.Weapon_Animation }
	local proxy = factory:CreateProxyObjectForPlayCharacterMontage(pawn, weapon, data:GetLinkedAnimGraph(), FName("None"), montages, 1.0, stop_previous, false, true)
	if util.valid(proxy) then proxy:Activate() end
end

local function linked_anim(pawn, tag)
	local mesh = pawn.Mesh
	local anim = util.valid(mesh) and mesh:GetLinkedAnimGraphInstanceByTag(tag)
	return util.valid(anim) and anim or nil
end

local function start_pose()
	if pose ~= PENDING then return end
	local pawn = player.pawn()
	local wc = player.weapon_component()
	if not (pawn and wc) then return end
	local anim = linked_anim(pawn, FName(COMBAT_GRAPH))
	if not anim or anim:IsAnyMontagePlaying() then return end
	local data = wc:GetWeaponDataAsset()
	if not util.valid(data) then return end

	play_montages(pawn, wc, data, data:GetNoMagMontageSet().HandOffMontageSet, false)
	pose = STARTED
	log.debug("fire mode: hand off")
end

--- Put the hand back on, as the closing inventory does, while the equipped weapon's hand-off montage still holds the pose.
local function end_pose()
	local started = pose == STARTED
	pose = nil
	if not started then return end
	local pawn = player.pawn()
	local wc = player.weapon_component()
	local data = wc and wc:GetWeaponDataAsset()
	if not (pawn and util.valid(data)) then return end

	local set = data:GetNoMagMontageSet()
	local off = set.HandOffMontageSet.FP_Animation
	local anim = linked_anim(pawn, data:GetLinkedAnimGraph())
	local active = anim and anim:GetCurrentActiveMontage()
	-- The hand-off montage stops on its last frame, so Montage_IsPlaying is false while it holds the pose. It stays the active montage until another replaces it.
	-- A montage that cut in, or a swapped weapon's, leaves nothing to undo.
	if not (util.valid(off) and util.valid(active) and active:GetFullName() == off:GetFullName()) then return end
	play_montages(pawn, wc, data, set.HandOnMontageSet, true)
	log.debug("fire mode: hand on")
end

--- The top widget holding `widget`, its HUD: each nested widget's outer is its parent widget's WidgetTree.
local function hud_root(widget)
	local root = widget
	local outer = root:GetOuter()
	while util.valid(outer) and util.class_name(outer) == "WidgetTree" do
		root = outer:GetOuter()
		outer = root:GetOuter()
	end
	return root
end

---@return UObject? # the fire mode card of the HUD on screen
local function live_card()
	for _, widget in ipairs(FindAllOf(CARD_WIDGET) or {}) do
		-- An earlier level's HUD outlives its level off screen and reports the current controller as its owning player. Its Slate widgets are gone, so IsVisible is false.
		-- IsInViewport is false for the live HUD too, and the hideout's controller has no mission component to read the HUD from.
		if util.valid(widget) and hud_root(widget):IsVisible() then return widget end
	end
	return nil
end

local function show()
	local wc = player.weapon_component()
	local library = StaticFindObject(GENERAL_LIBRARY)
	if not (wc and util.valid(library)) then return end

	local mode = wc:GetFireMode()
	local property = MODE_TAGS[mode]
	if not property then
		log.debug("fire mode: no tag for mode %s", tostring(mode))
		return
	end
	local settings = library:GetGeneralSettings()
	local widget = live_card()
	if not (util.valid(settings) and widget) then
		log.debug("fire mode: settings %s, card %s", tostring(util.valid(settings)), tostring(widget ~= nil))
		return
	end

	local tag = settings[property]
	widget:OnWeaponFireModeChanged_Event({ TagName = tag.TagName })
	log.debug("fire mode: showed %s", tag.TagName:ToString())
end

local function hold()
	shown_at = os.clock()
	show()
	pose = PENDING
	start_pose()
end

local function held()
	if not shown_at then return end
	start_pose()
	if (os.clock() - shown_at) * 1000 < REFRESH_MS then return end
	shown_at = os.clock()
	show()
end

local function release()
	shown_at = nil
	end_pose()
end

local function clear()
	shown_at = nil
	pose = nil
end

--- Move the card into the magazine check card's panel, with the magazine card's slot layout. A placed card is left as it is.
local function place(card)
	-- The card's outer is its HUD's WidgetTree, whose outer is the W_WeaponUI_C.
	local weapon_ui = card:GetOuter():GetOuter()
	if not (util.valid(weapon_ui) and util.class_name(weapon_ui) == WEAPON_UI) then return end
	local mag = weapon_ui.W_ShowMagCapacity
	local panel = util.valid(mag) and mag:GetParent()
	if not util.valid(panel) then return end
	local parent = card:GetParent()
	if util.valid(parent) and parent:GetFullName() == panel:GetFullName() then return end

	local layout = mag.Slot
	local p = layout.Padding
	-- AddChild takes the card out of its current panel first.
	local slot = panel:AddChild(card)
	slot:SetPadding({ Left = p.Left, Top = p.Top, Right = p.Right, Bottom = p.Bottom })
	slot:SetHorizontalAlignment(layout.HorizontalAlignment)
	slot:SetVerticalAlignment(layout.VerticalAlignment)
	log.debug("fire mode card: placed %s", card:GetFullName())
end

local function on_card_constructed(context)
	-- The hook fires while the HUD may still be building, so the card moves on the next tick. It is looked up again by path rather than held.
	local path = util.path(context:get())
	ExecuteInGameThreadWithDelay(1, hooks.guard(function()
		local card = StaticFindObject(path)
		if util.valid(card) then place(card) end
	end))
end

local function enabled()
	for _, bind in ipairs(config.binds) do
		if bind.action == "FireMode" then return bind.enabled end
	end
	return false
end

--- Define the FireMode action and place the fire mode cards, built and to be built.
function M.install()
	actions.define("FireMode", {
		tap = switch,
		hold = hold,
		held = held,
		release = release,
		reset = clear,
	})

	if not enabled() then return end
	hooks.install(CARD_CLASS .. ":Construct", CARD_CLASS, on_card_constructed)
	for _, card in ipairs(FindAllOf(CARD_WIDGET) or {}) do
		if util.valid(card) then hooks.try(place, card) end
	end
end

return M
