# Quick slot refill

## Intent

A quick slot binds an item type, not a single item. When the item bound to a quick slot is used up and leaves the inventory, the slot rebinds to another item of the same type from the same equipment, e.g. the next Morphine on the chest rig. The slot stays usable until that equipment holds no more of the type. Today the slot empties after one use and the player has to open the inventory and drop another item into it.

For single use items the quick slot shows how many of its type that equipment holds, so the player sees how many uses the slot has left. With 3 injectors on the chest rig, each injector's inventory tile still shows 1/1 and the quick slot shows 3.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from a UE4SS dump or Live View and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, no UObject is held across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The feature lives in `likhos-backpack` as a module toggled in its config, alongside the other inventory features.
- "Same type" means the same item definition (`ContainerItem.ItemDefinition`).
- "Same equipment" means the root container the used item sat in: the equipped item (chest rig, backpack) or the character's own container (pockets) whose grids hold it at any nesting depth. The replacement comes only from there.
- A refill happens only when the bound item leaves the player's inventory used up: a poll saw it at 0 uses before it left, or the player runs an item use ability as it leaves (a quick slot use, an item or medic use, a grenade throw or a quick heal). An item with uses left that leaves with no use running was dropped, discarded or sold, so the slot stays empty, and so does a slot the player clears or rebinds by hand while its item is still in the inventory.
- Seen in game 2026-11-08 (log): a used Morphine and a used Adrenaline injector each read 0 uses on a poll about 260 ms before they left the inventory, and when they left the only active ability was `SGA_EquipMelee_C`. The use ability had already ended, so for items with a uses stat the ability check alone never refills. Polled every 250 ms, two of five Adrenaline uses left without a poll seeing them at 0, so the window is too close to that interval. A thrown grenade left while `SGA_GrenadeThrow_OverArm_C` was active.
- Seen in game 2026-11-08 (frame by frame trace): a used item stays at its grid position until it leaves the player's inventory, early in its use, and the game deletes its `QuickSlots` entry at that moment. While in the hands it is in no inventory component. A used injector shows up in `VicinityInventory` (the floor items around the player) about 1.6 s later through its `Drop` notify. A slotted item dragged to the floor also leaves to no inventory first and shows up in `VicinityInventory` about 0.2 s later.
- Ruled out: telling a use from a deliberate drop by where the item is or goes. It never sits in an equipment slot during a use, and both end in no inventory, then on the floor. Ruled out: refilling only while no inventory screen is open. The player can open the inventory during a use. Ruled out: refilling only after a press of the slot's key. It needs a hook on the quick slot ability and misses a use from the inventory's context menu.
- No memory outlives the refill moment. Once the last item of the type is gone the slot empties as in vanilla and stays empty. Ruled out: a slot that remembers its type and re-arms when more of it is picked up later. It needs per-slot state that survives raids and saves, and a way for the player to forget it.
- The quick slot use path stays vanilla. The mod rebinds the slot, it does not redirect the use. Ruled out: hooking the quick slot use to use another item than the bound one. The use ability is native (`SimpleGameplayAbility_UseQuickSlot`) and resolves its item by slot index internally, so a redirect amounts to rebinding the slot at key press, and the slot would show empty between uses.
- Detection is a game thread poll of the quick slots, not an event hook. Ruled out: hooking the quick slot widget's item removal (`W_QuickSlotContainer_C:HandleItemRemoved`). The quick slot bar exists only inside the inventory screen (`W_PlayerInventory`, the only owner of `W_QuickSlotBar` in the dump), so it may not be constructed in a raid where the inventory was never opened. Ruled out: hooking the inventory's removal functions. Items leave the inventory through several paths (consume, drop, throw), some of them native calls a hook does not see.
- A struct returned by a UFunction call crashes the game when passed to another UFunction (finding behind `inventory_swap.lua`). The replacement item passed to `UpdateQuickSlot` is read from `MainContainers`.
- UE4SS crashes the game converting a `ContainerItem` returned by a UFunction to Lua, at its `SoftItemDefinition` (seen in game 2026-11-08 with `GetContainerItemByQuickSlotIndex`, an access violation in `push_softobjectproperty`). No UFunction returning a `ContainerItem` is called. Slots are read from the `QuickSlots` property and items from `MainContainers`.
- A single use item is one whose definition's uses stat (the `ItemStats` entry with a `U_Content_C` config) has a value of 1, or one with no uses stat that does not stack. From the game's assets 2026-11-08: health injector, morphine injector and bandage have 1, the MFAK has 6. Grenades have no uses stat. Multi use items (MFAK, painkillers) keep the vanilla quick slot text.
- The count covers only the quick slot's tile. Inventory tiles keep the vanilla text, and `whole_uses.lua` keeps rounding them.
- The quick slot tiles exist only inside the inventory screen (see the quick slot UI names below), so the count is visible only there.
- Ruled out: hooking the tile redraw (`ItemWidget.K2_UpdateItemCount`, as `whole_uses.lua` does) to write the count. The count changes when an item of the type is added or removed anywhere in the equipment, which redraws no quick slot tile, so the poll is needed anyway. One mechanism is kept.

