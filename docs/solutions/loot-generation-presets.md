# Loot generation presets

## Intent

The 2026-11-04 game update (Steam build 26437642) moved NPC loadout and loot container presets to a new loot generation format, and the Likho's Rearmed build fails on it. Rework the `pak.ps1` loadouts and loot stages so the pak again ships:

* The NPC weapon pools listed in `loadouts.json`, unchanged.
* The in-raid ammo box changes: 2 to 5 stacks per box, 30 to 90 rounds per stack and a tier 1 rarity weight of 0.65.

The README's ammo box section describes these values.

## Constraints and assumptions

* Property names and values below come from UAssetGUI dumps with the usmap UE4SS generated for build 26437642, and from `UE4SS_ObjectDump.txt` of the same build.
* A preset (class `IRRItemsPreset`) holds `ContainerSlots`, an array of `LootContainerSlot` structs. A slot has `ContainerIndex`, `ContainerType`, `FixedItems`, `ItemChoices`, `bGenerateRandomLoot`, `GenerationChance`, `PostProcessors` and `LootSettings`, a reference to a `LootGenerationSettings` object exported by the same asset.
* `LootGenerationSettings` (`/Script/Test_C`) has `bUseCurve`, `ItemCountChanceCurve`, `MinGeneratedItems`, `MaxGeneratedItems`, `MinTotalValue`, `MaxTotalValue`, `ItemTypeSpawnWeights` (gameplay tag to float), `RaritySpawnWeights` (gameplay tag to float), `bForceExactRarityMatch`, `LootConditions` (references to `LootCondition` objects), `ItemCountOverrides` (gameplay tag to Vector2D) and `ItemSpawnOverrides`.
* Properties at their class default are absent from the cooked asset, e.g. the ammo box's settings have no `MinGeneratedItems`.
* The old `DefaultItemsContainers` is gone from NPC presets. The ammo box keeps it as `DefaultItemsContainers_LEGACY`, which the game ignores: in raid, boxes follow the edited `LootGenerationSettings`.
* `DA_Inventory_AI_Patrol_UICS_A`, `DA_Inventory_AI_Sniper_UICS` and `DA_Inventory_AI_Patrol_VLF_A` moved from `pakchunk6` to `pakchunk0`. `pak.ps1` finds the pak holding an asset by itself.
* Each NPC preset in `loadouts.json` has exactly one slot whose settings' `ItemTypeSpawnWeights` keys are all `Inventory.Items.Weapons.*` tags. That map is the weapon pool, with the same tag to weight meaning as the old `ItemSpawnChances`.
* Vanilla ammo box settings: `bUseCurve` true, `ItemCountChanceCurve` keys at time 1, 2 and 3 with values 0.2, 1 and 0.2, `MaxGeneratedItems` 3, `ItemTypeSpawnWeights` `Inventory.Items.Ammunition` 2, `RaritySpawnWeights` tier 1 to 4 of 1, 0.2, 0.1 and 0.05, `ItemCountOverrides` `Inventory.Items.Ammunition` 10 to 40, no `LootConditions`. These match the legacy values (1 to 3 items, the same rarity numbers, 10 to 40 rounds). The developers migrated the old fields one to one: the min and max item counts became a count curve, `RarityChanceDrop` became `RaritySpawnWeights`.
* The old `bCanAddSameItem` false became a `LootCondition_DuplicatePolicy` object (`DuplicatePolicy` `DisallowExactItem`, `DebugName` `MigratedDuplicatePolicy`) referenced from `LootConditions`. NPC presets have these. The ammo box has none, since its legacy `bCanAddSameItem` was true.
* Ruled out: keeping the old ammo box rule against two stacks of the same round. It would need a new condition export and its imports built into the cooked asset, which no stage does and the round-trip check can't guard. Ammo boxes allow duplicate stacks, as in vanilla.
* With `bUseCurve` false, the item count rolls between `MinGeneratedItems` and `MaxGeneratedItems`, confirmed in raid. The curve's time axis is the item count and its value the relative weight of that count.
* UAssetGUI writes a property that is absent from the parsed asset, given its name is in the name map. The usmap supplies its schema index, and the property lands in schema order.

## Scope

Owned:

* `likhos-rearmed/pak.ps1`: the loadouts and loot stages, and the description lines naming them.
* `likhos-rearmed/loot.json`.
* `likhos-rearmed/README.md`: the ammo box section.

Context only: `loadouts.json`, which keeps its shape and content; the reclass, clone, retarget and stats stages; `Read-Assets`, `Save-Asset` and `Find-Tag` in `pak.ps1`; `build.ps1`; the rest of the README; the changelog.

## Solution

### Settings object of a slot

Both stages work on the `LootGenerationSettings` objects that a preset's `ContainerSlots` reference through `LootSettings`, not on the preset's own export. A slot without settings is skipped.

### Loadouts stage

For each preset in `loadouts.json`, the stage finds the one slot settings object whose `ItemTypeSpawnWeights` keys are all weapon tags and replaces that map whole with the listed pool. Tags are checked against the staged tag list and added to the name map, as before. It fails the build when a preset has no such settings object or more than one. It logs the weapon count per preset.

### Loot stage and `loot.json`

`loot.json` maps a loot container preset's `/Game/` path to fields of its `LootGenerationSettings`, keyed by the game's property names. The preset must have exactly one slot with settings. The stage sets:

* An int or bool field to the listed value. A field absent from the asset because it sits at its class default is written in, with an int or bool type taken from the JSON value.
* A tag-keyed map field, float or Vector2D valued, by setting the value of each listed key. A Vector2D value is listed as `[min, max]`. Only keys the map already has are set.

It fails the build on a field or key that isn't there to set, and logs each edit with its old and new value.

The ammo box entry sets `bUseCurve` false, `MinGeneratedItems` 2, `MaxGeneratedItems` 5, `ItemCountOverrides` `Inventory.Items.Ammunition` to `[30, 90]` and `RaritySpawnWeights` `Inventory.Rarity Types.Tier 1` to 0.65.

### README

The ammo box section lists 2 to 5 stacks instead of 1 to 3, 30 to 90 rounds instead of 10 to 40, and tier 1 rounds rolling about a third less often than vanilla.

### Result

`.\build.ps1` builds the pak against build 26437642. In game, NPCs roll weapons from the `loadouts.json` pools, and in-raid ammo boxes hold 2 to 5 stacks of 30 to 90 rounds with tier 1 rounds rarer than vanilla.

## Tradeoffs

* Min and max with the curve off over editing the curve: two plain ints in `loot.json` instead of a list of curve keys, at the cost of resting on the unverified meaning of `bUseCurve` false and of writing in a property the asset doesn't carry.
* `loot.json` uses the game's property names over keeping the old field names and translating them: the stage stays a generic setter, and the next format change shows up as a missing field instead of a wrong translation.
