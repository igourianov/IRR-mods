# Use Adrenaline bind

## Intent

Likho's Point and Shoot gets a Use Adrenaline keybind: one press injects an Adrenaline Injector carried anywhere on the player. It finds and uses the item the way Combat Heal does, with the injector as the only item it treats.

## Constraints and assumptions

- An item gives a stamina boost through a use context in its `ItemDefinition.ItemContexts` whose `ToTriggerActions` include an action with `Inventory.Stats.Stamina Boost` in `EffectStatTags`. The Adrenaline Injector (`Inventory.Items.Medical.Adrenaline Injector`, 1 use, 2 s) has one (`docs/solutions/combat-heal.md`, Recon, Items).
- Food and drink items carry the same stat (`docs/solutions/adrenaline-stamina.md`). Only items with an `ItemIdentifier` under `Inventory.Items.Medical` are candidates, which leaves the injector as the only one. The tag decides within medical items, so a new medical item with the stamina boost tag is picked up without a code change.
- Items are searched anywhere on the player, read from the inventory component's `MainContainers` and passed straight to the context, as Combat Heal does. A `ContainerItem` returned by one UFunction is never passed to another.
- Assumed, unverified: the injector's context's `IsValidContext(pawn, nil, item)` and `Execute(pawn, nil, item)` work without an item widget, as seen for food and the Morphine Injector.
- The injector's effect has `StackingBehaviour = Replace` (`docs/solutions/adrenaline-stamina.md`). Ruled out: skipping a press while a boost is active. Every press injects when the context reports itself valid, and a press during a boost restarts it. Wasting the remainder is the player's choice.
- The mapping id is `LikhosUseAdrenaline`.

## Scope

Owned, all in `likhos-point-and-shoot/`:

- `Scripts/combat_heal.lua`: the Use Adrenaline entry point and the stamina boost treatment. Combat Heal's own behavior stays as `docs/solutions/combat-heal.md` describes it.
- `Scripts/actions.lua`: the `UseAdrenaline` entry in `ACTIONS`
- `Scripts/keymap.lua` and `Scripts/menu.lua`: the `LikhosUseAdrenaline` mapping and its controls row
- `Scripts/config.lua`: the `adrenaline` bind
- `mod.txt` (minor version), `README.md` and `CHANGELOG.md`

Context only: `input.lua` and `triggers.lua` (key polling and press dispatch on the game thread), `context.lua` (`block_in_ui`), `lib/util.lua`, `lib/log.lua`, the vanilla inventory component and item contexts.

## Solution

### `combat_heal.lua`

Holds the medical item search both binds use: resolving the PlayerController, pawn and inventory component, one pass over `MainContainers` collecting medical items with uses left and their treatments, and the ranking and pick that ends in executing the chosen item's context. Holds no state and no UObject between presses.

Its treatment table maps `Inventory.Stats.Stamina Boost` to a stamina treatment. No Combat Heal step uses it, so Combat Heal's picks are unchanged.

It exposes `press()` for Combat Heal and `use_adrenaline()` for Use Adrenaline, both run on the game thread by their actions. `use_adrenaline()` runs a single stamina step: candidates are ranked as Combat Heal ranks a condition step (speed, then number of treatments, then fewest uses left), the pick must report its context valid, and its context is executed. No pawn or inventory, or no usable candidate: it logs at debug and does nothing. It reads no health or gameplay tags.

### `actions.lua`

`ACTIONS.UseAdrenaline` has a `press` only, pointing at `combat_heal.use_adrenaline`, the same shape as `CombatHeal`.

### `keymap.lua` and `menu.lua`

`LikhosUseAdrenaline` is a mapping with display name `Use Adrenaline`, unbound by default. `menu.lua` lists it after `LikhosCombatHeal`, so the row shows last in the Likho's Actions section.

### `config.lua`

The sixth bind is `id = "adrenaline"`, `mapping = "LikhosUseAdrenaline"`, `action = "UseAdrenaline"`, `block_in_ui = true`, enabled.

### `mod.txt`, `README.md` and `CHANGELOG.md`

`mod.txt` has the minor version bumped for the new feature. The README has a `Use Adrenaline` section after `Combat Heal`: one key that injects an Adrenaline Injector from anywhere in the inventory, and a press during a boost restarts it. The changelog has the entry under the version of the build.

### Result

The player binds Use Adrenaline under Settings > Controls > Likho's Actions. In a raid, a press injects an Adrenaline Injector carried anywhere on the player, with the game's own animation and effect. With no injector, a menu open or another use running, nothing happens. Combat Heal and the vanilla Quick Heal are unaffected.

## Tradeoffs

- Sharing Combat Heal's search over a standalone module: one copy of the inventory walk and use path, at the cost of `combat_heal.lua` holding a bind that isn't a heal.
- Every press injects over skipping during a boost: no new game names to find, at the cost of a stray press wasting a dose.
- Reusing the condition ranking over picking the first injector found: same code path as Combat Heal, at the cost of ranking work that only orders injectors by uses left.
