# Distribution build

## Intent

Every run of `build.ps1` produces a zip per mod that a user can extract into the game's install folder and play, with no manual file placement or `mods.txt` edit.

## Constraints and assumptions

- UE4SS Lua mods have no package format. A mod is a folder under `ue4ss\Mods\`. The zip is the distribution unit, as on Nexus Mods.
- The zip is laid out relative to the game install root (`PROJECT QUARANTINE`), so its entries start with the `ue4ss.modsDir` path from `build.config.json` (`Test_C\Binaries\Win64\ue4ss\Mods\<mod>\...`). Extracting it into the game root places the mod. Mod managers that expect a game-root layout handle it as is.
- The zip never contains `Mods\mods.txt`. It is shared by every installed mod and extracting ours would overwrite the user's entries.
- The mod is enabled by an empty `enabled.txt` in its folder. UE4SS experimental `v3.0.1-1136-g35d1795d` loads a mod folder that holds `enabled.txt` and has no `mods.txt` entry.
- Zip entry paths use `/` separators, so extractors other than Windows Explorer rebuild the folder tree instead of producing files with backslashes in their names.
- UE4SS itself is not bundled. The mod README links to it. Bundling pins one UE4SS build per mod and conflicts between mods.
- Ruled out: a separate `-Package` switch. Packaging is part of every build, so the zip always matches what was last deployed.
- Ruled out: a version in the zip name. The version lives in `mod.txt` inside the zip.
- Ruled out: refusing or warning on a dirty mod folder. The zip carries the same version the deploy just got.
- `-Unlink` does not package.

## Scope

Owned:

- `build.ps1`: the deploy loop and packaging.
- `likhos-point-and-shoot/enabled.txt`.
- `.gitignore`: the `dist/` entry.
- `likhos-point-and-shoot/README.md`: the Installation and Uninstall sections.

Context only: `build.config.json` (`ue4ss.modsDir`), the version bump from `docs/solutions/build-number.md`.

## Solution

`likhos-point-and-shoot/enabled.txt` is an empty tracked file. The mod folder in the workspace, the deployed copy and the zip hold the same files.

For each mod a build deploys, after the version bump and the copy into the game, `build.ps1` writes `dist\<mod>.zip` at the repository root, replacing any previous zip of that mod. The zip holds the mod folder under the `ue4ss.modsDir` path. The build output names each zip it wrote.

`build.ps1` does not read or write `Mods\mods.txt`. The deployed mod loads through `enabled.txt`, the same way it does for a user who extracted the zip.

`dist/` is gitignored.

The mod README installs the mod by extracting the zip into the game's install folder, after the existing UE4SS setup steps, with no `mods.txt` edit. Uninstall deletes the mod folder under `ue4ss\Mods\`.

## Tradeoffs

- Game-root layout over a bare mod folder: extract and play, at the cost of the zip embedding the `Test_C` module name and UE4SS's `ue4ss\Mods` location. A UE4SS release that moves the Mods folder needs a config change and a rebuild.
- `enabled.txt` over `mods.txt`: no shared file to merge, and the dev deploy exercises the same path as a user install. A user who disabled the mod in `mods.txt` with `: 0` depends on how UE4SS resolves the two, which the build does not check.
- Packaging on every build over an explicit switch: nothing to remember before a release, at the cost of writing a zip on every dev iteration.
- Fixed zip name over a versioned one: `dist\` holds one zip per mod, at the cost of an uploaded file name not telling versions apart.
