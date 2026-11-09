# Consume Food/Drink bind

## Intent

A new keybind in Likho's Point and Shoot that eats or drinks the way the vanilla Quick Heal key heals: one press, no inventory screen. Pressing it in game finds the first usable food or drink item in the player's inventory and uses it, with the vanilla use animation and effects. Medical items, adrenaline included, are never picked.

## Constraints and assumptions

- A food or drink item is one whose definition's `ItemIdentifier` tag sits under `Inventory.Items.Provisions.Food` or `Inventory.Items.Provisions.Drinks`. Medical items sit under `Inventory.Items.Medical` (see Recon). Use context, use action and effect stats don't separate the groups.
- The mod only reads game state to pick the item. The one call that changes anything is the item's own use, so a refused or failed use leaves nothing behind.
- Ruled out: running the vanilla Quick Heal ability with its `MedicalItemTags` swapped to food and drink tags. It writes a native tag container from Lua, whose parent tag cache a plain write leaves stale. A missed restore leaves the vanilla Quick Heal key using food until the pawn respawns. And its item choice is native code that no asset describes.
- Ruled out: a second, mod-owned Quick Heal instance. It needs the same tag container writes, a grant on every pawn and its trigger tag kept apart from the vanilla key's.
- Ruled out: using the item through a quick slot. It rewrites the player's quick slots.
- The item is read from the inventory component's `MainContainers` property and passed straight to a UFunction. A `ContainerItem` returned by one UFunction and passed to another crashes the game (`docs/solutions/quick-slot-refill.md`). One read from a property passes fine.
- The item definition's `U_UseInventoryItem_C` context, called with `Execute(pawn, nil, item)`, starts the same use as Use from the context menu, with no item widget (seen in game 2026-11-09). The menu passes the item's widget as `ItemRef`. Native `UItemContext:Execute` runs the context's `ToTriggerActions`, here `IA_UseInventoryItem_C`, which starts its `SGA_UseItem_C` ability.
- The same context's `IsValidContext(pawn, nil, item)` works without an item widget too (seen in game 2026-11-09). It is taken as the menu's own check for offering Use, including whether use is allowed in the current place (`bInGameSupported`, `bHideoutSupported`).
- The owner both calls take is the player's pawn.

## Scope

Owned, all in `likhos-point-and-shoot/`:

- `Scripts/consume.lua` (new)
- `Scripts/actions.lua`: the `ConsumeFoodDrink` entry in `ACTIONS`
- `Scripts/keymap.lua` and `Scripts/menu.lua`: the `LikhosConsumeFoodDrink` mapping and its controls row
- `Scripts/config.lua`: the `consume` bind
- `README.md` and `CHANGELOG.md`

Context only: `input.lua` and `triggers.lua` (key polling and press dispatch on the game thread), `context.lua` (`block_in_ui`), `lib/util.lua`, `lib/log.lua`, the vanilla inventory component and item contexts. `likhos-backpack` is untouched.

## Solution

### `consume.lua`

Owns the bind's whole behavior. Exposes `press()`, run on the game thread by the action. Holds no state and no UObject between presses.

On press it:

1. Resolves the local PlayerController, its pawn and the player's inventory component through `InventoryFunctionLibrary:GetPlayerInventoryComponent(pc)`, as `quick_slots.lua` in the backpack mod does. Any of them missing: logs at debug and does nothing.
2. Walks the inventory in the game's container order: each entry of `comp.MainContainers`, then each item of its `ContainerItems`.
3. Picks the first item that is food or drink by its definition's `ItemIdentifier`, has uses left and whose use context reports itself valid. Uses left is the item's `Inventory.Stats.Durability` entry in `CurrentStats` above 0.
4. Executes that item's use context. The game's own ability plays the animation, applies the effects and removes the item when used up.
5. Finds none: logs at debug and does nothing.

The inventory walk is a small local loop rather than a shared library module. `quick_slots.lua` in the backpack mod has its own iterator, and the two mods share no inventory code.

### `actions.lua`

`ACTIONS.ConsumeFoodDrink` has a `press` only, pointing at `consume.press`, the same shape as `QuickUse`.

