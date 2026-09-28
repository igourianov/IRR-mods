# Hideout quick sell

## Intent

In the hideout, Shift+Click on an inventory item sells it, the same as picking Sell from its context menu. In raid, Shift+Click drops the item and that stays as it is. In the hideout vanilla Shift+Click does nothing, so the feature takes no vanilla behavior away.

## Constraints and assumptions

- Vanilla's context menu actions are `UItemContext` subclasses, among them `U_Sell_C` (`/Game/Blueprints/InventorySystem/Objects/ItemContexts/U_Sell.U_Sell_C`) and `U_Drop_C`. Each has `ShouldAddToContextList(Owner, ItemRef, Item)`, `IsValidContext(Owner, ItemRef, Item)` and `Execute(Owner, ItemRef, Item)` with `Owner: AActor`, `ItemRef: UItemWidget`, `Item: FContainerItem`. `UItemContext` carries `bHideoutSupported` and `bInGameSupported`. Source: `CXXHeaderDump/U_Sell.hpp`, `Test_C.hpp` `UItemContext`.
- The one live Sell instance is `/Game/Blueprints/InventorySystem/Settings/DA_InventoryUISettings.DA_InventoryUISettings:U_Sell_C_0`, held in `UInventoryEnhancedUISettings.ItemDefaultContexts` of that data asset. Source: `UE4SS_ObjectDump.txt`.
- Inventory item tiles are `W_InventoryItem_C` (`/Game/Blueprints/InventorySystem/Widgets/W_InventoryItem.W_InventoryItem_C`, a `UItemWidget` subclass). Its Blueprint overrides `OnMouseButtonDown(MyGeometry, MouseEvent)`. `UItemWidget` holds `ContainerItem` and `OwnerInventoryComp`.
- Vanilla Sell in the hideout sells the whole item or stack on click, with no dialog (user confirmed).
- Selling goes through vanilla's `U_Sell_C`, not `UVendorComponent:RequestSellItem` directly. Vanilla's context then decides validity, price and the save, and the mod holds no sell logic of its own.
- Whether Shift+Click sells is decided by vanilla's own Sell context checks, not by a mod-side hideout test. In raid Sell is not offered, so Shift+Click falls through to vanilla's drop untouched.
- UE4SS does not pass the hook's `MouseEvent` (`FPointerEvent`) to a function taking its parent `FInputEvent`: "Can't copy struct of type PointerEvent into InputEvent". So Shift is not read from the event through `InputEvent_IsShiftDown`. It is read from Slate's current modifier state, `KismetInputLibrary:GetModifierKeysState()`, whose `FSlateModifierKeysState` has one reflected field, `ModifierKeysStateMask`. The mask's bit layout is engine-internal, so it is decoded by `ModifierKeysState_IsShiftDown`, given a fresh struct built from the mask rather than the returned one, which the code guide warns against passing on.
- **Unverified:** the left button can be read from the `MouseEvent` through `KismetInputLibrary:PointerEvent_GetEffectingButton`, whose parameter type matches it exactly.
- **Unverified:** the `Owner` vanilla passes to the Sell context is the widget's owning PlayerController. The build confirms it by logging what the context menu passes when Sell is picked there.
- **Unverified:** vanilla's Shift+Click in the hideout issues no other action on the item that would race the sell.

## Scope

Owned, all in `likhos-backpack`:

- `Scripts/quick_sell.lua`: the feature.
- `Scripts/main.lua`: installs it behind its config flag.
- `Scripts/config.lua`: the `quick_sell` flag.
- `README.md`: a section for the feature.

Context only: `lib/hook.lua`, `lib/util.lua`, `lib/log.lua` (used as they are), the game's `W_InventoryItem_C` and `U_Sell_C`.

## Solution

### `quick_sell.lua`

Follows the shape of `medic.lua`: one `hook.new("quick sell", "Shift+Click stays vanilla")` group created at module load and `M.install()` that hooks a Blueprint function once its class loads. Holds no UObject between calls.

- Hooks `W_InventoryItem_C:OnMouseButtonDown`, deferred until `W_InventoryItem_C` loads.
- On a left-button press, read from the click event, with Shift down, read from Slate's modifier state, it takes the clicked tile's `ContainerItem` and the owning player as `Owner`, and finds vanilla's `U_Sell_C` instance.
- It sells only when that Sell context passes both `ShouldAddToContextList` and `IsValidContext` for this owner, tile and item, so Shift+Click sells exactly the items the context menu offers Sell for. Otherwise it does nothing and vanilla handles the click.
- The sell is `Execute` on that context, run after vanilla's click handler has returned, since selling removes the clicked tile. Before selling it confirms the clicked tile still shows the same item.
- A missing class or function logs once through the hook group and leaves Shift+Click vanilla.
- Log lines: `debug` for each Shift+Click decision (sold, not offered), `error` only through the hook group.

### `config.lua`

`quick_sell = true`, with a comment in the style of the other flags: Shift+Click on an item in the hideout sells it, set false for the vanilla behavior where it does nothing.

### `main.lua`

`if config.quick_sell then quick_sell.install() end`, alongside the other features.

### `README.md`

A "Quick sell" section after "Whole use counts": Shift+Click an item in the hideout to sell it, the same as Sell from its context menu. Items the context menu doesn't offer Sell for are not affected. Shift+Click in raid still drops. How to turn it off.

### Result

In the hideout, Shift+Click on an item tile in the stash or character inventory sells it at vanilla's price, as if Sell was picked from its menu. Items that can't be sold, where vanilla's Sell context rejects them or the menu has no Sell entry, ignore Shift+Click as before: no sell, no message. In raid nothing changes.

## Tradeoffs

- **Vanilla `U_Sell_C` over `VendorComponent:RequestSellItem`.** Reuses vanilla's rules and any side effects of its Sell (price, UI refresh, save, `OnItemsSold` objectives). Costs a dependency on a Blueprint class path and on finding its instance. Calling `RequestSellItem` directly would skip vanilla's validity checks and need the FContainerItem passed into a native call, which the code guide flags as crash-prone.
- **No confirmation.** Matches vanilla Sell, which has none. A stray Shift+Click sells an item irreversibly. The config flag is the escape hatch.
- **Hooking the tile's click handler over hooking vanilla's in-raid drop path.** The drop path is inside the Blueprint graph and not visible in the dump. The click handler is a named override on the tile, independent of how vanilla routes the drop.
