# Clear leftover keybinds

## Intent

Remove key mappings that mod experiments left in the game's saved key profile, e.g. `LikhosQuickUse` after the mapping was renamed. A script edits the save file directly, with the game closed.

## Constraints and assumptions

- The save is `%LOCALAPPDATA%\Test_C\Saved\SaveGames\EnhancedInputUserSettings.sav`. The game keeps the settings in memory and saves them over the file, so it must be closed during the edit.
- The file layout below is read from the save itself (Recon). Only the observed layout is accepted. Any unexpected value, tag flag or trailing data refuses the write.
- A mod mapping is one whose name starts with `Likhos`. It is unused when no `likhos-*\Scripts\*.lua` mentions its name as a whole word. Vanilla `IA_*` mappings are never flagged, only removed by name.
- Removing a mapping that something still registers resets it to its default key.

## Scope

Owned: `tools/clear-keybinds.ps1`, the `tools/` entries in `.gitignore`, the `tools/` line in `README.md`.

## Solution

`tools\clear-keybinds.ps1` parses the whole file, then:

- no switches: lists every saved mapping with its key, marking unused mod mappings,
- `-Unused`: removes the unused mod mappings,
- `-Name <pattern>[,...]`: removes the mappings matching the names, `-like` wildcards allowed,
- `-Path`: another save file, for testing on a copy.

Before writing it refuses if a process runs from the game dir in `build.config.json`, then copies the original to `<file>.<yyyy-MM-dd.HHmmss>.bak`. It drops each removed entry's bytes and rewrites its profile's entry count. Nothing else in the file changes.

`.gitignore` no longer ignores the whole `tools/` folder, only `repak/`, `UAssetGUI/`, `UE4SS-Lua-Types/` and `ue4ss-*/`.

## Recon

From `EnhancedInputUserSettings.sav` on 2026-11-09 (engine 5.6.1 in its header), and its backup from the same day.

- GVAS header: `GVAS`, save game version 3, UE4 package version 522, UE5 package version 1017, engine 5.6.1 changelist 0, branch `UE5`, custom version format 3, 90 custom versions (GUID + int32 each), save class `/Script/EnhancedInput.EnhancedInputUserSettings`.
- Objects: one serialization control byte (0), tagged properties up to `None`, an int32 0. Tags use the complete type name layout: name FString, type name (FString, int32 parameter count, parameters, recursively), int32 size, uint8 flags (0 in every tag seen), value.
- Settings object properties: `CurrentProfileIdentifier` (`GameplayTag`), `CurrentProfileIdentifierString` (`StrProperty`), both `InputUserSettings.Profiles.Default`.
- After the settings object: int32 2 (meaning not identified), int32 profile count (1), then per profile:
  - FString class `/Script/EnhancedInput.EnhancedPlayerMappableKeyProfile`, FString object name `EnhancedPlayerMappableKeyProfile_2147482007`,
  - int32 entry count (27), then entries of: FString mapping name, FString key name, two FStrings for the hardware device (`None`, `None`), 6 bytes (all 0 in every entry seen),
  - FString `InputUserSettings.Profiles.Default`, the profile object (`ProfileIdentifier`, `ProfileIdentifierString`, `DisplayName` "Default Profile"), FString `ObjectEnd`. The file ends there.
- The backup file holds `LikhosQuickUse: N`, which no mod registers any more. Removing it from a copy took the file from 4270 to 4221 bytes, one 49 byte entry, and the result parses.

## Tradeoffs

- Direct file edit over an in-game console command: works on mappings no mod loads any more and needs no mod code, at the cost of depending on the file layout. The strict parse turns a layout change into a refusal, not a corrupt save.
- Unused means "not mentioned in this repo's Lua": no list to maintain, at the cost of flagging nothing for a name built at runtime from parts.
