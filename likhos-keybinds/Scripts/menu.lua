-- menu.lua : adds the mod's keybinding rows to the game's keyboard controls page.
--
-- Each row is a clone of a vanilla row (WB_SingleSettingBar_C), pointed at a mapping from keymap.lua.
-- The vanilla row logic then shows, rebinds, saves and resets the key.
-- See docs/solutions/point-aim-keybind-menu.md and docs/solutions/findings.md (Controls menu) for the recon behind every name here.

local log    = require("log")
local util   = require("util")
local keymap = require("keymap")

local M = {}

local ROW_CLASS = "/Game/Blueprints/UICore/Widgets/Settings/WB_SingleSettingBar.WB_SingleSettingBar_C"
local HOOK_FN   = ROW_CLASS .. ":On_WidgetConstructed"

-- Struct_SettingBar.LabelSettings.Text and Struct_InputKeyInfo fields. User-defined struct members carry GUID suffixes.
local LABEL_SETTINGS = "LabelSettings_17_C0FB3CF442EE50582D14F7910343E95C"
local LABEL_TEXT     = "Text_3_4CDF99D140A67A062FBAA99D135648EC"
local KEY_ACTION     = "InputAction_41_F0CC631D427AFF1C0FB2849BA41B6025"
local KEY_MAPPED     = "PlayerMappedName_60_D667E47C4761808F2AAD738F1F328FEA"

-- Vanilla row name -> mod mapping placed directly under it.
local ROWS = {
    PointShooting = "LikhosPointShootingDirect",
}

local hooked = false

local function mapped_name(row)
    local ok, name = pcall(function() return row.Keybindings[1][KEY_MAPPED]:ToString() end)
    return ok and name or nil
end

local function has_row(container, mapping)
    for i = 0, container:GetChildrenCount() - 1 do
        if mapped_name(container:GetChildAt(i)) == mapping then return true end
    end
    return false
end

-- AddChild creates a fresh slot, so a moved row's layout is carried over by value.
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

-- PanelWidget has no insert-at-index UFunction. Detach everything below the anchor, add the row, re-add the rest.
local function insert_after(container, anchor, widget)
    local index = container:GetChildIndex(anchor)
    local tail = {}
    while container:GetChildrenCount() > index + 1 do
        local child = container:GetChildAt(index + 1)
        table.insert(tail, { widget = child, layout = slot_layout(child.Slot) })
        container:RemoveChildAt(index + 1)
    end
    add_child(container, widget, slot_layout(anchor.Slot))
    for _, t in ipairs(tail) do add_child(container, t.widget, t.layout) end
end

local function add_row(anchor_path, mapping)
    local anchor = StaticFindObject(anchor_path)
    if not util.valid(anchor) then
        log.warn("menu: %s is gone, row not added", anchor_path)
        return
    end
    local container = anchor:GetParent()
    if not util.valid(container) then
        log.warn("menu: %s has no parent, row not added", anchor_path)
        return
    end
    if has_row(container, mapping) then return end

    local ia = keymap.action(mapping)
    if not ia then
        log.warn("menu: mapping %s isn't registered yet, row not added", mapping)
        return
    end

    -- The row's outer is the page's WidgetTree. The page is the world context for the new widget.
    local page = anchor:GetOuter():GetOuter()
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local row = lib:Create(page, anchor:GetClass(), anchor:GetOwningPlayer())
    if not util.valid(row) then
        log.warn("menu: could not create a row for %s", mapping)
        return
    end

    -- Assignment copies struct and array values, so the vanilla row is left unchanged.
    row.BarType = anchor.BarType
    row.SettingBar = anchor.SettingBar
    row.SettingBar[LABEL_SETTINGS][LABEL_TEXT] = FText(keymap.MAPPINGS[mapping].display)
    row.Keybindings = anchor.Keybindings
    row.Keybindings[1][KEY_ACTION] = ia
    row.Keybindings[1][KEY_MAPPED] = FName(mapping)

    insert_after(container, anchor, row)

    -- On_WidgetConstructed applies the label and switches to the keybinding view, but leaves the row at opacity 0, the start of a fade-in the page plays only for its own rows.
    -- Toggle_Widget shows it.
    row:On_WidgetConstructed()
    row:Toggle_Widget(false, 0.0)
    log.info("menu: added %s row to %s", mapping, page:GetFullName())
end

local function on_row_constructed(context)
    local anchor = context:get()
    local mapping = ROWS[anchor:GetFName():ToString()]
    if not mapping then return end

    -- The hook fires while the page may still be building its rows, so the list is changed on the next timer tick.
    -- The row is passed by path. It is looked up again rather than held.
    local path = anchor:GetFullName():match("^%S+ (.+)$")
    ExecuteInGameThreadWithDelay(1, function()
        util.safe("menu add_row", add_row, path, mapping)
    end)
end

local function hook()
    hooked = true
    RegisterHook(HOOK_FN, function(context)
        util.safe("menu hook", on_row_constructed, context)
    end)
    log.info("menu: hooked %s", HOOK_FN)
end

--- Hook the vanilla row class once it is loaded. RegisterHook needs the function in memory.
function M.install()
    if hooked then return end
    if util.valid(StaticFindObject(HOOK_FN)) then
        hook()
        return
    end
    NotifyOnNewObject(ROW_CLASS, function()
        if not hooked then util.safe("menu install", hook) end
        return true
    end)
end

return M
