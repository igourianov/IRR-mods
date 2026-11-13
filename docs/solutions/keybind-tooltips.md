# Keybind row descriptions in the controls info panel

## Intent

Hovering one of Point and Shoot's keybinding rows in the "Likho's Actions" section of Settings > Controls shows a description of the bind in the game's own setting info panel, the way vanilla settings show theirs. The rows keep working as `docs/solutions/keybind-section.md` and `docs/solutions/point-aim-keybind-menu.md` describe.

## Constraints and assumptions

- Game class, function and property names come from the Recon below (project rule).
- The panel is the page's own `WB_SettingInfo`, fed from the row's `SettingDescriptor`. No custom tooltip widget.
- Plain text only. `DescriptionRichText` goes to a `URichTextBlock`, and the game's rich text style tags are not recorded.
- Ruled out: descriptions on vanilla rows the mod changes the behavior of (Hold Breath). Only the mod's own rows get one.
- The page binds each vanilla row's `OnHovered` to its `OnSettingBarHovered` when it builds, before the mod rows exist, so a mod row's hover never reaches the page on its own (Recon).
- The keybinds page's `OnSettingBarHovered` shows `WB_SettingInfo` for a row whose descriptor is visible, as the gameplay page does, though no vanilla keybinding row has one (user observed in game, 2026-11-13).
- The mod rows are built once per game session and survive a Ctrl+R reload, so testing a change to them needs a game restart.
- UE4SS exposes a multicast delegate property as a wrapper with `Add(object, functionName)`, `Remove`, `Clear` and `GetBindings()` (`ue4ss\Docs\lua-api\classes\multicastdelegateproperty.md`).
- Ruled out: hooking the row's `OnMouseEnter` and `OnMouseLeave` to call the page by hand. The vanilla delegate wiring does the same without a per-hover hook on every settings row.
- Assumption, unverified: a mod row broadcasts `OnHovered` on hover and unhover as a vanilla row does, once something is bound to it.

## Scope

Owned: `likhos-point-and-shoot/Scripts/keymap.lua` (`MAPPINGS`), `likhos-point-and-shoot/Scripts/menu.lua` (`create_row`), `likhos-point-and-shoot/CHANGELOG.md`, the minor version in `likhos-point-and-shoot/mod.txt`, the Recon section of this doc.

Context only: the section building and row cloning in `menu.lua`, `docs/solutions/keybind-section.md`.

## Solution

- `keymap.MAPPINGS` holds a `description` next to each mapping's `display`. It is the single source of every row's text.
- `menu.lua` gives each cloned row a `SettingDescriptor` built from the source row's descriptor, with the mapping's description as `DescriptionRichText` and the descriptor visible. The headline is the row's display name.
- `menu.lua` gives each cloned row the source row's `OnHovered` bindings, which bind it to the keybinds page's `OnSettingBarHovered` as the page binds its own rows.
- The page's hover handling does the rest: hovering a mod row shows its description in the `WB_SettingInfo` panel, leaving it hides the panel as for a vanilla row.

Descriptions:

| Row | Description |
|---|---|
| Point Shooting + Laser (Hold) | Hold to go straight into the point shooting pose without aiming first. Turns on the first laser on the gun: a visible laser with NVG off, an IR laser with NVG on when the gun has one. |
| Flashlight (Hold/Toggle) | Tap to keep the weapon light on until the next press. Hold to light it only while held. Picks the light by the same NVG rule as the laser. |
| Interact (Instant) | Interact without the hold delay. A tap opens a container at once. A locked container still takes its unlock time but needs no holding. The vanilla Interact key is unaffected. |
| Smart Heal (Tap/Hold) | Uses the fastest item for the job from anywhere in the inventory, one item per press. Tap: take a painkiller, even over an active dose. Hold: treat the first of heavy bleed, bleed, fracture or missing health, the last with the IV that best covers it. |
| Use Adrenaline | Inject an Adrenaline Injector from anywhere in the inventory. Pressing during an active boost restarts it. |
| Consume Food/Drink | Eat or drink the first food or drink item in the inventory, like Quick Heal does for medical items. Medical items are never used. |

## Tradeoffs

- Reusing the vanilla panel keeps the look consistent and costs no widget work, but ties the feature to `SettingDescriptor` and the page's hover flow, which a game patch can rename.
- Plain text over rich text: no emphasis in the descriptions, in exchange for not guessing style tag names.

## Recon

### Setting info panel

From `CXXHeaderDump` of 2026-11-12 (`ue4ss\_old_dumps\2026-11-12`).

- `UIRRBaseSettingBarWidget` (`IRRCoreUI.hpp`), parent of `WB_SingleSettingBar_C`: `SettingDescriptor` (`FIRRSettingDescriptor`), `OnHovered` multicast delegate `(bool bHovered, UIRRBaseSettingBarWidget* SettingBarWidgetRef)`, `SettingId` (FName), `SettingDefinition` (`FIRRSettingDefinition`).
- `FIRRSettingDescriptor`: `OverrideTitle` (FText), `DescriptionRichText` (FText), `WarningRichText` (FText), `Extension` (`TSubclassOf<UIRRUserWidget>`), `bVisible` (bool).
- `WB_KeybindsSettings_C`: `WB_SettingInfo` (`WB_SettingInfo_C`), `OnSettingBarHovered(bool bHovered, UIRRBaseSettingBarWidget* BarWidget)`, `GetSettingBarWidgets()`.
- `WB_SettingInfo_C`: `HeadlineText` (`UIRRTextBlock`), `DescriptionRichText` (`URichTextBlock`), `Info` (`FIRRSettingDescriptor`), `Setting Ref` (`WB_SingleSettingBar_C`), `Update_Content(UIRRBaseSettingBarWidget* SettingRef)`, `Set_Content()`, `Hide_Info_Box()`.
- `WB_SingleSettingBar_C` also has `DescriptionText` (FText), `OnMouseEnter`, `OnMouseLeave`.
- Function paths from `UE4SS_ObjectDump.txt` of 2026-11-11: `/Game/Blueprints/UICore/Widgets/Settings/WB_SingleSettingBar.WB_SingleSettingBar_C:OnMouseEnter`, `/Game/Blueprints/UICore/Widgets/Settings/WB_KeybindsSettings.WB_KeybindsSettings_C:OnSettingBarHovered`, `/Game/Blueprints/UICore/Widgets/Settings/WB_SettingInfo.WB_SettingInfo_C:Update_Content`.

### Hover flow

From a throwaway probe hooking the three functions above, 2026-11-13, game build 26610539.

- Keybinds page: hovering a vanilla row calls `OnSettingBarHovered(true, row)` then the row's `OnMouseEnter`, and `OnSettingBarHovered(false, row)` on leave. Every vanilla keybinding row has `SettingDescriptor.bVisible` false and an empty description, and `Update_Content` is never called.
- Keybinds page: hovering a mod row calls only its `OnMouseEnter`. `OnSettingBarHovered` is not called.
- Gameplay page: `Update_Content(row)` runs on hover only for rows with `bVisible` true and a description, e.g. `PlayerOutfit` ("Change your third person character model"). Rows with `bVisible` false (`ToggleLean`, `ToggleAim`) get no `Update_Content`.
