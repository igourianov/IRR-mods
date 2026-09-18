# Findings

Fill this in during recon. This is the file that turns into `actions.lua`.

## Environment

| | |
|---|---|
| Game build ID | 22417726 |
| Date verified | 2026-09-18 |
| Engine version | **5.6** (NOT 5.4 - wikis say 5.4, the binary says 5.6) |
| UE4SS version | experimental `v3.0.1-1136-g35d1795d` (zDEV) - stable 3.0.1 CANNOT scan this build |
| UE4SS injects cleanly | **yes** - all scans resolve, HashTables self test passes (7657 classes) |
| GraphicsAPI setting that worked | `opengl` (default; no dx12 option exists in this build) |

## Working UE4SS config

Hard-won. Do not change these without re-testing.

```ini
[EngineVersionOverride]
MajorVersion = 5
MinorVersion = 6      ; <-- 4 causes a deterministic crash at first tick

[General]
EnableHotReloadSystem = 1
bUseUObjectArrayCache = true

[Debug]
GuiConsoleEnabled = 1
GuiConsoleVisible = 1
GraphicsAPI = opengl
```

`Mods/mods.txt`: `KismetDebuggerMod` and `EventViewerMod` set to 0 (not required;
setting 0 stops them starting, though the DLLs still load into the process).

### Failure modes seen, and what they meant

| Symptom | Cause |
|---|---|
| Stable 3.0.1: `Failed to find GUObjectArray` / `FText`, `PS scan timed out` | 3.0.1 has no UE5.6 support. Not a per-build signature issue. |
| Experimental + `MinorVersion = 4`: AV writing to exe image at `+0x15EF0F0`, right after `UStruct::Link` | Wrong engine version -> wrong member/vtable layouts when installing hooks. Deterministic, identical address every run. |

`WARNING: VTable and scan addresses differ for UGameEngine::Tick` still appears
on a healthy run - it is not fatal.

## Input stack

| Object | Present? | Full name |
|---|---|---|
| `EnhancedInputLocalPlayerSubsystem` | ☐ | |
| `EnhancedInputUserSettings` | ☐ | |
| `PlayerInput` (legacy mappings) | ☐ | |

Decision: ☐ IMC mutation ☐ MapPlayerKey ☐ pak override ☐ no interception

## Mapping contexts

Output of `kb_dump_imc` during an active raid:

```
(paste here)
```

`FEnhancedActionKeyMapping` property names observed:

| Property | Type | Notes |
|---|---|---|
| | | |

## Classes

| Role | Class name |
|---|---|
| PlayerController | |
| Player pawn | |
| Input handler owner | |

## Action handlers

| Action | Class | Press fn | Release fn | Args | Verified |
|---|---|---|---|---|---|
| Sprint | | | | | ☐ |
| Crouch | | | | | ☐ |
| Lean L/R | | | | | ☐ |
| Interact | | | | | ☐ |
| Aim | | | | | ☐ |

## UI focus detection

Property that reliably differs menu-open vs menu-closed:

| Object | Property | Closed | Open |
|---|---|---|---|
| PlayerController | `bShowMouseCursor` | | |

## Open questions

-
