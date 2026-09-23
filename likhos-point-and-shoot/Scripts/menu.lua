-- menu.lua : adds the mod's keybinding rows to the game's keyboard controls page.
--
-- Each row is a clone of a vanilla row (WB_SingleSettingBar_C), pointed at a mapping from keymap.lua.
-- The vanilla row logic then shows, rebinds, saves and resets the key.
-- See docs/solutions/point-aim-keybind-menu.md (Recon) for the recon behind every name here.

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

-- Vanilla row name -> mod mappings placed directly under it, in this order.
local ROWS = {
    PointShooting = { "LikhosPointShootingDirect", "LikhosFlashlight" },
}

local hooked = false

local function mapped_name(row)
    local ok, name = pcall(function() return row.Keybindings[1][KEY_MAPPED]:ToString() end)
    return ok and name or nil
end

local function find_row(container, mapping)
    for i = 0, container:GetChildrenCount() - 1 do
        local row = container:GetChildAt(i)
        if mapped_name(row) == mapping then return row end
    end
    return nil
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

--- Clone the vanilla row `source` into a row for `mapping` and put it directly under `below`. Returns the new row, or nil.
local function add_row(container, source, below, mapping)
    local ia = keymap.action(mapping)
    if not ia then
        log.warn("menu: mapping %s isn't registered yet, row not added", mapping)
        return nil
    end

    -- The vanilla row's outer is the page's WidgetTree. The page is the world context for the new widget.
    local page = source:GetOuter():GetOuter()
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local row = lib:Create(page, source:GetClass(), source:GetOwningPlayer())
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

    insert_after(container, below, row)

    -- On_WidgetConstructed applies the label and switches to the keybinding view, but leaves the row at opacity 0, the start of a fade-in the page plays only for its own rows.
    -- Toggle_Widget shows it.
    row:On_WidgetConstructed()
    row:Toggle_Widget(false, 0.0)
    log.info("menu: added %s row to %s", mapping, page:GetFullName())
    return row
end

local function add_rows(anchor_path, mappings)
    local anchor = StaticFindObject(anchor_path)
    if not util.valid(anchor) then
        log.warn("menu: %s is gone, rows not added", anchor_path)
        return
    end
    local container = anchor:GetParent()
    if not util.valid(container) then
        log.warn("menu: %s has no parent, rows not added", anchor_path)
        return
    end

    -- Every row is cloned from the vanilla one, but each lands under the row before it so the mod rows keep their declared order.
    local below = anchor
    for _, mapping in ipairs(mappings) do
        below = find_row(container, mapping) or add_row(container, anchor, below, mapping) or below
    end
end

local function on_row_constructed(context)
    local anchor = context:get()
    local mappings = ROWS[anchor:GetFName():ToString()]
    if not mappings then return end

    -- The hook fires while the page may still be building its rows, so the list is changed on the next timer tick.
    -- The row is passed by path. It is looked up again rather than held.
    local path = anchor:GetFullName():match("^%S+ (.+)$")
    ExecuteInGameThreadWithDelay(1, function()
        util.safe("menu add_rows", add_rows, path, mappings)
    end)
end

--- Returns false when RegisterHook refuses the function.
local function hook()
    -- At startup the function can be found while its class is still loading. Its Func pointer is still null then and RegisterHook throws.
    local ok, err = pcall(RegisterHook, HOOK_FN, function(context)
        util.safe("menu hook", on_row_constructed, context)
    end)
    if not ok then
        log.debug("menu: %s not hookable yet: %s", HOOK_FN, tostring(err))
        return false
    end
    hooked = true
    log.info("menu: hooked %s", HOOK_FN)
    return true
end

--- Hook the vanilla row class once it is loaded. RegisterHook needs the function in memory and linked.
function M.install()
    if hooked then return end
    if util.valid(StaticFindObject(HOOK_FN)) and hook() then return end
    NotifyOnNewObject(ROW_CLASS, function()
        if not hooked then hook() end
        return true
    end)
end

return M
