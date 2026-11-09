# Dedicated container loot

## Intent

The game added case items that hold one class of items: ammo, attachments, keys, intel, medical items, weapons, plus a general item case. Ctrl+Click on an item in a loot container or the stash moves it into the player's inventory. Vanilla puts it in the first free generic grid and uses a case only once the generic grids are full. The player wants Ctrl+Click to put the item into a matching case in their inventory first, when one has room, topping up matching stacks there before taking free space. Generic placement applies only when no case takes it.

The general item case takes sellable loot: what in-raid vendors accept.

## Constraints and assumptions

Constraints:

- Game class, function, property and tag names come from a UE4SS dump, Live View or the cooked assets, and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, no UObject is held between clicks and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The feature lives in `likhos-backpack` as a module toggled in its config, alongside the other inventory features.
- Direction: only loot container or stash to player. A Ctrl+Click on an item in the player's own inventory stays vanilla. Ruled out: a case first rule for player to loot container or stash. The player does not need it.
- Dedicated is read from game data, not from a list of case definitions, so a case the game adds later works with no config edit. Ruled out: a config list of case item definitions.
- Grids of equipped gear (backpack, rig, belt, pockets) are never dedicated. They are vanilla's generic placement, including rig pouches restricted to mags and ammo. Only grids of an item stored inside another grid are candidates.
- The mod moves the item before vanilla's Ctrl+Click runs. Ruled out: letting vanilla place the item and then moving it into a case. The item would show in a generic slot for a moment, and it takes two moves.
- UE4SS cannot skip a hooked Blueprint function. Vanilla's Ctrl+Click still runs after the mod has acted.
- Vanilla's quick loot places an item into a case when the player's generic grids are full (seen in game by the user). So a case grid is a valid move target for the player's inventory component.
- Stacking wins over free space: within the case order, a matching stack with room is topped up before any free slot is used.
- A struct returned by a UFunction call crashes the game when passed to another UFunction, and UE4SS crashes converting a `ContainerItem` returned by a UFunction (`docs/solutions/quick-slot-refill.md`). Items passed to a move or stack are read from a component's `MainContainers`.
- Supported item tags are hierarchical, and a grid's `SupportedItems` accepts an item whose tag is one of them or under one of them. Read from the cooked assets 2026-11-08 (repak and UAssetGUI with the current usmap):
  - Generic gear grids list `Inventory.Items` (`ID_AVS_Delta_Back` uses `UISI_AllItems`). Rig mag pouches list `Inventory.Items.Attachments.Mag` and `Inventory.Items.Ammunition` (`UISI_Mags`).
  - `ID_Ammo_Case`: `Inventory.Items.Ammunition` (`UISI_Ammunition`).
  - `ID_Attachment_Case`: `Inventory.Items.Attachments` (`UISI_Attachments`). It also takes mags, which sit under it.
  - `ID_Medical_Case`: `Inventory.Items.Medical` (`UISI_Medicals`).
  - `ID_Weapon_Case`: `Inventory.Items.Weapons` (`UISI_Weapons`).
  - `ID_Key_Intel_Case`: `Inventory.Items.Keys` (`UISI_Keys`) and specific quest item tags (`UISI_Intel`): `Inventory.Items.Quest.Defense.Intel A` to `D`, `Defense.Intel Fang`, `Operation Plans`, `Shipping Manifest`, `Troop Movement Paper`, `USB Drive`, `Classified Document-IGC`, `-VLF`, `-UICS`, `Construction HxAxS Blueprint Materials List`, `Construction HxAxS Blueprint Layout Guide`, `Key Cards`, all under `Inventory.Items.Quest`.
  - `ID_Item_Case`: `Inventory.Items` (`UISI_AllItems`), as broad as the backpack.
- In-raid vendors accept `Inventory.Items.Barter`, `Inventory.Items.Quest.Weapon Crate`, `Inventory.Items.Quest.Data Storage Crate` and `Inventory.Items.Quest.Chemical Crate` (`BP_RaidTrader` `AcceptedPlayerItems`). The faction traders `BP_RaidTrader_IGC`, `_UICS_Outskirts`, `_UICS_Quarry` and `_VLF` do not override it. No vendor exists in the hideout, so the list cannot be read there at click time.

Assumptions, unverified:

