# Findings

Fill this in during recon. This is the file that turns into `actions.lua`.

## Environment

| | |
|---|---|
| Game build ID | 22417726 |
| Date verified | 2026-09-18 |
| Engine version | **5.6** (NOT 5.4 - wikis say 5.4, the binary says 5.6) |
| UE4SS version | experimental `v3.0.1-1136-g35d1795d` (zDEV) - stable 3.0.1 CANNOT scan this build |
| UE4SS injects cleanly | **yes** - all scans resolve, HashTables self test passes (7657 classes) |
| GraphicsAPI setting that worked | `opengl` (default; no dx12 option exists in this build) |

## Working UE4SS config

Hard-won. Do not change these without re-testing.

```ini
[EngineVersionOverride]
MajorVersion = 5
MinorVersion = 6      ; <-- 4 causes a deterministic crash at first tick

[General]
EnableHotReloadSystem = 1
bUseUObjectArrayCache = true

[Debug]
GuiConsoleEnabled = 1
GuiConsoleVisible = 1
GraphicsAPI = opengl
```

`Mods/mods.txt`: `KismetDebuggerMod` and `EventViewerMod` set to 0 (not required;
setting 0 stops them starting, though the DLLs still load into the process).

### Failure modes seen, and what they meant

| Symptom | Cause |
|---|---|
| Stable 3.0.1: `Failed to find GUObjectArray` / `FText`, `PS scan timed out` | 3.0.1 has no UE5.6 support. Not a per-build signature issue. |
| Experimental + `MinorVersion = 4`: AV writing to exe image at `+0x15EF0F0`, right after `UStruct::Link` | Wrong engine version -> wrong member/vtable layouts when installing hooks. Deterministic, identical address every run. |

`WARNING: VTable and scan addresses differ for UGameEngine::Tick` still appears
on a healthy run - it is not fatal.

## Input stack

| Object | Present? | Full name |
|---|---|---|
| `EnhancedInputLocalPlayerSubsystem` | ☐ | |
| `EnhancedInputUserSettings` | ☐ | |
| `PlayerInput` (legacy mappings) | ☐ | |

Decision: ☐ IMC mutation ☐ MapPlayerKey ☐ pak override ☐ no interception

## Mapping contexts

Output of `kb_dump_imc` during an active raid:

```
(paste here)
```

`FEnhancedActionKeyMapping` property names observed:

| Property | Type | Notes |
|---|---|---|
| | | |

## Classes

| Role | Class name |
|---|---|
| PlayerController (raid) | `BP_InGamePlayerController_C` `/Game/Blueprints/Gameloop/InGame/BP_InGamePlayerController` |
| PlayerController (hideout) | `BP_HideoutPlayerController_C` `/Game/Blueprints/Gameloop/Hideout/BP_HideoutPlayerController` |
| PlayerController (main menu) | `PC_MenuController_C` `/Game/ThirdParty/UltimateShooterKit/UltimateMenu/Blueprints/Framework/PC_MenuController` |
| PlayerController (other) | `BP_RadialInputPlayerController_C` `/Game/ThirdParty/GenericRadialMenus/Blueprints/BP_RadialInputPlayerController`. Role unknown. |
| Player pawn | `BP_IRR_PlayerCharacter_C` `/Game/Blueprints/Gameloop/BP_IRR_PlayerCharacter`. From the object dump, not yet seen live. |
| Input handler owner | Abilities under `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/` (`SGA_*_C`), not the pawn directly. See Aim and point sight. |

PlayerController classes observed 2026-09-18 via `NotifyOnNewObject("/Script/Engine.PlayerController")`, all loaded at startup as class default objects (`Default__...`). The only live instance at the main menu was `LVL_Menu:PersistentLevel.PC_MenuController_C_<n>`. The raid and hideout rows are named by asset path only. Confirm each one is live in its level.

## Action handlers

| Action | Class | Press fn | Release fn | Args | Verified |
|---|---|---|---|---|---|
| Sprint | | | | | ☐ |
| Crouch | | | | | ☐ |
| Lean L/R | | | | | ☐ |
| Interact | | | | | ☐ |
| Aim | | | | | ☐ |

## Aim and point sight

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

## Enhanced Input injection

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

## Key state polling

`PlayerController:IsInputKeyDown({ KeyName = FName("H") })`, polled every 16 ms from `LoopAsync` through `ExecuteInGameThread`, reports each press and release of H (`kb_probe_key`, 2026-09-18). A struct parameter can be passed as a Lua table. The shortest press observed was about 70 ms, and it was caught.
- The game logs `LogTemp: Warning: Activating ability SGA_<Name>_C_<n>` on each ability activation. It shows in the UE4SS log window and is useful for tracing.

Unconfirmed:

- `SGA_Aim_C` and `SGA_PointSight_C` cast to `FPCC_Aiming_Base`, but the live aiming subobject is `BP_FPCC_ADS_C`. How the two relate is unknown.
- Aim runs through an ability. Calling `TriggerAim` directly skips `SGA_Aim_C`, so ability state such as tags, movement speed or sprint cancel may not follow.

## UI focus detection

Property that reliably differs menu-open vs menu-closed:

| Object | Property | Closed | Open |
|---|---|---|---|
| PlayerController | `bShowMouseCursor` | | |

## Open questions

-
