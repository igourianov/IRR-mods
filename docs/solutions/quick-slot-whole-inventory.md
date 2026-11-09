# Quick slot refill and count from the whole inventory

## Intent

A quick slot refills from, and its tile counts, items of its type anywhere in the player's inventory. Before, both were limited to the equipment the bound item sat in when the slot was bound (`docs/solutions/quick-slot-refill.md`), which needed the slot to track that equipment as the item moved (`docs/solutions/quick-slot-root-follow.md`). The player chose the simpler rule over keeping reserves in one piece of equipment apart from another.

## Constraints and assumptions

Constraints:

- Lives in `likhos-backpack/Scripts/quick_slots.lua`, in the poll of `quick-slot-refill.md`. No new game names. Everything used (`MainContainers`, `QuickSlots`, `UpdateQuickSlot`) is listed in that doc.
- "Same type" stays the same item definition. The inventory is the player's inventory component's `MainContainers`, the same set the stale slot clear checks (`docs/solutions/quick-slot-left-inventory.md`).
- Everything else of `quick-slot-refill.md` stays: what counts as used up, fewest uses first, single use items only for the count, no memory past the refill.

## Scope

Owned:

- `likhos-backpack/Scripts/quick_slots.lua`.
- `likhos-backpack/Scripts/config.lua`: the `quick_slot_refill` comment.
- `likhos-backpack/README.md`: the quick slot section.
- `likhos-backpack/CHANGELOG.md`: an entry for the change.

Context only: `quick-slot-refill.md`, `quick-slot-root-follow.md`, `quick-slot-left-inventory.md`.

## Solution

A slot's record drops the root container. The refill takes, from the whole inventory, the item with the recorded definition and uses left, fewest uses first. The tile count is the number of such items in the inventory. Slots bound to the same definition show the same count. The root walk, its periodic refresh and the main container lookups it needed are removed.

The player sees: bind a Morphine from the chest rig with 2 more on the rig and 2 in the backpack, and the slot shows 5. Using them all refills the slot from the rig and the backpack in container order. Moving the bound item between equipment changes nothing.

## Tradeoffs

- Whole inventory over one piece of equipment: no root tracking, and the count no longer walks up the containers of each matching item. The cost is that a slot can no longer be kept to the chest rig's supply. Two slots of one type share one pool.
