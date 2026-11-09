# Quick slot follows its item to other equipment

## Intent

A quick slot bound to an item stays bound when the player moves that item to other equipment within the inventory, e.g. 4 grenades from the pockets to the backpack. Vanilla keeps the binding then. The mod's count on the quick slot tile kept counting the old equipment and showed 0, and a refill would have looked for a replacement in the old equipment too.

The slot's equipment follows its bound item: after the move the tile shows 4 and a refill takes the next grenade from the backpack.

## Constraints and assumptions

Constraints:

- Lives in `likhos-backpack/Scripts/quick_slots.lua`, in the poll of `docs/solutions/quick-slot-refill.md`. No new game names. Everything used (`MainContainers`, `QuickSlots`, the root walk) is listed in that doc.
- Cause: a slot's record took its root container only when the binding was first seen (`quick-slot-refill.md`, Solution). A move of the still bound item never rewrote it.
- A move can leave the bound item's own main container unchanged, e.g. a box holding the grenade moved from the pockets to the backpack. So a change of the root is detected by rereading the root, not by watching the item's immediate container.

Assumptions, unverified:

1. Items move within the inventory only through the inventory screen, so the player cannot move a bound item and use it within one refresh interval.

## Scope

Owned:

- `likhos-backpack/Scripts/quick_slots.lua`.
- `likhos-backpack/CHANGELOG.md`: an entry for the fix.

Context only: `docs/solutions/quick-slot-refill.md`, `docs/solutions/quick-slot-left-inventory.md`.

## Solution

On every 5th poll, the same pace as the tile count (about 250 ms), each slot whose bound item is unchanged and still in the inventory has its root reread with the existing root walk. When it differs, the record takes the new root and the module logs the move at debug level. The count and the refill then use the new root.

The player sees: bind a grenade from the pockets, move all 4 grenades to the backpack, and the slot shows 4 within a fraction of a second. Throw one and the slot holds the next grenade from the backpack.

## Tradeoffs

- Periodic reread over a reread on every poll: the root walk costs about one pass over the inventory per bound slot, which every poll would multiply the poll's cost by up to 5. The cost is a stale root for up to 250 ms after a move.
- Reread over clearing the slot on a move: the vanilla binding stays and the mod's count and refill agree with it.
