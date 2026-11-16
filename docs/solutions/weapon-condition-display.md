# Weapon condition display

## Intent

A weapon's inventory tile shows its condition as a percentage of the maximum, e.g. `95%`, with no maximum text, the way a USB hacking device shows its remaining uses (`docs/solutions/usb-uses-display.md`). Vanilla shows `95.3` and `/ 100.0`. The same applies to every other item whose condition is the weapon condition stat: today the M1050 LRF binoculars and the TactiNav X-7 GCPS.

The tile of a weapon in an equipment slot, which shows condition as a vertical bar, stays vanilla.

## Constraints and assumptions

Constraints:

- Game names come from a UE4SS dump or Live View and are recorded in this doc (project rule).
- UObject access happens on the game thread only, no UObject is held between calls and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- Items are picked by stat config class, as for use counts. Ruled out: a check on the definition's `Items/Weapons/` path, which would leave the binoculars and GCPS with decimals.
- Armor is out of scope. Its condition is a different stat, `U_Armor_C`.
- The feature shares the `whole_uses` switch in `config.lua`. Ruled out: a separate switch, since the rewrite rides the same hook and flush.

Names from `UE4SS_ObjectDump.txt` (2026-11-11):

- `/Game/Blueprints/InventorySystem/Objects/Stats/U_Durability.U_Durability_C` is the condition stat config. Owners in the dump: every loaded `Items/Weapons/` definition (rifles, DMRs, SMGs, pistols, shotguns, LMGs, sniper rifles), `Items/Gadgets/Binoculars/M1050_LRF_Binoculars/ID_M1050_LRF_Binoculars` and `Items/Gadgets/GCPS/TactiNav_Communicator_X-7/ID_TactiNav_Communicator_X-7`. Melee items own none. Gear owns `U_Armor_C` and `U_ProtectionLevel_C` instead. The dump lists only what was loaded when it was taken.
- `/Script/Test_C.ItemWidget:bEquipped` is a bool on the tile, set from `InitItem`'s `bIsEquipped`.
- `/Script/Test_C.ItemWidget` also holds `WeaponDurabilityContainer` and `WeaponDurabilityProgressBar`, the vertical bar, driven by the Blueprint event `K2_UpdateWeaponDurabilityBar(NewDurability)`. This solution does not touch them.

Assumptions the build checks:

- A weapon tile in the inventory draws its condition in `ItemCapacity` and `ItemMaxCapacity`, each holding one number (`95.3` and `/ 100.0`), and `K2_UpdateItemCount` fires for it.
- A weapon tile in an equipment slot has `bEquipped` set. A weapon tile in the inventory, a container or a stash does not.
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

The percent format is the existing one: one tick after the native write it reads the numbers drawn in `ItemCapacity` and `ItemMaxCapacity`, sets `ItemCapacity` to `round(remaining / max * 100)%` and empties `ItemMaxCapacity`. A tile already rewritten has no number in `ItemMaxCapacity`, so a repeat rewrite does nothing. The hook, the batching of tiles per frame and the failure handling are shared with the use counts unchanged.

### `config.lua`, README and CHANGELOG

The `whole_uses` comment says weapons and other items with condition show it as a percentage in the inventory. The README's item use counts line covers condition too. `CHANGELOG.md` has an entry under `# Unreleased`.

### Result

An AK-74M in a backpack or stash shows `95%` where vanilla shows `95.3 / 100.0`. The same rifle in the primary weapon slot shows the vanilla vertical bar. The binoculars and GCPS show a percentage in the inventory. Armor, use counts and USB devices are unchanged. With `whole_uses = false` every tile is vanilla.

## Tradeoffs

- Filtering by `U_Durability_C` over the item's path or tags: any durable item a patch adds is covered. The cost is that a future item using that stat for something that should keep decimals would get a percentage too.
- Rounding to whole percent: `99.6` shows `100%`, matching the USB devices. The cost is that a nearly pristine weapon reads as full.
- Rewriting drawn text one tick after the native write, as for use counts: the tile can show `95.3 / 100.0` for one frame.
