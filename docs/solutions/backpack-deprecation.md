# Backpack deprecation

## Intent

Merge Likho's Backpack into Likho's Point and Shoot, so one mod carries both feature sets, and retire Backpack as a separate mod. Players keep every Backpack feature by installing Point and Shoot alone.

While merging, the inventory access that Point and Shoot's consumable binds and Backpack's quick slots each do their own way is folded into one shared module.

## Constraints and assumptions

- Backpack's three features move with their behavior unchanged, except quick sell: whole use counts, Shift+Click quick sell in the hideout and quick slot refill with click to clear and single use counts.
- Quick sell sells only. Vanilla no longer delivers a mission item from the inventory, so the Deliver path and every mention of delivery are gone.
- The mod keeps its name, Likho's Point and Shoot.
- Every game name the moved code uses already comes from the solution docs its file headers cite (`medic-uses-display.md`, `usb-uses-display.md`, `hideout-quick-sell.md`, `quick-deliver.md`, `quick-slot-*.md`). The merge introduces no new game name.
- The mod folder stays `likhos-point-and-shoot`. A renamed folder leaves the old one in every updating player's `ue4ss\Mods`, where both copies load and register the mod's key mappings twice.
- The Backpack Nexus page is retired by hand on the site. Nothing in the repo publishes to it again.
- Ruled out: a final inert Backpack release. The folder is deleted outright and git history keeps it.
- A player who installs the merged Point and Shoot and leaves `likhos-backpack` in `ue4ss\Mods` runs both. Assumption, unverified: this is harmless duplication, since a second quick sell or click clear finds its tile gone or bound to another item and does nothing, the second whole uses rewrite finds no decimals and a second quick slot poll rebinds its records to the slot the first one refilled. The README still tells the player to delete the old folder.
- Assumption, unverified: Backpack's features, last verified on game build 26487830, work on 26610539, the build Point and Shoot is verified on. The build checks this in game.
- `actions.lua` reads the equipped weapon, not the inventory component, and stays outside the shared inventory module.

## Scope

Owned:

- `likhos-point-and-shoot/`: `Scripts/`, `mod.txt`, `README.md` and `CHANGELOG.md`.
- `likhos-backpack/`: the whole folder, which does not exist in the end state.
- `tools/publish/publish.config.json`: the mod list.
- Root `README.md`: the mod table.
- `CLAUDE.md`: the example commands that name a mod.

Context only: `lib/` (`log`, `util`, `hook`), `tools/build/build.ps1`, the solution docs the moved code cites.

## Solution

### Mods

`likhos-backpack` is gone from the repo. `publish.config.json` lists `likhos-point-and-shoot` and `likhos-rearmed`. The root README's mod table lists the same two, with Point and Shoot's description covering the inventory features. `CLAUDE.md`'s build and publish examples name `likhos-point-and-shoot`.

### Point and Shoot modules

`main.lua` installs the three inventory features next to its existing ones, each behind its own config flag, the same way it gates `magnifier`, `low_ready` and `plant_marker`.

- `whole_uses.lua`: Backpack's module. Hooks `W_InventoryItem_C:K2_UpdateItemCount` and rewrites a uses tile's count a tick later in one batched flush per frame: whole numbers, nothing on an unused single use item, `~` on a spent one, a percentage on a USB hacking device.
- `quick_sell.lua`: Backpack's module. Hooks `W_InventoryItem_C:OnMouseButtonDown` and on a Shift+left click runs vanilla's `U_Sell_C` context a tick later, when vanilla offers it for the item, after checking the tile still shows the clicked item.
- `quick_slots.lua`: Backpack's module. A `LoopInGameThreadWithDelay` poll every 50 ms tracks each of the 4 quick slots' bound item and definition, refills a slot from the inventory with the same definition (fewest uses left first) once its item leaves, clears a slot naming an item outside the inventory and, every 5th poll, writes the inventory count onto single use slot tiles of the current inventory screen. It also hooks `W_InventoryItem_C:OnMouseButtonDown` and clears a quick slot on a bare left click.
- `inventory.lua`: the inventory reads shared by `combat_heal`, `consume`, `quick_slots` and `whole_uses`:
	- the player's inventory component from the PlayerController through `InventoryFunctionLibrary`, or nil outside a level with a player;
	- a walk over every item of the component's `MainContainers`, items as read from the property so they can be passed to a use context, with grid order (`grid_order`, as today) for the binds that pick by position;
	- an item's uses left from its `Inventory.Stats.Durability` current stat;
	- a definition's uses stat, told apart from weapon and armor durability by its `U_Content_C` config class;
	- the modifier state of a tile click (Shift, Ctrl, Alt), decoded through `KismetInputLibrary` from a fresh struct, used by both click handlers.
- `combat_heal.lua` and `consume.lua` keep their selection logic and take the component lookup, item walk and uses read from `inventory.lua`.

Each module keeps holding no UObject between calls, and each hook body stays inside its `hook.new` group's guard.

### Config

`config.lua` holds Backpack's three flags with their comments, all defaulting to `true`: `whole_uses`, `quick_sell` and `quick_slot_refill`. Each `false` gives the vanilla behavior its comment names.

### README

`README.md` has Backpack's three sections, Whole use counts, Quick sell and Quick slot refill, with their current text and no mention of delivery, grouped under an inventory heading after the existing features. The intro covers both the tactical shortcuts and the inventory tweaks. Configuration lists the three new flags. Installation tells a player who had Likho's Backpack installed to delete its `likhos-backpack` folder.

### Version and changelog

`mod.txt` has its minor version raised by one, for the new features. `game_build` stays Point and Shoot's. `CHANGELOG.md` has, under `# Unreleased`, entries saying Backpack's features are now part of this mod, that Likho's Backpack is retired and that Shift+Click no longer delivers mission items.

### Result

With only Point and Shoot installed, a player gets every Point and Shoot feature plus whole use counts on inventory tiles, Shift+Click selling in the hideout and refilling quick slots, and `UE4SS.log` shows them under `[PointAndShoot]`.

## Tradeoffs

- One mod over two: a player who wanted only Backpack now gets Point and Shoot's binds, tick loop, low ready change and marker recolor too, and turns those off in config. In exchange there is one install, one UE4SS log tag and one Nexus page to maintain.
- The shared `inventory.lua` touches `combat_heal` and `consume`, which work today, to remove the duplicated lookup and walk. The cost is a retest of Smart Heal, Use Adrenaline and Consume Food/Drink.
- Two modules hook the same `OnMouseButtonDown` rather than one dispatcher, so each feature keeps its own config flag and failure message. Each click pays two hook calls.

