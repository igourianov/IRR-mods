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
| `EnhancedInputLocalPlayerSubsystem` | ☑ | `/Engine/Transient.GameEngine_<n>:LocalPlayer_<n>.EnhancedInputLocalPlayerSubsystem_<n>` |
| `EnhancedInputUserSettings` | ☑ | `/Engine/Transient.EnhancedInputUserSettings_<n>`, from `subsystem:GetUserSettings()`. Saved to `%LOCALAPPDATA%\Test_C\Saved\SaveGames\EnhancedInputUserSettings.sav`. |
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

## Enhanced Input user settings

Probed 2026-09-18 with `kb_probe_keymap` (throwaway `probe.lua`).

- An `InputAction`, its `PlayerMappableKeySettings` (outer: the action, `Name` set to the mapping name) and an `InputMappingContext` can be built at runtime with `StaticConstructObject` in `/Engine/Transient`. `imc:MapKey(action, { KeyName = FName("None") })` adds an unbound mapping. It inherits the action's mappable settings (`SettingBehavior = 0`).
- `settings:RegisterInputMappingContext(imc)` returns true the first time, false once registered. `IsMappingContextRegistered` stays true. Registering adds a row for the mapping name to the active key profile (`settings:GetActiveKeyProfile()`).
- `profile:GetMappedKeysInRow(FName(name), out)` fills the Lua table `out` with struct wrappers. Read a key as `out[i]:get().KeyName`, not `out[i].KeyName`. An unbound row reports one key, `None`.
- A key bound through the controls menu is saved with the rest of the profile. After a game restart, re-registering the context restores it (bound J, restarted, row read J before the menu was opened).
- The constructed objects survive hot reload (found again by path). UE4SS has no `GetPathName` on UObject, so they are looked up as `/Engine/Transient.<name>`.

## Controls menu

From the object dump and `kb_probe_row` / `kb_probe_clone`, 2026-09-18.

- The keyboard bindings page is `WB_KeyboardSoldierBindings_C` (`/Game/Blueprints/UICore/Widgets/Settings/`), owned by the GameInstance (`UMS_GameInstance_C`). Each session has several live instances. Only one is on screen. The others' rows were never constructed: `IsVisible()` is false and their `LabelText` still reads "Text Block". `FindAllOf` also returns the blueprint's own template rows under `/Game/...:WidgetTree.<name>`.
- Rows are `WB_SingleSettingBar_C` in the page's `SettingsContainer`, a `VerticalBox` (51 children). `PointShooting` is child 22.
- A keybinding row has `BarType = 4`. Its label is `SettingBar.LabelSettings_17_….Text_3_…` (`Struct_SettingBar` → `Struct_CategoryHolderSettings`), not `Title`. Its key data is `Keybindings`, an array of `Struct_InputKeyInfo`: `KeyType_20_…`, `SharedMapNames_36_…`, `InputAction_41_…`, `PlayerMappedName_60_…`, `InputMapIndex_58_…`. The vanilla PointShooting row holds one entry: `IA_PointSight`, mapped name `IA_PointShooting`, index 0, type 0.
- Rebinding runs in `WB_KeyBindingButton_C:ReceiveInput` through `EnhancedInputUserSettings:MapPlayerKey`. The page calls `ResetKeyProfileToDefault` for reset.
- A key button shows its key through `WB_KeyBindingButton_C:FindInputActionKey`, which reads the subsystem's `QueryKeysMappedToAction` and `GetAllPlayerMappableActionKeyMappings`. Both see only contexts in the active input stack. A context registered with user settings but not added to the stack shows None after a restart, though its saved key is restored. Added with `AddMappingContext` at priority -1000, it shows the saved key, and a vanilla action on the same key keeps firing.
- A working mod row: `WidgetBlueprintLibrary:Create(page, WB_SingleSettingBar_C, row:GetOwningPlayer())`, copy `BarType`, `SettingBar` and `Keybindings` from `PointShooting` (assignment copies by value, the source stays unchanged), set the label text and the entry's action and mapped name, add it to `SettingsContainer`, then call `On_WidgetConstructed()` and `Toggle_Widget(false, 0)`. `On_WidgetConstructed` applies the label and switches `TypeSwitcher` to the keybinding view (index 4). It also leaves `Container` at opacity 0, the start of the fade-in the page normally plays. `Toggle_Widget` brings it to 1. `PreConstruct(false)`, `On_Panel_Loaded` and `Refresh_Keybinding` change nothing visible.
- The row then rebinds, applies and saves like a vanilla row, keyed by the mod's mapping name.
- `PanelWidget` has no `InsertChildAt` UFunction (`parent.InsertChildAt` returns a non-nil stub). A row lands after `PointShooting` by removing the children below it, adding the new row, then re-adding them. `AddChild` creates a fresh `VerticalBoxSlot`, so padding, size and alignments are copied from the old slot. Layout and navigation were unaffected in-game.
- Adding a second mod row to the same page (as after a hot reload) left two rows on one mapping name. A bound key did not survive that session.
- At startup `StaticFindObject` can find `WB_SingleSettingBar_C:On_WidgetConstructed` while its class is still loading. `RegisterHook` then throws "Was unable to register a hook" with `UFunction::Func: 0x0`, `FUNC_Native: 0` (2026-09-19). Retrying from a `NotifyOnNewObject` on the row class succeeds before the main menu is up.

