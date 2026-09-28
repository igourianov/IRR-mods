# Inventory swap

## Intent

Dropping an inventory item onto another item that it can't stack with or go inside is a no-op in vanilla: the dragged item returns to where it was. The player wants the two items to swap places instead, when both are 1x1. The feature ships as a new standalone UE4SS mod, Likho's Backpack.

## Constraints and assumptions

### Rules

- Both items are 1x1. Anything larger keeps the vanilla no-op. Rotation never matters at 1x1, so it is ignored.
- Vanilla outcomes win. A drop that stacks, goes inside the target, or lands anywhere vanilla accepts, is left to vanilla. The swap only replaces the no-op.
- The two items may belong to different inventory components: player inventory, stash, loot container, dead body.
- Drops onto the quick slot bar, equipment slots, weapon attachment slots, vendor and shopping cart keep vanilla behavior. Only drops onto a storage grid swap.
- A quick slot only references an item. Dropping onto one makes a reference and never reaches the swap. Dragging out of one drags the real item, so its swap trades the item's real place, and the quick slot reference drops as it does when vanilla moves the item.
- A swap happens entirely or not at all. Both destinations are checked before either item moves. An item a destination grid refuses (a pouch that takes only magazines, for example) cancels the swap.
- No 1x1 container exists in the game, so a swap of two 1x1 items can't put an item inside itself. There is no check for it.

### Game internals

From `ue4ss\UE4SS_ObjectDump.txt` dated 2026-09-22.

Drop handling, native base of the grid widgets:

- `/Script/Test_C.ContainerElementWidget:HandleItemDrop(InOperation: DragDropOperation)`
- `/Script/Test_C.ContainerElementWidget:ValidateDrop() -> bool`
- `ContainerElementWidget` drop state, filled while dragging over it: `DropToItem` (ContainerItem), `bCanBeDropped`, `bCanBeStacked`, `bTryAddToDescendant`, `DropToContainerUID` (Guid), `DropToContainerIndex`, `DropToSlotIndex`.
- `ContainerElementWidget` identity: `InventoryComponent`, `ContainerRef`, `SpecialContainerRef`, `MainContainerUID` (Guid), `ContainerIndex`.
- Blueprint slot widget: `/Game/Blueprints/InventorySystem/Widgets/W_InventorySlot.W_InventorySlot_C:OnDrop(MyGeometry, PointerEvent, Operation) -> bool`, `:OnDragEnter`, `:OnDragOver`. Its native base `/Script/Test_C.SlotWidget` has `SlotIndex`, `BaseContainerElement` (the ContainerElementWidget) and `bEquipToSlot`.
- The game's item drag operation is `/Game/Blueprints/InventorySystem/Widgets/BP_InventoryDragDropOperation.BP_InventoryDragDropOperation_C`, a subclass of `ItemDragDropOperation`.
- `W_QuickSlotContainer_C` overrides `HandleItemDrop`.
- `ContainerElementWidget` subclasses: `/Script/Test_C.SpatialContainerWidget` (`Columns`, `Rows`), parent of `W_SpatialContainer_C`, and `/Script/Test_C.EquipToContainerWidget`, parent of `W_EquipToContainer_C` and of `/Script/Test_C.QuickSlotContainerWidget` (`W_QuickSlotContainer_C`). `W_AttachmentContainer_C` is not a `ContainerElementWidget`.
- `/Script/Test_C.ItemWidget`: `ContainerItem`, `OwnerInventoryComp`, `BaseContainerElementRef` (the ContainerElementWidget showing the tile).

Drag operation, `/Script/Test_C.ItemDragDropOperation`: `Item` (ContainerItem), `ItemOwnerComp` (InventoryComponent), `ItemWidgetRef` (ItemWidget).

Item, `/Script/Test_C.ContainerItem`: `ItemInventoryComp`, `ItemDefinition`, `ItemUID` (Guid), `MotherUID` (Guid), `ContainerIndex`, `SlotIndex`, `ItemDimensions` (`/Script/Test_C.ItemDimensions`: `X` and `Y`, both Vector2D), `bRotated`, `CanStack`, `bQuestItem`.

Grid data: `/Script/Test_C.MainContainer`: `MainContainerUID`, `ContainerElements`, `ContainerItems`. `/Script/Test_C.ContainerSlot`: `Index`, `Row`, `Column`, `bEnabled`, `HostingUID`.

`/Script/Test_C.InventoryComponent`:

- `RequestMoveItem(ItemOwnerComp, TargetComp, Item: ContainerItem, NewMainContainerUID: Guid, NewContainerIndex, NewSlotIndex, bIsRotated, bValidate)`
- `TryMoveItem`, same without `bValidate`.
- `IsContainerSupportingItem(MainContainer, ContainerIndex, ToAddItem: ContainerItem) -> bool`
- `CheckItemRelations(MainContainer, ContainerItem) -> bool`, meaning of the result unknown.
- `GetMainContainerByUID(MainContainerUID) -> MainContainer`, `GetContainerItemByUID(ItemUID) -> ContainerItem`, `GetRootContainer`, `GetMotherContainerByUID`.
- `CanAddItemToSlots`, `FreeContainerSlots`, `OccupyContainerSlots`.
- `MainContainers` (`TArray<FMainContainer>`): every main container of the component, each with its `ContainerItems`.

Signatures, from `ue4ss\CXXHeaderDump\Test_C.hpp` generated 2026-09-28: `RequestMoveItem`, `IsContainerSupportingItem` and `CheckItemRelations` take `FMainContainer` and `FContainerItem` by value. `CanStackItem(FContainerItem& RootItem, FContainerItem ToAddItem, int32& StackAmount)` takes out parameters.

### Observed in game

Debug logs of drops, 2026-09-28:

- `RegisterHook` sees `HandleItemDrop` on drops onto `W_SpatialContainer_C` grids. Drops onto `W_QuickSlotContainer_C` don't reach it.
- Before `HandleItemDrop` runs, `bCanBeDropped` is true for every drop vanilla carries out (a stack, into a container, onto free space) and false for the no-op. `HandleItemDrop` resets it to false.
- `DropToItem` is the dragged item, not the item under the cursor. `ValidateDrop` returns true for the no-op too. Neither identifies the no-op or its target.
- Before `HandleItemDrop` runs, `DropToContainerUID` is the `ItemUID` of the item under the cursor, whatever its size: the no-op target, the stack target, the container dropped into. It is all zeros over free space.
- The hook on `W_InventorySlot_C:OnDrop` runs after `HandleItemDrop` for the same drop. Its `SlotIndex` is the slot under the cursor, including when an item tile covers it.
- `ItemDimensions` `X` and `Y` are the item's (min, max) extents in slots, (-0.5, 0.5) on both for a 1x1 item.
- `RequestMoveItem` called from Lua on the item owner's component moves an item into a free slot, validated, and the move shows in `MainContainers` within a tick. Onto a slot another item occupies it does nothing, even with `bValidate` false.
- A grid's free slots are its `ContainerSlots` entries (in the main container's `ContainerElements`, indexed by container index) with `bEnabled` true and a zero `HostingUID`.
- UE4SS runs each mod in its own Lua state: with both mods enabled, each one's `log` module kept its own name in log lines.
- UE4SS calls: a struct read from a property passes into a UFunction by value fine (`ContainerItem` into `CanSplitItem`). A struct returned by a UFunction call (`GetMainContainerByUID`) crashes the game when passed into another UFunction. An out parameter needs a Lua table, and UE4SS rejects anything else with a Lua error before calling.

### Assumptions (unverified, the build checks them)

3. Slot occupancy lives only in `ContainerSlot.HostingUID`, a Lua write to it takes effect, and nothing reacts to two items sharing a slot for the few ticks between the moves. Checked by moving each item again by vanilla drag after a swap, including onto the other's old slot, and by the swap surviving reopening the inventory and a game restart.
5. Vendor and shopping cart drops don't land on a `SpatialContainerWidget`.
6. `RequestMoveItem` is the game's replicated move request, so two calls in order behave the same for a co-op client as for the host. Only tested solo.
### Ruled out

- Shipping the swap inside `likhos-point-and-shoot`. The player chose a separate mod.

## Scope

Owned, the new mod folder `likhos-backpack/`:

- `mod.txt`, `enabled.txt`
- `Scripts/main.lua`, `Scripts/config.lua`
- `Scripts/inventory_swap.lua`
- `README.md`, `CHANGELOG.md`

Also owned: the `likhos-backpack` row in the root `README.md` mods table.

The mod also hosts `medic.lua` and `whole_uses.lua`, moved in from `likhos-point-and-shoot`. They, their config switches, `main.lua` installing them and their README and CHANGELOG parts belong to their own solution docs, not this one.