Assumptions, unverified:

1. `UpdateQuickSlot(Index, Item)` on the player's inventory component binds the item to the slot the same way a drag and drop does: the inventory screen shows it, the slot key uses it and the binding is saved with the inventory.
2. An empty quick slot has either no `QuickSlots` entry or one with a zero `ItemUID`.
3. A used item with uses left (a painkiller pack) keeps its UID, and a partly used stack keeps its UID until its count reaches zero, so neither reads as gone.
4. `InventoryFunctionLibrary.GetPlayerInventoryComponent`, given the player controller, returns the inventory that holds the quick slots, and nothing valid outside a level with a player.
5. A used item with a uses stat stays in the inventory at 0 uses for longer than one poll interval before it leaves, for every such item a quick slot takes. A grenade, which has no uses stat, leaves while an ability derived from a class in the use ability list below is in the player's `ActiveAbilities`. During a deliberate drop, discard or sale none is.
6. A container item's own grids are main containers whose `MainContainerUID` is its `ItemUID`, and an equipped item sits in an equip-to container (`ContainerSettings:GetContainerType()` 0), so the walk up from an item's grid stops at the chest rig or backpack it is in.
7. A quick slot's tile is the `W_InventoryItem_C` whose `BaseContainerElementRef` is that slot's `W_QuickSlotContainer_C` and whose `ContainerItem` is the bound item, and the container's `QuickSlotIndex` is the slot's `QuickSlots` index. Seen in game 2026-11-08: a tile read from the container's `ItemRef` was never written, and `GetContainerItems()` returns an empty array to Lua. `W_QuickSlotContainer_C` overrides `AddItem` and `GetContainerItems` of `W_EquipToContainer_C`.
8. On a tile, `ItemCapacity` shows the uses left and `ItemMaxCapacity` the maximum together with its separator, so the count in `ItemCapacity` with `ItemMaxCapacity` empty reads as a bare number. A grenade tile has `ItemCapacity` hidden or collapsed, and making it visible shows the count where an injector's would be.
9. The game writes a tile's texts only on its own redraw events, so text the mod writes stays until the next redraw.

Names from `CXXHeaderDump` (dumped 2026-11-06, read 2026-11-08):

- `/Script/Test_C.InventoryComponent`:
  - `QuickSlots` (`TArray<FQuickSlotItem>`). `FQuickSlotItem` holds `Index` (`int32`) and `ItemUID` (`FGuid`). The same array is saved in `InventorySaveGame.QuickSlots`.
  - `UpdateQuickSlot(int32 Index, FContainerItem Item)`.
  - `GetContainerItemByQuickSlotIndex(int32 Index)` returns `FContainerItem`. Not callable from Lua, see constraints.
  - `MainContainers` (`TArray<FMainContainer>`), each with `MainContainerUID` and `ContainerItems`. A container item's own grids are main containers whose `MainContainerUID` is its `ItemUID` (`inventory_swap.lua`).
  - `OnQuickSlotsUpdated` multicast delegate, bound by the quick slot widgets.
