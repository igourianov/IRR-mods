# CLAUDE.md

**Resuming? Read `docs/00-session-state.md` first.**

UE4SS Lua mods for **Incursion Red River** (UE 5.6, Steam, no anti-cheat).

## Before changing code

Read `CODE_GUIDE.md`. Its rules are not style preferences — each one exists
because breaking it crashes the game or silently breaks after a patch.

The load-bearing ones:

- `RegisterKeyBind` / `LoopAsync` callbacks run **off the game thread**.
  Hop via `ExecuteInGameThread` before touching a UObject.
- Never cache a UObject across a level load. Cache the PlayerController, not
  the pawn.
- `util.valid(obj)`, never `if obj then` — UE4SS returns an invalid stub.
- No memory offsets. Resolve by name through reflection, lazily.

## Layout

- `likhos-<name>/` — one mod: `mod.txt`, `Scripts/`, `README.md`,
  `INSTRUCTIONS.md`. All Lua lives flat in `Scripts/`; plain `require("log")`.
- `docs/03-findings.md` — recon results. Source of truth for class and
  function names. Do not invent names that are not recorded there.

## Do not fabricate game internals

Class names, UFunction names and property paths must come from a UE4SS dump
or Live View, recorded in `docs/03-findings.md`. If a name is unknown, leave
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

Scaffold complete, action table empty, UE4SS verified working.
See `docs/00-session-state.md` for where things stand and what is next.
