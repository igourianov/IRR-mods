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

```powershell
.\build.ps1                 # deploy all mods into the game, bump the mod version
.\publish.ps1 -DryRun       # pack dist\<mod>.zip, show what would go to Nexus
.\publish.ps1               # pack and upload as a new Nexus file version
```

In-game console: `kb_status`, `kb_dump_imc`.

## Current state

UE4SS verified working. `point_aim` is the only bind and the only defined
action.