- `/Script/Test_C.InventoryFunctionLibrary` (Blueprint function library): `GetPlayerInventoryComponent(UObject* WorldContextObject)` returns `UInventoryComponent*`.
- `/Script/Test_C.ContainerItem`: `ItemDefinition` (`UIRRItemDefinition*`), `ItemUID`, `MotherUID`, `ContainerIndex`, `SlotIndex`, `CurrentStats`, `Count`, `CanStack`.
- Quick slot use: input handlers `IH_EquipQuickSlot_0_C` to `IH_EquipQuickSlot_3_C` (`InputHandler_TriggerSimpleAbility`) trigger abilities `SGA_EquipQuickSlot_0_C` to `SGA_EquipQuickSlot_3_C`, derived from `SGA_EquipQuickSlot_C` (overrides `CanStartAbility`), derived from native `SimpleGameplayAbility_UseQuickSlot` (`QuickSlotIndex`). Four slots, indexes 0 to 3.
- `/Script/Test_C.GameplayAbilityComponent`, a component of the player pawn: `ActiveAbilities` (`TArray<USimpleGameplayAbility*>`).
- Use ability list, the classes whose subclasses take an item out of the inventory by using it:
  - `/Script/Test_C.SimpleGameplayAbility_UseQuickSlot` (parent of `SGA_EquipQuickSlot_C`).
  - `/Script/Test_C.SimpleGameplayAbility_UseItem` (parent of `SGA_UseItem_C`, holds `InventoryItem`).
  - `/Script/Test_C.SimpleGameplayAbility_ThrowGrenade` (parent of `SGA_Grenade_Throw_UnderArm_C`, `SGA_GrenadeThrow_OverArm_C`).
  - `/Script/Test_C.SimpleGameplayAbility_QuickHeal` (parent of `SGA_QuickHeal_C`).
  - `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_UseMedic.SGA_UseMedic_C`, derived from `SimpleGameplayAbility` directly. Parent of the medical item abilities (`docs/solutions/medic-drop.md`).
  - Not listed: `SimpleGameplayAbility_EquipGadget` (`SGA_EquipGadget_C`), which may stay active while the player merely holds a gadget.
- `VicinityInventory`: an inventory component on a level actor holding the floor items around the player (seen in game, path `Actor_<n>.VicinityInventory`).
- Quick slot UI: `W_PlayerInventory_C.W_QuickSlotBar` holds four `W_QuickSlotContainer_C` (`QuickSlotIndex`, `HandleItemRemoved`, `OnQuickSlotsUpdated_Event`, `GetQuickSlotItemUID`, `GetContainerItems()` returning `TArray<UItemWidget*>`, `AddItem`), derived from `W_EquipToContainer_C` (`ItemRef`) and native `QuickSlotContainerWidget`. `W_PlayerInventory_C` is the only owner of `W_QuickSlotBar` in the dump.
- Item tile: `W_InventoryItem_C`, derived from native `ItemWidget`, which holds `ContainerItem`, `BaseContainerElementRef` (`UContainerElementWidget*`, set by `InitItem`; `EquipToContainerWidget` derives from `ContainerElementWidget`), the text blocks `ItemCapacity` and `ItemMaxCapacity` (the only text blocks of the tile besides `ArmorTierText` and `CaliberText`) and `K2_UpdateItemCount`. Text block visibility is engine `ESlateVisibility` (`Collapsed` 1, `Hidden` 2, `HitTestInvisible` 3).
- `UIRRItemDefinition.ItemStats` (`TArray<FBaseStatItem>`: `Value`, `StatItemConfig`) and `ItemProperties.CanStack`. The uses stat's config class is `U_Content_C` (`whole_uses.lua`).

## Scope

Owned:

- `likhos-backpack/Scripts/quick_slots.lua`, new.
- `likhos-backpack/Scripts/main.lua`: installs the module when its config flag is on.
- `likhos-backpack/Scripts/config.lua`: the `quick_slot_refill` flag.
- `likhos-backpack/README.md`: a section describing the feature.

Context only: `lib/` (`log`, `util`, `hook`), `inventory_swap.lua` (the inventory reading patterns it follows), `whole_uses.lua` (the uses stat check and tile texts it follows), the game's quick slot use and UI.

## Solution

`quick_slots.lua` refills the quick slots. `install()` starts its poll once, guarded so a hot reload does not start a second one, following the loop in `likhos-point-and-shoot/Scripts/main.lua` but on `LoopInGameThreadWithDelay` at a fixed interval well inside the 0 uses window, about 50 ms. The tile count runs on every few polls only, a few times a second. The poll runs inside `util.safe`.

