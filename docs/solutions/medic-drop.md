# Medic drop

## Intent

A bandage or painkiller pack whose last use is spent leaves the inventory and drops on the floor, the same way a used health injector does, at the same point in its use animation. Today both stay in the inventory at 0 uses (0/1 for the bandage, 0/4 for painkillers). A painkiller pack with uses left stays in the inventory as before.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from the cooked assets or a UE4SS dump and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, no UObject is held across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The item is dropped through the game's own drop path, the one the injector uses. The mod does not remove or spawn items itself.
- The feature lives in `likhos-point-and-shoot` as a Lua hook. Ruled out: adding a `Drop` notify to the bandage and painkiller montages in a pak (`likhos-rearmed`). It would match the injector exactly, but can't check remaining uses (the vanilla `Drop` branch has no condition, so a painkiller pack would drop after its first use), needs a new pak stage that adds notify exports to anim montages, and belongs to a different mod than the one requested.
- The items are a fixed list: bandage and painkillers. The health injector and revive syringe already drop through their own `Drop` notify, and a general rule covering them would drop them twice.
- The drop happens only while the use that spent the last use is still running. If that use ends before the drop point, the item stays in the inventory at 0 uses, as an injector does when its use is cut short before its `Drop` notify.

Names from the cooked assets (game build 22417726, read with UAssetGUI 2026-09-26) and `UE4SS_ObjectDump.txt` (2026-09-22):

- Item definitions under `/Game/Blueprints/InventorySystem/Items/Medical/` (class `IRRItemDefinition`): `Bandage/ID_Bandage`, `Painkiller/ID_Painkiller`, `Health_Injector/ID_Health_Injector`, `Revive_Syringe/ID_Revive_Syringe`. Each carries a `U_ItemUsage` stat of class `/Game/Blueprints/InventorySystem/Objects/Stats/U_Content.U_Content_C`, whose `StatTag` is `Inventory.Stats.Durability`. That is the use counter shown in the inventory: `MaxValue` 1 on the bandage and injector, 4 on painkillers. No definition names a leftover item. The item dropped after an injection is the used injector itself.
- `/Script/Test_C.InventoryFunctionLibrary:GetStatValueByTag(Item: ContainerItem, StatTypeTag: GameplayTag) -> float` and `GetStatMaxValueByTag` read a stat of an item. `TryRemoveItemDurability(Item, Amount, out NewDurability) -> bool` spends uses.
- `/Script/Test_C.ContainerItem` is the inventory item struct. It holds `ItemDefinition`, `ItemInventoryComp`, `CurrentStats` and `Count` among others.
- The use abilities under `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/`: `SGA_UseMedic_Bandage_C`, `SGA_UseMedic_Painkillers_C`, `SGA_UseMedic_HealthInjector_C`, `SGA_UseMedic_Revive_Syringe_C`. Each only sets `Medic Character Montage` (and a few properties) and overrides no function. All derive from `SGA_UseMedic.SGA_UseMedic_C`.
- `SGA_UseMedic_C` holds the item being used in its `Item` variable (`ContainerItem`), plays the montage and routes each `PlayMontageNotify` name from `OnNotifyBegin` to `ExecuteNotify(Name)` (a Blueprint function, one `FName` parameter `Name`):
  - `Use`: `TryRemoveItemDurability(Item, 1)`, then starts the item's gameplay effects.
  - `Drop`: `GetPlayerInventoryComponent(self)`, then `InventoryComponent:TryDropItem(Item, 1, true, true)`. No condition.
- Montages under `/Game/Animations/UE5/FP/Meds/`, used for both first and third person:

  | Montage | Length | `Use` | `Drop` |
  |---|---|---|---|
  | `HealthInjector/AM_FP_Injector_Use` | 2.5 s | 1.94 s | 2.33 s |
  | `Revive/AM_FP_ReviveSyringe` | 5.0 s | 4.17 s | 4.66 s |
  | `Bandage/AM_FP_Bandage_Use` | 6.5 s | 5.39 s | none |
  | `Painkiller/AM_FP_Painkiller_Use` | 7.0 s | 5.35 s | none |

  The missing `Drop` notify is the whole difference between the items that drop and the ones that don't. The injector drops 0.17 s before its montage ends.

Assumptions the build checks:

