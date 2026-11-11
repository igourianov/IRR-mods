# Hold breath tap or hold

## Intent

The vanilla **Hold Breath** key serves both toggle and hold use, decided by how long it is held:

- Tap: toggles, as in vanilla. A tap starts the hold breath and it stays on until the next press, or until it ends by itself.
- Hold: holds breath only while the key is down. Released past the tap window, the hold breath ends.

No new keybind: the vanilla key keeps its binding and its row in the controls menu. A config switch restores the vanilla toggle.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from a UE4SS dump or Live View and are recorded here (project rule). UObject access happens on the game thread only, no UObject is cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The mod never consumes or remaps the vanilla key. It reads the key's binding from the active key profile and polls it, like its own keys, so a rebind in the controls menu applies at once.
- Only the vanilla press starts a hold breath. Ruled out: starting it when the player aims while the key is already held, or again once stamina recovers after running out mid-hold. Vanilla doesn't, and a restart would loop on and off at the stamina threshold.
- The tap window is the mod's shared `tap_ms`, the one the Flashlight and Combat Heal keys use.
- The mod ends only a hold breath that is active at a release past the tap window. One that already ended itself, out of stamina or by an interrupting ability, or that the press itself toggled off, stays ended. A release never starts one.
- Ruled out: a new mod binding. Bound to the same key as the vanilla one, both would fire and the two toggles would cancel out, so the player would have to unbind the vanilla key first.

Verified in the dumps (`UE4SS_ObjectDump.txt`, `CXXHeaderDump`, build 26487830):

- `/Game/Blueprints/InputSystem/InputActions/IA_HoldBreath.IA_HoldBreath` has one trigger, `InputTriggerPressed`, and a `PlayerMappableKeySettings` subobject, so it has a row in the key profile.
- It is handled by `IH_HoldBreath_C` in `/Game/Blueprints/InputSystem/DA_IngameInput.DA_IngameInput` (`IH_HoldBreath_C_0`), a `UInputHandler_TriggerSimpleAbility` with `AbilityTag` and `bOnlyTab`.
- The ability is `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_HoldBreath.SGA_HoldBreath_C`, a `USimpleGameplayAbility_Toggleable`, with `MinArmStamina`, `CanStartAbility`, `IsAbilityToggled` and `FinishAbility`. It starts and stops the effect `SGE_HoldBreath_C`. Each player character holds one instance under its `BP_GameplayAbilityComponent`.
- `UGameplayAbilityComponent` has `ActiveAbilities` (`TArray<USimpleGameplayAbility*>`), the abilities running now, and `StopAbilityByClass`. The pawn returns it from `GetAbilityComponent()`.

Verified in game (per the user):

- A one-frame injected `IA_HoldBreath` press while the hold breath is active ends it, as a second press of the key does in vanilla.

Verified in `EnhancedInputUserSettings.sav` (`tools/clear-keybinds/clear-keybinds.ps1` listing):

- The key profile row of `IA_HoldBreath` is named `IA_HoldBreath`. The user's binding shares its key with `IA_Run`, so the key runs when not aimed and holds breath when aimed.

Assumptions, unverified:

- A2. `keymap.keys` returns a vanilla row's bound keys the same way it returns the mod's own.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/actions.lua`: the `HoldBreath` action.
- `likhos-point-and-shoot/Scripts/config.lua`: the `hold_breath` bind, its line in the `tap_ms` description and the description of a bind's `mapping`.
- `likhos-point-and-shoot/README.md`: the Hold Breath section.

Context only: `input.lua` polling and the context gate, `triggers.lua` hold state, `keymap.lua` key lookup, the vanilla input handler and ability.

## Solution

`config.lua` holds a `hold_breath` bind like the mod's other binds, with `block_in_ui`, whose `mapping` is the vanilla row `IA_HoldBreath` and whose `action` is `HoldBreath`. A bind's `mapping` is any key profile row name: one of the mod's own from `keymap.MAPPINGS` or a vanilla one. The bind's `enabled` is the switch. Set false, the key is vanilla.

Since it is an ordinary bind, `input.poll` reports its press and release and `kb_status` lists it with its keys, with no change to either.

`actions.lua` defines `HoldBreath` with a press and a release side. The vanilla handler toggles the hold breath on the press itself. The action's press records only the press time, a plain value, the way `Flashlight` tells a tap from a hold. On a release within the tap window it does nothing. On a later release, it finds the local pawn's ability component and checks whether `SGA_HoldBreath_C` is active. If it is, it ends it through the vanilla toggle path, a one-frame `IA_HoldBreath` press through the existing `inject_press`.

Flow:

1. The player aims and presses the Hold Breath key. Vanilla toggles `SGA_HoldBreath_C`: it starts it, ends a running one, or does nothing when not aimed or low on stamina. The mod records the press time.
2. Released within the tap window, the mod does nothing. The hold breath stays as the press left it.
3. Released later with the hold breath active, the mod injects one `IA_HoldBreath` press. Vanilla toggles it off on the next frame.
4. Released later after the hold breath ended by itself, or when the press ended it or never started it, the mod does nothing.

The player sees a tap toggle the hold breath as in vanilla, and a hold last exactly as long as the key is down, capped by stamina as in vanilla.

`README.md` has a Hold Breath section saying the vanilla key now toggles on a tap and holds on a hold, and naming the config switch.

## Tradeoffs

- Ending through an injected key press over `StopAbilityByClass`: the hold breath ends the way the vanilla second press ends it, with its own finish path and effect cleanup. The cost is a one-frame delay and a small window where the hold breath runs out of stamina between the check and the injected press, which would then start a new one.
- Sharing `tap_ms` over a separate hold breath tap window: one setting for every tap/hold key. The cost is that it can't be tuned for hold breath alone.
- Modifying the vanilla key over a new binding: no setup for the player and no key conflict. The cost is that the mod changes a vanilla control by default, which the config switch undoes.
