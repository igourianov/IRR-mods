# Nexus publish changelog

## Intent

`publish.ps1` publishes changelog notes to Nexus along with each new file version. The notes cover every change since the version currently live on Nexus, taken from the mod's `CHANGELOG.md` and squished under the version being pushed. E.g. with 1.0.10 live on Nexus and 1.0.12 being pushed, the line items of 1.0.12 and 1.0.11 are published together as the changelog of 1.0.12.

## Constraints and assumptions

- Nexus v3 takes changelog text through `POST /mods/{id}/changelogs` with a JSON body of `version` and `changelog` (strings), separate from the file version request. Source: `src/openapi.schema.ts` and `src/index.ts` in the official `Nexus-Mods/upload-action` repo, which posts it after the file version is created.
- `{id}` there is the v3 mod id, not the game-scoped `mod_id` in `publish.config.json` that appears in the mod page URL. E.g. `likhos-rearmed` is game-scoped 273 and v3 id 27217207755025. `GET /games/{game_domain}/mods/{game_scoped_id}` returns the v3 id as `data.id`.
- The endpoint is additive. A repeated call for the same version appends text rather than replacing it. There is no GET for changelogs in v3.
- `CHANGELOG.md` shape, per mod folder: `# <version>` headings, newest first, each followed by `* ` line items. Versions are sparse. A heading does not exist for every `mod.txt` version, since `build.ps1` bumps `mod.txt` on every build.
- Local files are never modified. `CHANGELOG.md` and `mod.txt` are only read.
- Nexus splits changelog text into separate changes on line breaks.
- Inline markdown in items (code spans, emphasis, links) is not stripped. Stripping it correctly needs a markdown parser, which is not worth it for changelog lines. Items are written without markdown instead.

## Scope

Owned: `publish.ps1`.

Context only: `publish.config.json` (`mod_id` per mod, already present), each mod's `CHANGELOG.md` and `mod.txt`.

## Solution

### Nexus version

The live version of the mod file is read from `GET /mod-files/{file_id}/versions`, taking the first version not in the `archived`, `old_version` or `removed` categories, as `Assert-NewerVersion` does today. The lookup runs on every publish, `-Force` and `-DryRun` included. `-Force` only skips the newer-version assertion that uses it.

### Squished changelog

The script reads `<mod>\CHANGELOG.md` and selects every section whose heading version is newer than the Nexus version and not newer than the version being pushed (from `mod.txt`). Versions compare as `[Version]`. With no live version on Nexus, every section up to the pushed version is selected.

The changelog text holds only the selected line items, joined with newlines, one line per item. Version headings and blank lines are not part of it. Each item has its leading bullet marker and surrounding whitespace stripped and is otherwise passed through as written. Sections stay newest first and items keep their order within a section.

A Nexus version, pushed version or heading that does not parse as a version fails the publish before anything is uploaded, `-Force` included. A missing `CHANGELOG.md` or an empty selection is a warning. The publish proceeds without a changelog call.

### Flow

1. Pack the archive.
2. Load the API key and read the Nexus version.
3. Unless `-Force`, assert the pushed version is newer than the Nexus version.
4. Build the changelog text. If it is non-empty, resolve the v3 mod id from `nexus.game` and `mod_id` in `publish.config.json`.
5. `-DryRun`: print the file version request and the changelog request (`POST /mods/{id}/changelogs` with the resolved id and its body), then stop. Nothing is uploaded or posted.
6. Upload, finalise and create the file version.
7. If the changelog text is non-empty, post it to `/mods/{id}/changelogs` under the pushed version.

A failed changelog call reports its error after the file version already exists. The file version stays published.

## Tradeoffs

- The range is anchored on the live file version on Nexus rather than on the mod page version or a local record of the last publish. It needs no local state and matches what users download. The cost is one extra GET per dry run and an API key requirement for `-DryRun`.
- The v3 mod id is resolved at publish time rather than stored in `publish.config.json`. The config keeps only the ids visible in the mod page URL. The cost is one more GET per publish that has a changelog.
- Posting the changelog after the file version, as `upload-action` does, means a changelog failure leaves a published version with no notes. Rerunning the publish does not repair it, since the Nexus version then equals the pushed one and the selection is empty. The notes are added by hand on Nexus in that case.
