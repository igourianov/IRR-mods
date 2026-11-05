# Low ready as the default weapon position

## Intent

In vanilla, low ready is a toggle on its keybind, and the game's own auto low ready only kicks in after 10 seconds of idle, which almost never happens. The player wants low ready to be the resting position: whenever nothing holds the gun up (aiming, sprinting, reloading, firing or any other action), the weapon goes back to low ready on its own. What the low ready keybind does afterwards doesn't matter.

## Constraints and assumptions

### Game internals

From `UE4SS_ObjectDump.txt` of 2026-11-04 (game update of that date). The CXX header dump predates it and has none of these names.

- `/Game/Blueprints/InputSystem/InputActions/IA_LowReady.IA_LowReady` is the keybind's input action, handled by `/Game/Blueprints/InputSystem/InputHandlers/IH_LowReady.IH_LowReady_C`, which runs the toggled ability `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_LowReady.SGA_LowReady_C`.
- `/Script/Test_C.FirstPersonAutoLowReady` is the game's native auto low ready. Its Blueprint subclass `/Game/Blueprints/FirstPersonCoreComponent/SubObjects/BP_FPCC_AutoLowReady.BP_FPCC_AutoLowReady_C` lives under the player character's `BP_FirstPersonCoreComponent`. It has `LowReadyAbilityTag`, `IdleBlockingTags`, `GameplayAbilityComponent`, `FirstPersonCoreComponent` and the UFunctions `OnControllerSettingsChanged(NewSettings)`, `OnAbilityStarted(AbilityTag)` and `OnAbilityEnded(AbilityTag, bSuccess)`. Its idle timer is native code that reflection does not expose.
- `/Script/Test_C.IRRGameplaySettings` is the settings struct. It holds `bAutoLowReadyOnIdle` (bool, the menu's auto low ready toggle) and `AutoLowReadyIdleDelay` (float, seconds, 10 in vanilla).
- `/Script/Test_C.FirstPersonCoreComponent` keeps the live settings in `ControllerSettings`. `UpdateSettings(NewSettings)` stores them there and then broadcasts `OnFirstPersonControllerSettingsChanged`. The saved copy lives in `SettingsSaveGame:FirstPersonControllerSettings`.

### Observed in game

- Moving the mouse or the character does not end low ready. Only actions such as aiming or sprinting raise the gun.
- `FirstPersonAutoLowReady:OnControllerSettingsChanged` is called on every menu apply, not when the character loads.
- The native auto low ready ignores the delay in the `NewSettings` parameter. It reads `AutoLowReadyIdleDelay` from `FirstPersonCoreComponent.ControllerSettings` while running.
- Every menu apply overwrites `ControllerSettings` with the saved values, and a new character starts from them.
- `FirstPersonAutoLowReady:OnAbilityEnded` is called each time an ability such as aim or sprint ends. With the delay written into `ControllerSettings` before each call, the gun lowers right after the ability ends, also on the first ability after a fresh load.
- UE4SS gotchas: `RemoteUnrealParam:get()` on a struct parameter returns a copy, so field writes on it never reach the call. A struct property read off a UObject (`obj.ControllerSettings`) writes through to the object.

### Ruled out

- **Overriding the delay in `OnControllerSettingsChanged`'s parameter.** The native code ignores it (see Observed in game).
- **Writing the settings through `SettingsFunctionLibrary:ApplyGameplaySettings` or the save game.** That changes the player's saved settings, which would outlive removing the mod.
- **Writing `ControllerSettings` once at character spawn.** The game reloads `ControllerSettings` on spawn and on every menu apply, and when that happens isn't exposed. Writing before every ability end avoids guessing.
- **Forcing `bAutoLowReadyOnIdle` on.** The menu toggle stays the player's switch for the feature.
- **Restarting `SGA_LowReady` from a Lua polling loop.** It duplicates what the native auto low ready already does.
- **Editing `SGA_LowReady` or `IH_LowReady` in a pak.** Inverting a toggled ability's meaning inside Blueprint bytecode is fragile across patches, and the animation Blueprints read the low ready state directly.

## Scope

Owned, all in `likhos-point-and-shoot`:

- `Scripts/low_ready.lua`: the low ready default feature.
- `Scripts/config.lua`: its switch and delay.
- `Scripts/main.lua`: installing it.
- `README.md`: a section describing it.
- `CHANGELOG.md`: its entry.

Context only: `lib/hook.lua`, `lib/log.lua` and the game's settings and auto low ready above.

## Solution

### `low_ready.lua`

Owns the delay the native auto low ready uses.

- Pre-hooks `FirstPersonAutoLowReady:OnAbilityEnded` through a `lib/hook.lua` group, the same way `magnifier.lua` hooks its native function. A failed hook logs once and leaves the game's 10 second delay.
- In the hook, writes `config.low_ready_delay_ms` into `AutoLowReadyIdleDelay` on the hooked object's `FirstPersonCoreComponent.ControllerSettings`, so the value is in place before the native code starts its idle timer. Every other field, including `bAutoLowReadyOnIdle`, is left alone.
- The delay is kept above zero, since an engine timer with a zero rate never fires.
- Holds no UObject and no state between calls.

### `config.lua`

- `low_ready_default`: switch, on by default. Off leaves the game's own delay.
- `low_ready_delay_ms`: the idle delay the auto low ready uses, in milliseconds.

### `main.lua`

Installs `low_ready` when `config.low_ready_default` is set, like the other feature modules.

### Result the player sees

- With auto low ready on in the gameplay settings, the gun goes to low ready right after aiming, sprinting, reloading, firing and other actions end, in the hideout and in raid.
- With auto low ready off in the gameplay settings, the game behaves as vanilla.
- The saved settings keep the game's own delay, so removing the mod restores vanilla.
- The low ready key works as in vanilla, but its effect lasts only until the auto low ready lowers the gun again.

### `README.md` and `CHANGELOG.md`

The README section says what the feature does, that auto low ready must be on in the gameplay settings and the two config keys. The changelog has one entry in the existing style.

## Tradeoffs

- **Reusing the native auto low ready.** One hook and no per-tick Lua, at the cost of relying on native idle logic that can't be inspected and could change in a patch.
- **Writing on every ability end.** The same value is written each time an ability ends, a cheap field write, in exchange for not depending on when the game reloads `ControllerSettings`.
- **The live settings carry the modded delay.** Anything else reading `ControllerSettings.AutoLowReadyIdleDelay` sees it too. Nothing else in the dump is known to read it.
- **The keybind loses its use.** Accepted by the player.
