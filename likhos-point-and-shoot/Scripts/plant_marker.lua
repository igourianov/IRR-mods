-- plant_marker.lua : the interaction marker on a quest placement spot is drawn in a color that stands out and is less transparent while out of reach (docs/solutions/plant-spot-marker.md).
--
-- Every game name here comes from docs/solutions/plant-spot-marker.md.
-- Holds no UObject between calls. Plant spot markers are tracked by path for the per-frame opacity floor.

local log    = require("log")
local util   = require("util")
local hook   = require("hook")
local config = require("config")

local M = {}

local hooks = hook.new("plant marker", "plant spot markers stay vanilla")

local MARKER_CLASS = "/Game/Blueprints/InteractionSystem/Widgets/W_InteractionTargetMarker.W_InteractionTargetMarker_C"
local UPDATE_FN    = MARKER_CLASS .. ":UpdateTargetMarker"
local PLANT_ICON   = "T_IRR_Interaction_ItemInteractionIcon"

-- Background is the ring and the dark fill inside it, one material image tinted with the setting's BorderColor.
local BACKGROUND, ICON = "Background", "Icon"

-- Linear color parsed from config.plant_marker_color by install().
local tint = nil

-- config.plant_marker_min_opacity, set by install().
local min_opacity = 0

-- Paths of the plant spot markers decorated this level, for tick(). Paths of destroyed markers drop out on the next tick.
local plant_markers = {}

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

-- Absolute colors, so a repeated update gives the same result whether or not vanilla reset the image in between. The alpha stays whatever vanilla left.
local function set_tint(image)
	image:SetColorAndOpacity({ R = tint.R, G = tint.G, B = tint.B, A = image.ColorAndOpacity.A })
end

local function decorate(path)
	local marker = StaticFindObject(path)
	if not util.valid(marker) then return end
	local background = marker[BACKGROUND]
	-- Vanilla tints the ring grey with the setting's BorderColor, which would dim the configured color multiplied over it.
	background:SetBrushTintColor({ SpecifiedColor = { R = 1, G = 1, B = 1, A = 1 }, ColorUseRule = 0 })
	set_tint(background)
	set_tint(marker[ICON])
	plant_markers[path] = true
end

-- UE4SS runs a single callback for a Blueprint function hook, never a post callback, so the marker is changed a tick later, after the vanilla body has run.
-- The setting is read here, where the parameter is valid. The marker is passed by path, not held.
-- Any other icon is left to vanilla, which sets the marker's colors on each update.
local function on_update(context, setting)
	local texture = setting:get().Texture
	local icon = util.valid(texture) and texture:GetFName():ToString() or "none"
	local path = util.path(context:get())
	log.debug("plant marker: %s shows %s", path, icon)
	if icon ~= PLANT_ICON then return end
	ExecuteInGameThreadWithDelay(1, hooks.guard(function() decorate(path) end))
end

-- The native fade sets OpacityAlpha to 0 beyond the outer radius, 0.2 out of reach and 1 within it, and eases ContentBox's render opacity toward it.
-- Both are raised: the target so the easing doesn't pull back, the box so the marker doesn't fade up to it over several frames.
local function hold_opacity()
	if min_opacity <= 0 then return end
	for path in pairs(plant_markers) do
		local marker = StaticFindObject(path)
		if not util.valid(marker) then
			plant_markers[path] = nil
		else
			local alpha = marker.OpacityAlpha
			if alpha > 0 and alpha < min_opacity then
				marker.OpacityAlpha = min_opacity
				local box = marker.ContentBox
				if box:GetRenderOpacity() < min_opacity then box:SetRenderOpacity(min_opacity) end
			end
		end
	end
end

--- Hold every plant spot marker that is showing at the configured minimum opacity. Called every frame, so a failure logs once.
M.tick = hooks.guard(hold_opacity)

--- Forget the tracked markers. Called on level load, when every marker widget is replaced.
function M.reset()
	plant_markers = {}
end

--- Hook the marker widget once its Blueprint class is loaded.
function M.install()
	tint = parse_color(config.plant_marker_color)
	if not tint then
		log.error("plant marker: plant_marker_color '%s' is not a #RRGGBB color, plant spot markers stay vanilla", tostring(config.plant_marker_color))
		return
	end
	min_opacity = tonumber(config.plant_marker_min_opacity) or 0
	hooks.install(UPDATE_FN, MARKER_CLASS, on_update)
end

return M
