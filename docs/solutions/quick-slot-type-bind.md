# Quick slot binds an item type

## Intent

A quick slot binds an item type, not the item that happens to sit in it. Before, the slot refilled only when its item left the inventory used up (`docs/solutions/quick-slot-refill.md`). Moving the bound item to the stash, dropping it or selling it emptied the slot even with more of its type in the inventory, so the player had to know which item was the bound one.

Now the slot refills whenever its item leaves the inventory, for any reason, and empties only when the inventory holds none of its type or the player clears it by hand.

## Constraints and assumptions

Constraints:

- Lives in `likhos-backpack/Scripts/quick_slots.lua`, in the poll of `quick-slot-refill.md`. No new game names. Everything used (`MainContainers`, `QuickSlots`, `UpdateQuickSlot`) is listed in that doc.
- Refill source and count stay the whole inventory (`docs/solutions/quick-slot-whole-inventory.md`). Fewest uses first and the tile count stay as they were.
- A slot cleared or rebound by hand while its item is still in the inventory follows the player: cleared stays empty, rebound takes the new item's type.
- A slot left bound to an item outside the inventory by the game (its container moved out, `docs/solutions/quick-slot-left-inventory.md`) refills like any other exit, and is cleared only when nothing of its type is left.
- Ruled out: keeping the used up detection (0 uses seen on a poll, a use ability running) to tell a use from a drop. Under a type binding both lead to the same refill, so it is removed together with the use ability list.

## Scope

Owned:

- `likhos-backpack/Scripts/quick_slots.lua`.
- `likhos-backpack/Scripts/config.lua`: the `quick_slot_refill` comment.
- `likhos-backpack/README.md`: the quick slot section.
- `likhos-backpack/CHANGELOG.md`: an entry for the change.

Context only: `quick-slot-refill.md`, `quick-slot-whole-inventory.md`, `quick-slot-left-inventory.md`.

## Solution

A slot's record keeps the bound item's UID, definition and whether it is single use. The uses left at the last poll and the ability check are removed.

When a slot with a record has no live item, the slot is checked once and the record is dropped. If the recorded item is still in the inventory, the player cleared the slot by hand and it stays empty. Otherwise the slot takes the item of the recorded definition with uses left from the inventory, fewest uses first, through `UpdateQuickSlot`. When there is none, a stale entry is cleared and the slot stays empty.

The player sees: bind a grenade with 3 more in the inventory, move the bound grenade to the stash, and the slot holds another grenade within a fraction of a second.

## Tradeoffs

- Any exit over used up only: one rule, no timing window and no ability class list to keep up after a patch. The cost is that the player cannot empty a slot by dropping its item while more of the type is left. Clearing the slot by hand still empties it.
