# Mod keybinds in their own controls section

## Intent

Move the mod's keybinding rows (Point Shooting (Direct), Flashlight (Hold/Toggle), Interact (Instant)) out of the vanilla sections into a section of their own, "Likho's Actions", at the top of the keyboard controls page. The section looks like a vanilla one: a section header, the rows, then a spacer before the vanilla Equipment Input section. The rows keep working as `docs/solutions/point-aim-keybind-menu.md` describes.

## Constraints and assumptions

- Game class, function and property names come from the Recon below (project rule).
- The header and spacer are clones of the page's own, so the section looks like the vanilla ones without a pak or asset override.
- `PanelWidget` has no insert-at-index function, so every vanilla child is detached and re-added below the section with its slot layout.
- Vanilla section headers are not clickable (user observed in game, 2026-11-09), so the header's `OnFoldPressed` and `Folded` are left alone.

## Scope

Owned: `likhos-point-and-shoot/Scripts/menu.lua`, `likhos-point-and-shoot/README.md`, the Recon section of this doc.

Context only: `keymap.lua` (mappings and display names, unchanged).

## Solution

`menu.lua` hooks `WB_SingleSettingBar_C:On_WidgetConstructed` as before. When the page's `IA_PointShooting` row is built, one timer tick later it:

- registers the mod's context (`keymap.register`), as before,
- skips the page if `SettingsContainer` already has a `W_InventorySection_C` titled "Likho's Actions". The section is built in one pass,
- creates a `W_InventorySection_C` for the page with `SectionName` set, the mod rows in a fixed order cloned from `PointShooting` as before, and a `Spacer` sized like the page's first spacer. All are created before the page is touched, so a failure leaves it unchanged,
- detaches every child of `SettingsContainer`, adds the header (then calls `SetText` with the title), the rows (then `On_WidgetConstructed` and `Toggle_Widget(false, 0)`) and the spacer, then re-adds the vanilla children. Slot layouts are copied from the first vanilla header, `PointShooting` and the first vanilla spacer.

## Recon

### Keyboard controls page layout

From `kb_probe_sections` (throwaway `probe.lua`) on 2026-11-09, game build 26487830, with Settings > Controls open.

- The page is now `WB_KeybindsSettings_C` (`/Game/Blueprints/UICore/Widgets/Settings/`), owned by `UMS_GameInstance_C`. `docs/solutions/point-aim-keybind-menu.md` recorded `WB_KeyboardSoldierBindings_C`. The rows are still `WB_SingleSettingBar_C` in `WidgetTree.SettingsContainer`, a `VerticalBox`, inside `W_IRR_ScrollBox_C_1`. 57 children with the old mod rows inserted.
- Each section is a `Spacer`, then a `W_InventorySection_C` header, then its `WB_SingleSettingBar_C` rows (`BarType = 4`). The first section has no spacer before it. Sections in order: Equipment Input (`W_InventorySection`), Combat Input (`_2`), Gameplay Input (`_1`), Movement Input (`_3`), Misc Input (`_4`). Spacers: `Spacer_80`, `Spacer`, `Spacer_1`, `Spacer_2`. The last child is the Chat row (`WB_Chat`, `IA_Chat`).
- The header's caption is the TextBlock `SectionNameText`.
- One hidden row: `WB_SingleSettingBar_7`, "Attachment Wheel", `IA_ToggleAttachmentMenu`, `IsVisible()` false. A visible "Toggle Attachment Menu" row has the same mapped name.

### Section header class

From the UE4SS object dump of 2026-11-08.

- `/Game/Blueprints/InventorySystem/Widgets/W_InventorySection.W_InventorySection_C` members: `W_IRR_Line`, `SectionNameText` (ObjectProperty), `SectionName` (NameProperty), `OnFoldPressed` (multicast delegate), `Folded` (bool), `PreConstruct(IsDesignTime)`, `SetText(InText: Text)`.
- `/Script/UMG.Spacer` has `Size` (StructProperty) and `SetSize`.
- UE4SS `StaticConstructObject(Class, Outer, Name?)` takes an optional name (`ue4ss/Docs/lua-api.md`).