1. Vanilla's Ctrl+Click on a tile whose item has fully left the source component does nothing: no second move, no duplicate, no move back. The build checks this first with debug output. If it fails, the design goes back to the design loop.
2. When the mod stacks only part of an item, vanilla's Ctrl+Click then acts on the remainder left in the source, not on the count the tile showed at the click.
3. `RequestMoveItem` and `RequestStackItem` on the host (single player) apply before they return, so the source reflects them by the time vanilla's `RequestQuickLoot` runs in the same click handler, and the mod can read the remainder between steps.
4. A case's grids are main containers of the player's inventory component whose `MainContainerUID` is the case's `ItemUID`. A stored case sits in a spatial grid, not an equip-to slot (`EContainerType` `Container` 1 vs `EquipTo` 0). Held for equipped gear in `quick-slot-refill.md`.
5. A grid's tags are readable at runtime from its `ContainerElements` entry's `ContainerSettings`, matching the cooked values above, and the clicked item's own tag is readable from its definition for the specificity ranking.
6. `CanAddItemToMainContainer` and `CanStackItem` are callable from Lua with items and main containers read from `MainContainers`, and report placement (container and slot index) and stack room.
7. The stash in the hideout opens in the same `W_PlayerInventory` as a loot container, and Ctrl+Click on a stash item goes through the same `W_InventoryItem_C:OnMouseButtonDown` path.

Names from `CXXHeaderDump` and `UE4SS_ObjectDump.txt` (dumped 2026-11-06 and 2026-11-08, after the 2026-11-06 game update, read 2026-11-08):

- Vanilla Ctrl+Click: `/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C:OnMouseButtonDown` checks `KismetInputLibrary:ModifierKeysState_IsControlDown`, then calls `RequestQuickLoot(UItemWidget* ItemRef)` (`InventoryWidgetInterface`) on `W_PlayerInventory_C`. That calls `GetInventoryComponent` twice, compares the two and calls native `/Script/Test_C.InventoryComponent:TryQuickLoot(UItemWidget* ItemRef)`, returning `bool`. `quick_sell.lua` hooks the same `OnMouseButtonDown` for Shift+Click and reads the mouse button and modifiers there.
- `/Script/Test_C.InventoryComponent`:
  - `MainContainers` (`TArray<FMainContainer>`). `FMainContainer`: `MainContainerUID`, `ContainerElements` (`TArray<FContainerElement>`), `ContainerItems` (`TArray<FContainerItem>`).
  - `QuickLootOrder` (`TMap<FGameplayTag, FQuickLootOrder>`, `FQuickLootOrder.Order` is `TArray<int32>`). Vanilla's per item class order of main container indexes for quick loot.
  - `RequestMoveItem(UInventoryComponent* ItemOwnerComp, UInventoryComponent* TargetComp, FContainerItem Item, FGuid NewMainContainerUID, int32 NewContainerIndex, int32 NewSlotIndex, bool bIsRotated, bool bValidate, UIRRItemDefinition* ReplaceWith)`.
  - `RequestStackItem(UInventoryComponent* RootComp, UInventoryComponent* TargetComp, FContainerItem RootItem, FContainerItem ToAddItem, int32 StackAmount)`.
  - `CanStackItem(FContainerItem& RootItem, FContainerItem ToAddItem, int32& StackAmount)` returns `bool`.
  - `CanAddItemToMainContainer(FMainContainer& MainContainer, FContainerItem& ContainerItem, bool bAddToDescendants, bool bTryRotated, bool bIgnoreVitalParts, int32& OutContainerIndex, int32& OutSlotIndex)` returns `bool`.
- `FContainerElement`: `ContainerSettings` (`UInventoryContainerSettings*`), `ContainerSlots`, `ContainerTier`.
- `/Script/Test_C.InventoryContainerSettings`: `SupportedItems` (`TArray<UInventorySupportedItems*>`, each with `SupportedItems` `FGameplayTagContainer`), `GetSupportedItems()` returns `FGameplayTagContainer`, `GetContainerType()` returns `EContainerType` (`EquipTo` 0, `Container` 1, `Storage` 2).
- `FContainerItem`: `ItemInventoryComp`, `ItemDefinition`, `ItemUID`, `MotherUID`, `ContainerIndex`, `SlotIndex`, `bRotated`, `Count`, `CanStack`, `MaxStack`.
- `/Script/Test_C.IRRItemDefinition`: the item definition. `TODO_` the property holding the item's own tag. Not settled from the dump; the build finds it.
- `/Script/Test_C.InventoryFunctionLibrary`: `GetPlayerInventoryComponent(UObject* WorldContextObject)`.
- Case items, under `/Game/Blueprints/InventorySystem/Items/Containers/`: `Ammo_Case/ID_Ammo_Case`, `Attachment_Box/ID_Attachment_Case`, `Item_Case/ID_Item_Case`, `Key_Intel_Case/ID_Key_Intel_Case`, `Medical_Case/ID_Medical_Case`, `Weapon_Case/ID_Weapon_Case`. Each has its own spatial grid (`ItemSpatialContainer_1`). The mod does not name them.
- Supported item assets: `/Game/Blueprints/InventorySystem/Objects/InventorySupportedItems/General/...` (`UISI_*`), referenced by the grids' settings.
- In-raid vendor: `/Game/Blueprints/InventorySystem/BaseActors/Trader/BP_RaidTrader` (`/Script/Test_C.RaidTrader`) `AcceptedPlayerItems` (`FGameplayTagContainer`).

