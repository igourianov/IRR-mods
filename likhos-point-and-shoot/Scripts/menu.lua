-- menu.lua : adds the mod's keybinding rows to the game's keyboard controls page, in their own "Likho's Actions" section at the top.
--
-- Each row is a clone of a vanilla row (WB_SingleSettingBar_C), pointed at a mapping from keymap.lua.
-- The vanilla row logic then shows, rebinds, saves and resets the key.
-- The section header is a clone of the page's first one (W_InventorySection_C), followed by a clone of its first Spacer.
-- See docs/solutions/point-aim-keybind-menu.md and docs/solutions/keybind-section.md (Recon) for the recon behind every name here.

local log    = require("log")
local util   = require("util")
local keymap = require("keymap")
local hook   = require("hook")

local M = {}

local hooks = hook.new("menu", "mod rows may be missing from the controls page")

local ROW_CLASS = "/Game/Blueprints/UICore/Widgets/Settings/WB_SingleSettingBar.WB_SingleSettingBar_C"
local HOOK_FN   = ROW_CLASS .. ":On_WidgetConstructed"
local HEADER_CLASS = "W_InventorySection_C"
local SPACER_CLASS = "Spacer"

-- Struct_SettingBar.LabelSettings.Text and Struct_InputKeyInfo fields. User-defined struct members carry GUID suffixes.
local LABEL_SETTINGS = "LabelSettings_17_C0FB3CF442EE50582D14F7910343E95C"
local LABEL_TEXT     = "Text_3_4CDF99D140A67A062FBAA99D135648EC"
local KEY_ACTION     = "InputAction_41_F0CC631D427AFF1C0FB2849BA41B6025"
local KEY_MAPPED     = "PlayerMappedName_60_D667E47C4761808F2AAD738F1F328FEA"

-- The vanilla row every mod row is cloned from. Its construction triggers the section.
local SOURCE_MAPPING = "IA_PointShooting"
local SECTION_TITLE  = "Likho's Actions"
local MAPPINGS = { "LikhosPointShootingDirect", "LikhosFlashlight", "LikhosInteractInstant", "LikhosConsumeFoodDrink" }

local function mapped_name(row)
	local ok, name = pcall(function() return row.Keybindings[1][KEY_MAPPED]:ToString() end)
	return ok and name or nil
end

local function header_title(header)
	local ok, title = pcall(function() return header.SectionNameText:GetText():ToString() end)
	return ok and title or nil
end

local function class_name(widget)
	return widget:GetClass():GetFName():ToString()
end

--- The first child of container that matches, or nil.
local function find_child(container, matches)
	for i = 0, container:GetChildrenCount() - 1 do
		local child = container:GetChildAt(i)
		if matches(child) then return child end
	end
	return nil
end

-- AddChild creates a fresh slot, so a slot's layout is carried over by value.
local function slot_layout(slot)
	local p, s = slot.Padding, slot.Size
	return {
		padding = { Left = p.Left, Top = p.Top, Right = p.Right, Bottom = p.Bottom },
		size = { Value = s.Value, SizeRule = s.SizeRule },
		h = slot.HorizontalAlignment,
		v = slot.VerticalAlignment,
	}
end

local function add_child(container, widget, layout)
	local slot = container:AddChild(widget)
	slot:SetPadding(layout.padding)
	slot:SetSize(layout.size)
	slot:SetHorizontalAlignment(layout.h)
	slot:SetVerticalAlignment(layout.v)
end

--- A new user widget of source's class for the page source sits on. The vanilla widget's outer is the page's WidgetTree.
local function create_like(source)
	local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
	return lib:Create(source:GetOuter():GetOuter(), source:GetClass(), source:GetOwningPlayer())
end

--- Clone the vanilla row source into a row for mapping, not yet on the page. Returns the new row, or nil.
local function create_row(source, mapping)
	local ia = keymap.action(mapping)
	if not ia then
		log.warn("menu: mapping %s isn't registered yet, row not added", mapping)
		return nil
	end

	local row = create_like(source)
	if not util.valid(row) then
		log.warn("menu: could not create a row for %s", mapping)
		return nil
	end

	-- Assignment copies struct and array values, so the vanilla row is left unchanged.
	row.BarType = source.BarType
	row.SettingBar = source.SettingBar
	row.SettingBar[LABEL_SETTINGS][LABEL_TEXT] = FText(keymap.MAPPINGS[mapping].display)
	row.Keybindings = source.Keybindings
	row.Keybindings[1][KEY_ACTION] = ia
	row.Keybindings[1][KEY_MAPPED] = FName(mapping)
	return row
