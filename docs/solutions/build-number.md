# Build number

## Intent

A run of `build.ps1` that deploys changed mod code gives the mod a new version number.

## Constraints and assumptions

- The build number is the third (patch) segment of `version` in the mod's `mod.txt`: `0.1.0`, `0.1.1`, `0.1.2`. `mod.txt` is the only place it lives. No separate counter file.
- A build deploys by copying the mod into the game's Mods folder, replacing any previous deploy. There is no symlink mode. An edit reaches the game only through a build.
- A build bumps the version only when the mod folder has uncommitted changes in git. A clean folder deploys at its current version. The bumped `mod.txt` keeps the folder dirty, so every build bumps again until the work is committed. Accepted.
- Without git (not installed or not a repository) every build bumps, with a warning.
- `-Unlink` never bumps.
- The bump is written to the tracked `mod.txt`. A bump is not rolled back if the copy after it fails.
- The mod does not read or display its version in game.
- The pattern follows `build.ps1` in the sibling RTV-mods repository.
- Ruled out: deriving the number from git (commit count or hash). Uncommitted edits would share one number.
- Ruled out: a gitignored local counter. The number would mean nothing outside this machine.
- Ruled out: symlink deploys. They need Administrator rights or Developer Mode, and hot reload of unbuilt edits is not wanted.
- Ruled out: preserving `mod.txt`'s original encoding. It is written back as UTF-8 without BOM.

## Scope

Owned: `build.ps1`, its deploy mode and the deploy loop.

Context only: `likhos-point-and-shoot/mod.txt`. The build rewrites its `version` field and leaves every other line unchanged.

## Solution

For each mod being deployed, before it is copied, `build.ps1` reads `version` from the mod's `mod.txt`. If the mod folder is dirty in git, or git is unavailable, it increments the patch segment and writes the file back as UTF-8 without BOM. Major and minor are untouched. The deploy output line shows the deployed version next to the mod name.

A mod whose `mod.txt` has no `version` field, or one not shaped `major.minor.patch`, gets a warning naming the mod and is deployed without a bump.

## Tradeoffs

- Tracked counter over git derived or local counter: the number travels with the repo and matches the file a user installs, at the cost of a modified `mod.txt` after a build, which has to be committed or reverted.
- Bumping only dirty folders over bumping every build: rebuilding unchanged code keeps its version, at the cost of every build between two commits taking a new number once the first bump dirties the folder.
- Patch segment as build number: no fourth segment or extra field, at the cost of patch no longer being a hand-managed semantic version. Major and minor stay manual.
