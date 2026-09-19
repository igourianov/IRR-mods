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
- `docs/solutions/` — session level docs: solution docs, recon findings
  (`findings.md`) and notes for one piece of work. Read them only when the
  task points at one.

## Do not fabricate game internals

Class names, UFunction names and property paths must come from a UE4SS dump
or Live View, and recorded in the task's solution doc or
`docs/solutions/findings.md`. If a name is unknown, leave
the `TODO_` placeholder and say so. A plausible-looking wrong name costs
hours of debugging.

## Commands

```powershell
.\build.ps1                 # symlink all mods into the game
.\build.ps1 -Copy           # clean install test
.\build.ps1 -Unlink         # remove from game
```

In-game console: `kb_status`, `kb_dump_imc`.

## Current state

UE4SS verified working. `point_aim` is the only bind and the only defined
action.
