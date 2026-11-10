# Gunsmith build search

## Intent

The weapon balance work in `ak-rpm-recoil-balance.md` through `stock-scale-outliers.md` used a scratchpad script that grouped every reachable attachment by category and picked the best per category. The user asked for a reusable tool. The category grouping missed stacked parts (a chassis with its own stock slot), skipped required parts that cost ergonomics (buffer tubes) and combined parts that never fit together (a 14" MPX barrel with a flash hider from a shorter barrel). The tool walks the real slots instead.

## Constraints

- Game data comes from the game's own paks, never from a deployed mod pak.
- A pak mod's edit lists apply on top, the way `tools/pak/pak.ps1` stages them, so the numbers match what the built pak gives.
- Named `gunsmith`, not `builds`, so it doesn't read as part of `build.ps1`.

## Recon

From UAssetGUI JSON of the cooked assets, game build 26487830, read with the usmap:

- An item definition is the export named like the package, class `IRRItemDefinition`. `ItemIdentifier.TagName` is its tag. `ItemStats` entries hold `StatItemConfig` (an export whose class is `U_<Stat>_C`, e.g. `U_Recoil_C`, `U_Ergonomics_C`, `U_RoundsPerMinute_C`) and `Value`.
- `ItemContainers` lists the item's slots, as references to container exports (class `U_<Slot>_C`, e.g. `U_Barrel_C`, `U_Handguard_AK_C`, `U_RailMount_AK_C`).
- A container's `SupportedItems` lists references to supported-items objects:
  - an `InventorySupportedItems` export whose own `SupportedItems` property is a tag container,
  - or a `UISI_<List>_C` instance, whose tags are on its class's default object `Default__UISI_<List>_C` (`SupportedItems.SupportedItems`).
  - An `InventorySupportedItems` export with no data, and a container with no `SupportedItems`, keep the container class's default: `Default__U_<Slot>_C.SupportedItems` in `Objects/ItemContainers`, then its parent class's.
- `ItemRelations.ConflictingItemsQuery` tags (e.g. on `ID_AK_Zenitco_B-13_Rail`) name items that can't be fitted together with the item. They are not supported items.
- Fire modes are the `Weapon.FireMode.Auto`, `.Semi` and `.Burst` tags in the definition's name map (`U_FireModes_C`).
- The slot data lets a Magpul M-LOK rail on every M-LOK side position of a handguard take a foregrip (`ID_Magpul_M-LOK_4x1_Inch_Rail` slot `U_TacticalDevices_EverySize_C` lists `UISI_Foregrip_All_C`). Whether the game allows several foregrips at once is unchecked in game.

## Solution

`tools/gunsmith/gunsmith.ps1` with `gunsmith.json`:

- Extracts every `ID_*` under `Items/Weapons` and `Items/Attachments`, `UISI_*` under `Objects/InventorySupportedItems` and `U_*` under `Objects/ItemContainers` (677 assets), converts them in parallel like `pak.ps1` and keeps only a compact index in `tools/gunsmith/cache/index.json`. A stamp of the game paks and the usmap decides when to rebuild.
- Applies `clone.json` (a renamed copy of a class, with its tags renamed), `retarget.json` (slot classes renamed), `stats.json` (`Recoil`, `Ergonomics`) and `reclass.json` (weapon class) unless `-Vanilla`.
- Search: each slot holds at most one item it accepts. `Find-Best` combines slots one at a time over states of how much of the suppressor need (exactly one in a suppressed build, none in a loud one) and of the one-per-category allowance each slot took. Lower score wins: the ranked stat × 1000, the other stat breaking ties.
- `gunsmith.json`: `skip` categories (Sight, Tactical, Mag), `required` categories (Barrel), `unique` categories capped at one per build (empty by default, `-Unique` overrides), `ignore` for game bugs (the KAC QDC eliminator taking a second flash hider).
- `-Trace` prints slot paths to matching parts.

Docs: `CLAUDE.md` (layout, commands), `.gitignore` (cache).

## Tradeoffs and open

- Conflicts are only flagged (`!`), not avoided. Avoiding them would need the search to track every chosen tag.
- A required category is a guess per category, not read from the game. Only Barrel is listed.
- Suppressor detection is by name (`Suppressor`, `Silencer`) in the Muzzle folder.
- Against the scratchpad script, the AKs come out about 3 worse (the WASR handguard can't hold a grip), the MPX 3 worse (its flash hider doesn't fit the 14" barrel), and the M14 and M305 much better (Troy SASS chassis stacking).
