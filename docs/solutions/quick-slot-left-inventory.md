# Quick slot cleared when its item leaves the inventory

## Intent

A quick slot bound to an item nested in a container stays bound when that container leaves the player's control. Bind a Morphine from the chest rig, or from a box inside the backpack, then move the chest rig or the backpack to the stash or drop it: the slot keeps the binding. Vanilla does the same. The game clears a slot when the bound item itself moves out, but not when one of its containers does.

The player wants such a slot cleared, as it is when the bound item itself is dropped.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from a UE4SS dump or Live View and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, no UObject is held across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The fix lives in `quick_slots.lua` in `likhos-backpack` and runs in its existing poll (`docs/solutions/quick-slot-refill.md`). It is on whenever `config.quick_slot_refill` is on. Ruled out: a separate config flag. The poll already reads every slot and looks its item up, so the check adds no new mechanism.
- "Out of the player's control" means the bound item is not in the player's inventory component (`MainContainers` of the component `GetPlayerInventoryComponent` returns). The stash (`InventoryFunctionLibrary.GetStashInventoryComponent`), the floor (`VicinityInventory`) and loot containers are other inventory components.
- The bound item moving out by itself is vanilla behavior and stays vanilla: the game deletes the slot's `QuickSlots` entry then.
- Any slot whose `QuickSlots` entry names an item that is not in the player's inventory is cleared, whether or not the poll saw the item in the inventory before. That covers bindings already stale in an existing save, e.g. a chest rig left in the stash before this fix. Ruled out: clearing only slots the poll saw live and then lose. It needs the same check plus a condition, and leaves stale saved bindings in place.
- A refill takes precedence over a clear. When the slot's recorded item was used up (`quick-slot-refill.md`), the slot is refilled from the same equipment, and cleared only when none is left there.
- The dump has no function that removes a quick slot binding. The only writer is `UpdateQuickSlot`.
- Seen in game 2026-11-09: `UpdateQuickSlot(Index, Item)` with an item whose only field set is a zero `ItemUID` clears the slot, and an open inventory screen shows it empty. A nested item's container moved to the stash or dropped leaves the item absent from the player's `MainContainers`. Reloading the game keeps bound slots bound and cleared slots empty, so the first poll after a load sees the saved bindings' items in `MainContainers` and a cleared slot is saved as cleared.

Assumptions, unverified:

1. An item moved within the player's inventory never reads absent from `MainContainers` on a poll, since the poll runs on the game thread between frames.
2. When a used item leaves the inventory, the game deletes its `QuickSlots` entry in the same frame (`quick-slot-refill.md`, frame by frame trace 2026-11-08), so a use never reads as a stale entry.

Names from `CXXHeaderDump` (dumped 2026-11-06, read 2026-11-09):

- `/Script/Test_C.InventoryComponent`: `QuickSlots` (`TArray<FQuickSlotItem>`, each `Index` and `ItemUID`), `MainContainers`, `UpdateQuickSlot(int32 Index, FContainerItem Item)`, `OnQuickSlotsUpdated`.
- `/Script/Test_C.InventoryFunctionLibrary`: `GetPlayerInventoryComponent(UObject*)`, `GetStashInventoryComponent(UObject*)`, both returning `UInventoryComponent*`.

## Scope

Owned:

- `likhos-backpack/Scripts/quick_slots.lua`.
- `likhos-backpack/README.md`: the quick slot section mentions the clear.
- `likhos-backpack/CHANGELOG.md`: an entry for the fix.

Context only: `lib/` (`log`, `util`), `docs/solutions/quick-slot-refill.md` (the poll, records and refill this extends), the game's quick slot UI.

## Solution

`quick_slots.lua` keeps its poll, records, refill and count as `quick-slot-refill.md` describes. The poll also clears stale slots.

Each poll reads every `QuickSlots` entry with a nonzero `ItemUID` and looks the items up in the player's `MainContainers` in its existing single pass. Per slot:

- Item found: the slot is live and its record is tracked as before.
- Item not found, the slot has a record and the record's item was used up: the refill runs as before. When it finds no replacement, the slot is cleared.
- Item not found otherwise, with or without a record: the entry is stale and the slot is cleared. The record is dropped.

Clearing calls `UpdateQuickSlot` on the player's inventory component with the slot's index and an empty item. The clear does not repeat on later polls, since the entry is gone after it.

Per slot the outcome is that a slot never stays bound to an item outside the player's inventory for longer than one poll, about 50 ms. The player sees: bind a Morphine from a box inside the backpack, move the backpack to the stash or drop it, and the slot is empty right away, also in an open inventory screen. Taking the backpack back does not bring the binding back. A slot used up by its last Morphine still empties as before, and one with Morphine left on the same equipment still refills.

The module logs each clear at debug level, naming the slot and the item UID.

## Tradeoffs

- Clearing any stale entry over only the ones seen leaving: one rule, and saves already holding stale bindings are fixed too. The cost is a dependency on the game loading the inventory's containers before the first poll sees the component, seen to hold on a reload 2026-11-09. If a patch changes that order, a load clears valid bindings.
- Poll over a hook on the move, drop or stash functions: the item can leave through several request paths (`RequestMoveItem`, `RequestDropItem`, `TrySwapItem`), and the poll already sees the result. The cost is up to one poll interval of a stale binding.
- No memory of a cleared binding: a container brought back from the stash does not rebind its slot. Same as `quick-slot-refill.md`, nothing to save.
