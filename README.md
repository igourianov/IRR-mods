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
| `likhos-reclass` | pre-alpha | Likho's Reclass: moves weapons to a different weapon class (pak mod) |

## Layout

```
likhos-<name>/     one mod: mod.txt + Scripts/ + README
                   a pak mod has pak= in mod.txt and a pak.ps1 that stages the pak's files instead of Scripts/
tools/             tools build.ps1 downloads on first use (gitignored)
docs/solutions/    per-task solution docs, recon findings and session notes
build.ps1          copy mods into the game and bump the mod version
publish.ps1        pack dist/<mod>.zip and upload it to Nexus Mods as a new file version
dist/              distribution zips, each holding the bare mod folder to extract into ue4ss\Mods (gitignored)
```

## First-time setup

```powershell
Copy-Item build.config.example.json build.config.json
# edit build.config.json -> game.dir
.\build.ps1
```

Then launch the game. The UE4SS console should log the mod loading.

## Publishing to Nexus

`publish.ps1` packs the mod folder into `dist\<mod>.zip` and uploads it as a new version of the mod's existing Nexus file, under the version in its `mod.txt`.

```powershell
.\publish.ps1 -DryRun    # pack the zip, show the request, upload nothing
.\publish.ps1            # pack and publish
```

One-time setup per mod:

1. Create `nexus-api.key` holding a personal key from https://www.nexusmods.com/settings/api-keys (gitignored).
2. Upload the mod's first file on the Nexus site by hand.
3. Put the `file_id` from the Files tab URL into `publish.config.json` (`docs/solutions/nexus-publish.md` has the API query for it).
