# CLAUDE.md

UE4SS Lua mods for **Incursion Red River** (UE 5.6, Steam, no anti-cheat).

## Before changing code

Read `CODE_GUIDE.md`. Its rules are not style preferences — each one exists
because breaking it crashes the game or silently breaks after a patch.

The load-bearing ones:

- `RegisterKeyBind` callbacks run **off the game thread**. Hop via
  `ExecuteInGameThread` before touching a UObject.
- Never use `LoopAsync` / `ExecuteAsync`. Per-tick loops use
  `LoopInGameThreadWithDelay`. `LoopAsync` calling `ExecuteInGameThread` every
  tick corrupted the Lua state and crashed the game.
- Never cache a UObject across a level load. Cache the PlayerController, not
  the pawn.
- `util.valid(obj)`, never `if obj then` — UE4SS returns an invalid stub.
- No memory offsets. Resolve by name through reflection, lazily.

## Layout

- `likhos-<name>/` — one mod: `mod.txt`, `Scripts/`, `README.md`.
  All Lua lives flat in `Scripts/`; plain `require("log")`.
- `lib/` — Lua modules shared by every Lua mod (`log`, `util`, `hook`).
  `build.ps1` and `publish.ps1` copy them into each mod's `Scripts/`, so a
  mod never has its own file with a `lib` name. Each mod names itself for
  log lines with `log.setup("<Name>", config.log_level)`.
- A pak mod (`likhos-rearmed`) has `pak=` in `mod.txt` and a `pak.ps1` that
  stages the pak's files. `build.ps1` packs it with repak into `dist\` and
  installs it into `Content\Paks\~mods`.
- `docs/solutions/` — session level docs: one solution doc per piece of work,
  holding its design and its own recon. Read another solution doc only when
  the user points at it.
  A solution doc records what was done at the time and why. Do not update it when later work changes or supersedes that solution.

## Do not fabricate game internals

Class names, UFunction names and property paths must come from a UE4SS dump
or Live View, and recorded in the current task's solution doc only. There is
no shared findings file. If a name is unknown, leave
the `TODO_` placeholder and say so. A plausible-looking wrong name costs
hours of debugging.

## Commands

### build.ps1

```powershell
.\build.ps1                          # build and deploy every mod folder that has mod.txt
.\build.ps1 likhos-backpack          # one mod
.\build.ps1 likhos-backpack likhos-rearmed   # several mods
```

- Needs `build.config.json` (gitignored, copy of `build.config.example.json`) holding the game dir.
- Bumps the patch number in `mod.txt` when the mod folder has uncommitted changes. For a Lua mod, a change in `lib\` also counts. The bumped `mod.txt` keeps the folder dirty, so every build bumps again until committed.
- Lua mod: copies the mod folder to `ue4ss\Mods\<mod>` and `lib\*.lua` into its `Scripts\`. Fails if `Scripts\` has a file with a `lib` name.
- Pak mod: runs the mod's `pak.ps1` to stage files, packs with repak into `dist\<pak>`, copies it into `Content\Paks\~mods`. Downloads repak and UAssetGUI into `tools\` on first use. Needs a usmap in the UE4SS folder, generated in game with the UE4SS mappings dump key after every game patch.

### publish.ps1

```powershell
.\publish.ps1 likhos-backpack -DryRun   # pack dist\<mod>.zip, print the Nexus requests, upload nothing
.\publish.ps1 likhos-backpack           # pack and upload as a new version of the mod's Nexus file
```

- Mod name is required unless `publish.config.json` lists only one mod.
- Needs `publish.config.json` (`mod_id`, `file_id` per mod) and the API key in `nexus-api.key` (gitignored) or `-ApiKey`.
- Publishes the version currently in `mod.txt`. It does not bump it. Run `build.ps1` first. A pak mod fails if `dist\<pak>` is older than any file in the mod folder.
- Refuses a version equal to or older than the live Nexus version unless `-Force`.
- Posts the `CHANGELOG.md` sections newer than the live version, up to the published one, as the Nexus changelog. Every heading must be a bare version (`# 1.2.38`).
- Other switches: `-Category main|optional|miscellaneous`, `-NoArchive` (keep the previous file version unarchived), `-NoBumpModVersion` (do not update the mod page version).

In-game console: `kb_status`.

## Mod version

`mod.txt` holds `version="major.minor.patch"`.

- Patch is the build number. `build.ps1` increments it on every build of a changed mod. Never reset it and never edit it by hand.
- A new feature bumps minor by 1 by hand in `mod.txt`, keeping the patch number as is: `1.1.32` becomes `1.2.32`. Fixes and tweaks leave minor alone.
- Major changes only when the user asks.

