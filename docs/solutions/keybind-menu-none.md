# Controls page shows None for bound keys

## Intent

Find out why the vanilla controls page sometimes shows a bound key as None while the key keeps working. It happens mostly on the rows added by likhos-point-and-shoot (`docs/solutions/point-aim-keybind-menu.md`). Once every row on the page showed None, and all keys kept working. It is unknown whether the mod causes it or it is a vanilla bug.

This stage adds temporary debug output only. The fix is decided once the log shows the cause.

## Constraints and assumptions

- Keys keep working, so the saved key profile is intact. The fault is in what the page reads to display a key.
- A key button shows its key through `WB_KeyBindingButton_C:FindInputActionKey`, which reads the subsystem's `QueryKeysMappedToAction` and sees only contexts on the active input stack (`docs/solutions/point-aim-keybind-menu.md`, Recon, Controls menu). The mod's binds read the profile directly (`keymap.keys`, `GetMappedKeysInRow`), so they work whether or not the mod's context is on the stack.
- `menu.lua` only detaches and re-adds rows below the Point Shooting and Interact rows. Rows above them are not touched by the mod.

## Hypotheses

1. The game clears or rebuilds the input stack (level load, menu, input mode switch) and drops `IMC_LikhosKeybinds`. The mod re-adds it only on PlayerController acquire.
2. `keymap.register` ran before Enhanced Input user settings existed. It logs that at debug level and never retries.
3. `FindFirstOf("EnhancedInputLocalPlayerSubsystem")` returned a stale subsystem, so the context went onto the wrong one.
4. All rows None: the page built its rows while the stack held no vanilla contexts. Likely vanilla.

## Solution

`likhos-point-and-shoot/Scripts/diag.lua`, wired in `main.lua`. Temporary. Remove it with the fix.

- `diag.state(tag)` logs each `EnhancedInputLocalPlayerSubsystem`, which one `FindFirstOf` returns, whether the mod's context is built and on that subsystem's stack (`HasMappingContext`), and each mod mapping's keys from the profile and from the stack (`QueryKeysMappedToAction`). It runs after each `keymap.register` (tag `register`), at the start of each page build (tag `page`) and from the console command `kb_diag` (tag `console`).
- The input stack functions are not hooked. Both attempts crashed the game (Recon), so who changes the stack is not logged, only its state at the snapshot points.
- A post-hook on `WB_KeyBindingButton_C:FindInputActionKey` logs one line per button: mapped name, gamepad flag, the out key, the button's `CurrentKey`, its `Mapping Context` property and what `QueryKeysMappedToAction` returns for its action right then.

Reading the log when a row shows None:

- `stack=empty` with `profile=<key>` on a mod mapping and `has_mod_ctx=false`: hypothesis 1 or 3. The `register` snapshot before it shows whether the context was on the stack after the last level load.
- No `register` state after the last level load, or `0 subsystem(s)`: hypothesis 2.
- `stack=empty` on every vanilla button too: hypothesis 4.
- `stack=<key>` but `key=None`: the page logic itself loses the key, not the stack.

## Results

Session of 2026-11-08, v1.1.120, main menu then hideout. The mod rows showed None on the open controls page.

- One subsystem per session. `FindFirstOf` returns it. Hypotheses 2 and 3 are out.
- At each `register` (main menu and hideout load): `has_mod_ctx=true`, every mod mapping `profile=<key>`, `stack=empty`.
- The mod rows were added 20 to 30 ms after each `register`, during the load. The controls page builds its rows at level load, not when it is opened.
- No `FindInputActionKey` line at all, at build time or with the page open. A row reads its key once, when built, and does not read it again when the page opens.
- `kb_diag` with the page open and the rows showing None: `stack=<key>` for every mod mapping.

Cause: a race, a narrower form of hypothesis 1. `AddMappingContext` with default options defers the stack rebuild. The mod rows were built and read their keys before it ran, and kept None. The all-rows case fits the same race on the vanilla contexts, which would make it vanilla.

## Fix

- `keymap.register` passes `{ bForceImmediately = true }` (`FModifyContextOptions`, engine) to `AddMappingContext`, so the context is live when it returns.
- `menu.add_rows` calls `keymap.register()` before adding rows, so the context is live before a mod row reads its key whichever of the two runs first during a load.

To verify: the `register` snapshot shows `stack=<key>`, and the mod rows show their keys. Then remove `diag.lua`, its `main.lua` wiring and `kb_diag`.

## Recon

From the CXX header dump and object dump, game build of 2026-11-06.

- `IEnhancedInputSubsystemInterface` (`EnhancedInput.hpp`) declares `AddMappingContext(MappingContext, Priority, Options)`, `RemoveMappingContext(MappingContext, Options)`, `ClearAllMappings()`, `HasMappingContext(MappingContext, OutFoundPriority&) -> bool`, `QueryKeysMappedToAction(Action) -> TArray<FKey>`. The UFunctions live at `/Script/EnhancedInput.EnhancedInputSubsystemInterface:<name>`.
- The key button class is `/Game/ThirdParty/UltimateShooterKit/UltimateMenu/UserInterface/MenuElements/WB_KeyBindingButton.WB_KeyBindingButton_C`. Its `FindInputActionKey(bool Gamepad?, FKey& Key, FText& KeyName)` is a Blueprint function. Properties: `CurrentKey` (FKey), `KeyInfo` (`Struct_InputKeyInfo`), `Mapping Context` (UInputMappingContext, the name holds a space), `EmptyKey`. It also has `ClearActionMapping`, `ClearActionKeys`, `Finalize_ReMappingAction`, `ApplyNewKeybind`, `ResetSettings` and `ApplySettings`, which are not probed yet.
- Reading a parameter in a pre-hook on a native `EnhancedInputSubsystemInterface` function crashed the game during a level load (2026-11-08, v1.1.118). The crash was `EXCEPTION_ACCESS_VIOLATION` reading 0x40 in `RemoteUnrealParam::prepare_to_handle` → `auto_construct_object` → `UObjectBase::IsA`, under `lua_unreal_script_function_hook_pre`. pcall does not catch it. A native function called from Blueprint takes its parameters from the bytecode, not from the frame the hook reads.
- Reading only the hook context (`context:get()`) in the same hooks crashed the game with the same stack on the first call, at startup before any hook line was logged (2026-11-08, v1.1.119). Pre-hooks on `EnhancedInputSubsystemInterface` UFunctions can't read anything from Lua.
