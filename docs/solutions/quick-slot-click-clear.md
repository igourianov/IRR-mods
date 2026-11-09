# Quick slot cleared by a click

## Intent

Since a quick slot binds an item type (`docs/solutions/quick-slot-type-bind.md`), moving its item out refills it, so the player has no way left to empty a slot while items of its type remain. A bare left click on a quick slot's tile in the inventory screen clears the slot. The item stays where it is.

## Constraints and assumptions

Constraints:

- Lives in `likhos-backpack/Scripts/quick_slots.lua`, behind `config.quick_slot_refill`. Without the type binding vanilla's ways to empty a slot still work, so the click has no use on its own.
- Modified clicks keep their vanilla actions (user, 2026-11-09): Shift+Click sells in the hideout and drops in raid, Ctrl+Click moves the item out, right click opens the context menu. Alt+Click is left alone too.
- `W_InventoryItem_C` handles `OnMouseButtonDown` and `OnDragDetected`, and has no mouse up handler (`CXXHeaderDump/W_InventoryItem.hpp`). A press can't be told from the start of a drag when it happens. Chosen (user, 2026-11-09): clear on the press. The slot's tile is gone a tick later, so a quick slot's item can no longer be dragged out of the slot. Ruled out: clearing on release unless a drag started. It needs the mouse button polled, whose reading while the inventory screen has focus is unverified.
- The clear goes through `UpdateQuickSlot` with an empty item, as the stale entry clear does (`docs/solutions/quick-slot-left-inventory.md`). The poll then finds the slot empty with its item still in the inventory, which `quick-slot-type-bind.md` treats as a manual clear, and leaves it empty.
- Modifier keys are read as `quick_sell.lua` reads Shift (`docs/solutions/hideout-quick-sell.md`): Slate's modifier state decoded by `KismetInputLibrary`, from a fresh struct.

Assumptions, unverified:

1. A pre hook on `OnMouseButtonDown` runs before vanilla's handler and leaves its result alone, as Shift+Click quick sell does in the hideout.
2. Clearing the slot a tick after the press, while vanilla's drag detection is armed on the removed tile, starts no drag and leaves no drag operation behind.

Names:

- `/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C`: `OnMouseButtonDown(MyGeometry, MouseEvent)`, `OnDragDetected` (`CXXHeaderDump/W_InventoryItem.hpp`).
- `/Script/Test_C.ItemWidget`: `BaseContainerElementRef` (`UContainerElementWidget*`), `ContainerItem` (`CXXHeaderDump/Test_C.hpp`).
- `W_QuickSlotContainer_C`: `QuickSlotIndex` (`CXXHeaderDump/W_QuickSlotContainer.hpp`).
- `/Script/Engine.KismetInputLibrary`: `PointerEvent_GetEffectingButton`, `GetModifierKeysState`, `ModifierKeysState_IsShiftDown`, `ModifierKeysState_IsControlDown`, `ModifierKeysState_IsAltDown` (`CXXHeaderDump/Engine.hpp`).
- `/Script/Test_C.InventoryComponent`: `QuickSlots`, `UpdateQuickSlot` (`docs/solutions/quick-slot-refill.md`).

## Scope

Owned:

- `likhos-backpack/Scripts/quick_slots.lua`.
- `likhos-backpack/Scripts/config.lua`: the `quick_slot_refill` comment.
- `likhos-backpack/README.md`: the quick slot section.
- `likhos-backpack/CHANGELOG.md`: an entry for the change.

Context only: `quick_sell.lua` (the click hook and modifier read it follows), `lib/hook.lua`.

## Solution

`quick_slots.lua` gets a hook group, `hook.new("quick slot clear", "a click on a quick slot stays vanilla")`, and `M.install()` hooks `W_InventoryItem_C:OnMouseButtonDown` through it, deferred until the class loads, next to starting the poll.

On a press, the hook checks that the tile's `BaseContainerElementRef` is a `W_QuickSlotContainer_C`, that the button is the left one and that Shift, Ctrl and Alt are all up. Then it takes the slot's `QuickSlotIndex` and the tile's item UID, and a tick later clears the slot through `UpdateQuickSlot`, if the slot still names that UID. The player's inventory component is resolved the same way as in the poll, through a shared helper.

The player sees: click a quick slot in the inventory screen and it is empty, with the item still in its grid. The slot stays empty until the player drags an item onto it.

## Tradeoffs

- Clear on press over clear on release: one hook on a handler already in use, no polling of input. The cost is that a quick slot's item can't be dragged out of the slot. Rebinding works by dragging another item onto the slot.
- Behind `quick_slot_refill` over its own flag: the click exists only because of the type binding.
