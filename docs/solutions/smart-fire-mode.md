# Smart Fire Mode

## Intent

A new keybind, **Smart Fire Mode (Tap/Hold/Double Tap)**, switches the equipped weapon straight to a chosen fire mode rather than cycling to the next one:

- Tap: Semi.
- Double tap: Burst.
- Hold: Auto.

Each gesture switches once, with one switch animation, also on a weapon with three modes.

Every gesture shows the fire mode card, whether or not it switched: the weapon may already be in that mode or lack it.

The row sits on the controls page right below **Switch Fire Mode (Tap/Hold)**.

## Constraints and assumptions

- The game has three fire modes, the `Weapon.FireMode.Semi`, `.Burst` and `.Auto` tags. `EFireMode` lists more (`FM_InterBurst`, `FM_Manual`, `FM_Slamfire`, `FM_Gatling`), but no tag, setting or weapon uses them.
- Weapons have Semi only, Auto only, Auto and Semi, or all three (MP5, MP5K, MP5SD and KRISS Vector .45). Every weapon with Burst also has Auto.
- The vanilla switch is driven by its animation. Each switch animation carries a `Notify_SwitchFireMode` with a fixed `OldFireMode` and `NewFireMode`, which switches the weapon to `NewFireMode` when it fires, whatever mode the weapon is in. The weapon data asset gives each mode one such animation, so the vanilla switch only cycles forward, in the order those animations make.
- The keybind is one of the mod's own mappings, unbound by default like the others. It coexists with Switch Fire Mode (Tap/Hold) and the vanilla key, and asks the player to unbind neither.
- A gesture for a mode the weapon lacks switches nothing and shows the card with the current mode. No gesture falls back to another mode.
- A double tap needs `double_tap_ms` to pass before a tap counts, so Semi lands that long after the release, the same as Smart Grenade's frag.
- The switch is not gated: it happens also during a reload or another action, where the vanilla ability may refuse. Whether that looks or behaves wrong is checked in game before any gate is designed (per the user).
- Accepted (per the user): a switch to the mode before the current one in the cycle (Vector: Burst to Semi, Auto to Burst, Semi to Auto) plays the animation that ends on the target from the mode before it, so the selector starts that animation from the wrong position.
- Ruled out: repeated injected vanilla presses. On a 3-mode weapon a gesture can take two switches, which plays two animations and shows the middle mode on the card.
- Ruled out: a direct switch to the target followed by the current mode's switch animation. That animation's notify switches on to its own fixed mode, past the target.
- Ruled out: a hold that keeps the card up or takes the hand off, as Switch Fire Mode (Tap/Hold)'s hold does. Here a hold is only a gesture that picks Auto.

Assumptions, unverified:

- A1. `WeaponComponent:SwitchFireMode(OldFireModeTag, NewFireModeTag)` with the current and another `GeneralSettings` tag switches the weapon to the new mode. Seen in game: a direct switch from Burst to Semi showed Semi, before a montage's notify switched it on.
- A2. Reading the weapon data asset's switch montage sets reaches each set's `Notify_SwitchFireMode` and its `NewFireMode` through reflection, from the arm montage to its animation's notifies.
- A3. `WeaponComponent:HasFireMode(tag)` with a `GeneralSettings` fire mode tag reports whether the weapon has that mode. Seen to hold in game with the earlier press based build.

## Recon

Verified in `UE4SS_ObjectDump.txt`, `DefaultGameplayTags.ini` and the assets extracted from `pakchunk0-Windows.pak` (game build 26610539) on 2026-11-26:

- `DefaultGameplayTags.ini` defines `Weapon.FireMode.Auto`, `.Burst` and `.Semi`, plus redirects from `Weapon.FireMode.Full Auto` and `.Single Fire`.
- `SGA_SwitchFireMode_C`'s ubergraph reads the weapon definition's `U_FireModes_C` stat (`Inventory.Stats.Firemodes`) `Fire Modes` container into an array. It finds the tag in the weapon item's `CurrentState`, and then calls `WeaponDataAsset:GetSwitchFireModeMontageSet(FromFireModeTag)` with that tag. When the set is found and the array has more than one mode, it commits, plays the set's `SwitchFireModeAnimSet` through `AsyncAction_PlayMontage:CreateProxyObjectForPlayCharacterMontage(Instigator, equipped weapon, GetLinkedAnimGraph(), None, set, 1, false, false, true)` and finishes on the montage's completion. Otherwise it finishes at once. It calls no switch function itself.
- `/Script/Test_C.Notify_SwitchFireMode` has `OldFireMode` and `NewFireMode` (GameplayTag). The arm animations carry it, not the montages or the weapon animations: `A_FP_AK74M_ToSemi` Auto to Semi, `A_FP_Vector_ToAuto` Burst to Auto, `A_FP_Vector_ToBurst` Semi to Burst, `A_FP_Vector_ToSemi` Auto to Semi.
- A weapon data asset's `SwitchFireModeMontageSets` holds a `SwitchFireModeMontageSet` (`FromFireMode`, `SwitchFireModeAnimSet`) per mode. The Vector's: from Burst `AM_FP_Vector_ToAuto`, from Auto `AM_FP_Vector_ToSemi`, from Semi `AM_FP_Vector_ToBurst` (FP, TP and weapon montages). The MP5's has sets from Semi, Auto and Burst.
- `WeaponComponent` has `SwitchFireMode(OldFireModeTag, NewFireModeTag)`, `HasFireMode(FireMode: GameplayTag) -> bool`, `GetFireMode() -> EFireMode`, `GetWeaponDataAsset()` and the delegate `OnFireModeSwitched(NewFireMode)`.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/weapon/fire_mode.lua`: the `SmartFireMode` action, beside the `FireMode` action and the card placement it already holds.
- `likhos-point-and-shoot/Scripts/controls/keymap.lua`: the `LikhosSmartFireMode` entry of `MAPPINGS`.
- `likhos-point-and-shoot/Scripts/config.lua`: the `smart_fire_mode` bind and its lines in the `tap_ms` and `double_tap_ms` descriptions.
- `likhos-point-and-shoot/README.md`: the feature line.
- `likhos-point-and-shoot/CHANGELOG.md`: the entry under `# Unreleased`.
- `likhos-point-and-shoot/mod.txt`: the minor version bump for a new feature.