### `keymap.lua` and `menu.lua`

`LikhosConsumeFoodDrink` is a mapping with display name `Consume Food/Drink`, unbound by default. `menu.lua` lists it after `LikhosInteractInstant`, so the row shows last in the Likho's Actions section.

### `config.lua`

A fourth bind, `id = "consume"`, `mapping = "LikhosConsumeFoodDrink"`, `action = "ConsumeFoodDrink"`, `block_in_ui = true`, enabled.

### `README.md` and `CHANGELOG.md`

The README has an `Consume Food/Drink` section: one key eats or drinks the first food or drink item found in the inventory, like Quick Heal does for medical items, never using a medical item. The changelog has the entry under the version of the build, with the minor version bumped for the new feature.

### Result

The player binds Consume Food/Drink under Settings > Controls > Likho's Actions. In a raid, pressing it starts eating or drinking the first usable food or drink item in their inventory, with the vanilla animation and effects, and the inventory screen stays closed. With no food or drink, with a menu open, or while the game refuses the use (another use running, in the hideout if the context isn't hideout supported), nothing happens. The vanilla Quick Heal key is unaffected.

## Recon

Sources: cooked assets read with repak and UAssetGUI (usmap of game build 26487830), `UE4SS_ObjectDump.txt` of 2026-11-08 and `CXXHeaderDump`.

### Item tags

`IRRItemDefinition.ItemIdentifier` (`FGameplayTag`), read from the cooked definitions:

- `ID_Canned_Corn`: `Inventory.Items.Provisions.Food.Canned Corn`
- `ID_Water_Bottle`: `Inventory.Items.Provisions.Drinks.Water Bottle`
- `ID_Bandage`: `Inventory.Items.Medical.Bandage`
- `ID_Blood_IV`: `Inventory.Items.Medical.Blood IV`
- `ID_Adrenaline_Injector`: `Inventory.Items.Medical.Adrenaline Injector`

The tag tree follows the asset folders. Food definitions live under `/Game/Blueprints/InventorySystem/Items/Provisions/Food/<Name>/ID_<Name>`: `Canned_BeefStew`, `Canned_Corn`, `Canned_PorkPatey`, `Canned_Sardines`, `Canned_Soup`, `Canned_Squid`, `Canned_TunaMix`, `Chips`, `Cornflakes`, `Peanut_Butter`, `Squid_Chips`. Drinks under `.../Provisions/Drinks/`: `Beer_BiaSaigon_Bottle`, `Beer_Biere_Larue_Can`, `Condensed_Milk`, `Milk`, `Misprinted_Condensed_Milk`, `Water_Bottle`. `PreppedMeal` sits under `Barter` and has no use context.

### Item definitions

- Class `/Script/Test_C.IRRItemDefinition`: `ItemIdentifier`, `ItemProperties`, `ItemStats` (`TArray<FBaseStatItem>`), `ItemContexts` (`TArray<UItemContext*>`).
- Every food and drink definition holds a `U_UseInventoryItem_C` context (named `U_UseItem_C_0`) whose `ToTriggerActions` holds one `IA_UseInventoryItem_C`, plus stats `U_HealOverTime_C`, `U_Content_C` (uses), `U_UsageTime_C`, `U_Weight_C`, `U_InspectItem_C`. All but `Canned_PorkPatey` also hold `U_StaminaBoost_C`.
- Medical definitions hold the same `U_UseInventoryItem_C` and `IA_UseInventoryItem_C`, with effect stats `U_StopWound_C`, `U_StopHeavyWound_C`, `U_StopFracture_C`, `U_PainDebuff_C`, `U_HealInstant_C`, `U_HealOverTime_C` (`Blood_IV`, `Saline_IV`) or `U_StaminaBoost_C` (`Adrenaline_Injector`). Ammunition rounds also hold `U_UseInventoryItem_C`.

### Use path

