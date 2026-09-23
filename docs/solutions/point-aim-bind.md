# Point aim bind

## Intent

A dedicated "Point Aim" keybind on H. Holding it aims straight into point aim. Releasing it ends the aim.

Today point aim is reachable only as a mode of regular aim: aim, then press the mode switch. The mode is sticky, so it carries into the next regular aim. The new bind must not disturb that: after it is released, regular aim is in whatever mode it was in before.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from recon recorded in this doc (project rule). Engine names (`APlayerController`, Enhanced Input) are not game internals and may be used directly.
- The bind is client-local. No replication, no host requirement.
- UObject access happens on the game thread only, UObjects are never cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The key is fixed to H in `config.lua`. User-facing configuration of this bind (an unbound default, a row in the game's controls menu) is out of scope for now.
- The `hold` timeout approximation in `triggers.lua` is ruled out for this bind. Aim ending 150 ms after the press is not hold.
- Aim is driven through the game's own `IA_Aim` input action, not by calling `FirstPersonWeaponADS:TriggerAim`. A direct call aims on screen but skips the `SGA_Aim_C` ability, so the game doesn't treat the player as aiming (the sprint key sprints instead of holding breath).
- `IA_Aim` is held by injecting a one-frame press every tick. Continuous injection is ruled out: its `FInputActionValue` parameter can't be built from UE4SS Lua (Recon, Enhanced Input injection).
- The tick runs on the game thread through UE4SS's `LoopInGameThreadWithDelay`. `LoopAsync` with an `ExecuteInGameThread` hop per tick is ruled out: it corrupted the Lua state and crashed the game within minutes (Recon, Lua threading).
- While H is held, pressing the vanilla aim key changes nothing, and point aim stays. H injects the same `IA_Aim` input the aim key produces, so the game can't tell them apart. Handing control to the aim key would mean polling the physical aim key, which the mod can't identify without reading the player's bindings. That's ruled out until configurable bindings are in scope. Releasing H while the aim key is held leaves the player aimed in the restored mode.
- The mode is read from `BP_WeaponComponent.bIsPointSight` on the equipped weapon. The aiming subobject's own `bIsPointSight` doesn't track the mode.

Verified by recon (Recon below): `IsInputKeyDown` polling reports H press and release. Per-tick injection of `IA_Aim` holds aim, follows the sticky mode and behaves like vanilla aim (the sprint key holds breath). `TriggerPointSight` on the aiming subobject flips the sticky mode while not aimed.

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
- The Recon section of this doc: recon results.

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

## Recon

### Classes

| Role | Class name |
|---|---|
| PlayerController (raid) | `BP_InGamePlayerController_C` `/Game/Blueprints/Gameloop/InGame/BP_InGamePlayerController` |
| PlayerController (hideout) | `BP_HideoutPlayerController_C` `/Game/Blueprints/Gameloop/Hideout/BP_HideoutPlayerController` |
| PlayerController (main menu) | `PC_MenuController_C` `/Game/ThirdParty/UltimateShooterKit/UltimateMenu/Blueprints/Framework/PC_MenuController` |
| PlayerController (other) | `BP_RadialInputPlayerController_C` `/Game/ThirdParty/GenericRadialMenus/Blueprints/BP_RadialInputPlayerController`. Role unknown. |
| Player pawn | `BP_IRR_PlayerCharacter_C` `/Game/Blueprints/Gameloop/BP_IRR_PlayerCharacter`. From the object dump, not yet seen live. |
| Input handler owner | Abilities under `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/` (`SGA_*_C`), not the pawn directly. See Aim and point sight. |

PlayerController classes observed 2026-09-18 via `NotifyOnNewObject("/Script/Engine.PlayerController")`, all loaded at startup as class default objects (`Default__...`). The only live instance at the main menu was `LVL_Menu:PersistentLevel.PC_MenuController_C_<n>`. The raid and hideout rows are named by asset path only. Confirm each one is live in its level.

### Aim and point sight

From `UE4SS_ObjectDump.txt` (Ctrl+J), taken 2026-09-18 in the hideout. Class and member names only. Nothing below has been observed firing yet.

Input actions (`/Game/Blueprints/InputSystem/InputActions/`):

| Action | Triggers | Notes |
|---|---|---|
| `IA_Aim` | `InputTriggerPressed`, `InputTriggerReleased` | |
| `IA_PointSight` | `InputTriggerPressed` | The point aim mode switch. Has no `PlayerMappableKeySettings` subobject in the dump, unlike `IA_CycleSights`. |
| `IA_CycleSights` | `InputTriggerPressed` | |

The keyboard bindings widget has a `PointShooting` row: `WB_KeyboardSoldierBindings_C:WidgetTree.PointShooting`.

Abilities: `SGA_Aim_C` and `SGA_PointSight_C` both call `FirstPersonCoreFunctionLibrary:GetFirstPersonCoreSubObject` and cast the result to `FPCC_Aiming_Base`. That Blueprint class isn't loaded in the hideout, so its parent class isn't confirmed. `SGA_Aim_C` also calls `GetEquippedWeapon`.

Native candidates in `/Script/Test_C`:

| Class | Member | Kind |
|---|---|---|
| `FirstPersonWeaponADS` | `TriggerAim(bool bEnabled)` | Function. Start or stop aim. |
| `FirstPersonWeaponADS` | `TriggerPointSight()` | Function, no parameters. Probably flips the mode. |
| `FirstPersonWeaponADS` | `bIsPointSight` | Bool |
| `FirstPersonWeaponADS` | `AimTransitionState` | Enum |
| `QUA_Weapon` | `TriggerPointSight()` | Function |
| `QUA_Weapon` | `isPointSight` | Bool |
| `WeaponComponent` | `bIsPointSight` | Bool |

Observed live 2026-09-18 in the hideout with an SR-25 (`kb_probe_aim`, not aiming, after using point sight):

| Object | How reached | Class chain | Point flag |
|---|---|---|---|
| Aiming subobject `BP_FirstPersonCoreComponent.BP_FirstPersonADS_C_0` on the pawn | `FirstPersonCoreFunctionLibrary:GetFirstPersonCoreSubObject(pawn, FirstPersonWeaponADS)` | `BP_FPCC_ADS_C -> FirstPersonWeaponADS -> FirstPersonWeaponSubObject -> FirstPersonCoreSubObject` | `bIsPointSight = false`, `AimTransitionState = 1` |
| Equipped weapon `BP_SR-25_C` | `InventoryFunctionLibrary:GetEquippedWeapon(pawn)` | `BP_SR-25_C -> BP_MasterWeapon_C -> BP_SkeletalMasterPickup_C -> PickUpActor` | none. It is not a `QUA_Weapon`, so `isPointSight` doesn't apply. |
| `BP_WeaponComponent` on the weapon | `GetComponentByClass(WeaponComponent)` | `BP_WeaponComponent_C -> WeaponComponent` | `bIsPointSight = true` |

- The player pawn is `BP_IRR_PlayerCharacter_C -> PlayerBaseCharacter -> IRRBaseCharacter -> Character`.
- The weapon component's flag is set while the aiming subobject's is clear when not aiming. The sticky mode probably lives on the weapon component, which makes it per weapon, and the ADS flag probably reflects the live aim. Not yet confirmed.
- `TriggerPointSight()` on the aiming subobject, called while not aiming, flipped `BP_WeaponComponent.bIsPointSight` from `true` to `false` at once (`kb_probe_point`). The aiming subobject's `bIsPointSight` stayed `false`. So the call toggles the sticky mode, and the weapon component holds it.
- `TriggerAim(true)` on the aiming subobject, called from the console with the aim key up, enters aim and stays aimed. `TriggerAim(false)` ends it. The game does not cancel a directly started aim. But this aim skips `SGA_Aim_C`. In vanilla, the sprint key while aiming activates hold breath (`SGA_HoldBreath_C`). With the directly started aim, the sprint key sprints and aim stays up. The game treats the player as not aiming. It also came up as regular aim, and it's unconfirmed whether the weapon was in point mode at the time.
- `QUA_Weapon` is not the player's weapon class and is likely unrelated.

### Enhanced Input injection

Probed 2026-09-18 in the hideout with `kb_probe_inject`, through `FindFirstOf("EnhancedInputLocalPlayerSubsystem")`. UE4SS resolves the interface UFunctions (`EnhancedInputSubsystemInterface:*`) through the subsystem object.

| Call | Result |
|---|---|
| `InjectInputVectorForAction(IA_Aim, {X=1,Y=0,Z=0}, {}, {})` once | Aim starts and is cancelled on the next frame. `IA_Aim` has a Released trigger, so a one-frame press reads as press then release. |
| The same call every 16 ms from `LoopAsync` for 3 s | Aim holds for the full 3 s, then ends. |
| `StartContinuousInputInjectionForAction(IA_Aim, value, {}, {})` | Returns ok, no aim. `FInputActionValue` has no reflected properties. A Lua table can't fill it, and `EnhancedInputLibrary:MakeInputActionValueOfType` returns it to Lua as a plain table, so the value is lost either way. Unusable from UE4SS Lua. |

Point sight with injected aim (`aim_pulse_point`, `aim_pulse`):

- Injecting one `IA_PointSight` press 500 ms into an injected aim switches to point aim on screen. It flips `BP_WeaponComponent.bIsPointSight` from `false` to `true`, the same as the vanilla key.
- With the weapon component flag at `true`, a fresh injected aim comes up directly in point aim. Injected aim follows the sticky mode.
- The aiming subobject's `bIsPointSight` read `false` at every sample, including while aimed in point mode. It isn't a usable mode source. The weapon component's flag is.
- `AimTransitionState` read 1 when idle or just starting, 0 while aimed and 2 at the end of a pulse. Its meaning isn't confirmed and nothing depends on it.

`util.now_ms()` (`os.clock`) measured the 3 s pulse as 3.0 s of wall time (log timestamps 20:04:58.10 to 20:05:01.10).

### Key state polling

`PlayerController:IsInputKeyDown({ KeyName = FName("H") })`, polled every 16 ms from `LoopAsync` through `ExecuteInGameThread`, reports each press and release of H (`kb_probe_key`, 2026-09-18). A struct parameter can be passed as a Lua table. The shortest press observed was about 70 ms, and it was caught.

Unconfirmed:

- `SGA_Aim_C` and `SGA_PointSight_C` cast to `FPCC_Aiming_Base`, but the live aiming subobject is `BP_FPCC_ADS_C`. How the two relate is unknown.
- Aim runs through an ability. Calling `TriggerAim` directly skips `SGA_Aim_C`, so ability state such as tags, movement speed or sprint cancel may not follow.

### Lua threading

Seven crashes between 20:16 and 21:01 on 2026-09-18, all `EXCEPTION_ACCESS_VIOLATION` inside UE4SS's Lua runtime on the game thread (`lua_getiuservalue`, `lua_rawgeti`, `lua_getfield`, `push_nameproperty`), at different call sites. Six entered through `process_simple_actions` (the `ExecuteInGameThread` queue), one through a console command. Crash reports: `%LOCALAPPDATA%\Test_C\Saved\Crashes\*\CrashContext.runtime-xml`. `UE4SS.log` loses its tail on a hard crash, and a relaunch overwrites it.

They started when the first always-on bind started a 16 ms `LoopAsync` whose callback called `ExecuteInGameThread`. Non-fatal symptoms of the same corruption: `ipairs` "number expected, got function" and `IsInputKeyDown` "expected 1 parameters, received 2". With no loop running, and later with the loop on `LoopInGameThreadWithDelay`, no crash occurred across several sessions of menu probing and play.

This UE4SS build deprecates `LoopAsync` and `ExecuteAsync` in favour of the game-thread delayed actions (`LoopInGameThreadWithDelay`, `LoopInGameThreadAfterFrames`, `ExecuteInGameThreadWithDelay`), citing thread safety. See `ue4ss\Changelog.md` and `ue4ss\Docs\lua-api\global-functions\delayedactions.md`.

#### Hot reload and delayed actions

Probed 2026-09-21 with Ctrl+R in the hideout.

- `ModRef` is userdata with no readable metatable. `ModRef:OnUnload` is nil at runtime (`attempt to call a nil value (method 'OnUnload')`), although `Mods\shared\Types.lua` from the same install declares it. Upstream lists it under v4.0.0-rc1.
- `CancelDelayedAction`, `ClearAllDelayedActions`, `IsValidDelayedActionHandle`, `ModRef:SetSharedVariable` and `ModRef:GetSharedVariable` exist.
- Delayed action handles are process-wide integers (1, 4, 5, 6 across reloads).
- A hot reload cancels the unloaded mod's `LoopInGameThreadWithDelay` loop. The old handle reads invalid from the new instance, and a per-second heartbeat from the old loop stopped at the reload while the new loop's kept going. No crash across three reloads.
