# Point aim bind

## Intent

A dedicated "Point Aim" keybind on H. Holding it aims straight into point aim. Releasing it ends the aim.

Today point aim is reachable only as a mode of regular aim: aim, then press the mode switch. The mode is sticky, so it carries into the next regular aim. The new bind must not disturb that: after it is released, regular aim is in whatever mode it was in before.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from recon recorded in `docs/solutions/findings.md` (project rule). Engine names (`APlayerController`, Enhanced Input) are not game internals and may be used directly.
- The bind is client-local. No replication, no host requirement.
- UObject access happens on the game thread only, UObjects are never cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The key is fixed to H in `config.lua`. User-facing configuration of this bind (an unbound default, a row in the game's controls menu) is out of scope for now.
- The `hold` timeout approximation in `triggers.lua` is ruled out for this bind. Aim ending 150 ms after the press is not hold.
- Aim is driven through the game's own `IA_Aim` input action, not by calling `FirstPersonWeaponADS:TriggerAim`. A direct call aims on screen but skips the `SGA_Aim_C` ability, so the game doesn't treat the player as aiming (the sprint key sprints instead of holding breath).
- `IA_Aim` is held by injecting a one-frame press every tick. Continuous injection is ruled out: its `FInputActionValue` parameter can't be built from UE4SS Lua (`docs/solutions/findings.md`, Enhanced Input injection).
- The tick runs on the game thread through UE4SS's `LoopInGameThreadWithDelay`. `LoopAsync` with an `ExecuteInGameThread` hop per tick is ruled out: it corrupted the Lua state and crashed the game within minutes (`docs/solutions/findings.md`, Lua threading).
- While H is held, pressing the vanilla aim key changes nothing, and point aim stays. H injects the same `IA_Aim` input the aim key produces, so the game can't tell them apart. Handing control to the aim key would mean polling the physical aim key, which the mod can't identify without reading the player's bindings. That's ruled out until configurable bindings are in scope. Releasing H while the aim key is held leaves the player aimed in the restored mode.
- The mode is read from `BP_WeaponComponent.bIsPointSight` on the equipped weapon. The aiming subobject's own `bIsPointSight` doesn't track the mode.

Verified by recon (`docs/solutions/findings.md`): `IsInputKeyDown` polling reports H press and release. Per-tick injection of `IA_Aim` holds aim, follows the sticky mode and behaves like vanilla aim (the sprint key holds breath). `TriggerPointSight` on the aiming subobject flips the sticky mode while not aimed.

Assumptions, unverified:

- A2. Per-tick injection from the 16 ms tick loop holds aim without flicker at any game frame rate. No flicker was seen on a setup using Radeon driver frame generation. Generated frames don't run game ticks, so that setup's real game tick rate was lower than its displayed frame rate. At a native game frame rate above roughly 60 fps, some frames get no injection, which may read as a release. This doesn't block the build. If it fails, the fix is to run the tick per frame with `LoopInGameThreadAfterFrames`.
- A3. Flipping the mode with `TriggerPointSight` just before injected aim starts brings aim up directly in point aim. Flipping it back right after the injection stops, while aim is transitioning out, leaves the mode restored.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/triggers.lua`: hold mode.
- `likhos-point-and-shoot/Scripts/input.lua`: bind registration for polled binds.
- `likhos-point-and-shoot/Scripts/actions.lua`: the `PointAim` action.
- `likhos-point-and-shoot/Scripts/config.lua`: the `point_aim` bind entry.
- `likhos-point-and-shoot/Scripts/main.lua`: startup wiring and the game-thread tick loop.
- `likhos-point-and-shoot/Scripts/probe.lua`: throwaway recon. Not part of the end state.
- `docs/solutions/findings.md`: recon results.

Context only: `context.lua` (UI gate, reused unchanged), `util.lua`, `log.lua`, the game's own aim and point sight bindings.

## Solution

### Bind definition

`config.lua` holds a `point_aim` bind: mode `hold`, action `PointAim`, `block_in_ui = true` and an engine key name (`engine_key = "H"`) instead of a UE4SS key name. Binds with a UE4SS `key` keep using `RegisterKeyBind` as today.

### Press and release: `input.lua` and `triggers.lua`

- For `engine_key` binds, `input.lua` registers no UE4SS key bind. The tick loop polls `IsInputKeyDown` on the PlayerController for that key and turns the transitions into press and release events for `triggers.lua`.
- `triggers.lua` hold mode is a real hold for these binds. Press invokes the action's press side, every tick while held invokes its held side, and release invokes its release side. Release is also forced on level load (trigger reset) and when the context gate starts blocking mid-hold, so aim never sticks on.
- The UI gate from `context.lua` applies to the press as for every other bind.

### Action: `PointAim` in `actions.lua`

`actions.lua` holds two kinds of action. A plain entry is a pair of UFunction names on a class, as today. A scripted entry is Lua functions for press, held and release. `PointAim` is scripted. It resolves everything by name at call time and holds no UObject between ticks:

- Aiming subobject: `FirstPersonCoreFunctionLibrary:GetFirstPersonCoreSubObject(pawn, FirstPersonWeaponADS)`.
- Mode flag: `bIsPointSight` on the equipped weapon's `WeaponComponent`, found through `InventoryFunctionLibrary:GetEquippedWeapon(pawn)`.
- Aim: `IA_Aim` injected through the `EnhancedInputLocalPlayerSubsystem` with `InjectInputVectorForAction`.

Behaviour:

- Press: records whether the mode was already point. If not, flips it with `TriggerPointSight` on the aiming subobject. Then injects `IA_Aim`.
- Held: injects `IA_Aim` again.
- Release: stops injecting, so the game sees the aim input released and ends aim through its own path. If the mode was flipped on press, flips it back with `TriggerPointSight`.
- A weapon switch during the hold ends the aim, and it stays ended until H is released and pressed again, because re-injecting a held `IA_Aim` isn't a new press. Release then restores nothing, and the weapon that was flipped keeps point mode. Handling the switch (restoring the first weapon, re-aiming on the new one) is ruled out as not worth the extra object lookups. If the player switched the mode back themselves mid-hold, release doesn't flip it again.
- The recorded "flipped" flag and weapon identity are plain Lua values and are cleared on level load. With no pawn, aiming subobject or weapon, press does nothing and nothing is recorded.

### Result

Holding H goes straight into point aim, with the game treating it as normal aiming. Releasing H drops aim, and the regular aim key afterwards behaves in whatever mode it had before. With a menu or text field focused, the key does nothing.

## Tradeoffs

- Polling key state over UE4SS `RegisterKeyBind`: gives a release event, which `RegisterKeyBind` lacks, at the cost of up to one tick (16 ms) of latency and a second key-naming scheme in `config.lua`.
- Injecting `IA_Aim` over calling `TriggerAim`: the game runs its full aim path, abilities included, at the cost of per-tick injection and its frame-rate risk (A2).
- Flipping the mode with a direct `TriggerPointSight` call over injecting `IA_PointSight`: aim comes up already in point aim with no visible switch, and the mode can be restored after aim ends. Injected `IA_PointSight` has only been seen working while aimed. The cost is a dependency on one native function name.
- The keystroke isn't consumed, so H must be free in the game's own bindings. If a vanilla action uses H, both fire.

## Open questions

- Should `hold` mode for ordinary `config.lua` binds (UE4SS key names) also move to `IsInputKeyDown` polling, retiring the timeout approximation everywhere? Currently out of this solution's scope.
