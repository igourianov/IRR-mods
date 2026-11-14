# Injector stacking

## Intent

Adrenaline Injectors and Morphine Injectors stack up to 5 per inventory tile, so carrying several takes one grid cell instead of one cell each.

## Constraints and assumptions

### Game internals (from UE4SS CXXHeaderDump 2026-11-12 and the cooked item definitions)

- Stacking is defined per item definition in the `ItemProperties` struct (`FItemProperties`) of `IRRItemDefinition`: `CanStack` (bool) and `MaxStack` (int32). Its other fields are `ContainerWidget`, `bAddToInspectWidget`, `DefaultContext`, `ActionContext`, `VitalPartsList`, `DefaultItemState`, `DefaultDimensions`, `InternalMag` and `bQuestItem`.
- Stackable game items set both fields, e.g. `ID_762x39_HP` (`CanStack` true, `MaxStack` 60), `ID_Battery_18650` and `ID_Sewing_Kit` (5), `ID_PreppedMeal` (3).
- `ID_Adrenaline_Injector` (`/Game/Blueprints/InventorySystem/Items/Medical/Adrenaline_Injector/ID_Adrenaline_Injector`) and `ID_Morphine_Injector` (`/Game/Blueprints/InventorySystem/Items/Medical/Morphine_Injector/ID_Morphine_Injector`) have no `ItemProperties` in the asset at all: every field keeps the class default.
- Both injectors carry a uses stat (`U_Content_C`) of 1. No stackable game item has a `U_Content_C` stat, so the game never ships this combination.
- An inventory entry (`FContainerItem`) holds its own copy of `CanStack` and `MaxStack`, its stack size in `Count` and its uses in `CurrentStats` (`FCurrentStatItem`: `Tag`, `Value`, `MaxValue`; the uses tag is `Inventory.Stats.Durability`). A stack is one entry, so its injectors share one uses value.
- An inventory tile (`UItemWidget`, extended by `W_InventoryItem_C`) shows counts in two text blocks, `ItemCapacity` and `ItemMaxCapacity`. Which of `Count` and the uses the native widget writes there for an item that has both is not in the dump.
- Cooked exports are unversioned. A struct property written into an export replaces the inherited struct as a whole, and its unwritten fields take the struct's own defaults.

### Ruled out

- Health Injector and Revive Syringe stay unstackable. Only Adrenaline and Morphine are in scope.
- Likho's Backpack quick slot counts stay as they are: a quick slot bound to an injector counts inventory entries, so a stack of 5 counts as 1.
- No Lua runtime patch of `ItemProperties`. The pak is where Likho's Rearmed changes item definitions, and a live edit would need to land before any inventory reads the definition.

### Assumptions (unverified, the build checks them in game)

1. Writing `ItemProperties` with only `CanStack` and `MaxStack` leaves every other field at the value the injectors have now. Checked in Live View by comparing the injector definitions' `ItemProperties` before and after the pak.
2. Using an injector from a stack lowers `Count` by one and leaves the rest of the stack with its uses intact, rather than spending the shared uses and removing the whole stack.
3. Picking up, moving, splitting and merging injector stacks works like any other stackable item.
4. Loot generation keeps spawning injectors one per spawn, since no loot preset gives them an item count override.
5. Injectors in existing saves load intact. Whether they stack depends on whether an entry's `CanStack` and `MaxStack` come from the definition on load or from the save.
6. A stacked injector tile shows the stack count. Likho's Backpack `whole_uses.lua` blanks a tile reading `1/1`, so if the game writes the uses there instead, the count is hidden or never shown.

Assumption 2 failing changes the design. The others failing may only add edit list entries.

## Scope

Owned:

- `tools/pak/pak.ps1`, stats stage: sets an item definition's stack size.
- `likhos-rearmed/stats.json`: the two injector entries.
- `likhos-rearmed/README.md` and `likhos-rearmed/CHANGELOG.md` (`# Unreleased`).

Context only, not changed:

- `likhos-backpack/Scripts/quick_slots.lua`. A quick slot of a single use item shows how many items of its type the inventory holds by counting inventory entries, so a stack of 5 counts as 1. `single_use()` still reads a stacked injector as single use, by its uses stat.
- `likhos-backpack/Scripts/whole_uses.lua`. It hides the count on an unused single use item's tile (`1/1`). Whether the game writes the stack count to those same text blocks on a stacked tile is unknown.
- `likhos-point-and-shoot` Use Adrenaline and Smart Heal, which pick injectors from the inventory and use them through the game.

## Solution

### pak.ps1 stats stage

A `stats.json` entry accepts a `MaxStack` key next to its stat values. The stats stage writes it to the item definition's `ItemProperties`: `MaxStack` to the given integer and `CanStack` to whether it is above 1. A definition without `ItemProperties` gets the struct with just those two fields. One with the struct keeps its other fields and gets the two set or added. The stage logs the old and new stack size like any other stat.

The stage's header description names stack size alongside stat values.

### likhos-rearmed/stats.json

`ID_Adrenaline_Injector` keeps its stamina multipliers and gets `"MaxStack": 5`. `ID_Morphine_Injector` gets an entry holding only `"MaxStack": 5`.

### Result in game

Adrenaline and Morphine Injectors merge into stacks of up to 5 on one tile. Using one from a stack uses one injector.

## Tradeoffs

- `MaxStack` lives in `stats.json` rather than a new `properties.json` edit list. Every stage that edits an item definition writes the same staged file, so a separate list would need its own merge into the stats stage the way `retarget` and `supported` have. The cost is a key in `stats.json` that is an item property, not an `ItemStats` value, as `BleedingChance` and the stamina multipliers already are.
- The written struct holds only the two fields instead of copying the inherited struct first. The inherited value comes from a native class default object, which is not in the paks. This rests on assumption 1.
