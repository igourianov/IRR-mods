# Magnifier zoom

## Intent

On a hybrid sight with a flip magnifier (the EOTech HHS-1), the vanilla zoom input (mouse wheel) folds and unfolds the magnifier, using the same vanilla flip as the **Toggle Magnifier** key. The wheel direction sets the state. It never toggles:

- Scroll forward (zoom in) unfolds the magnifier. With it already unfolded, scroll forward does nothing to it.
- Scroll back (zoom out) folds it. With it already folded, scroll back does nothing to it.
- Several notches in one direction end in that direction's state. They never fold and unfold back and forth.

It works aimed and not aimed, the same as the vanilla Toggle Magnifier key and the vanilla zoom on a variable scope. The vanilla Toggle Magnifier key keeps working, and zoom on every other optic behaves as vanilla.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from a UE4SS dump or Live View and are recorded in this doc (project rule). Everything this solution uses is listed below.
- UObject access happens on the game thread only, UObjects are never cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The feature fires whenever vanilla zoom fires. Vanilla zoom runs while not aimed, and the mod adds no aim gate of its own.
- The magnifier is flipped through the vanilla input path, so the vanilla ability, its animation and its own gating apply unchanged. Ruled out: `SightComponent:SetSightMode` and `TryCycleSightMode` called from the mod. The vanilla flip also changes an item tag that the sight's anim blueprint reads for the folded or unfolded pose, so a direct mode change would likely leave the model and the view out of step.
- The fold state is read from the game every time, never tracked by the mod, so a flip done with the vanilla key is always accounted for.
- The magnifier flips only when the zoom input has nowhere left to go on the current sight. A sight with several magnification levels steps through them first, as vanilla, and the magnifier flips at the end stop.
- No hooks on `TacticalComponent` or `WeaponComponent` functions. Native hooks there crashed the game when the vanilla device toggle fired.
- Ruled out: polling the wheel keys from the tick loop. A wheel notch is a press and release inside one frame, which a 16 ms timer misses. Ruled out: hooking `IH_SwitchMagnificationLevel_C:HandleTriggeredEvent`. Its direction is in an `FInputActionValue`, which has no reflected properties and can't be read from Lua.

Names from `UE4SS_ObjectDump.txt` (2026-09-22):

- Input actions under `/Game/Blueprints/InputSystem/InputActions/`: `IA_SwitchMagnificationLevel` (`InputTriggerDown`), handled by `IH_SwitchMagnificationLevel_C` in `DA_IngameInput`, and `IA_ToggleMagnifier` (`InputTriggerPressed`, has `PlayerMappableKeySettings`), the vanilla Toggle Magnifier key, handled by `IH_ToggleMagnifier_C` and the ability `SGA_ToggleMagnifier_C`.
- `IH_SwitchMagnificationLevel_C:HandleTriggeredEvent` gets the equipped weapon, its weapon component and `WeaponComponent:GetCurrentSightComponent()`, then calls `SightComponent:TrySwitchMagnificationLevel(bIncrement)`.
- `SightComponent` (`/Script/Test_C`): `SightModes` (map of name to sight data), `SightModeKey` (name), `SetSightMode(NewMode)`, `TryCycleSightMode()`, `MagnificationIndex`, `GetMagnificationLevel()`, `GetSightData()`.
- `BP_EOTECH_HHS-1_Hybrid_Sight_C` holds `BP_HybridSightComponent` (`BP_SightComponent_C`), `SightData_Folded` and `SightData_UnFolded`. Its `ExecuteItemAction` calls `HasTag`, selects between two names and calls `TryCycleSightMode`. Its anim blueprint `ABP_EOTECH_HHS-1_Hybrid_Sight_Skeleton_C` calls `HasTag` to choose the pose. The item `ID_EOTECH_HHS-1_Hybrid_Sight` carries the item action `IA_ToggleMagnifier_C`.

Verified by a probe, 2026-09-23 in the hideout, on an MPX with the HHS-1 and a gun with an EOTech Vudu 1-6x:

- `WeaponComponent:GetCurrentSightComponent()` returns the sight. The HHS-1 is one sight component, the weapon's only entry in `LocSightComponents`.
- Each wheel notch, aimed or not, calls `TrySwitchMagnificationLevel` on the equipped weapon's current sight, with `bIncrement` true for scroll forward and false for scroll back. One flick delivers several notches 20 to 55 ms apart.
- A native pre and post hook on that function held through scrolling and vanilla magnifier flips without a crash. `bIncrement` reads correctly in the pre callback only. The post callback's parameter values are unreliable.
- A notch hit the end stop exactly when `MagnificationIndex` is the same after the call as before it. Otherwise it moves by one: the Vudu steps 1.5x, 3x, 6x at index 0, 1, 2 and stops at either end.
- The HHS-1's `SightModes` holds `Default` (unfolded, 3.0x) and `Folded` (folded, 1.0x), each with a single level, so every notch on it is at the end stop. The Vudu's `SightModes` holds `Default` only.
- `SightModeKey` changes within the first 16 ms tick of a flip, not at the end of the animation, whether the flip comes from the vanilla key or an injected press. Two vanilla presses 816 ms apart both flipped.
- A one-frame `InjectInputVectorForAction(IA_ToggleMagnifier, {X=1,Y=0,Z=0}, {}, {})` on `EnhancedInputLocalPlayerSubsystem` flips the HHS-1 with the vanilla animation, the same as the key.

