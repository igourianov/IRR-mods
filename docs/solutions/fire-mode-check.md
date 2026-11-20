# Fire mode check

## Intent

A new keybind, **Switch Fire Mode (Tap/Hold)**, replaces the vanilla **Switch Fire Mode** key and serves both switching and checking, decided by how long it is held:

- Tap: switches to the weapon's next fire mode and shows the fire mode card in the lower right corner, as the vanilla key does.
- Hold: shows the fire mode card with the current mode selected, without switching, for as long as the key is held. After the release it hides on its vanilla timer. While the key is held the character also takes the support hand off the weapon, the pose of an open inventory, and puts it back on release.

The fire mode card shows where the magazine check card does, at the bottom center just above the health bar, instead of the lower right corner. This applies to every time the card shows, a switch or a check.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from a UE4SS dump or Live View and are recorded here (project rule). UObject access happens on the game thread only, no UObject is cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The keybind is one of the mod's own mappings (`controls/keymap.lua`), unbound by default like the others. The player binds it and unbinds the vanilla Switch Fire Mode key in the controls menu. Bound to the same key, both would switch on the press.
- The switch itself stays vanilla: the mod sends the vanilla action a one-frame press, so the vanilla handler, ability, animation and card run as they do for the vanilla key.
- The tap window is the mod's shared `tap_ms`.
- A hold shows the card for any equipped weapon, including one with a single fire mode, where a switch does nothing.
- The fire mode card and the magazine check card never show at the same time (per the user), so they share one spot.
- The card's placement follows the `fire_mode` bind's `enabled`. Set false, the card stays in the lower right corner.
- Ruled out: giving the vanilla `IA_SwitchFireMode` a tap trigger at runtime. A mod-built `InputTriggerTap` in its `Triggers` crashed the game on the next level load (an access violation right after the player's input setup), most likely because the engine freed the trigger while the action still pointed at it.
- Ruled out: sharing a vanilla action's own tap trigger, such as `IA_Reload`'s, with `IA_SwitchFireMode`. It ties the fire mode key to another action's asset and its fixed 200 ms window.
- The hands-off pose is the vanilla inventory's own montages, played the way the inventory ability plays them. The pose blocks no other action: firing, reloading or any other montage ends it, and it is not started again within the same hold.
- Ruled out: letting the vanilla key switch on the press and switching back on a hold. The switch animation plays, the card first shows the wrong mode and a three mode weapon needs two more switches to return.

Verified in `UE4SS_ObjectDump.txt` (2026-11-18) and in the assets extracted from `pakchunk0-Windows.pak` (game build 26610539):

- `/Game/Blueprints/InputSystem/InputActions/IA_SwitchFireMode.IA_SwitchFireMode` has one trigger, `InputTriggerPressed_0`, so the vanilla key switches on the press itself. Its key profile row is `IA_SwitchFireMode`, default key X.
- It is handled by `IH_SwitchFireMode_C_0` in `DA_IngameInput`, an `InputHandler_TriggerSimpleAbility` with `AbilityTag` `Character.Abilities.Allowed.SwitchFireMode` and `TriggerEvents` = `[Triggered]`. The ability is `SGA_SwitchFireMode_C`.
- The card is `/Game/Blueprints/InventorySystem/Widgets/WeaponUI/W_ShowFireMode.W_ShowFireMode_C`, a `ShowMagCapacityWidget`, with `OnWeaponFireModeChanged_Event(NewFireMode: GameplayTag)`, `OnWeaponEquipped_Event` and `FireModeElements`.
- `WeaponComponent:GetFireMode()` returns `EFireMode` (`/Script/EasyBallistics`: `FM_Auto` 0, `FM_Semiauto` 1, `FM_Burst` 2, others).
- `GeneralFunctionLibrary:GetGeneralSettings()` returns `GeneralSettings`, with `AutoFireModeTag`, `SemiAutoFireModeTag` and `BurstFireModeTag`.
- HUD layout (`W_InGame`, `W_WeaponUI`, `W_StaminaAndHealthBars` assets): `W_InGame_C`'s root overlay holds `W_StaminaAndHealthBars` at the bottom center and `W_WeaponUI` filling the screen. `/Game/Blueprints/FirstPersonCoreComponent/W_WeaponUI.W_WeaponUI_C`'s root `Overlay_1` holds `W_ShowMagCapacity` (centered, bottom, 150 bottom padding) and `VerticalBox_0` (right, bottom, 150 bottom padding), which stacks `W_ShowFireMode`, `W_ShowMagnificationLevel` and a spacer. `W_WeaponUI_C` has the properties `W_ShowFireMode`, `W_ShowMagCapacity` and `W_ShowMagnificationLevel`. `W_ShowFireMode_C` has a `Construct` function.
- The inventory pose (`/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_OpenInventory.SGA_OpenInventory_C` bytecode): on open it waits, in 0.2 s steps, until the character `Mesh`'s `GetLinkedAnimGraphInstanceByTag("Combat")` reports no `IsAnyMontagePlaying`. Then it calls `/Script/Test_C.AsyncAction_PlayMontage:CreateProxyObjectForPlayCharacterMontage(Actor, Weapon, LinkedAnimGraph, MontageSection, CharacterMontages, PlayRate, StopPreviousMontage, SyncAnimLength, Predict)` with the character, the equipped weapon actor, the weapon data asset's `GetLinkedAnimGraph()`, `None`, `GetNoMagMontageSet().HandOffMontageSet`, 1, false, false and true, and calls `Activate()` on the returned proxy. On close it does the same with `HandOnMontageSet` and `StopPreviousMontage` true, but only while its own open flag is set. The weapon data asset is `WeaponComponent:GetWeaponDataAsset()`. `NoMagMontageSet` holds `HandOffMontageSet`, `HandOnMontageSet` and `NoMagCheckMontageSet`, each a `CharacterMontageSet` of `TP_Animation`, `FP_Animation` and `Weapon_Animation` montages.

Assumptions, unverified:

- A1. A one-frame injected `IA_SwitchFireMode` press switches the fire mode as the vanilla key does, also with the vanilla key unbound. Hold Breath and the magnifier inject vanilla actions the same way, but with their keys bound.
- A2. Calling `OnWeaponFireModeChanged_Event` on the live `W_ShowFireMode_C` with a fire mode tag shows the card with that mode selected, the same as after a switch, and changes no weapon state.
- A3. The current mode's tag is the `GeneralSettings` tag matching `GetFireMode()`'s value. The weapon may instead hold its current tag directly, which the build may read instead.
- A4. The card lists a single mode weapon's one mode.
- A5. Calling `OnWeaponFireModeChanged_Event` again while the card is up restarts its hide timer without a visible flicker. The card hides on a timer a few seconds after it is shown, also while the key is held (seen in game). What hides it is not in the dump: `W_ShowFireMode_C` has no timer or animation members and its native base `ShowMagCapacityWidget` exposes none.
- A6. Moving a built card into another panel keeps it working: the card's own logic and the base class's show and hide still apply to it in its new slot.
- A7. The hand-off montage holds its last pose and stays the active montage of the weapon's linked anim graph (`Combat`, `ABP_Procedurals_FP_C`) until another montage replaces it. Seen in game: on release `GetCurrentActiveMontage` there is `AM_FP_AK74M_Hand_Off_Montage` while `Montage_IsPlaying` on it is false, and without a hand-on montage the hand stays off.
- A8. The proxy the factory returns to the mod plays its montages as it does for the ability, with nothing of the mod's bound to its delegates.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/weapon/fire_mode.lua`: the `FireMode` action, its hands-off pose and the fire mode card's placement.
- `likhos-point-and-shoot/Scripts/controls/keymap.lua`: the `LikhosSwitchFireMode` entry of `MAPPINGS`.
- `likhos-point-and-shoot/Scripts/main.lua`: installing the module.
- `likhos-point-and-shoot/Scripts/config.lua`: the `fire_mode` bind and its line in the `tap_ms` description.
- `likhos-point-and-shoot/README.md`: the Features line.
- `likhos-point-and-shoot/CHANGELOG.md`: the `# Unreleased` entry.
- `likhos-point-and-shoot/mod.txt`: minor version bump for a new feature.

Context only: `core/input.lua` polling and the context gate, `core/triggers.lua` hold state, `core/actions.lua`, `core/player.lua` (`inject_press`, `weapon_component`), `controls/menu.lua` rows, the vanilla handler, ability and card widget.

## Solution

`keymap.MAPPINGS` has a `LikhosSwitchFireMode` entry, shown in the controls menu as **Switch Fire Mode (Tap/Hold)** after Flashlight, whose description says a tap switches, a hold shows the current mode and the vanilla Switch Fire Mode key should be unbound.

`config.lua` holds a `fire_mode` bind with `block_in_ui` on that mapping, whose `action` is `FireMode`. As an ordinary bind it is polled by `input.poll` and listed by `kb_status` with no change to either.

`weapon/fire_mode.lua` follows `weapon/hold_breath.lua`: it holds no UObject between calls and defines its action in `install`.

- `tap`: a one-frame `IA_SwitchFireMode` press through `player.inject_press` (A1).
- `hold`, when the key is still down past `tap_ms`: it resolves the equipped weapon's component through `player.weapon_component`, takes its current mode's tag (A3) and calls `OnWeaponFireModeChanged_Event` on the live `W_ShowFireMode_C` of the current PlayerController's HUD (A2). Without an equipped weapon or a live card widget it does nothing.
- `held`, after `hold` has shown the card: it shows it again at a fixed refresh interval, shorter than the card's vanilla timer, so the card stays up until the release (A5). The time of the last show is a plain value, dropped on release and on level load.
- The pose: from `hold` on, once the Combat linked anim graph plays no montage, the hold plays the equipped weapon's hand-off montage set through `AsyncAction_PlayMontage` with the inventory ability's arguments (A8). It starts once per hold. On release, if the equipped weapon's hand-off montage is still the active montage of the weapon's linked anim graph (A7), it plays the hand-on set with the inventory ability's close arguments, as the closing inventory does. A montage that cut in or a swapped weapon leaves the release with nothing to undo. The montages are resolved again on release from the equipped weapon, and only a flag that the pose is pending or started is kept, dropped on release and on level load.

It also places the card, following the way `controls/menu.lua` moves vanilla widgets. It hooks `W_ShowFireMode_C:Construct` through `lib/hook`, and on the next tick it moves the built card from its `W_WeaponUI_C`'s `VerticalBox_0` into the panel holding that HUD's `W_ShowMagCapacity`, with the same slot layout as the magazine card (A6). Install does the same for cards already built, so a hot reload places them too. A card already beside the magazine card is left as it is. The card is looked up by path, never held.

Flow:

1. The player presses the Switch Fire Mode (Tap/Hold) key. Nothing happens yet.
2. Released within `tap_ms`, the mod injects one `IA_SwitchFireMode` press. The vanilla handler runs `SGA_SwitchFireMode_C`, which switches the mode, plays the animation and shows the card.
3. Held past `tap_ms`, the mod shows the card with the current mode selected and keeps showing it while the key is down. Once no other montage plays, the support hand comes off the weapon.
4. On release the support hand goes back on, the mode is not switched and the card hides on its vanilla timer.

The player sees a tap switch the fire mode as with the vanilla key, a fraction of a second later, on release instead of press. A hold shows which mode is selected for as long as it lasts, on any weapon, with the inventory's hands-off pose and no switch.

`README.md`'s Features list has a **Switch Fire Mode (Tap/Hold)** line saying the new keybind switches on a tap, shows the selected mode on a hold with the inventory's hands-off pose and replaces the vanilla key, which should be unbound.

`CHANGELOG.md` has the feature under `# Unreleased`. `mod.txt`'s minor version is one higher than before the feature, patch unchanged.

## Tradeoffs

- A new keybind over changing the vanilla key: the vanilla input asset stays untouched, so nothing of the mod's can dangle across a level load. The cost is setup for the player, who binds the new row and unbinds the vanilla one.
- Switching on release over press: a tap can only be told from a hold once the key is up, so every switch lands up to `tap_ms` later than with the vanilla key.
- Showing the card through the widget's own event over drawing a mod widget: it looks and fades exactly like the vanilla card. The cost is a dependency on a Blueprint event name that a patch could rename, in which case the hold logs and does nothing.
- Copying the magazine card's slot over a fixed position: the card follows the magazine card if a patch moves it. The cost is that the two overlap if they ever do show at once.
- Playing the inventory's montages directly over running the inventory ability: no inventory opens and the pose comes with each weapon's own animations. The cost is that nothing blocks firing or other actions during the pose, which cut it short.- Re-showing the card on an interval over stopping its hide timer: it works without knowing what hides the card. The cost is a guessed interval, and a patch that shortens the vanilla timer below it makes the card blink while held.
