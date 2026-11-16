# Weapon condition display

## Intent

A weapon's inventory tile shows its condition as a percentage, e.g. `95%`, with no maximum text, the way a USB hacking device shows its remaining uses (`docs/solutions/usb-uses-display.md`). Vanilla shows `95.3` and `/ 100.0`. Each repair lowers the weapon's maximum condition, and the percentage reflects that: a repaired weapon at its lowered maximum of `95.0` shows `95%`, not `100%`. The same applies to every other item whose condition is the weapon condition stat: today the M1050 LRF binoculars and the TactiNav X-7 GCPS.

The tile of a weapon in an equipment slot, which shows condition as a vertical bar, stays vanilla.

## Constraints and assumptions

Constraints:

- Game names come from a UE4SS dump or Live View and are recorded in this doc (project rule).
- UObject access happens on the game thread only, no UObject is held between calls and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- Items are picked by stat config class, as for use counts. Ruled out: a check on the definition's `Items/Weapons/` path, which would leave the binoculars and GCPS with decimals.
- Armor is out of scope. Its condition is a different stat, `U_Armor_C`.
- `U_Durability_C` and `U_Battery_C` both start at a maximum of 100 (stated by the user). A repair lowers a weapon's maximum. The USB devices have no repair, so theirs stays 100.
- The percentage is the drawn value itself, rounded, for both stats. Ruled out: the ratio of the value to the drawn maximum, which shows `100%` on a repaired weapon whose maximum has dropped, and which for the USB devices gives the same number as the value.
- The feature shares the `whole_uses` switch in `config.lua`. Ruled out: a separate switch, since the rewrite rides the same hook and flush.

Names from `UE4SS_ObjectDump.txt` (2026-11-11):

- `/Game/Blueprints/InventorySystem/Objects/Stats/U_Durability.U_Durability_C` is the condition stat config. Owners in the dump: every loaded `Items/Weapons/` definition (rifles, DMRs, SMGs, pistols, shotguns, LMGs, sniper rifles), `Items/Gadgets/Binoculars/M1050_LRF_Binoculars/ID_M1050_LRF_Binoculars` and `Items/Gadgets/GCPS/TactiNav_Communicator_X-7/ID_TactiNav_Communicator_X-7`. Melee items own none. Gear owns `U_Armor_C` and `U_ProtectionLevel_C` instead. The dump lists only what was loaded when it was taken.
- `/Script/Test_C.ItemWidget:bEquipped` is a bool on the tile, set from `InitItem`'s `bIsEquipped`. It is set on a weapon tile in an equipment slot and not on one in the inventory, a container or a stash (observed in game).
- A weapon tile in the inventory draws its condition in `ItemCapacity` and `ItemMaxCapacity`, each holding one number (`95.3` and `/ 100.0`), and `K2_UpdateItemCount` fires for it (observed in game).
- `/Script/Test_C.ItemWidget` also holds `WeaponDurabilityContainer` and `WeaponDurabilityProgressBar`, the vertical bar, driven by the Blueprint event `K2_UpdateWeaponDurabilityBar(NewDurability)`. This solution does not touch them.

Assumptions the build checks:

- The binoculars' and GCPS's tiles draw their condition the same way as a weapon's.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/items/tile_counts.lua`: picking the tile format and rewriting the tile.
- `likhos-point-and-shoot/Scripts/main.lua`: installing `tile_counts.lua` under the `whole_uses` switch.
- `likhos-point-and-shoot/Scripts/config.lua`: the `whole_uses` switch's comment.
- `likhos-point-and-shoot/README.md` and `CHANGELOG.md`: the user-facing description.

Context only: `items/item_tile.lua` (the tile class name), `items/inventory.lua` (`config_stat`), `lib/hook.lua`, `lib/util.lua`, the vanilla `ItemWidget` and `W_InventoryItem_C`.

## Solution

### `tile_counts.lua`

Owns every rewrite of the count text on an inventory tile: whole use counts, the single use `~` and the percentages. It is the module `docs/solutions/medic-uses-display.md` and `docs/solutions/usb-uses-display.md` call `whole_uses.lua`. The config key keeps the name `whole_uses`, so a user's edited `config.lua` still works.

Maps a tile's item to a format by the stat configs on its definition: `U_Content_C` to whole numbers, `U_Battery_C` and `U_Durability_C` to percent. A `U_Durability_C` item on a tile with `bEquipped` set gets no format, so its tile stays as the game drew it.

The percent format works on the number the game drew in `ItemCapacity`, one tick after the native write. It sets `ItemCapacity` to that number, rounded, followed by `%`, and empties `ItemMaxCapacity`. A repeat rewrite reads the number it wrote and writes it again.

The hook, the batching of tiles per frame and the failure handling are shared with the use counts unchanged.

### `config.lua`, README and CHANGELOG

The `whole_uses` comment says weapons and other items with condition show it as a percentage in the inventory. The README's item use counts line covers condition too. `CHANGELOG.md` has an entry under `# Unreleased`.

### Result

An AK-74M in a backpack or stash shows `95%` where vanilla shows `95.3 / 100.0`, and a repaired one at `95.0 / 95.0` also shows `95%`. The same rifle in the primary weapon slot shows the vanilla vertical bar. The binoculars and GCPS show a percentage in the inventory. A USB device with 75 of its 100 uses left shows `75%`. Armor and use counts are unchanged. With `whole_uses = false` every tile is vanilla.

## Tradeoffs

- Filtering by `U_Durability_C` over the item's path or tags: any durable item a patch adds is covered. The cost is that a future item using that stat for something that should keep decimals would get a percentage too.
- The drawn value over a ratio to the item's maximum: repair wear stays visible, one format serves weapons and USB devices, and no factory maximum is looked up. The cost is that an item a patch adds with either stat and a maximum other than 100 shows a number that is not a percentage.
- Rounding to whole percent: `99.6` shows `100%`. The cost is that a nearly pristine weapon reads as full.
- Rewriting drawn text one tick after the native write, as for use counts: the tile can show `95.3 / 100.0` for one frame.