Assumptions the build checks:

- An injected `IA_ToggleMagnifier` press made from inside the zoom hook is picked up on a following frame, as the probe's injection from a console command was.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/magnifier.lua`: the feature.
- `likhos-point-and-shoot/Scripts/actions.lua`: the one-frame action injection that `PointAim` and the magnifier share.
- `likhos-point-and-shoot/Scripts/main.lua`: installing and resetting the feature.
- `likhos-point-and-shoot/Scripts/config.lua`: the feature switch.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description and the version it ships in.

Context only: the vanilla zoom handler and Toggle Magnifier ability, `input.lua`, `triggers.lua`, `menu.lua`, `keymap.lua`, `devices.lua`, `util.lua`, `log.lua`.

## Solution

### `magnifier.lua`

Owns every game name to do with sights and the magnifier. Holds no UObject between calls.

- `install()` registers a pre and post hook on `/Script/Test_C.SightComponent:TrySwitchMagnificationLevel`, once per session, following `menu.lua`'s pattern: resolved by name, a refusal logged once and the feature left off rather than failing the mod.
- The pre callback records the call's direction and the sight's `MagnificationIndex`. The post callback compares the index to tell whether the notch moved the zoom.
- The direction maps to a target mode: scroll forward to `Default` (unfolded), scroll back to `Folded`.
- After a call the hook acts only when all of these hold:
  - the sight is the current sight of the local player's equipped weapon,
  - the call did not move the magnification,
  - the sight's `SightModes` has a `Folded` entry, its `SightModeKey` is not the target mode and no flip the mod requested is pending.
- It then injects one `IA_ToggleMagnifier` press through the Enhanced Input subsystem and records a pending flip: plain values only, the sight's full name, the target mode and the time. The vanilla ability does the flip.
- A pending flip clears once the sight reads the target mode, the sight is no longer current or a short timeout passes. While it is pending, further notches inject nothing, so the rest of a flick's notches, which arrive before the game has handled the injected press, can't send a second toggle that undoes the first. The pending flip also clears on level load.
- Every hook body runs under `util.safe`. A failed state read logs once per session and leaves zoom vanilla.

### `actions.lua`

The one-frame press injection is one function parameterized by input action path, used by `PointAim` for `IA_Aim` and by `magnifier.lua` for `IA_ToggleMagnifier`. `PointAim`'s behavior is unchanged.

### `main.lua` and `config.lua`

`config.lua` has a top-level `magnifier_zoom` switch, default true, documented as "the zoom input folds and unfolds the magnifier on a hybrid sight". `main.lua` installs `magnifier.lua` when the mod is enabled and the switch is on, independent of the bind list and the tick loop, and resets its pending flip on level load next to `actions.reset`.

### Result

With the EOTech HHS-1 mounted, aimed or not, scrolling forward unfolds the magnifier with the vanilla animation and further forward scrolling leaves it unfolded. Scrolling back folds it and further back scrolling leaves it folded. On a variable scope, the wheel steps through its levels as before. The Toggle Magnifier key and the mod's keys are unaffected.

## Tradeoffs

- Hooking the sight's magnification call over reading the input: the direction and the end stop come from the game's own call, at the cost of a native hook, the kind that crashed on `WeaponComponent`. The probe ran it through scrolling and vanilla flips without a crash.
- Flipping at the end stop over flipping on every zoom input: a hybrid sight whose modes had several levels would still step through them, at the cost of an extra notch there. The HHS-1 has one level per mode, so it flips on the first notch.
- Injecting the vanilla toggle over calling `SetSightMode`: the animation, the item tag, the pose and the ability gating stay vanilla and in step. The cost is that the mod gets only a toggle, so it must read the state before each flip and guard against a burst of notches.
- Ignoring notches while a flip is pending over queueing the last direction: no toggle can undo the mod's own flip. The cost is that a reverse notch inside that short window is dropped.
- No aim gate: the magnifier behaves like the vanilla key and the vanilla LPVO zoom, which both work unaimed.
- A config switch over always on: a player who wants vanilla zoom back doesn't have to remove the mod.