## Tactical devices

From the object dump and `kb_probe_laser` / `kb_probe_laser_set`, 2026-09-19 in the hideout, on an AUG A3 (CQBL-1 laser, APLc flashlight) and a SCAR-L (PEQ-15, Klesch 2IKS3, CQBL-1).

- `WeaponComponent:TacticalAttachments` on the equipped weapon's `BP_WeaponComponent` lists one component per emitter across all mounted devices. Lasers are `LaserComponent` (native, subclass of `TacticalComponent`). Lights are `BP_FlashlightComponent_C`.
- Each laser emitter is its own component. Two-laser devices name them `Laser_A` and `Laser_B`. The single-laser Klesch names it `Laser`.
- `TacticalComponent` state: `DeviceState` (`EIRRTacticalDeviceState`: `Off` = 0, `On` = 1), `GetDeviceState()`, `IsDeviceActive()`.
- The infrared flags don't mark IR lasers. `bHasInfraredMode`, `bDeviceInfraredOn` and `IsInInfraredMode()` read false on every laser, including the on IR ones. The PEQ-15's flashlight has `bHasInfraredMode = true` (IR illuminator mode).
- Visible vs IR laser shows in `LaserComponent.LaserSettings.DefaultLaserMaterial.Laser` (`IRRLaserSettings` → `IRRLaserMaterial`), an asset reference. `LaserSettings.InfraredLaserMaterial.Laser` is nil on all lasers seen.

| Device | Component | `DefaultLaserMaterial.Laser` | Seen in game |
|---|---|---|---|
| Steiner CQBL-1 | `Laser_A` | `MI_LaserGreen` | IR |
| Steiner CQBL-1 | `Laser_B` | `MI_LaserRed` | visible |
| PEQ-15 LA-5 | `Laser_A` | `MI_LaserGreen` | IR |
| PEQ-15 LA-5 | `Laser_B` | `MI_LaserRed` | visible |
| Zenitco Klesch 2IKS3 | `Laser` | `MI_LaserRed` | not checked |

Material paths: `/Game/ThirdParty/SKGShooterFramework/Assets/Firearm/FirearmParts/LightLaser/Materials/Red/MI_LaserRed.MI_LaserRed` and `.../Green/MI_LaserGreen.MI_LaserGreen`. The laser mesh itself carries a per-instance `MaterialInstanceDynamic` (`MID_MI_LaserRed_<n>`) made from it.

- `SetDeviceState(1)` / `SetDeviceState(0)` on one laser component, called from Lua, turns that emitter on and off on screen, alone. The vanilla toggle key, cycle key and radial menu keep working normally afterwards.
- `LocTacticalAttachmentOptions` is the vanilla cycle list: an array of `IRRTacticalAttachmentOption` (`TacticalAttachments`, `bEnabled`), one per combination of emitters (5 on the AUG, 35 on the SCAR). `GetCurrentTacticalOption().bEnabled` followed a probe `SetDeviceState` on the AUG.
- Native hooks (`RegisterHook`) on `TacticalComponent` and `WeaponComponent` functions registered fine, and the game crashed without a dump when the vanilla toggle fired `WeaponComponent:ToggleCurrentTacticalOption` with them active. The toggle didn't crash without the hooks. Don't hook these.
- Reading `LocalAttachmentBase.LaserIndex` / `FlashlightIndex` returned a `TrivialObject`, not a number. `GameplayTags` could not be enumerated with `ForEach`. Neither is needed.

