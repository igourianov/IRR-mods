# Session state — resume here

Last updated: 2026-09-18 19:10 (America/Toronto)

Read this first, then `CLAUDE.md`, then `docs/03-findings.md`.

## Where the project is

Scaffold complete, UE4SS verified working on the current game build, **nothing
deployed and nothing committed yet**. No game-specific code exists — the action
table is empty by design.

## What the mod is meant to do

Keybinding *behaviour*, not just remapping: toggle↔hold conversion, double-tap,
tap-vs-hold on one key, modifier chords. Context-gated so binds do not fire
while a menu is open or a text field has focus.

Game-state awareness is the entire justification for injecting. Pure remapping
would be better served by AutoHotkey / reWASD / Steam Input with zero patch
fragility — an external tool just cannot know the stash is open.

Co-op: input is client-local and unreplicated, so this is safe. Other players
do not need it installed and there is no host requirement.

## Environment (verified 2026-09-18)

| | |
|---|---|
| Game | Incursion Red River, Steam build **22417726** |
| Install | `D:\SteamLibrary\steamapps\common\PROJECT QUARANTINE` |
| Module | `Test_C` (pre-EA project name, still used internally) |
| Engine | **UE 5.6** — wikis say 5.4 and are wrong |
| UE4SS | experimental `v3.0.1-1136-g35d1795d` (zDEV), in `Test_C\Binaries\Win64\ue4ss\` |
| Project | `D:\Projects\IRR-mods` |

Working UE4SS config and the two failure modes are recorded in
`docs/03-findings.md`. **The critical value is `MinorVersion = 6`** — setting 4
produces a deterministic access violation at the first tick.

## How we got here (so a fresh session does not redo it)

1. Stable UE4SS 3.0.1 cannot scan this binary at all — no UE5.6 support.
   `Failed to find GUObjectArray` / `FText`, then `PS scan timed out`.
2. The experimental build scans fine but crashed deterministically with
   `MinorVersion = 4` — access violation writing into the game exe's own image
   at `+0x15EF0FA`, immediately after `UStruct::Link`.
3. Disabling the bundled C++ mods did not change it. Not the cause.
   (`mods.txt : 0` stops them *starting*; their DLLs still load.)
4. The StashSearch mod's Nexus page revealed the game is UE 5.6.
   Setting `MinorVersion = 6` fixed it outright.

Healthy startup ends with `[HashTables] Self test passed (7657 classes with
instances)`. The `VTable and scan addresses differ for UGameEngine::Tick`
warning appears on healthy runs too — not fatal.

## Immediate next steps

1. **Deploy.** `Copy-Item build.config.example.json build.config.json`, set
   `game.dir` to the path above, run `.\build.ps1` (needs an elevated shell or
   Windows Developer Mode for symlinks; `-Copy` otherwise). Relaunch; expect
   `[KeybindOverhaul] INFO: loading` plus a warning that no actions are
   defined — that warning is correct.
2. **Dumps.** UE4SS GUI → Dumpers: CXX headers, usmap, Ctrl+J for objects.
   Move output to `tools\dumps\` (gitignored).
3. **Decide the input strategy.** In Live View search for
   `EnhancedInputLocalPlayerSubsystem` and `EnhancedInputUserSettings`.
   Their presence decides everything downstream. Record in `03-findings.md`.
4. **Fill `actions.lua`.** Class + UFunction names from the dump, never guessed.

## Known unresolved

- `hold` mode in `triggers.lua` is an approximation. `RegisterKeyBind` gives
  press events only — no release, no repeat. A real key-release source is
  needed; until then a timeout ends the action.
- `util.now_ms()` uses `os.clock()`, which is CPU time on some builds. Verify
  it tracks wall clock under UE4SS Lua 5.4 or swap it.
- Key stealing is not implemented (the stub was removed). It is the answer to the core obstacle:
  `RegisterKeyBind` does **not** consume the keystroke, so the game's own
  binding still fires and a naive toggle double-fires. Intended fix is to
  rewrite the conflicting `FEnhancedActionKeyMapping.Key` in the active IMC.
  Blocked on step 3.
- `context.lua` reads `bShowMouseCursor` as the UI gate. Unverified — confirm
  it actually differs with the stash open.

## Standing risks

- Two moving targets: the game patches (~quarterly) and UE4SS patches
  independently. Either can break the mod. Retest and bump `game_build` in
  `mod.txt` after every game patch.
- UE4SS is a **runtime** dependency for end users, not just a dev tool. If it
  cannot run on a future build, the mod cannot ship at all. Users install the
  plain build (8.3 MB); zDEV is dev-only. MIT licensed, so bundling is legal,
  but linking the release is the better practice.
- Fallback if UE4SS breaks: the UEVR Lua runtime, which is proven on this game
  (the Nexus Radar Mod migrated to it at game patch 1.3).

## Housekeeping

- Git is initialised, 24 files staged, **no commits yet**.
- `mod-lib/` was removed — it was premature abstraction for a second mod that
  does not exist. All Lua is flat in `likhos-keybinds/Scripts/`, plain
  `require("log")`. Re-split only when a second mod actually needs it.
- Backups made this session: `UE4SS-settings.ini.bak`, `Mods/mods.txt.bak`,
  and old crash dumps in `ue4ss\_old_dumps\`.
