# IRR-mods

UE4SS mods for **Incursion Red River** (Games of Tomorrow, UE 5.6, Steam).

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
| `likhos-point-and-shoot` | pre-alpha | Likho's Point and Shoot: hold a key to aim straight into point shooting |

## Layout

```
likhos-<name>/     one mod: mod.txt + Scripts/ + README
docs/solutions/    per-task solution docs, recon findings and session notes
build.ps1          copy mods into the game and package each as dist/<mod>.zip
dist/              distribution zips, laid out to extract into the game install folder (gitignored)
```

## First-time setup

```powershell
Copy-Item build.config.example.json build.config.json
# edit build.config.json -> game.dir
.\build.ps1
```

Then launch the game. The UE4SS console should log the mod loading.