Context only: `core/triggers.lua` and `core/actions.lua` (tap, hold and double tap phases), `core/player.lua` (`weapon_component`, `pawn`), `controls/menu.lua` (rows in `MAPPINGS` order).

## Solution

`keymap.MAPPINGS` has a `LikhosSmartFireMode` entry right after `LikhosSwitchFireMode`, shown as **Smart Fire Mode (Tap/Hold/Double Tap)**. Its description says it switches straight to a mode: tap Semi, double tap Burst, hold Auto.

`config.lua` holds a `smart_fire_mode` bind right after `fire_mode`, with `block_in_ui` on that mapping, whose `action` is `SmartFireMode`. The `tap_ms` and `double_tap_ms` descriptions name Smart Fire Mode beside Smart Grenade.

`weapon/fire_mode.lua` defines `SmartFireMode` with `tap`, `double_tap` and `hold` phases, each naming its target mode. It keeps no state between calls and holds no UObject. A gesture, all within one game thread call:

- When the weapon is already in the target mode or lacks it (A3), nothing switches.
- Otherwise the mod looks for the switch montage set whose animation's notify lands on the target (A2). The set's `FromFireMode` is the mode before the target in the weapon's cycle.
  - Found: unless the weapon is already in that mode, the mod switches it there with `WeaponComponent:SwitchFireMode` (A1). Then it plays the set as `SGA_SwitchFireMode_C` plays it, through the module's existing montage helper, which the Switch Fire Mode hold uses for its hand-off pose. The animation's notify makes the switch to the target.
  - Not found: the mod switches straight to the target with `WeaponComponent:SwitchFireMode`, with no animation.
- Then it shows the card through the `show` the Switch Fire Mode hold uses, with the target mode after a switch and the current mode otherwise. The card shows the target from the start, also while the animation is still on its way to the notify.

The card's placement at the magazine check spot applies while either the `FireMode` or the `SmartFireMode` bind is enabled.

The flow end to end, a tap on a Vector in Burst:

1. The player taps the Smart Fire Mode key. After `double_tap_ms`, the tap fires with Semi as the target.
2. The Vector has Semi and is not in it. Its set landing on Semi is the one from Auto, `AM_FP_Vector_ToSemi`.
3. The mod switches the Vector from Burst to Auto, plays the from Auto set and shows the card with Semi.
4. The animation's notify switches the Vector to Semi.

A tap on a Vector in Auto plays the same set with no switch beforehand, as the vanilla key would. On an AK, any gesture to the other mode is the vanilla switch.

The player sees each gesture land on its mode in one switch, with the switch animation that ends on that mode, and the card. On a weapon without the mode, or when it is already selected, the card shows the current mode and nothing switches.

`README.md`'s Features list has a **Smart Fire Mode (Tap/Hold/Double Tap)** line, right after Switch Fire Mode (Tap/Hold), saying the new keybind selects a fire mode directly: tap for semi, double tap for burst, hold for auto. `CHANGELOG.md` has an entry under `# Unreleased` for the new keybind. `mod.txt`'s minor version is one higher than at the last release.

## Tradeoffs

- The animation that ends on the target, after a silent switch to the mode before it: one animation that names the target, and the notify keeps the last switch the game's own. The cost is the selector's wrong start position on a backward switch, the weapon sitting in the mode before the target until the notify fires, and reflection into the animation's notifies.
- Ungated switch: no reload or action check to design until it proves needed. The cost is that the switch also goes through where the vanilla ability would refuse.
- Double tap for Burst: every Semi tap waits out `double_tap_ms`. Burst exists on four weapons, but Semi on almost all of them.
- One module for both fire mode actions: they share the card's lookup, show, placement and montage helper. `fire_mode.lua` grows by a second action rather than a new module that would reach into its internals.
