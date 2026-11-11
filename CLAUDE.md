# CLAUDE.md

UE4SS Lua mods for **Incursion Red River** (UE 5.6, Steam, no anti-cheat).

## Before changing code

Read `CODE_GUIDE.md`. Its rules are not style preferences. Each one exists because breaking it crashes the game or silently breaks after a patch.

The load-bearing ones:

- `RegisterKeyBind` callbacks run **off the game thread**. Hop via `ExecuteInGameThread` before touching a UObject.
- Never use `LoopAsync` / `ExecuteAsync`. Per-tick loops use `LoopInGameThreadWithDelay`. `LoopAsync` calling `ExecuteInGameThread` every tick corrupted the Lua state and crashed the game.
- Never cache a UObject across a level load. Cache the PlayerController, not the pawn.
- `util.valid(obj)`, never `if obj then`. UE4SS returns an invalid stub.
- No memory offsets. Resolve by name through reflection, lazily.

## Layout

- `likhos-<name>/`: one mod, with `mod.txt`, `Scripts/` and `README.md`. All Lua lives flat in `Scripts/`; plain `require("log")`.
  A mod's `README.bbcode` (gitignored) is regenerated from `README.md` before publishing. Never edit it; edit `README.md` only.
- `lib/`: Lua modules shared by every Lua mod (`log`, `util`, `hook`). `build.ps1` and `publish.ps1` copy them into each mod's `Scripts/`, so a mod never has its own file with a `lib` name. Each mod names itself for log lines with `log.setup("<Name>", config.log_level)`.
- A pak mod (`likhos-rearmed`) has `pak=` in `mod.txt` and the JSON edit lists (`reclass`, `clone`, `retarget`, `stats`, `supported`, `effects`, `loadouts`, `loot`) that `tools\pak\pak.ps1` stages the pak's files from. `build.ps1` packs it with repak into `dist\` and installs it into `Content\Paks\~mods`.
- `tools/`: one folder per repo tool (`build/`, `publish/`, `pak/`, `gunsmith/`, `clear-keybinds/`), each holding the script and its configs. The scripts resolve paths from their own location, so they run from any directory. The tools `build.ps1` downloads (`repak/`, `UAssetGUI/`) and local backups in `tools/` are gitignored.
- `docs/solutions/`: session level docs, one solution doc per piece of work, holding its design and its own recon. Read another solution doc only when the user points at it.
  A solution doc records what was done at the time and why. Do not update it when later work changes or supersedes that solution.

## Do not fabricate game internals

Class names, UFunction names and property paths must come from a UE4SS dump or Live View, and recorded in the current task's solution doc only. There is no shared findings file. If a name is unknown, leave the `TODO_` placeholder and say so. A plausible-looking wrong name costs hours of debugging.

## Commands

### tools/build/build.ps1

```powershell
.\tools\build\build.ps1                          # build and deploy every mod folder that has mod.txt
.\tools\build\build.ps1 likhos-backpack          # one mod
.\tools\build\build.ps1 likhos-backpack likhos-rearmed   # several mods
```

- Needs `tools\build\build.config.json` (gitignored, copy of `tools\build\build.config.example.json`) holding the game dir.
- Bumps the patch number in `mod.txt` when the mod folder has uncommitted changes. For a Lua mod, a change in `lib\` also counts. A pak mod counts only its own folder, so a `tools\pak\` change bumps no mod. The bumped `mod.txt` keeps the folder dirty, so every build bumps again until committed.
- Lua mod: copies the mod folder to `ue4ss\Mods\<mod>` and `lib\*.lua` into its `Scripts\`. Fails if `Scripts\` has a file with a `lib` name.
- Pak mod: runs `tools\pak\pak.ps1` on the mod's edit lists to stage files, packs with repak into `dist\<pak>`, copies it into `Content\Paks\~mods`. Downloads repak and UAssetGUI into `tools\` on first use. Needs a usmap in the UE4SS folder, generated in game with the UE4SS mappings dump key after every game patch.

### tools/publish/publish.ps1

```powershell
.\tools\publish\publish.ps1 likhos-backpack -DryRun   # pack dist\<mod>.zip, print the Nexus requests, upload nothing
.\tools\publish\publish.ps1 likhos-backpack           # pack and upload as a new version of the mod's Nexus file
```

- Mod name is required unless `tools\publish\publish.config.json` lists only one mod.
- Needs `tools\publish\publish.config.json` (`mod_id`, `file_id` per mod) and the API key in `tools\publish\nexus-api.key` (gitignored) or `-ApiKey`.
- Publishes the version currently in `mod.txt`. It does not bump it. Run `build.ps1` first. A pak mod fails if `dist\<pak>` is older than any file in the mod folder or `tools\pak\`.
- Refuses a version equal to or older than the live Nexus version unless `-Force`.
- Posts the `CHANGELOG.md` sections newer than the live version, up to the published one, as the Nexus changelog. Every heading must be a bare version (`# 1.2.38`).
- Other switches: `-Category main|optional|miscellaneous`, `-NoArchive` (keep the previous file version unarchived), `-NoBumpModVersion` (do not update the mod page version).