end

--- The section's widgets in page order, each with the slot layout it takes, built before the page is touched so a failure leaves it unchanged. Nil if the page has no header and spacer to clone.
local function create_section(container, source)
	-- The page's first header has no spacer above it. The first spacer separates our section from it.
	local header_src = find_child(container, function(c) return class_name(c) == HEADER_CLASS end)
	local spacer_src = find_child(container, function(c) return class_name(c) == SPACER_CLASS end)
	if not header_src or not spacer_src then
		log.warn("menu: no vanilla section header to clone, rows not added")
		return nil
	end

	local header = create_like(header_src)
	if not util.valid(header) then
		log.warn("menu: could not create the section header")
		return nil
	end
	-- PreConstruct may set the caption from SectionName when the header is added, so SetText runs again after.
	header.SectionName = FName(SECTION_TITLE)

	local widgets = { { widget = header, layout = slot_layout(header_src.Slot), header = true } }
	local row_layout = slot_layout(source.Slot)
	for _, mapping in ipairs(MAPPINGS) do
		local row = create_row(source, mapping)
		if row then table.insert(widgets, { widget = row, layout = row_layout, row = true }) end
	end

	local spacer = StaticConstructObject(spacer_src:GetClass(), spacer_src:GetOuter())
	local size = spacer_src.Size
	spacer:SetSize({ X = size.X, Y = size.Y })
	table.insert(widgets, { widget = spacer, layout = slot_layout(spacer_src.Slot) })
	return widgets
end

local function add_section(source_path)
	local source = StaticFindObject(source_path)
	if not util.valid(source) then
		log.warn("menu: %s is gone, rows not added", source_path)
		return
	end
	local container = source:GetParent()
	if not util.valid(container) then
		log.warn("menu: %s has no parent, rows not added", source_path)
		return
	end

	-- A row reads its key once, when built. The page can build before the PlayerController acquire registers the mod's context, so it is registered here too.
	keymap.register()

	-- The section is built in one pass, so a page that has its header already has its rows.
	if find_child(container, function(c) return class_name(c) == HEADER_CLASS and header_title(c) == SECTION_TITLE end) then return end

	local section = create_section(container, source)
	if not section then return end

	-- PanelWidget has no insert-at-index UFunction. Detach every child, add the section, re-add the rest.
	local rest = {}
	while container:GetChildrenCount() > 0 do
		local child = container:GetChildAt(0)
		table.insert(rest, { widget = child, layout = slot_layout(child.Slot) })
		container:RemoveChildAt(0)
	end
	for _, s in ipairs(section) do
		add_child(container, s.widget, s.layout)
		if s.header then s.widget:SetText(FText(SECTION_TITLE)) end
		-- On_WidgetConstructed applies the label and switches to the keybinding view, but leaves the row at opacity 0, the start of a fade-in the page plays only for its own rows.
		-- Toggle_Widget shows it.
		if s.row then
			s.widget:On_WidgetConstructed()
			s.widget:Toggle_Widget(false, 0.0)
		end
	end
	for _, r in ipairs(rest) do add_child(container, r.widget, r.layout) end
	log.info("menu: added section '%s' with %d row(s)", SECTION_TITLE, #section - 2)
end

local function on_row_constructed(context)
	local source = context:get()
	if mapped_name(source) ~= SOURCE_MAPPING then return end

	-- The hook fires while the page may still be building its rows, so the list is changed on the next timer tick.
	-- The row is passed by path. It is looked up again rather than held.
	local path = util.path(source)
	ExecuteInGameThreadWithDelay(1, hooks.guard(function() add_section(path) end))
end

--- Hook the vanilla row class once it is loaded.
function M.install()
	hooks.install(HOOK_FN, ROW_CLASS, on_row_constructed)
end

return M
