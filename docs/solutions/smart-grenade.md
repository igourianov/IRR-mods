# Smart Grenade

## Intent

One new Point and Shoot keybinding equips a grenade by category:

- Tap equips a frag.
- Hold equips a smoke.
- Double tap equips a flashbang.

The grenade comes from the rig, armored rig or pockets, as with the vanilla grenade function, and never from elsewhere in the player's inventory. Within a category the most expensive grenade carried goes first.

## Constraints and assumptions

### Constraints

- The bind only equips. Throwing stays the game's own separate action.
- Eligible grenades sit in the Rig slot's storage or the Belt slot. The Rig slot holds both armored and unarmored rigs (`U_Rig` supports `Inventory.Items.Gear.Armored Rig` and `Inventory.Items.Gear.Unarmored Rig`).
- Ruled out as sources: backpack, Plate Carrier slot, stash and any other container.
- Only items directly in the Belt or the rig's storage count. Containers nested there are not searched, unlike the vanilla deep search, because a container is unlikely to fit in a rig.
- A gesture never falls back to another category. With no eligible grenade of its category it does nothing, so a player expecting smoke never ends up holding a frag.
- RGR Gas belongs to the smoke category and ranks by price like any other grenade, so it comes before RGD Smoke when both are carried.
- The double tap window is 200 ms, measured from the first release, and is editable in `config.lua`.
- With a grenade in hand, a gesture for the same category changes nothing. Repeating the use action with that category in hand put a frag in hand (seen in game 2026-11-23).
- A gesture for another category equips directly through the same use action, with no holster or swap of its own.
- Ruled out: handling an occasional frag right after a held smoke, possibly from a brief key state dropout. Key reads stay undebounced.
- Ruled out: the `log_level` value in `config.lua` is not part of this solution.
- Ruled out: Recon does not have to list every game name the code uses.
- The code guide applies: game thread only, no UObject held between calls, `util.valid` on every object and every boundary wrapped in `util.safe`.

### Recon

From the game paks and the CXXHeaderDump of 2026-11-11.

| Category | Grenade | `ItemIdentifier` | Price |
|---|---|---|---|
| Frag | RGO | `Inventory.Items.Grenades.RGO Grenade` | 300 |
| Frag | F-1 | `Inventory.Items.Grenades.F-1 Hand Grenade` | 250 |
| Frag | M67 | `Inventory.Items.Grenades.M67 Hand Grenade` | 160 |
| Smoke | RGR Gas | `Inventory.Items.Grenades.RGR Gas Grenade` | 140 |
| Smoke | RGD Smoke | `Inventory.Items.Grenades.RGD_Smoke_Grenade` | 90 |
| Flashbang | Zarya | `Inventory.Items.Grenades.Zarya Flash Grenade` | 400 |

- Prices are `MarketAvailability.DefaultMarketPrice` in `DT_Vendor_Old`, the table `DA_VendorSettings` points at.
- The M67 definition has one item context, `U_UseGadget_C`. All six definitions contain that context and an `IA_UseDrawGadget_C_0` action object, and reference the `IA_UseGadget_C` class, whose `Ability` property is typed `SGA_EquipGadget_C`.
- The player's slot containers come from `DA_PlayerContainerSettings`, as `U_Rig_C_0` and `U_Belt_C_0` for these two slots.
- `MainContainers` interleaves each slot with the storage of what it holds, so its order does not follow the default container list. A slot's main container has one element, whose `ContainerSettings` is a subobject of the slot's default container (live dump, 2026-11-23).
- An equipped rig's storage is the main container whose `MainContainerUID` equals the rig's `ItemUID`. The Belt holds its items directly (live dump, 2026-11-23).

### Assumptions (unverified)

- Executing `U_UseGadget_C` with no item widget equips exactly the item passed, the way the existing consumable binds use their contexts.
- The Belt slot is the storage the game's UI shows as pockets.
- The use action equips the item passed when a grenade of another category is in hand.

## Scope

Owned, all under `likhos-point-and-shoot/`:

- `Scripts/items/smart_grenade.lua`
- `Scripts/items/inventory.lua`, for the slot storage lookup and the container filter only
- `Scripts/core/triggers.lua`, `Scripts/core/actions.lua` and `Scripts/core/input.lua`, for the double tap phase and its context gate only
- `Scripts/controls/keymap.lua`, for the new row only
- `README.md`, for the Smart Grenade entry and section only
- `Scripts/config.lua`, for the new bind and window only
- `Scripts/main.lua`, for the install call only
- `mod.txt` (minor version) and `CHANGELOG.md` (`# Unreleased`)

Context only: `Scripts/core/player.lua` and the vanilla grenade key, which stays as it is.

## Solution

### Key mapping

`controls/keymap.lua` has a `LikhosSmartGrenade` row labelled "Smart Grenade (Tap/Hold/Double Tap)", directly above Smart Heal and unbound by default like every mod row. Its description names the three gestures. `config.lua` binds it to the `SmartGrenade` action with `block_in_ui = true` and holds `double_tap_ms = 200`.

### Gesture detection

`core/triggers.lua` recognizes a double tap for actions that define a `double_tap` phase. Every other action keeps its current timing.

For an action with that phase:

- A press held past `tap_ms` fires `hold` at the threshold, as it does for other binds.
- A release inside `tap_ms` starts the double tap window. The `tap` phase fires when the window ends without another press.
- A press inside the window fires `double_tap` at once. That press produces no `tap` or `hold`.
- A pending tap is dropped on level load and when the context gate starts blocking the bind, so it never fires into an open menu.

`core/actions.lua` exposes whether an action defines `double_tap`, so triggers holds no per-action knowledge.

### Inventory reads

`items/inventory.lua` owns the container layout. Given a set of slot classes, it returns the set of main container IDs storing what those slots hold: a slot with its own item grid, like the Belt, counts itself, and a slot holding equipment, like the Rig, counts the equipped item's storage. Containers nested inside those are not included. `inventory.items` and `inventory.usable` take that set as an optional filter, and without it they read every container as before.

### Grenade selection

`items/smart_grenade.lua` owns the category table: each category is its `ItemIdentifier` list in descending price order, from Recon. It defines the `SmartGrenade` action with `tap` for frag, `hold` for smoke and `double_tap` for flashbang.

On a gesture it reads the usable grenades of the Rig and Belt through `items/inventory.lua` and walks the category's list in order. The first item whose `U_UseGadget_C` context reports valid is executed with the pawn and no widget, the same call pattern as `items/food_drink.lua`. With no such item it logs at debug level and does nothing.

A gesture first looks at the item in hand through the pawn's `UEquipmentComponent`. For the same category it ends there. Otherwise it equips as above.

### Result

With the key bound, a tap puts the most expensive frag from the rig or pockets in hand about 200 ms after release. A hold equips the most expensive smoke category grenade at 250 ms. A double tap equips a flashbang on the second press. The player then throws with the game's own throw action.

## Tradeoffs

- **Static price order over a live vendor lookup.** The order lives in the category table, with no dependency on a vendor component that may not exist in a raid. A game patch that changes prices or adds a grenade needs a table edit, and a grenade missing from the table is ignored.
- **One key with three gestures over three keys.** It uses one binding, at the cost of a 200 ms delay on every frag equip, since a tap can only be confirmed once the double tap window has passed.
- **Double tap in `core/triggers.lua` over inside the grenade module.** Gesture timing stays in one place and other binds can opt in. The cost is a wider change to a core module, limited by making the phase opt-in.
- **RGR Gas ranked by price.** A hold equips gas whenever it is carried, even if the player also has RGD Smoke.
