# Medic drop

## Intent

A bandage or painkiller pack whose last use is spent leaves the inventory and drops on the floor, the same way a used health injector does, at the end of its use animation. Today both stay in the inventory at 0 uses (0/1 for the bandage, 0/4 for painkillers). A painkiller pack with uses left stays in the inventory as before.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from the cooked assets or a UE4SS dump and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, no UObject is held across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The item is dropped through the game's own drop path, the one the injector uses. The mod does not remove or spawn items itself.
- The feature lives in `likhos-point-and-shoot` as a Lua hook. Ruled out: adding a `Drop` notify to the bandage and painkiller montages in a pak (`likhos-rearmed`). It would match the injector exactly, but can't check remaining uses (the vanilla `Drop` branch has no condition, so a painkiller pack would drop after its first use), needs a new pak stage that adds notify exports to anim montages, and belongs to a different mod than the one requested.
- The items are a fixed list: bandage and painkillers. The health injector and revive syringe already drop through their own `Drop` notify, and a general rule covering them would drop them twice.
- A use cut short drops nothing. The item stays in the inventory at 0 uses, as an injector does when its use is cut short before its `Drop` notify.
- The drop is timed by the ability's own montage end event, not read from the character's anim instance. Ruled out: timing the drop 0.17 s before the montage end from the montage's play position, which needs the mesh playing the montage and its anim instance.
- UE4SS hooks a Blueprint function as a script hook, which runs a single callback and never a post callback (seen in game 2026-09-26).

Names from the cooked assets (game build 22417726, read with UAssetGUI 2026-09-26) and `UE4SS_ObjectDump.txt` (2026-09-22):