### tools/gunsmith/gunsmith.ps1

Use it to check weapon and attachment balance: it prints each weapon's lowest-recoil build (loud and suppressed) and best-ergonomics build, with a pak mod's edits applied. Layout and recon: `docs/solutions/gunsmith.md`.

```powershell
.\tools\gunsmith\gunsmith.ps1                        # every weapon with likhos-rearmed's edits
.\tools\gunsmith\gunsmith.ps1 -Class Rifle, Smg      # by weapon class, after reclass.json
.\tools\gunsmith\gunsmith.ps1 '*AK*' -Detail         # the parts of each build
.\tools\gunsmith\gunsmith.ps1 -Unique ''             # lift gunsmith.json's one-per-build caps
.\tools\gunsmith\gunsmith.ps1 'AK-74M' -Trace '*Foregrip*'   # every slot path to matching parts
.\tools\gunsmith\gunsmith.ps1 -Vanilla               # the game's own values
```

- Extracts the item definitions and slot classes from the game paks into `tools\gunsmith\cache` (gitignored) on first run, and again when a game pak or the usmap changes or with `-Refresh`. That takes about 2 minutes; later runs take seconds.
- Needs repak and UAssetGUI in `tools\` (fetched by the first pak build) and the usmap in the UE4SS folder.
- `gunsmith.json` lists categories left out of the search, required slots, categories capped at one per build and game bugs to ignore.
- Recoil is the stat sum. For full auto weapons it also shows recoil per second, stat × RPM / 700. `!` marks a build whose parts list each other as conflicting.

### tools/clear-keybinds/clear-keybinds.ps1

Use it when a mod key mapping is renamed or removed, or when a saved key mapping needs to go. It edits `EnhancedInputUserSettings.sav` directly and backs it up first. Run it without switches to list first and tell the user what it would remove. The game must be closed. Layout and recon: `docs/solutions/clear-keybinds.md`.

```powershell
.\tools\clear-keybinds\clear-keybinds.ps1                        # list saved mappings, mark unused Likhos* ones
.\tools\clear-keybinds\clear-keybinds.ps1 -Unused                # remove Likhos* mappings no likhos-*\Scripts\*.lua mentions
.\tools\clear-keybinds\clear-keybinds.ps1 -Name LikhosQuickUse   # remove by name, wildcards allowed
```

In-game console: `kb_status`.

## Mod version

`mod.txt` holds `version="major.minor.patch"`.

- Patch is the build number. `build.ps1` increments it on every build of a changed mod. Never reset it and never edit it by hand.
- A new feature bumps minor by 1 by hand in `mod.txt`, keeping the patch number as is: `1.1.32` becomes `1.2.32`. Fixes and tweaks leave minor alone.
- Major changes only when the user asks.

## Changelog

- New entries go under a `# Unreleased` heading at the top of the mod's `CHANGELOG.md`, never under a version number. Every debug build bumps the patch, so a number written during work goes stale.
- Before publishing, rename `# Unreleased` to the version in `mod.txt` after the last build. `publish.ps1` refuses a heading that is not a bare version, so an unrenamed `# Unreleased` stops the publish.

## Log level

A mod's `Scripts/config.lua` is committed with `log_level = "info"`. Setting `"debug"` for a test in game is fine, but set it back to `"info"` before committing unless the user asks to commit another level.

