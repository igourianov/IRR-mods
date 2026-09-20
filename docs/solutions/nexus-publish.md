# Nexus publish

## Intent

Releasing a mod is one command: `publish.ps1` packs the mod folder into `dist\<mod>.zip` and uploads it to the mod's Nexus page as a new file version, with no browser steps.

The two scripts split by audience: `build.ps1` serves the dev loop (deploy into the game folder, bump the version), `publish.ps1` serves the release (pack, upload). A dev iteration no longer writes a zip nobody reads.

`build.ps1 -Unlink` is gone with it. A deploy is a copy, so removing a mod from the game is deleting its folder under `ue4ss\Mods`, which the mod README already tells users to do.

## Constraints and assumptions

- The process mirrors the one in the RtV-mods repository: `publish.ps1` + a tracked `publish.config.json` + an untracked `nexus-api.key`, against the Nexus v3 API at `https://api.nexusmods.com/v3`.
- The v3 flow is three calls: `POST /uploads` for a presigned URL, `PUT` the bytes there, `POST /uploads/{id}/finalise`, then `POST /mod-files/{file_id}/versions`. Both the `Content-Disposition` and `Content-Type` headers on the `PUT` are part of the presigned signature and must match the values sent to `/uploads`.
- `file_id` identifies an existing *mod file*, which new versions are added to. Nexus has no API call here for creating the first file, so a mod's first upload is done by hand on the site. `mod_id` is only used to print the mod page link.
- The `file_id` is *not* the id the v1 API returns for a file: v1 `file_id` is the game-scoped version (515 here) and v1 `uid` is the v3 version id. The v3 mod file id is `groupId` in the v2 GraphQL API, and the site's Files tab URL carries the same value:

  ```powershell
  $k = (Get-Content .\nexus-api.key -Raw).Trim()
  $g = (Invoke-RestMethod 'https://api.nexusmods.com/v1/games/incursionredriver.json' -Headers @{ apikey = $k }).id
  $q = @{ query = "{ modFiles(modId: <mod_id>, gameId: $g) { fileId groupId name version category } }" } | ConvertTo-Json -Compress
  (Invoke-RestMethod 'https://api.nexusmods.com/v2/graphql' -Method Post -Headers @{ apikey = $k } -ContentType 'application/json' -Body $q).data.modFiles
  ```
- The zip holds the bare mod folder, as before: extracting it into `ue4ss\Mods` installs the mod. Entry paths use `/` separators, so extractors other than Windows Explorer rebuild the folder tree.
- The zip is packed from the workspace at publish time, so it always matches what `build.ps1` last deployed and the version cannot drift between the two.
- The published version is the one in the mod's `mod.txt`. `publish.ps1` never bumps it; that is the build's job, on a dirty mod folder.
- Uploads over 100 MiB need a multipart upload. Not implemented; the script refuses instead.
- Nexus accepts letters, digits, `.` and `-` in a version, up to 50 characters.
- The API key is a credential: `nexus-api.key` stays gitignored and is never echoed. `publish.config.json` holds only public ids, so it is tracked.
- Ruled out: publishing an arbitrary prebuilt archive (a `-Zip` switch). Publishing always packs, so there is one path to reason about.
- Ruled out: pushing the README as the mod description. That conversion is the `md-to-bb` skill's job and a separate, manual step.

## Scope

Owned:

- `publish.ps1`.
- `publish.config.json`.
- `build.ps1`: the packaging removed from the deploy loop, the `-Unlink` switch dropped, and the header.
- `README.md`: the Publishing to Nexus section and the Layout block.
- `CLAUDE.md`: the Commands block.

Context only: `.gitignore` (already ignores `nexus-api.key` and `dist/`), `docs/solutions/distribution-build.md` (which introduced the zip layout, then part of the build).

## Solution

`publish.ps1 [<mod>]` resolves the mod from `publish.config.json`, defaulting to the single entry when only one mod is configured, and fails there when the mod has no `file_id` yet.

It then reads the mod id and version from the workspace `mod.txt`, rejecting a mismatched id or a version Nexus would refuse, packs `dist\<mod>.zip` from the mod folder, and refuses a file over 100 MiB.

`-DryRun` stops after packing and prints the version request, so it never reads the API key and never touches Nexus. The zip it leaves behind is a normal release artifact.

Otherwise it reads `nexus-api.key`, and unless `-Force` is passed, compares the version against the live one from `GET /mod-files/{file_id}/versions`, refusing an equal or older version. It then uploads, finalises, polls `GET /uploads/{id}` for up to two minutes for the `available` state, and creates the version with `archive_existing_file`, `update_mod_version` and `primary_mod_manager_download` (set for a `main` file). `-NoArchive`, `-NoBumpModVersion` and `-Category` override those per run; `category` and `update_mod_version` in the config override them per mod.

Failures are plain errors carrying the HTTP status and the API's response body.

`build.ps1` keeps the version bump and the copy into the game's Mods folder, and no longer writes `dist\`.

## Tradeoffs

- Packing in `publish.ps1` over packing in every build: the dev loop stays cheap and the zip only exists when a release is being made, at the cost of the published zip never having been the one deployed and played. The deployed copy and the packed copy are the same files on disk, so they differ only if the workspace changed in between.
- Manual first upload over a full mod-creation flow: far less API surface to get wrong, at the cost of one `file_id` to paste per new mod.
- A tracked `publish.config.json` over inferring ids from the mod page: the ids survive a clone and a scrape cannot break, at the cost of editing a file for each new mod.
- No multipart upload: a Lua mod zip is kilobytes, so the 100 MiB path would be dead code.
