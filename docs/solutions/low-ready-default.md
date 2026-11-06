# Low ready as the default weapon position

## Intent

In vanilla, low ready is a toggle on its keybind, and the game's own auto low ready only kicks in after 10 seconds of idle, which almost never happens. The player wants low ready to be the resting position: the gun stays in low ready pretty much always, standing or moving, and comes up only for aiming (point aim included) and whatever the game itself won't do from low ready, such as sprinting or firing. Once those end, the weapon goes back to low ready on its own. Holstering keeps the game's behavior, since it operates the gun. What the low ready keybind does afterwards doesn't matter.

## Constraints and assumptions

### Game internals

From `UE4SS_ObjectDump.txt` of 2026-11-04 (game update of that date). The CXX header dump predates it and has none of these names.

- `/Game/Blueprints/InputSystem/InputActions/IA_LowReady.IA_LowReady` is the keybind's input action, handled by `/Game/Blueprints/InputSystem/InputHandlers/IH_LowReady.IH_LowReady_C`, which runs the toggled ability `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_LowReady.SGA_LowReady_C`.
- `/Script/Test_C.FirstPersonAutoLowReady` is the game's native auto low ready. Its Blueprint subclass `/Game/Blueprints/FirstPersonCoreComponent/SubObjects/BP_FPCC_AutoLowReady.BP_FPCC_AutoLowReady_C` lives under the player character's `BP_FirstPersonCoreComponent`. It has `LowReadyAbilityTag` (`GameplayTag`), `IdleBlockingTags` (`GameplayTagContainer`), `GameplayAbilityComponent`, `FirstPersonCoreComponent` and the UFunctions `OnControllerSettingsChanged(NewSettings)`, `OnAbilityStarted(AbilityTag)` and `OnAbilityEnded(AbilityTag, bSuccess)`. Its idle timer is native code that reflection does not expose.
- `/Script/Test_C.GameplayAbilityComponent` has `CanStartAbilityByTag(AbilityTag, bForcedGranted) -> bool`, `IsAbilityActiveByTag(AbilityTag) -> bool` and `TryStartAbilitiesByTag(AbilityTag) -> bool`.
- `/Script/Test_C.IRRGameplaySettings` is the settings struct. It holds `bAutoLowReadyOnIdle` (bool, the menu's auto low ready toggle) and `AutoLowReadyIdleDelay` (float, seconds, 10 in vanilla).
- `/Script/Test_C.FirstPersonCoreComponent` keeps the live settings in `ControllerSettings`. The saved copy lives in `SettingsSaveGame:FirstPersonControllerSettings`.

### Observed in game

- `FirstPersonAutoLowReady:OnAbilityStarted` and `OnAbilityEnded` are called for every ability of the player character. The tags seen include `Character.Abilities.Active.Aiming`, `Character.Abilities.Active.Running.Wants To Run` (sprint), `Character.Abilities.Active.Crouching`, `Character.Abilities.Active.Sneaking`, `Character.Abilities.Active.Low Ready`, `Inventory.Equipment Slots.Primary` and the menu, laptop and gunsmith abilities.
- `IdleBlockingTags` holds `Character.Abilities.Active.Menu Open`, `Inventory Open`, `Holstering` and `Interacting`.
- The native auto low ready never lowers the gun while the character moves, whatever its delay. After an action ends while walking, the gun lowers only once the character stops.
- `CanStartAbilityByTag(LowReadyAbilityTag, false)` is false while aiming or sprinting, also when another ability such as crouch ends during the aim. It is true once they end, while walking or standing, and while crouching or sneaking.
- `CanStartAbilityByTag` is also true while low ready is already active.
- `CanStartAbilityByTag` is false while the inventory or a container screen is open. The container screen ability reports its tag as `None`.
- Starting aim, sprint or fire ends low ready and starts that ability in the same frame.
- Reloading (`Character.Abilities.Active.Reloading`), interacting, the gunsmith and the laptop run without ending low ready.
- `Character.Abilities.Active.Firing` lasts from trigger press to release: about 80 ms for a semi-auto shot, the whole burst in full auto. `CanStartAbilityByTag` refuses low ready while it is active and allows it right after.
- The game itself starts low ready during `Character.Abilities.Active.Chamber Actioning`.
- `TryStartAbilitiesByTag(LowReadyAbilityTag)` lowers the gun the same way the keybind does, while standing and while moving.
- A start one frame after an ability ends goes straight to low ready. A start some time later first shows the raised pose, then low ready.
- Holding the run key runs `Character.Abilities.Active.Running.Wants To Run`. Double tapping it is the tactical sprint, which logs as that run ending and starting again 20 to 40 ms apart. A one frame start after the run ends dips the gun through the run to walk transition. A start about 120 ms later doesn't.
- Drawing a weapon (`Inventory.Equipment Slots.Primary` and the other slots) ends low ready, and `SGA_LowReady_C` lists `ChangingSlot` in its `ActivationBlockedTags`, so low ready can't start until the draw ends.
- Removing low ready from the run and sprint abilities' `InterruptAbilitiesWithTags` and their tags from low ready's `ActivationBlockedTags` works in memory, but the animation Blueprint then stacks the low ready and run poses and pushes the gun below the screen.
- The mod's point aim (`actions.lua` `PointAim`) presses the game's aim input, so it runs as `Character.Abilities.Active.Aiming`.
- Moving the mouse or the character does not end low ready. Only actions such as aiming or sprinting raise the gun.
- UE4SS gotchas: `RemoteUnrealParam:get()` on a struct parameter returns a copy, so field writes on it never reach the call. A struct property read off a UObject (`obj.ControllerSettings`) writes through to the object.

### Ruled out

- **Relying on the native auto low ready, with its delay shortened in `ControllerSettings`.** It refuses to lower the gun while moving (see Observed in game).
- **Writing the settings through `SettingsFunctionLibrary:ApplyGameplaySettings` or the save game.** That changes the player's saved settings, which would outlive removing the mod.
- **Forcing `bAutoLowReadyOnIdle` on.** The menu toggle stays the player's switch for the feature.
- **Starting low ready from a Lua polling loop.** Every way the gun goes up ends in an ability end the hook already sees, so a loop adds per-tick work for nothing.
- **A hand-kept list of abilities that hold the gun up.** The game's own start check for low ready already refuses during aim and sprint, and a list would go stale with patches.
- **Firing from low ready without leaving it.** Firing ends low ready as in vanilla. Accepted by the player for now.
- **Honoring the whole `IdleBlockingTags` list.** It is the native auto low ready's idea of not idle, not a limit of the low ready ability. Menus, inventory and interacting don't need it: the start check refuses where low ready can't run, and low ready stays on through the rest.
- **The same delay after every ability end.** Any delay past one frame shows the raised pose before low ready.
- **Keeping low ready on through run and sprint by editing their tag lists.** The poses stack and push the gun below the screen.
- **Hiding the raised pose after a draw.** Low ready can't start during it. Accepted by the player.
- **Editing `SGA_LowReady` or `IH_LowReady` in a pak.** Inverting a toggled ability's meaning inside Blueprint bytecode is fragile across patches, and the animation Blueprints read the low ready state directly.

## Scope

Owned, all in `likhos-point-and-shoot`:

- `Scripts/low_ready.lua`: the low ready default feature.
- `Scripts/config.lua`: its switch and delay.
- `Scripts/main.lua`: installing it.
- `README.md`: a section describing it.
- `CHANGELOG.md`: its entry.

Context only: `lib/hook.lua`, `lib/util.lua`, `lib/log.lua` and the game's auto low ready and ability component above.

## Solution

### `low_ready.lua`

Starts low ready after every ability end.

- Post-hooks `FirstPersonAutoLowReady:OnAbilityEnded` through a `lib/hook.lua` group, the same way `magnifier.lua` hooks its native function. A failed hook logs once and leaves the game's own auto low ready.
- After each ability end, starts one frame later on the game thread with `ExecuteInGameThreadAfterFrames`, outside the game's ability callback. One frame is the earliest the start check allows and keeps the raised pose from showing.
- After a run end (`Character.Abilities.Active.Running.Wants To Run`), waits `config.low_ready_run_delay_ms` with `ExecuteInGameThreadWithDelay` instead, so the run to walk transition finishes first.
- A later ability end supersedes a pending start.
- Then starts low ready through the hooked object's `GameplayAbilityComponent:TryStartAbilitiesByTag(LowReadyAbilityTag)` when all of these hold:
  - `FirstPersonCoreComponent.ControllerSettings.bAutoLowReadyOnIdle` is on.
  - Low ready is not already active.
  - `CanStartAbilityByTag(LowReadyAbilityTag, false)` allows it.
  - `Character.Abilities.Active.Holstering` is not active.
- Holds the auto low ready object only until the start and checks it is still valid before use. Between ability ends it keeps only a plain counter that tells the latest pending start apart.
- Leaves `ControllerSettings` untouched. The game's own auto low ready keeps running with the player's delay.

### `config.lua`

- `low_ready_default`: switch, on by default. Off leaves the game's own auto low ready.
- `low_ready_run_delay_ms`: how long after a run ends the gun lowers, in milliseconds. 150 by default.

### `main.lua`

Installs `low_ready` when `config.low_ready_default` is set, like the other feature modules.

### Result the player sees

- With auto low ready on in the gameplay settings, the gun goes straight to low ready as aiming, point aiming, sprinting, firing and other actions end, standing or moving, in the hideout and in raid. After a run it lowers once the run to walk transition is done.
- After drawing a weapon, the gun shows raised for a split second before low ready.
- Reloading, interacting and the inventory keep low ready as the game does.
- An action ending while another still holds the gun up, such as crouching during an aim, leaves the gun up.
- With auto low ready off in the gameplay settings, the game behaves as vanilla.
- The saved settings are not touched, so removing the mod restores vanilla.
- With auto low ready on, what the low ready key does doesn't matter. Raising the gun with it ends low ready, which is itself an ability end, so the gun lowers again the next frame. During sprint the key does nothing, as in vanilla. With auto low ready off, the key is vanilla.

### `README.md` and `CHANGELOG.md`

The README section says what the feature does, that auto low ready must be on in the gameplay settings and the two config keys.
The changelog entry says low ready no longer waits for the character to stop and no longer flashes the raised pose. The changelog has one entry in the existing style.

## Tradeoffs

- **The game's start check as the only guard.** It needs no list of abilities and follows patches, at the cost of trusting that every ability that holds the gun up blocks low ready from starting. One that doesn't would be cancelled when another ability ends during it.
- **One frame after most ability ends, a delay only after a run.** The raised pose never shows, at the cost of a run delay tuned by eye and a second hard-coded tag. If a patch renames the run tag, a run end gets the one frame start and the dip.
- **Holstering as a hard-coded exception.** It names one game tag, at the cost of breaking silently if a patch renames it, in which case low ready may start during holstering.
- **The raised pose after a draw.** Accepted, since low ready can't start during the draw.
- **The keybind loses its use.** Accepted by the player.
