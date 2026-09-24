# Parallel pak build

## Intent

Cut the time `likhos-rearmed/pak.ps1` takes to stage the pak. It went from 114 s to 24 s, with staged output byte-identical to the sequential build.

## Recon

* Per asset the sequential build ran 2 `repak unpack` calls (0.07 s each), 1 UAssetGUI `tojson` (0.49 s), 2 UAssetGUI `fromjson` (0.57 s each: round-trip check and final write) and JSON conversion (0.03 s). About 1.8 s per asset, 1.6 s of it UAssetGUI launches, each starting .NET and loading the usmap. `stats.json` alone lists 56 assets.
* UAssetGUI v1.1.0's command line converts one file per call. It has no batch mode.
* `repak unpack` takes several input paks and a repeated `-i`, extracting every included file from whichever pak holds it into one output folder. Without `-i` it extracts everything.
* Parallel UAssetGUI instances given the same mappings name often skip the usmap silently: exit code 0, every export left as `RawExport`. 42 of 96 parallel `tojson` calls did so. With one usmap copy per parallel instance, 0 of 96 did.
* `Start-Process -PassThru` without `-Wait` reports a null `ExitCode` unless the process handle is taken while it runs.

## Design

* `build.ps1` copies the game's usmap into UAssetGUI's mappings folder once per logical core, as `<module>-<n>.usmap`, and passes the names to `pak.ps1 -Mappings`.
* `Invoke-UAssetGUI` takes a list of calls and runs them in parallel, one per usmap copy. Call i waits for call i - N, whose copy it reuses. It waits for all calls before checking exit codes.
* `Expand-GameFiles` extracts a list of files in one `repak unpack` call over every game pak holding them.
* `Read-Assets` reads one stage's assets as a batch: one extract, parallel `tojson`, then JSON parsing. A parsed read whose exports are all `RawExport` fails, so a skipped usmap can't pass unnoticed.
* `Save-Asset` only writes the JSON and queues the `fromjson` call. `Save-QueuedAssets` runs every queued write in one parallel batch at the end, then checks each output exists and that each round-trip check matches the game's bytes.
* Each stage loop reads its assets up front and pairs them with its entries by index.

## Verification

Staged the pak with the sequential and the parallel `pak.ps1` into separate folders. Both hold the same 135 files with identical hashes.