Per slot, the module keeps a record of the last live binding: the bound item's UID, its item definition's path, the UID of its root container and the item's uses left at the last poll. The record holds plain Lua values, no UObject. It also keeps the path of the inventory component the records came from.

Each poll:

- Resolves the player's inventory component through `GetPlayerInventoryComponent`. When there is none, or it differs from the recorded one (level load, respawn), the records reset and the poll ends. The next poll seeds them, so a load never reads as a used up item.
- For each slot index 0 to 3, reads the slot's `QuickSlots` entry and looks its UID up in `MainContainers`, in one pass for all slots. A slot whose item resolves is live. When its item differs from the record, the record is rewritten from it, root container included. That covers a player binding a new item or rebinding by hand. The root is taken only when a binding is first seen.
- A slot that is dead now and has a record is checked once, and the record is dropped: if the recorded UID is still in the inventory, the player cleared the slot by hand. If the item was not seen at 0 uses and none of the player's active abilities derives from a class in the use ability list, the player dropped, discarded or sold the item. Either way the slot stays empty. Otherwise the module looks in the recorded root container for an item with the recorded definition, preferring the one with the fewest uses left (`Inventory.Stats.Durability` in `CurrentStats`) so partly used items are finished first. Items without a use count are taken in container order. When one is found it binds it with `UpdateQuickSlot` and the record follows the new item. When none is found the record is dropped and the slot stays empty.

After the slots are checked, the same poll writes the count into the quick slot tiles that exist, which is while the inventory screen is open. For each `W_QuickSlotContainer_C` whose slot has a live record of a single use definition, it counts the items of the recorded definition under the recorded root, the bound one included, and shows that number on the container's tile in place of the uses: the number in `ItemCapacity`, made visible when the game hid it, and `ItemMaxCapacity` empty. Only texts and the hidden `ItemCapacity` change, which the game's own redraw sets again for whatever item the tile shows next. A tile already showing the count is left alone, so the text is written only after the game redraws the tile or the count changes. A tile of a multi use item, of a slot without a record or still showing another item than the record's is not touched. Widgets are found anew each poll and not held.

`main.lua` installs the module when `config.quick_slot_refill` is true, like the other features. The flag covers both the refill and the count. `config.lua` documents the flag with the vanilla behavior it falls back to.

The player sees: bind a Morphine to slot 6 from the chest rig, use it, and the slot holds the next Morphine from the chest rig within a fraction of a second, with no inventory screen involved. Once the chest rig has no Morphine left the slot is empty. Morphine in the backpack does not refill a slot bound from the chest rig. Dropping the bound Morphine on the floor from the inventory leaves the slot empty. In the inventory screen the slot shows 3 while the chest rig holds 3 Morphine, where each Morphine tile shows 1/1, and the number follows as Morphine is used, added or moved out.

The module logs each binding, refill and empty-out at debug level, naming the slot, the definition and the root container.

## Tradeoffs

- Poll over event hook: a refill lags the use by up to one poll interval and the module spends a few property reads per poll while idle, about 20 times a second for the 0 uses window. In return every way an item can leave the inventory is covered with one anchor that needs no Blueprint class loaded.
- Used up evidence over refilling on any exit: a deliberate drop does not rebind the slot. The cost is two signals. The 0 uses reading depends on the game keeping a spent item for longer than one poll interval, and a removal the poll misses at 0 leaves the slot empty. The ability check, for grenades, depends on a fixed class list: a use through an ability missing from it leaves the slot empty, and an item that leaves the inventory by any means during a use refills its slot. The list is read only when a slot dies.
- Rebind over redirect: the slot always shows a real item and the use path stays vanilla. The cost is that the slot's binding changes under the player, which is the requested behavior.
- No type memory: a slot emptied by its last item does not come back when more of the type is picked up. Simple, nothing to save.
- Count written by the poll over a tile redraw hook: one mechanism that also follows count changes no redraw announces. The cost is that a redrawn quick slot tile, e.g. when the inventory opens, shows the vanilla 1/1 for up to one poll interval before the count, and once the inventory screen has been opened the poll looks through every item tile on each pass while a single use item is bound.
- Fewest uses first over container order: partly used items are spent before fresh ones, at the cost of reading each candidate's stats. Candidates share one definition, so `Inventory.Stats.Durability`, which weapons and armor also use for durability, means the same thing across them.
