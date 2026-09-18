# Findings

Fill this in during recon. This is the file that turns into `actions.lua`.

## Environment

| | |
|---|---|
| Game build ID | 22417726 |
| Date verified | 2026-09-18 (recorded, not yet verified) |
| Engine version | 5.4 |
| UE4SS version | _TODO_ |
| UE4SS injects cleanly | ☐ yes ☐ no — notes: |
| GraphicsAPI setting that worked | _TODO_ |

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