- `/Script/Test_C.ItemContext`: `bHideoutSupported`, `bInGameSupported`, `ToTriggerActions` (`TArray<UItemAction*>`), `IsValidContext(Owner, ItemRef, Item)`, `ShouldAddToContextList(Owner, ItemRef, Item)`, `Execute(Owner, ItemRef, Item)`. `ItemRef` is a `UItemWidget`.
- `/Game/Blueprints/InventorySystem/Objects/ItemContexts/U_UseInventoryItem.U_UseInventoryItem_C`: overrides `ShouldAddToContextList` and `IsValidContext` only.
- `/Script/Test_C.ItemAction`: `Execute(Owner, ItemRef, ContainerItem)`, `CanStart(Owner, ItemRef, ContainerItem)`, `CanApplyAnyEffect(Owner, ContainerItem)`, `UseCost`, `bDropWhenUsedUp`.
- `/Game/Blueprints/InventorySystem/Objects/ItemActions/IA_UseInventoryItem.IA_UseInventoryItem_C`: `Ability` (`TSubclassOf<USGA_UseItem_C>`), `ItemRef` (`ContainerItem`), `InstigatorRef`, `Execute(Owner, ItemRef, ContainerItem)` overridden.
- `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_UseItem.SGA_UseItem_C`, derived from native `SimpleGameplayAbility_UseItem` (`InventoryItem`, `bDropItemOnFinish`).

### Inventory

- `InventoryFunctionLibrary:GetPlayerInventoryComponent(pc)`, the component's `MainContainers[i].ContainerItems[j]`, an item's `ItemDefinition` and `CurrentStats` (uses under tag `Inventory.Stats.Durability`): as used by `likhos-backpack/Scripts/quick_slots.lua` (`docs/solutions/quick-slot-refill.md`).

### Key profile

- `CXXHeaderDump/EnhancedInput.hpp`: `UEnhancedPlayerMappableKeyProfile` has `PlayerMappedKeys` (`TMap<FName, FKeyMappingRow>`), `ResetMappingToDefault(FName InMappingName)`, `GetMappedKeysInRow(FName, TArray<FKey>&)`. `UEnhancedInputUserSettings` has `GetActiveKeyProfile()`, `UnMapPlayerKey(FMapPlayerKeyArgs, FGameplayTagContainer&)`, `SaveSettings()`.
- Saved to `%LOCALAPPDATA%\Test_C\Saved\SaveGames\EnhancedInputUserSettings.sav`. On 2026-11-09 its rows held `LikhosQuickUse: N`, `LikhosInteractInstant: Backslash` and `LikhosConsumeFoodDrink: N`.

### Quick Heal

Context for the ruled out approaches.

- `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_QuickHeal.SGA_QuickHeal_C` derives from `/Script/Test_C.SimpleGameplayAbility_QuickHeal` and adds nothing. Its class default sets only `TagToTriggerAbility = Character.Abilities.Allowed.Quick Heal`.
- `SimpleGameplayAbility_QuickHeal` members: `TriageOrder` (`TArray<FGameplayTag>`), `MedicalItemTags`, `HealingStatTags`, `PainReliefStatTags` (each `FGameplayTagContainer`), values set in native code.
- Triggered by `IH_QuickHeal_C` (native `InputHandler_TriggerSimpleAbility`) in `/Game/Blueprints/InputSystem/DA_IngameInput.DA_IngameInput`, on input action `IA_QuickHeal`.

## Tradeoffs

- A read only Lua pick over steering the vanilla Quick Heal: no vanilla object is ever written, so the worst failure is a press that does nothing. The cost is that the order is the mod's (first in inventory), not a ranking like Quick Heal's, and the use depends on the context working without an item widget.
- `ItemIdentifier` tag over the definition's asset folder: the tag is the game's own classification and survives an asset move. A food item tagged outside `Inventory.Items.Provisions` is never picked.
- The item's own use context over starting `SGA_UseItem_C` directly: the game's checks, ability, animation and effects stay its own.
- First in container order over a preference such as partly used items first or food before drinks: simplest, but which equipment comes first is the game's container order, not one the player picks.
- A local inventory walk over moving `inventory_items` from `quick_slots.lua` into `lib/`: a few lines duplicated across the two mods, and the backpack mod stays untouched.
