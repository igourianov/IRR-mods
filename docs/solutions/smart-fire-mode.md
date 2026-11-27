# Smart Fire Mode

## Intent

A new keybind, **Smart Fire Mode (Tap/Hold/Double Tap)**, switches the equipped weapon straight to a chosen fire mode rather than cycling to the next one:

- Tap: Semi.
- Double tap: Burst.
- Hold: Auto.

Every gesture shows the fire mode card, whether or not it switched: the weapon may already be in that mode, lack it or be unable to switch right now.

The row sits on the controls page right below **Switch Fire Mode (Tap/Hold)**.

## Constraints and assumptions

- The game has three fire modes, the `Weapon.FireMode.Semi`, `.Burst` and `.Auto` tags. `EFireMode` lists more (`FM_InterBurst`, `FM_Manual`, `FM_Slamfire`, `FM_Gatling`), but no tag, setting or weapon uses them.
- Weapons have Semi only, Auto only, Auto and Semi, or all three (MP5, MP5K, MP5SD and KRISS Vector .45). Every weapon with Burst also has Auto.
- The vanilla switch only cycles forward through the weapon's modes. It has no direction and no way to name a target.
- The keybind is one of the mod's own mappings, unbound by default like the others. It coexists with Switch Fire Mode (Tap/Hold) and the vanilla key, and asks the player to unbind neither.
- A gesture for a mode the weapon lacks switches nothing and shows the card with the current mode. No gesture falls back to another mode.
- A double tap needs `double_tap_ms` to pass before a tap counts, so Semi lands that long after the release, the same as Smart Grenade's frag.
- Ruled out: calling `WeaponComponent:SwitchFireMode(old, new)` directly and playing the switch montage from the mod. It skips the game's own switch path and its gating, and it is unknown whether that call alone completes a switch.
- Ruled out: a hold that keeps the card up or takes the hand off, as Switch Fire Mode (Tap/Hold)'s hold does. Here a hold is only a gesture that picks Auto.

Assumptions, unverified:

- A1. After an injected `IA_SwitchFireMode` press, `WeaponComponent:GetFireMode()` reports the new mode within about a second, or never when the game refuses the switch (a single-mode weapon, or the ability blocked by another action).
- A2. A second injected press switches again once `GetFireMode()` reports the first switch. For the 3-mode weapons this holds if their ability ends at once, which it should since they have no switch montage (Recon).
- A3. `WeaponComponent:HasFireMode(tag)` with a `GeneralSettings` fire mode tag reports whether the weapon has that mode.

## Recon

Verified in `UE4SS_ObjectDump.txt`, `DefaultGameplayTags.ini` and the assets extracted from `pakchunk0-Windows.pak` (game build 26610539) on 2026-11-26:

- `DefaultGameplayTags.ini` defines `Weapon.FireMode.Auto`, `.Burst` and `.Semi`, plus redirects from `Weapon.FireMode.Full Auto` and `.Single Fire`.
- `SGA_SwitchFireMode_C`'s ubergraph reads the weapon definition's `U_FireModes_C` stat (`Inventory.Stats.Firemodes`) `Fire Modes` container into an array. It finds `OldIndex`, the position of the tag in the weapon item's `CurrentState`, and then calls `WeaponDataAsset:GetSwitchFireModeMontageSet(FromFireModeTag)` with that tag. When the set is found and the array has more than one mode, it commits, plays the set's `SwitchFireModeAnimSet` through `CreateProxyObjectForPlayCharacterMontage` and finishes on the montage's completion. Otherwise it finishes at once. It calls no switch function itself: the mode changes natively, outside this blueprint.
- `WeaponComponent` has `SwitchFireMode(OldFireModeTag, NewFireModeTag)`, `HasFireMode(FireMode: GameplayTag) -> bool`, `GetFireMode() -> EFireMode` and the delegate `OnFireModeSwitched(NewFireMode)`. `QUA_Character:RequestSwitchFireMode()` takes no parameters.
- The paks hold switch montages only for the AK family (`AM_FP_AK74M_SwitchFireMode_Auto_To_Semi_UE5`, `..._Semi_To_Auto_UE5` and their weapon montages). The montage has no notify of its own.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/weapon/fire_mode.lua`: the `SmartFireMode` action, beside the `FireMode` action and the card placement it already holds.
- `likhos-point-and-shoot/Scripts/controls/keymap.lua`: the `LikhosSmartFireMode` entry of `MAPPINGS`.
- `likhos-point-and-shoot/Scripts/config.lua`: the `smart_fire_mode` bind and its lines in the `tap_ms` and `double_tap_ms` descriptions.
- `likhos-point-and-shoot/README.md`: the feature line.
- `likhos-point-and-shoot/CHANGELOG.md`: the entry under `# Unreleased`.
- `likhos-point-and-shoot/mod.txt`: the minor version bump for a new feature.

