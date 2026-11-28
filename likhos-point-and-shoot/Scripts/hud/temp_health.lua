-- hud/temp_health.lua : the temporary health a painkiller adds shows on the HUD health bar in its own color instead of a faint pink.
-- Design: docs/solutions/temp-health-color.md
--
-- Every game name here comes from that doc.
-- Holds no UObject between calls.

local log    = require("lib.log")
local util   = require("lib.util")
local hook   = require("lib.hook")
local config = require("config")

local M = {}

local hooks = hook.new("temp health", "temp health stays vanilla")

local BAR_CLASS = "/Game/Blueprints/UICore/Widgets/Base/W_GeneralStatBar.W_GeneralStatBar_C"
local HEALTH_BAR = "W_HealthBar"
local HUD_CLASS = "W_StaminaAndHealthBars_C"

-- Linear color parsed from config.temp_health_color, set by install().
local tint = nil

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

-- The stamina bars and the inventory's stat bars are the same class. The HUD health bar's outer is the HUD widget's WidgetTree.
-- The class's own template has the same name, but its WidgetTree belongs to the generated class, not to a HUD widget.
local function is_hud_health_bar(bar)
	if bar:GetFName():ToString() ~= HEALTH_BAR then return false end
	local tree = bar:GetOuter()
	local owner = util.valid(tree) and tree:GetOuter() or nil
	return util.valid(owner) and util.class_name(owner) == HUD_CLASS
end

-- PreConstruct copies the instance's PositiveStyle into this bar's WidgetStyle, so the tint goes on after it, every time it runs.
local function recolor(bar)
	if not (util.valid(bar) and is_hud_health_bar(bar)) then return end
	local positive = bar.PB_ProgressBar_Positive
	if not util.valid(positive) then return end
	local fill = positive.WidgetStyle.FillImage
	fill.TintColor = { SpecifiedColor = { R = tint.R, G = tint.G, B = tint.B, A = fill.TintColor.SpecifiedColor.A }, ColorUseRule = 0 }
	log.debug("temp health: recolored %s", util.path(bar))
end

function M.install()
	tint = parse_color(config.temp_health_color)
	if not tint then
		log.error("temp health: temp_health_color '%s' is not a #RRGGBB color, temp health stays vanilla", tostring(config.temp_health_color))
		return
	end
	hooks.install(BAR_CLASS .. ":PreConstruct", BAR_CLASS, function() end, function(context)
		recolor(context:get())
	end)
	-- A hot reload, or an init after the HUD was built, finds the bar already constructed.
	hooks.try(function()
		for _, bar in ipairs(FindAllOf("W_GeneralStatBar_C") or {}) do recolor(bar) end
	end)
end

return M
