# Session state: resume here

Last updated: 2026-09-18

Read `CLAUDE.md` and `docs/solutions/findings.md` alongside this.

## Where the project is

`likhos-keybinds` works in game with one feature: the **point aim** bind. Holding a key aims straight into point aim and releasing it ends the aim. The key is set in the game's Settings > Controls, in a row "Point Shooting (Direct)" that the mod adds under the vanilla "Point Shooting" row. It is unbound by default.

- `docs/solutions/point-aim-bind.md`: the aim action, polling and hold release. Its fixed H key and `engine_key` are superseded by `point-aim-keybind-menu.md`.
- `docs/solutions/point-aim-keybind-menu.md`: the mapping and the controls menu row (`keymap.lua`, `menu.lua`).

The trigger modes in `triggers.lua` (toggle, double_tap, tap_hold) exist, but the only defined action is `PointAim` and `point_aim` is the only bind in `config.lua`.

Game-state awareness is the entire justification for injecting. Pure remapping would be better served by AutoHotkey, reWASD or Steam Input with zero patch fragility. An external tool cannot know the stash is open.

## Environment (verified 2026-09-18)

| | |
|---|---|
| Game | Incursion Red River, Steam build **22417726** |
| Install | `D:\SteamLibrary\steamapps\common\PROJECT QUARANTINE` |
| Module | `Test_C` (pre-EA project name, still used internally) |
| Engine | **UE 5.6**. Wikis say 5.4 and are wrong |
| UE4SS | experimental `v3.0.1-1136-g35d1795d` (zDEV), in `Test_C\Binaries\Win64\ue4ss\` |
| Project | `D:\Projects\IRR-mods` |

Working UE4SS config and the two failure modes are recorded in `docs/solutions/findings.md`. **The critical value is `MinorVersion = 6`.** Setting 4 produces a deterministic access violation at the first tick.

Deploy with `.\build.ps1` (symlinks need an elevated shell or Windows Developer Mode, `-Copy` otherwise). Healthy startup ends with `[HashTables] Self test passed`. The `VTable and scan addresses differ for UGameEngine::Tick` warning appears on healthy runs too and is not fatal.

## Hard-won lessons

- Stable UE4SS 3.0.1 cannot scan this binary (no UE5.6 support). Only the experimental build works.
- `LoopAsync` with a per-tick `ExecuteInGameThread` hop corrupted the Lua state and crashed the game seven times. The tick now runs on `LoopInGameThreadWithDelay` (`docs/solutions/findings.md`, Lua threading).
- `RegisterKeyBind` gives press events only, with no release. Binds that need a real release name a `mapping` and are polled with `IsInputKeyDown`.
- `RegisterKeyBind` does not consume the keystroke. The game's own binding still fires. Key stealing is not implemented, and the point aim bind does not need it.
- The aiming subobject's `bIsPointSight` does not track the sticky mode. The equipped weapon's `WeaponComponent.bIsPointSight` does.
- Calling `TriggerAim` directly skips the `SGA_Aim_C` ability. Aim is driven by injecting `IA_Aim` instead.

## Open items

Unverified:

- `context.lua` reads `bShowMouseCursor` as the UI gate. Confirm it differs with the stash open and with the search box focused (the table in `docs/solutions/findings.md` is blank).
- Per-tick `IA_Aim` injection holds aim at native frame rates above about 60 fps (`docs/solutions/point-aim-bind.md`, A2).
- Hot reload does not double-register binds or the menu row. After a hot reload two rows on one mapping name lost the saved key in a probe. `menu.lua` skips a page that already holds a mod row, but this has not been tested.
- Co-op as host and as client.

Known issues:

- Unreproduced crash on 2026-09-18 20:16: `EXCEPTION_ACCESS_VIOLATION reading address 0x70` while toggling the vanilla point sight mode with the bind held, in the tick loop. It matches the time of the first `LoopAsync` crash. That loop has since been replaced and there was no crash after, so this is probably the same cause, but it is not confirmed. Full notes are in git history (`TODO.md` at commit `7e25a79`). If it recurs, save `ue4ss\UE4SS.log` before relaunching, since a launch overwrites it.
- `hold` mode for binds with a UE4SS `key` is still a timeout approximation. Only `mapping` binds get a real release (`docs/solutions/point-aim-bind.md`, open questions).
- A weapon switch while the bind is held ends the aim until the key is released and pressed again. The flipped weapon keeps point mode.

Housekeeping:

- `docs/solutions/findings.md` still has empty template sections: input stack decision, mapping contexts, action handlers, UI focus.
- Set Steam to "only update when launched", so a game patch does not break the mod between sessions.

## Standing risks

- Two moving targets: the game patches (about quarterly) and UE4SS patches independently. Either can break the mod. Retest and bump `game_build` in `mod.txt` after every game patch.
- UE4SS is a **runtime** dependency for end users, not just a dev tool. If it cannot run on a future build, the mod cannot ship. MIT licensed, so bundling is legal, but linking the release is the better practice.
- Fallback if UE4SS breaks: the UEVR Lua runtime, which is proven on this game (the Nexus Radar Mod migrated to it at game patch 1.3).