Context only: `core/triggers.lua` and `core/actions.lua` (tap, hold and double tap phases), `core/player.lua` (`inject_press`, `weapon_component`), `controls/menu.lua` (rows in `MAPPINGS` order).

## Solution

`keymap.MAPPINGS` has a `LikhosSmartFireMode` entry right after `LikhosSwitchFireMode`, shown as **Smart Fire Mode (Tap/Hold/Double Tap)**. Its description says it switches straight to a mode: tap Semi, double tap Burst, hold Auto.

`config.lua` holds a `smart_fire_mode` bind right after `fire_mode`, with `block_in_ui` on that mapping, whose `action` is `SmartFireMode`. The `tap_ms` and `double_tap_ms` descriptions name Smart Fire Mode beside Smart Grenade.

`weapon/fire_mode.lua` defines `SmartFireMode` with `tap`, `double_tap` and `hold` phases, each naming its target mode, and a `reset`. It keeps one plain value between calls, which marks the switch in progress, and holds no UObject.

- A gesture starts a switch to its target, which ends the waiting of any switch still in progress.
- Unless the weapon is already in the target mode or lacks it (A3), the mod injects one `IA_SwitchFireMode` press through `player.inject_press`, the same press the Switch Fire Mode tap sends.
- On the game thread, with delayed retries in the way `keymap.when_live` waits, the mod watches `GetFireMode()` until it reports a new mode (A1). Each new mode that is not the target gets another press (A2). The presses stop at the target, after one fewer press than the weapon has modes, or when a switch has not landed within the wait limit.
- Once the presses stop, the mod shows the card with the current mode through the `show` the Switch Fire Mode hold uses. The card therefore shows after every gesture, also when the game's own switch showed it already.
- `reset` ends any waiting on level load.

The card's placement at the magazine check spot applies while either the `FireMode` or the `SmartFireMode` bind is enabled.

The flow end to end, a tap on an AK in Auto:

1. The player taps the Smart Fire Mode key. After `double_tap_ms`, the tap fires with Semi as the target.
2. The weapon has Semi and is not in it, so the mod injects one press. The vanilla ability plays the Auto to Semi montage and the game switches the mode and shows the card.
3. `GetFireMode()` reports Semi, the target, so the presses stop and the mod shows the card again with Semi.

On an MP5 in Auto with Burst as the target, the vanilla cycle may go through Semi first. The card shows Semi briefly before the second press reaches Burst.

The player sees each gesture land on its mode with the vanilla switch animation and the card, on any weapon. On a weapon without the mode, or when it is already selected, the card shows the current mode and nothing switches.

`README.md`'s Features list has a **Smart Fire Mode (Tap/Hold/Double Tap)** line, right after Switch Fire Mode (Tap/Hold), saying the new keybind selects a fire mode directly: tap for semi, double tap for burst, hold for auto. `CHANGELOG.md` has an entry under `# Unreleased` for the new keybind. `mod.txt`'s minor version is one higher than at the last release.

## Tradeoffs

- Vanilla presses over a direct switch: the game's own switch, gating and animation stay in charge. The cost is that a 3-mode weapon can take two switches, with the middle mode shown briefly on the card, and that the mod has to wait for each switch to land.
- Double tap for Burst: every Semi tap waits out `double_tap_ms`. Burst exists on four weapons, but Semi on almost all of them.
- One module for both fire mode actions: they share the card's lookup, show and placement. `fire_mode.lua` grows by a second action rather than a new module that would reach into its internals.
