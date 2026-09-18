# IRR-mods

UE4SS mods for **Incursion Red River** (Games of Tomorrow, UE 5.4, Steam).

| | |
|---|---|
| Install dir | `steamapps\common\PROJECT QUARANTINE` |
| Game module | `Test_C` (the pre-EA project name, still used internally) |
| UE4SS mods  | `Test_C\Binaries\Win64\ue4ss\Mods\` |
| Paks        | `Test_C\Content\Paks\` |
| Saves       | `%LocalAppData%\Test_C\Saved\` |

## Mods

| Folder | Status | Description |
|---|---|---|
| `likhos-keybinds` | pre-alpha | Toggle/hold conversion, double-tap, tap-hold for any bind |

## Layout

```
likhos-<name>/     one mod: mod.txt + Scripts/ + README
docs/              recon notes and findings
tools/dumps/       UE4SS dumps (gitignored, regenerate per patch)
build.ps1          deploy mods into the game (symlink by default)
```

## First-time setup

```powershell
Copy-Item build.config.example.json build.config.json
# edit build.config.json -> game.dir
.\build.ps1
```

Then launch the game. The UE4SS console should log the mod loading.

**Before anything else**, confirm UE4SS actually injects into the current
game build — see `docs/01-recon.md`. That is the project's single largest
risk, not the mod code.

## Conventions

- Never hardcode memory offsets. Resolve everything by UFunction/class name
  through UE4SS reflection, lazily, at call time.
- Never cache a `UObject` across a level load.
- A renamed handler after a game patch must disable *one bind*, not the mod.
- `RegisterKeyBind` callbacks run off the game thread — always hop via
  `ExecuteInGameThread` before touching a UObject.