- A post hook on `SGA_UseMedic_C:ExecuteNotify` fires for the bandage and painkiller abilities' calls, since the subclasses don't override it.
- The remaining uses of the item being used can be read from Lua after its `Use` notify, through `GetStatValueByTag` with `Inventory.Stats.Durability` or the item's `CurrentStats`, and reflect the use just spent. The ability's `Item` is a struct copy, so it may still hold the count from before the use. The build finds which read is current.
- The montage's actual play position and length can be read from Lua while it plays. The items' `U_UsageTime` stats (5 s bandage, 7 s painkillers, 3 s injector) don't match the montage lengths, so the play rate may not be 1.
- Calling `ExecuteNotify` with `Drop` on the ability from Lua drops the item as it drops the injector.
- Co-op is untested. The hook runs wherever the vanilla notify runs, so the drop happens on the same machine as the injector's.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/medic.lua`: the feature.
- `likhos-point-and-shoot/Scripts/main.lua`: installing and resetting the feature.
- `likhos-point-and-shoot/Scripts/config.lua`: the feature switch.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description and the version it ships in.

Context only: the vanilla `SGA_UseMedic_C` ability and its subclasses, `menu.lua` (hook install pattern), `util.lua`, `log.lua`.

## Solution

### `medic.lua`

Owns every game name to do with medical item use. Holds no UObject across a level load.

- `install()` registers a post hook on `SGA_UseMedic_C:ExecuteNotify` once per session. The class is a Blueprint loaded on demand, so it follows `menu.lua`'s pattern: hook right away when the function is already in memory, otherwise hook when the first object of the class is created. A refusal is logged and leaves the feature off without failing the mod.
- The hook acts only on a `Use` notify of an ability whose class is in the item list (`SGA_UseMedic_Bandage_C`, `SGA_UseMedic_Painkillers_C`). Every other ability and notify passes through untouched, including the mod's own `Drop` call.
- On such a `Use` it reads the item's remaining uses from its `Inventory.Stats.Durability` stat. With uses left it does nothing.
- With none left it schedules the drop for 0.17 s before the ability's montage ends, the injector's margin, measured on the montage as it actually plays. At that point, if the same ability is still playing that montage, it calls the ability's `ExecuteNotify` with `Drop` and the game's own `Drop` branch drops the item. Otherwise it does nothing.
- The pending drop refers to the ability by full name, not by a held object, and clears on level load.
- The hook body and the scheduled drop are guarded so an error never escapes. A failure logs once per session and leaves the items vanilla.

### `main.lua` and `config.lua`

`config.lua` has a top-level `medic_drop` switch, default true, documented as "a bandage or painkiller pack with no uses left drops on the floor, like a used health injector". `main.lua` installs `medic.lua` when the mod is enabled and the switch is on, independent of the bind list and the tick loop, and resets its pending drop on level load next to `magnifier.reset`.

### README, CHANGELOG and `mod.txt`

The README has a section describing the drop and the switch. `CHANGELOG.md` has an entry for the version that ships it, and `mod.txt`'s description names the feature.

### Result

Using a bandage plays the vanilla animation and stops bleeding as before. Near the end of the animation, at the moment a used injector would drop, the bandage leaves the inventory and lands on the floor. A painkiller pack does the same on its fourth use, and its first three uses leave it in the inventory at 3/4, 2/4 and 1/4. Injectors, revive syringes and other items behave as vanilla. With `medic_drop = false` both items stay in the inventory at 0 uses.

## Tradeoffs

- A Lua hook over pak edits of the montages: ships in the requested mod, can check remaining uses and needs no new build stage. The cost is a hook on a Blueprint function and a timer from the `Use` notify to the drop point instead of a notify placed in the montage.
- Timing the drop from the montage as it plays over a fixed delay per item: stays right if the play rate isn't 1 or a patch retimes the montage. The cost is reading the montage position at `Use`.
- No drop when the use is cut short before the drop point: matches the injector and never drops from an ability that has finished. The cost is that an interrupted last use leaves an item at 0 uses in the inventory.
- A fixed item list over every medic ability without a `Drop` notify: no double drops and no surprises from a future item. The cost is that a new consumable medic item added by a patch needs a list entry.
- Reusing the ability's own `Drop` branch over calling `TryDropItem` from Lua: the drop arguments and the item reference stay the game's. The cost is a dependency on the `Drop` name staying in `ExecuteNotify`.
- A config switch over always on, following `magnifier_zoom`.