- Item definitions under `/Game/Blueprints/InventorySystem/Items/Medical/` (class `IRRItemDefinition`): `Bandage/ID_Bandage`, `Painkiller/ID_Painkiller`, `Health_Injector/ID_Health_Injector`, `Revive_Syringe/ID_Revive_Syringe`. Each carries a `U_ItemUsage` stat of class `/Game/Blueprints/InventorySystem/Objects/Stats/U_Content.U_Content_C`, whose `StatTag` is `Inventory.Stats.Durability`. That is the use counter shown in the inventory: `MaxValue` 1 on the bandage and injector, 4 on painkillers. No definition names a leftover item. The item dropped after an injection is the used injector itself.
- `/Script/Test_C.ContainerItem` is the inventory item struct. It holds `ItemDefinition`, `ItemInventoryComp`, `CurrentStats` and `Count` among others. `CurrentStats` is an array of `CurrentStatItem` (`Tag`, `Value`, `MaxValue`, `StatModifyType`).
- The use abilities under `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/`: `SGA_UseMedic_Bandage_C`, `SGA_UseMedic_Painkillers_C`, `SGA_UseMedic_HealthInjector_C`, `SGA_UseMedic_Revive_Syringe_C`. Each only sets `Medic Character Montage` (and a few properties) and overrides no function. All derive from `SGA_UseMedic.SGA_UseMedic_C`. Each use runs a new ability instance.
- `SGA_UseMedic_C` holds the item being used in its `Item` variable (`ContainerItem`), a copy taken when the use starts. Seen in game 2026-09-26: its `Inventory.Stats.Durability` value still holds the count from before the use after the `Use` notify (4, 3, 2, 1 over a painkiller pack's four uses).
- `SGA_UseMedic_C` equips the item to the `Inventory.Equipment Slots.Gadget` slot, plays `Medic Character Montage` through `CreateProxyObjectForPlayCharacterMontage` at rate 1 and binds the proxy's events to its own functions:
  - `OnNotifyBegin_BC5AE83245D2760642BF14BE4B42A1EF` routes each `PlayMontageNotify` name to `ExecuteNotify(Name)`:
    - `Use`: `TryRemoveItemDurability(Item, 1)`, then starts the item's gameplay effects. The amount is a constant 1.
    - `Drop`: `GetPlayerInventoryComponent(self)`, then `InventoryComponent:TryDropItem(Item, 1, true, true)`. No condition.
  - `OnBlendOut_BC5AE83245D2760642BF14BE4B42A1EF(NotifyName)`: does nothing.
  - `OnCompleted_BC5AE83245D2760642BF14BE4B42A1EF`: `FinishAbility(true)`, which unequips the item from the Gadget slot.
  - `OnInterrupted_BC5AE83245D2760642BF14BE4B42A1EF`: prints a debug string only.
- Montages under `/Game/Animations/UE5/FP/Meds/`, used for both first and third person. Every one has a blend out time of 0.

  | Montage | Length | `Use` | `Drop` |
  |---|---|---|---|
  | `HealthInjector/AM_FP_Injector_Use` | 2.5 s | 1.94 s | 2.33 s |
  | `Revive/AM_FP_ReviveSyringe` | 5.0 s | 4.17 s | 4.66 s |
  | `Bandage/AM_FP_Bandage_Use` | 6.5 s | 5.39 s | none |
  | `Painkiller/AM_FP_Painkiller_Use` | 7.0 s | 5.35 s | none |

  The missing `Drop` notify is the whole difference between the items that drop and the ones that don't. The injector drops 0.17 s before its montage ends.

Assumptions the build checks:

- The proxy calls `OnBlendOut` when the montage plays to its end and `OnInterrupted` instead when it is cut short, and `OnBlendOut` runs before `OnCompleted` unequips the item.
- Calling `ExecuteNotify` with `Drop` on the ability from inside the `OnBlendOut` hook drops the item as it drops the injector.
- Co-op is untested. The hook runs wherever the vanilla event runs, so the drop happens on the same machine as the injector's.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/medic.lua`: the feature.
- `likhos-point-and-shoot/Scripts/main.lua`: installing the feature.
- `likhos-point-and-shoot/Scripts/config.lua`: the feature switch.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description and the version it ships in.

Context only: the vanilla `SGA_UseMedic_C` ability and its subclasses, `hook.lua` (hook install and error guard), `util.lua`, `log.lua`.

## Solution

### `medic.lua`

Owns every game name to do with medical item use. Holds no state between calls.

- `install()` hooks `SGA_UseMedic_C`'s `OnBlendOut` event function through `hook.lua`, which waits for the Blueprint class to load, logs a refusal and leaves the feature off without failing the mod. The hook fires for the subclasses, since they don't override it.
- The hook acts only on an ability whose class is in the item list (`SGA_UseMedic_Bandage_C`, `SGA_UseMedic_Painkillers_C`). Every other ability passes through untouched.
- It reads the uses the item had before this use, from the `Inventory.Stats.Durability` entry in the ability's `Item` copy. The `Use` branch spends exactly one, so a count above 1 means uses are left and it does nothing.
- Otherwise it calls the ability's `ExecuteNotify` with `Drop`, and the game's own `Drop` branch drops the item while it is still equipped, as the injector's does.
- The hook body is guarded so an error never escapes. A failure logs once per session and leaves the items vanilla.

### `main.lua` and `config.lua`

`config.lua` has a top-level `medic_drop` switch, default true, documented as "a bandage or painkiller pack with no uses left drops on the floor, like a used health injector". `main.lua` installs `medic.lua` when the mod is enabled and the switch is on, independent of the bind list and the tick loop.

### README, CHANGELOG and `mod.txt`

The README has a section describing the drop and the switch. `CHANGELOG.md` has an entry for the version that ships it, and `mod.txt`'s description names the feature.

### Result

Using a bandage plays the vanilla animation and stops bleeding as before. When the animation ends, the bandage leaves the inventory and lands on the floor. A painkiller pack does the same on its fourth use, and its first three uses leave it in the inventory at 3/4, 2/4 and 1/4. A last use cut short leaves the item in the inventory at 0 uses. Injectors, revive syringes and other items behave as vanilla. With `medic_drop = false` both items stay in the inventory at 0 uses.

## Tradeoffs

- A Lua hook over pak edits of the montages: ships in the requested mod, can check remaining uses and needs no new build stage. The cost is a hook on a Blueprint event function whose name carries a GUID suffix, which a game patch that rebuilds the ability may change.
- The montage end event over a timer from the `Use` notify: no timer, no montage position reads and no state between calls, and an interrupted use is told apart by the game itself. The cost is that the drop lands at the very end of the animation, 0.17 s later than the injector's.
- Telling the last use from the pre-use count in the ability's copy over looking up the live item in the inventory: no extra game names. The cost is a dependency on the `Use` branch spending exactly one use.
- A fixed item list over every medic ability without a `Drop` notify: no double drops and no surprises from a future item. The cost is that a new consumable medic item added by a patch needs a list entry.
- Reusing the ability's own `Drop` branch over calling `TryDropItem` from Lua: the drop arguments and the item reference stay the game's. The cost is a dependency on the `Drop` name staying in `ExecuteNotify`.
- A config switch over always on, following `magnifier_zoom`.
