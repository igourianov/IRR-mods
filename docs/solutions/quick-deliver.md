# Quick deliver

## Intent

Extends hideout quick sell (`docs/solutions/hideout-quick-sell.md`). A mission item's context menu offers Deliver and no Sell, so Shift+Click did nothing on it. Shift+Click on a mission item in the hideout now delivers it, the same as picking Deliver from its context menu. Every other item keeps quick sell as it was.

## Constraints and assumptions

- Vanilla's Deliver action is `U_Deliver_C` (`/Game/Blueprints/InventorySystem/Objects/ItemContexts/U_Deliver.U_Deliver_C`), a `UItemContext` subclass. It overrides `ShouldAddToContextList(Owner, ItemRef, Item)` and `Execute(Owner, ItemRef, Item)` with the same signatures as `U_Sell_C`, and has `GetObjectives(ItemTag, WorldContextObject, Objectives)`. It inherits `IsValidContext` from `UItemContext`. Source: `CXXHeaderDump/U_Deliver.hpp`, `Test_C.hpp` `UItemContext`.
- The one live Deliver instance is `/Game/Blueprints/InventorySystem/Settings/DA_InventoryUISettings.DA_InventoryUISettings:U_Deliver_C_0`, beside `U_Sell_C_0` in the same data asset. Source: `UE4SS_ObjectDump.txt`.
- Mission items offer Deliver and no Sell in the context menu (user confirmed).
- **Unverified:** Deliver is not offered in raid, so Shift+Click there still falls through to vanilla's drop.
- **Unverified:** vanilla Deliver completes on click with no dialog, as Sell does.
- **Known vanilla bug:** `U_Deliver_C:Execute` looks the item up only in the stash (`GetStashInventoryComponent`, `GetContainerItemByUID`, per its graph locals in `UE4SS_ObjectDump.txt`). An item in the character inventory is credited to the mission but not removed, so the same item can be delivered repeatedly. Observed: one `ID_Classified_Document-UICS` Shift+Clicked three times completed a 3 document objective. The context menu's Deliver behaves the same (user confirmed). Accepted as is and listed under the README's known issues. Quick deliver does not restrict itself to stash items and does not remove the item itself.
- **Unverified:** delivery from the stash removes the item.

## Scope

Owned, all in `likhos-backpack`:

- `Scripts/quick_sell.lua`: tries Deliver before Sell.
- `Scripts/config.lua`: the `quick_sell` flag comment.
- `README.md`: the "Quick sell" section and a "Known issues" section.
- `CHANGELOG.md`: an entry.

## Solution

`quick_sell.lua` keeps a list of context classes, `U_Deliver_C` then `U_Sell_C`. On Shift+Click it runs `Execute` on the first one that passes both `ShouldAddToContextList` and `IsValidContext` for the clicked tile's owner, tile and item. None offered logs at debug and leaves the click to vanilla. The rest of quick sell (click hook, Shift read, one tick deferral, tile identity check, hook group) is unchanged.

The `quick_sell` flag turns both off. No separate flag.

## Tradeoffs

- **Deliver before Sell.** An item offered both would be delivered. Delivering a mission item is the likelier intent, and per the user mission items offer no Sell, so the order only matters for items that offer both.
- **A missing `U_Deliver_C` instance errors the whole Shift+Click, sell included**, through the hook group. Both instances live in the same data asset, so one missing without the other is unlikely.