Lights, from `kb_probe_devices` / `kb_probe_dev_set`, 2026-09-19 in the hideout, on a SCAR-L (PEQ-15 LA-5, SureFire Mini Scout):

- Lights are `BP_FlashlightComponent_C` (`/Game/Blueprints/InventorySystem/Components/ItemComponents/BP_FlashlightComponent`), one per device, named `BP_FlashlightComponent`. Native parent `/Script/Test_C.FlashlightComponent` (object dump). The probe's `IsA` against it matched both lights.
- `bHasInfraredMode` tells lights apart: `true` on the PEQ-15's light, `false` on the Mini Scout. `bDeviceInfraredOn` and `IsInInfraredMode()` read false on both. Per the user, the PEQ-15's light is the only IR light in the game and it is IR only.
- `TacticalAttachments` order on that SCAR-L: PEQ-15 `Laser_B` (red), `Laser_A` (green), PEQ-15 light, Mini Scout light.
- `SetDeviceState(1)` / `SetDeviceState(0)` on the Mini Scout's light turns it on and off on screen, and `DeviceState` follows.

## Night vision

From the object dump and `kb_probe_nvg`, 2026-09-19 in the hideout.

- `IRRNightVision_Subsystem` (`/Script/IRRNightVision`) is a per-level object: `LVL_HideoutNEW:IRRNightVision_Subsystem_<n>`, one live instance, found with `FindFirstOf("IRRNightVision_Subsystem")`.
- `IsInfraredModeEnabledOnPlayer()` (no parameters) read `false` with NVG off and `true` with NVG on.
- Toggled by `IA_ToggleNightVision` through `SGA_NightVision_C`. The goggles view is `BP_FPCC_NightVision_C`, a first person core subobject.

## Lua threading

Seven crashes between 20:16 and 21:01 on 2026-09-18, all `EXCEPTION_ACCESS_VIOLATION` inside UE4SS's Lua runtime on the game thread (`lua_getiuservalue`, `lua_rawgeti`, `lua_getfield`, `push_nameproperty`), at different call sites. Six entered through `process_simple_actions` (the `ExecuteInGameThread` queue), one through a console command. Crash reports: `%LOCALAPPDATA%\Test_C\Saved\Crashes\*\CrashContext.runtime-xml`. `UE4SS.log` loses its tail on a hard crash, and a relaunch overwrites it.

They started when the first always-on bind started a 16 ms `LoopAsync` whose callback called `ExecuteInGameThread`. Non-fatal symptoms of the same corruption: `ipairs` "number expected, got function" and `IsInputKeyDown` "expected 1 parameters, received 2". With no loop running, and later with the loop on `LoopInGameThreadWithDelay`, no crash occurred across several sessions of menu probing and play.

This UE4SS build deprecates `LoopAsync` and `ExecuteAsync` in favour of the game-thread delayed actions (`LoopInGameThreadWithDelay`, `LoopInGameThreadAfterFrames`, `ExecuteInGameThreadWithDelay`), citing thread safety. See `ue4ss\Changelog.md` and `ue4ss\Docs\lua-api\global-functions\delayedactions.md`.

### Hot reload and delayed actions

Probed 2026-09-21 with Ctrl+R in the hideout.

- `ModRef` is userdata with no readable metatable. `ModRef:OnUnload` is nil at runtime (`attempt to call a nil value (method 'OnUnload')`), although `Mods\shared\Types.lua` from the same install declares it. Upstream lists it under v4.0.0-rc1.
- `CancelDelayedAction`, `ClearAllDelayedActions`, `IsValidDelayedActionHandle`, `ModRef:SetSharedVariable` and `ModRef:GetSharedVariable` exist.
- Delayed action handles are process-wide integers (1, 4, 5, 6 across reloads).
- A hot reload cancels the unloaded mod's `LoopInGameThreadWithDelay` loop. The old handle reads invalid from the new instance, and a per-second heartbeat from the old loop stopped at the reload while the new loop's kept going. No crash across three reloads.

## UI focus detection

Property that reliably differs menu-open vs menu-closed:

| Object | Property | Closed | Open |
|---|---|---|---|
| PlayerController | `bShowMouseCursor` | | |

## Open questions

-