Context only, left as they are: `lib/` (the shared `log`, `util` and `hook` modules `build.ps1` and `publish.ps1` copy into each mod's `Scripts/`), `likhos-point-and-shoot/` (the module pattern), `build.ps1` (finds any folder with a `mod.txt`, so it deploys the new mod with no change), `publish.ps1` and `publish.config.json`. The publish entry needs a Nexus page and a hand-uploaded first file, which is the user's step.

## Solution

### Mod shell

`likhos-backpack/` is laid out like `likhos-point-and-shoot/`:

- `mod.txt` has the same `[mod]` / `[ue4ss]` sections, starting at version `1.0.0`, which `build.ps1` bumps. `enabled.txt` is empty, as in the other mod.
- `log`, `util` and `hook` come from the shared `lib/`. The mod names itself `Backpack` for log lines through `log.setup`.
- `config.lua` is user-editable and hot-reloadable, with `log_level`, the master `enabled` switch and `inventory_swap`, commented in the style of `likhos-point-and-shoot`'s config.
- `main.lua` is the idempotent entry point: sets up logging, loads inert when `enabled` is false, installs `inventory_swap` when its switch is on, and logs `loading` / `ready`. It has no binds, tick loop or console commands.

### inventory_swap.lua

Follows the shape of `likhos-point-and-shoot`'s `whole_uses.lua` and `medic.lua`: a `hook.new("inventory swap", "drops onto items stay vanilla")` group, `M.install()` that hooks `ContainerElementWidget:HandleItemDrop`, no UObject held between calls.

The hook runs before vanilla handles the drop, while the grid's drop state still holds vanilla's decision. The drop is a swap when all hold:

- the grid is a storage grid (`SpatialContainerWidget`) and the operation an item drag (`ItemDragDropOperation`),
- vanilla rejects the drop: `bCanBeDropped` is false,
- an item is under the cursor: one of the grid's items has the `ItemUID` in `DropToContainerUID`,
- the target is a different item from the dragged one,
- both items are 1x1,
- each item is accepted by the other's grid (`IsContainerSupportingItem`).

Anything else returns without touching the drop.

Every main container and item the module passes to the game is read from the owning component's `MainContainers`, never taken from another call's return value. Each item's position is its own: the main container in its owner's `MainContainers` that holds it, plus its `ContainerIndex` and `SlotIndex`. The dragged item's owner is the operation's `ItemOwnerComp`, the target's owner the grid's `InventoryComponent`. The widget the item was dragged out of plays no part.

The swap waits for vanilla to finish the drop, so the drag ends the vanilla way and the dragged tile snaps back. Then, carrying only item UIDs, owner components' paths and positions, it runs:

1. clear: the target's slot gets a zero `HostingUID`, so the game sees it free. The target item's own record is untouched.
2. move 1: a validated `RequestMoveItem` of the dragged item onto the target's slot. Both items' records now name that slot.
3. move 2: a validated `RequestMoveItem` of the target onto the dragged item's old slot, which move 1 freed.
4. fix: each of the two slots gets the `HostingUID` of the item now in it, whatever the moves left there.

Each move is called on the moving item's owner with the destination's component as target, so a swap across inventory components goes through the same call. Each step starts once the previous move shows in `MainContainers`, waiting a few ticks at most.

A move that doesn't land stops the sequence and undoes it: move 1 failing restores the target's `HostingUID`. Move 2 failing moves the dragged item back to its old slot, which is still free, and restores the target's `HostingUID`. Either way both items end where they started, and the failure is logged as an error. The hook group's guard covers errors.

`log.debug` reports each swap and each refused candidate with its reason, so a tester can tell "not a swap case" from "hook not firing".

`config.inventory_swap` defaults to `true`: dropping a 1x1 item onto another 1x1 item swaps them, `false` for the vanilla no-op.

### Docs

`README.md` follows `likhos-point-and-shoot`'s README structure: a one-line intro, a feature section on the swap and its limits (1x1 only, storage grids only), then Requirements, Installation, Uninstall and Troubleshooting adapted to the `likhos-backpack` folder and the `[Backpack]` log prefix. `CHANGELOG.md` opens with the first release entry in the other mod's style. The root README mods table lists `likhos-backpack` as pre-alpha, described as Likho's Backpack: inventory handling improvements.

### Observable result

In the inventory, stash or a loot screen, dragging a 1x1 item onto another 1x1 item it can't stack with or go into makes them trade places, across any two grids including between the player and a container. Every other drop behaves as in vanilla.

## Tradeoffs

- Two validated moves around a direct write to slot occupancy, instead of one atomic swap. The game has no general swap call (`CanSwapWeapons` / `FinishSwapWeapons` and `OnPickupSwap` serve weapon slots and pickups), and it refuses a move onto an occupied slot. Chosen over parking the dragged item in a free slot, which fails when every reachable inventory is full, and over a spawned hidden inventory, which needs unexplored actor and grid setup and holds the item in an unsaved actor mid-swap. The costs: the swap writes game data directly and depends on assumption 3. A co-op client's write stays local, so a swap there is expected to fail and undo.
- Every move is validated, so the game applies its own move rules to each step. The `IsContainerSupportingItem` precheck only avoids starting a swap whose moves the game would refuse.
- 1x1 only. Larger items would need footprint and rotation handling across two moves and aren't asked for.

## Open questions

None.
