# Medic uses display

## Intent

The use count drawn on a medical item's inventory tile shows whole numbers. Today both the remaining and the maximum uses show decimals, e.g. `3.0` and `4.0` on a painkiller pack. After the change the tile shows `3` and `4`. Other items' tiles stay vanilla.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from the cooked assets or a UE4SS dump and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, no UObject is held across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- Only medical items change: items whose `ItemDefinition.ItemIdentifier` tag is under `Inventory.Items.Medical`. Ruled out: every item whose use counter is a `U_Content_C` stat, which would also cover keys.
- Only the inventory tile changes. Ruled out: the tooltip's stat row (`W_StatPlainTextBox_C`), which the user doesn't see decimals in.
- The feature lives in `likhos-point-and-shoot` as a Lua hook, next to the medic drop. Ruled out: a pak edit of `W_InventoryItem` or `ItemWidget`. The count text is written by native C++ in `ItemWidget`, so no asset holds the formatting, and patching widget bytecode has no build stage.

Names from the cooked assets (game build 22417726, read with UAssetGUI 2026-09-26) and `UE4SS_ObjectDump.txt` (2026-09-22):

- `/Script/Test_C.ItemWidget` is the native inventory tile. It holds `ContainerItem` (`ContainerItem` struct) and the text blocks `ItemCapacity` and `ItemMaxCapacity`, which show the item's count and maximum. No Blueprint in the widget writes to either, so native code sets their text.
- The tile has no number format setting. `WidgetItemAppearance` only toggles `bShowCapacity` and `bShowDurability`, and `InventoryEnhancedUISettings` only picks fonts. Ammo stacks and mags already show whole numbers because their counts are integers. A stack's is its `Count`. A mag (e.g. `ID_VR80_12ga_5rnd`) has no use stat: its count is the rounds held by its `U_Ammunition_C` object, an `InventoryEquipToContainerSettings` container. Medical uses show decimals because they come from the float `Inventory.Stats.Durability` stat.
- `ItemWidget:K2_UpdateItemCount` is a Blueprint event with no parameters. Its native declaration has no body.
- `/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C` is the only Blueprint subclass of `ItemWidget` and implements `K2_UpdateItemCount` (it only refreshes hover state and the mag name).
- `ItemWidget:OnItemChanged(PickUpContainerItem)` is a native function, the tile's handler for its item changing.
- Medical item definitions carry an `ItemIdentifier` gameplay tag under `Inventory.Items.Medical`, e.g. `Inventory.Items.Medical.Painkiller` on `ID_Painkiller`.
- A medical item's use counter is its `Inventory.Stats.Durability` stat (`docs/solutions/medic-drop.md`), read from `ContainerItem.CurrentStats` or `InventoryFunctionLibrary:GetStatValueByTag` / `GetStatMaxValueByTag`.

Assumptions the build checks:

- The decimals the user sees are the text of `ItemCapacity` and `ItemMaxCapacity` on a `W_InventoryItem_C` tile. Debug output of both texts on a painkiller tile confirms or refutes this.
- `ItemWidget` calls `K2_UpdateItemCount` after it writes both texts, on the tile's creation and whenever the item's uses change. If it fires before the write, or not on every change, the hook point moves to `OnItemChanged` or a one tick deferral, whichever debug output shows lands after the native write.
- Setting a text block's text from Lua with an `FText` built from a string sticks until the game next writes it.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/medic_uses.lua`: the feature.
- `likhos-point-and-shoot/Scripts/main.lua`: installing the feature.
- `likhos-point-and-shoot/Scripts/config.lua`: the feature switch.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description and the version it ships in.

Context only: `hook.lua` (hook install, guards and deferral until the Blueprint class loads), `medic.lua`, `util.lua`, `log.lua`, the vanilla `ItemWidget` and `W_InventoryItem_C`.

## Solution

### `medic_uses.lua`

Owns every game name to do with the tile's use count. Holds no UObject between calls.

- `install()` hooks `W_InventoryItem_C:K2_UpdateItemCount` through `hook.lua`, which waits for the Blueprint class to load and logs a refusal once without failing the mod.
- After the event runs, the hook looks at the tile's item. When its identifier tag is under `Inventory.Items.Medical`, it rewrites `ItemCapacity` and `ItemMaxCapacity` to the same values as whole numbers, rounded to nearest. Any other item's tile is left as the game drew it.
- A failure logs once per session and leaves the tiles vanilla.

### `main.lua` and `config.lua`

`config.lua` has a top-level `medic_whole_uses` switch, default true, documented as "a medical item's inventory tile shows its uses as whole numbers". `main.lua` installs `medic_uses.lua` when the mod is enabled and the switch is on, next to `medic.install`. The feature keeps no per-level state, so it has no reset.

### README, CHANGELOG and `mod.txt`

The README has a section describing the whole number count and the switch. `CHANGELOG.md` has an entry for the version that ships it, and `mod.txt`'s description names the feature.

### Result

A painkiller pack's tile shows `4` and `4` when new and `3` and `4` after one use. Bandages, injectors and revive syringes show `1` and `1`. The tooltip, ammo stacks, keys and every other tile are unchanged. With `medic_whole_uses = false` the tiles show the vanilla decimals.

## Tradeoffs

- A Lua hook over a pak edit: the formatting is native, so there's no asset to edit. The cost is rewriting text the game has already drawn, which depends on the Blueprint event running after the native write.
- Filtering by the `Inventory.Items.Medical` tag over an item list: a medical item added by a patch is covered without a list entry. The cost is that a patch moving medical items to another tag branch turns the feature off silently.
- Medical items only over every `U_Content_C` counter: keys keep their decimals, as requested.
- A config switch over always on, following `medic_drop`.
