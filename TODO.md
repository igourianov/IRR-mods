# TODO

## Blocking — do these first

- [x] **Verify UE4SS injects on the current game build.** DONE — needs the
      experimental build and `MinorVersion = 6`. See `docs/03-findings.md`.
- [ ] ~~old note~~ Install the zDev
      build, launch, confirm the GUI console appears and `UE4SS.log` is
      written. If it fails, this is an AOB signature mismatch — check
      `ue4ss\UE4SS_Signatures\` before considering the UEVR fallback.
      (The Radar Mod on Nexus moved off UE4SS at game patch 1.3.)
- [x] Record the exact Steam build ID in `likhos-keybinds/mod.txt`
      (`game_build` = 22417726).
- [ ] Set Steam to "only update when launched".
- [ ] Generate dumps: CXX headers, `.usmap`, object dump → `tools/dumps/`.

## Recon — fills in actions.lua

- [ ] Does `EnhancedInputLocalPlayerSubsystem` exist? (decides the whole
      interception strategy — see `docs/01-recon.md`)
- [ ] Does `EnhancedInputUserSettings` exist? (sanctioned rebind API)
- [ ] Enumerate `InputMappingContext` objects and their mappings
      (`kb_dump_imc` console command once the mod loads).
- [ ] Identify the pawn/controller class that owns input handlers.
- [ ] Fill `ACTIONS` in `likhos-keybinds/Scripts/actions.lua`.

## Implementation

- [ ] Verify `util.now_ms()` behaves as wall-clock under UE4SS Lua 5.4.
      `os.clock()` is CPU time on some builds — swap if it drifts.
- [ ] Find a real key-release source so `hold` mode stops being a timeout
      approximation (see header of `likhos-keybinds/Scripts/triggers.lua`).
- [ ] Implement key stealing (rewrite the conflicting `FEnhancedActionKeyMapping.Key` in the active IMC) once the IMC property layout is known.
- [ ] Confirm the `context.lua` UI gate actually blocks while the stash
      search box has focus.

## Known issues

- [ ] **Unreproduced crash: vanilla mode toggle while holding the PointAim bind (H).** Seen once on 2026-09-18 20:16 and not reproduced since, including with trace logging.
      - Report: `%LOCALAPPDATA%\Test_C\Saved\Crashes\UECC-Windows-4C745A2D4FE1CFD2397E0EADB3F9B37E_0000` (`CrashContext.runtime-xml`, `UEMinidump.dmp`, `Test_C.log`).
      - Error: `EXCEPTION_ACCESS_VIOLATION reading address 0x70`. `pcall` can't catch it.
      - Stack: `engine_tick_hook` -> `process_simple_actions`, so an `ExecuteInGameThread` callback, meaning our tick loop. The failing call ran two `pcall`s deep (`util.safe("tick")` -> `util.safe` in `actions.invoke`) and was a built-in UE4SS UObject member function (`UObjectBase::setup_member_functions` lambda_17), not a UFunction call.
      - Suspects in `PointAim` (`likhos-keybinds/Scripts/actions.lua`): `IsValid` (via `util.valid`) or `GetFullName` on an object the toggle had just replaced. The game log ends with `SGA_PointSight_C` activating while aimed (`BP_PointSight Sight Triggered false`, `BP_SightComponent Sight Triggered true`).
      - If it happens again, don't relaunch before saving `ue4ss\UE4SS.log`, which is overwritten on launch. Then re-add per-step trace logging around every UObject call in `PointAim` and `input.poll`.

## Before release

- [ ] Test in co-op as host and as client.
- [ ] Test hot reload does not double-register binds.
- [ ] Write `likhos-keybinds/INSTRUCTIONS.md` for end users.