## Scope

Owned:

- `likhos-backpack/Scripts/quick_loot.lua`, new.
- `likhos-backpack/Scripts/main.lua`: installs the module when its config flag is on.
- `likhos-backpack/Scripts/config.lua`: the `quick_loot_cases` flag and the `sellable_loot` tag list.
- `likhos-backpack/README.md`: a section describing the feature.

Context only: `lib/` (`log`, `util`, `hook`), `quick_sell.lua` (same click anchor and modifier reading), `quick_slots.lua` (inventory reading patterns), vanilla quick loot.

## Solution

`quick_loot.lua` installs a pre-hook on `W_InventoryItem_C:OnMouseButtonDown` through a `hook` group, as `quick_sell.lua` does. The hook acts only on a left click with Ctrl held, on a tile whose item belongs to an inventory component other than the player's. Anything else returns at once and vanilla runs as usual.

On such a click the module, inside the handler and before vanilla's `RequestQuickLoot`:

- Resolves the player's inventory component through `GetPlayerInventoryComponent`, and reads the clicked item from the source component's `MainContainers` by the tile's item UID.
- Collects the candidate grids: main containers of the player's component owned by an item that sits in a spatial grid of the player's inventory, i.e. a stored case, at any nesting depth. Grids of equipped gear are not candidates. Only grids whose tags accept the item's tag stay.
- Orders the candidates in two tiers:
  - Class grids: candidates that do not list the generic tag `Inventory.Items`. Those accepting the item through a more specific tag come first (an attachment case before an item case, for a mag), then inventory order.
  - Broad grids: candidates that list `Inventory.Items`, such as the general item case. They stay only when the item's tag is one of, or under one of, the `sellable_loot` tags in config.
- Places as much of the item as it can, in two passes over the ordered grids:
  - Stacks: matching stacks with room in any candidate grid, through `CanStackItem` and `RequestStackItem`. After each partial stack it rereads the remainder in the source and goes on with it.
  - Free space: the first grid with room for the remainder, through `CanAddItemToMainContainer` without descending into nested containers, then `RequestMoveItem` from the source component to the player's component at the reported container and slot index, with validation on.
  - It stops once the item has left the source or no grid takes more.

What the mod could not place stays in the source, and vanilla's Ctrl+Click then handles it as before, cases last (assumption 2). When the whole item went into cases, vanilla's Ctrl+Click finds it gone and does nothing (assumption 1).

`config.lua` holds `sellable_loot`, a copy of the in-raid vendors' `AcceptedPlayerItems` (the four tags above), because no vendor exists in the hideout. It is refreshed by hand when a patch changes what vendors accept. It also holds the `quick_loot_cases` flag, documented with the vanilla behavior it falls back to. `main.lua` installs the module when the flag is true.

The player sees: with an ammo case and a medical case in the backpack, Ctrl+Click on a box of rounds in a loot crate tops up the matching stack in the ammo case, and the rest fills free space in the ammo case, even with free pockets. A bandage goes into the medical case. A barter item from the stash goes into the item case. A rifle, with no weapon case on the player, goes to generic space as before. With the ammo case full, rounds go to generic space.

The module logs at debug level each Ctrl+Click it handles: the item and its tag, the candidate grids with their tags and tier, each stack and move it made, and what it left to vanilla.

## Tradeoffs

- Pre-empt over relocate after vanilla: one move, no flicker, at the cost of relying on vanilla ignoring a tile whose item is gone and acting correctly on a remainder (assumptions 1 and 2).
- Data rule over a case list: a new case works with no config edit. A new case as broad as the backpack lands in the broad tier and takes only sellable loot. A backpack stored inside the backpack is also a broad candidate for sellable loot.
- Equipped gear never dedicated: rig pouches keep vanilla's quick loot order, and the rule needs no exception for them.
- Sellable loot as a config copy of vendor tags: works in the hideout, but goes stale when a patch changes what vendors accept.
- Stacking before free space, across all case tiers: a partial stack in a case is filled before a free slot in a more specific case. Fewer half stacks, at the cost of the mod issuing several stack calls per click.
- No descent into nested containers: a case inside a case is a candidate of its own, so the order stays the mod's, not vanilla's.
