# Uses display

## Intent

The use count drawn on an item's inventory tile shows whole numbers, for every item that counts uses: medical items, keys and the quest poison today. In vanilla both the remaining and the maximum uses show decimals, e.g. `3.0` and `/ 4.0` on a painkiller pack. With the mod the tile shows `3` and `/ 4`. Other items' tiles stay vanilla.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from the cooked assets or a UE4SS dump and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, no UObject is held across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- Only items that count uses change: items whose definition has a use count stat, a `U_Content_C` stat config. Ruled out: a list of item tag branches, which a new kind of consumable would miss, and the `Inventory.Stats.Durability` tag, which a use count shares with weapon and armor durability.
- Only the inventory tile changes. Ruled out: the tooltip's stat row (`W_StatPlainTextBox_C`), which the user doesn't see decimals in.
- The feature lives in `likhos-point-and-shoot` as a Lua hook. Ruled out: a pak edit of `W_InventoryItem` or `ItemWidget`. The count text is written by native C++ in `ItemWidget`, so no asset holds the formatting, and patching widget bytecode has no build stage.

Names from the cooked assets (game build 22417726, read with UAssetGUI 2026-09-26) and `UE4SS_ObjectDump.txt` (2026-09-22):

- `/Script/Test_C.ItemWidget` is the native inventory tile. It holds `ContainerItem` (`ContainerItem` struct) and the text blocks `ItemCapacity` and `ItemMaxCapacity`, which show the item's count and maximum. No Blueprint in the widget writes to either, so native code sets their text.
- The tile has no number format setting. `WidgetItemAppearance` only toggles `bShowCapacity` and `bShowDurability`, and `InventoryEnhancedUISettings` only picks fonts. Ammo stacks and mags already show whole numbers because their counts are integers. A stack's is its `Count`. A mag (e.g. `ID_VR80_12ga_5rnd`) has no use stat: its count is the rounds held by its `U_Ammunition_C` object, an `InventoryEquipToContainerSettings` container. Use counts show decimals because they come from a float stat.
- `ItemWidget:K2_UpdateItemCount` is a Blueprint event with no parameters. Its native declaration has no body. It fires for every tile when the inventory opens, and the native code writes the count texts after it, so a rewrite inside the event is overwritten. A rewrite one tick later sticks (observed in game 2026-09-26).
- `/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C` is the only Blueprint subclass of `ItemWidget` and implements `K2_UpdateItemCount` (it only refreshes hover state and the mag name).
- The decimals are the text of `ItemCapacity` (`1.0`) and `ItemMaxCapacity` (`/ 4.0`) on a `W_InventoryItem_C` tile (observed in game).
- `/Script/Test_C.IRRItemDefinition:ItemStats` is the item definition's stat list, an array of `/Script/Test_C.BaseStatItem` structs. Each holds `Value` and `StatItemConfig`, the stat's config object, whose class tells the stats apart.
- `/Game/Blueprints/InventorySystem/Objects/Stats/U_Content.U_Content_C` is the use count stat config, tagged `Inventory.Stats.Durability` and shown by `W_StatPlainTextBox_C` in the tooltip (`docs/solutions/medic-drop.md`). Weapon and armor durability is a different class, `U_Durability_C`.
- Items with a `U_Content_C` stat in the object dump: the bandage, health injector, painkiller and revive syringe under `Items/Medical/`, all 14 keys under `Items/Keys/` and `Items/Quest/Poison`. The dump lists only what was loaded when it was taken.

Assumptions the build checks:

- `K2_UpdateItemCount` also fires when a use changes an item's count, not only when the inventory opens.
- A key or quest poison tile draws its uses in `ItemCapacity` and `ItemMaxCapacity` in the same format as a medical tile.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/whole_uses.lua`: the feature.
- `likhos-point-and-shoot/Scripts/main.lua`: installing the feature.
- `likhos-point-and-shoot/Scripts/config.lua`: the feature switch.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description and the version it ships in.

Context only: `hook.lua` (hook install, guards and deferral until the Blueprint class loads), `util.lua`, `log.lua`, the vanilla `ItemWidget` and `W_InventoryItem_C`.

## Solution

### `whole_uses.lua`

Owns every game name to do with the tile's use count. Holds no UObject between calls.

- `install()` hooks `W_InventoryItem_C:K2_UpdateItemCount` through `hook.lua`, which waits for the Blueprint class to load and logs a refusal once without failing the mod.
- On the event, the hook looks at the tile's item. When the item's definition has a `U_Content_C` stat, it rewrites `ItemCapacity` and `ItemMaxCapacity` one tick later, after the native write, to the same values as whole numbers, rounded to nearest. The tile is found again by full name at that point, not held. Any other item's tile is left as the game drew it.
- A failure logs once per session and leaves the tiles vanilla.

### `main.lua` and `config.lua`

`config.lua` has a top-level `whole_uses` switch, default true, documented as "items that count uses, like medical items and keys, show them as whole numbers on inventory tiles". `main.lua` installs `whole_uses.lua` when the mod is enabled and the switch is on. The feature keeps no per-level state, so it has no reset.

### README, CHANGELOG and `mod.txt`

The README has a section describing the whole number use count and the switch. `CHANGELOG.md` has an entry for the version that ships it, and `mod.txt`'s description names the feature.

### Result

A painkiller pack's tile shows `4` and `/ 4` when new and `3` and `/ 4` after one use. Bandages, injectors and revive syringes show `1` and `/ 1`. Keys and the quest poison show their uses the same way. The tooltip, ammo stacks, mags and every other tile are unchanged. With `whole_uses = false` the tiles show the vanilla decimals.

## Tradeoffs

- A Lua hook over a pak edit: the formatting is native, so there's no asset to edit. The cost is rewriting text the game has already drawn, one tick after the native write, so a tile can show the decimals for one frame.
- Filtering by the `U_Content_C` stat over item tags: any item a patch adds with a use count is covered, whatever its kind. The cost is walking the item's stat list on every tile update, and a dependency on the `U_Content_C` class name.
- A config switch over always on, following `medic_drop`.
