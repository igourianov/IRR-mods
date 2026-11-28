# Military time

## Intent

The deploy screen offers two insertion times 12 hours apart, shown in 12 hour AM/PM format. Players complain about it. Every in-game clock shows 24 hour time instead.

## Constraints and assumptions

- The game has no 24 hour clock setting.
- Recon from `UE4SS_ObjectDump.txt` (2026-11-18):
	- `WB_DeployTab_C` (`/Game/Blueprints/MissionSystem/UI/Deploy/WB_DeployTab.WB_DeployTab_C`) builds the two insertion option texts in `ExecuteUbergraph_WB_DeployTab` with two calls to `DayTimeToString`, converts them with `Conv_StringToText` and puts them on `WB_TimeFrameSwitcher` (`W_IRR_Setting_Switcher_C`) through `GetSwitcherRefByIndex`. `OnLocalDayTimeUpdated_Event` drives the refresh.
	- `/Script/IRRMissionSystem.IRRMissionSystemFunctionLibrary:DayTimeToString` is native and static, with params `DayTime` (`IRRDayTime`: `Hours`, `Minutes`, `Seconds`), `b24Hour`, `bIncludeHours`, `bIncludeMinutes`, `bIncludeSeconds` and a `ReturnValue` string.
	- Blueprint callers of `DayTimeToString`: `WB_DeployTab_C`, `W_MapToolTip_C` (job board), `W_GCPS_ToolTip_ExtractionZone_C`, `W_GCPS_TopBar_C`, `WBP_KronosLobby_C` and `BP_InGamePlayerController_C:FinalizeRaidData`.
- Ruled out: a pak edit flipping the `b24Hour` literal in `WB_DeployTab`'s bytecode. `tools\pak\pak.ps1` edits data only and has no Kismet bytecode support. It would also tie the fix to one widget and need a republish after every game patch.
- Ruled out: rewriting only the deploy screen's option texts. The user chose 24 hour time for every clock that goes through `DayTimeToString`.
- A UE4SS pre-hook on the native `DayTimeToString` that sets `b24Hour` to true through the param's `set` reaches the native call. Confirmed in game.
- The game's own 24 hour output is acceptable as is. The mod doesn't reformat it.

## Scope

Owned, all in `likhos-point-and-shoot`:

- `Scripts/world/clock.lua`, new.
- `Scripts/main.lua`: installing the module.
- `Scripts/config.lua`: the `clock_24h` switch.
- `README.md` and `CHANGELOG.md`: the feature's entry.

Context only: `lib/hook.lua` (used as is), the game's widgets and `DayTimeToString`.

## Solution

- `world/clock.lua` owns the 24 hour clock. Its `install` hooks `IRRMissionSystemFunctionLibrary:DayTimeToString` through a `lib/hook.lua` group with no class path, since the class is native. The pre callback sets `b24Hour` to true on every call. It holds no state and no UObject.
- `main.lua` installs it when `config.clock_24h` is true, alongside the other optional features.
- `config.lua` has `clock_24h = true` with a comment in the file's style: every in-game clock shows 24 hour time, including the deploy screen's insertion times, and `false` keeps the game's own 12 hour clock.
- Flow: a widget calls `DayTimeToString`, the pre callback forces `b24Hour`, the native function returns the 24 hour string and the widget shows it.
- Result: the deploy screen's two insertion options, the job board map tooltip, the extraction zone tooltip, the in-raid top bar and the lobby show 24 hour time. A hook failure logs once and leaves the game's 12 hour clock.
- README lists the feature with the config switch. `CHANGELOG.md` has an entry under `# Unreleased`. As a new feature it bumps the minor version in `mod.txt`.

## Tradeoffs

- One global hook over a deploy screen only text rewrite: less code, no widget internals to track and consistent clocks everywhere, at the cost of changing places the user didn't name, including the raid summary string built in `FinalizeRaidData`.
- Native code that calls `DayTimeToString` directly in C++ bypasses the hook and keeps its own format.
