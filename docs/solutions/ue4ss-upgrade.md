# UE4SS upgrade to v3.0.1-1217

## Intent

Move to the UE4SS experimental build `v3.0.1-1217-g4fb9b615` (2026-11-07) from `v3.0.1 Beta f6d5f942` (2026-09-14). That covers the dev install and the build named in the mod READMEs. Confirm that both Lua mods and the pak build work on it. Find out whether its soft object pointer fix ends the crashes the backpack mod works around.

## Constraints and assumptions

### Upstream facts

- 1217 is the head of `UE4SS-RE/RE-UE4SS` `main` as of 2026-11-07, 82 commits past f6d5f942. `experimental-latest` holds only 1217. The `experimental2` archive release holds 1212, 1214 and 1217. f6d5f942 is no longer downloadable anywhere, so going back to it needs a local backup.
- The upstream changelog marks breaking changes for C++ mods only and states the Lua API is unchanged. This project has no C++ mods.
- Upstream changes that touch this project:
	- `6eef940d` and its Unreal submodule update: soft object and soft class pointers resolve their layout at runtime. UE 5.3 removed `TagAtLastTest`, which moved `ObjectID` from 0x10 to 0x08. f6d5f942 reads the old offset, and the game is UE 5.6. The f6d5f942 changelog has no entry for this fix.
	- `97c5642a`, `0c5cb730`: a hot reload waits for running game-thread actions before closing the mod's Lua state.
	- `cdbc0b66`: queued game-thread events run outside the event queue lock.
	- `e3ba1016`: event loops end on shutdown.
	- `3a4b6422`: a non-struct out parameter no longer shifts the parameters after it.
	- `03dbd5c0`: `UObject == UObject` compares the underlying pointers.
	- `5c8583b1`, `c7c5cbbb`: growing a TArray from Lua constructs the new elements.
	- `4e6307e6`, `23e089e4`, `e84db30c`: the usmap generator aborts without writing a file on an enum property with a null enum reference. A GUI checkbox writes such enums as integers into a `-lossy-enums.usmap` instead.
	- `83330635`: `UE4SS-settings.ini` has a new `PointerHash` entry.
- Checked to change nothing in this project's code:
	- Every equality in the mods compares strings, numbers or GUID fields. None compares two UObject wrappers.
	- No mod calls a UFunction with a non-struct out parameter.
	- TArray access is 1-indexed in both builds, and no mod grows a TArray from Lua.
	- The FText runtime layout is already in f6d5f942.

### Install

- The dev install comes from the `zDEV-UE4SS_v3.0.1-1217-g4fb9b615.zip`, which adds `Types.lua`, the `.pdb`, docs and the dev built-in mods. Its `UE4SS.dll` and `dwmapi.dll` are byte-identical to those in the `UE4SS_v3.0.1-1217-g4fb9b615.zip` users install, so a dev test covers the user runtime.
- 1217 ships `EnableHotReloadSystem = 0`, where f6d5f942 shipped 1. A user on 1217 has hot reload off unless they turn it on.
- The dev `UE4SS-settings.ini` differs from the shipped one in `[EngineVersionOverride]` `MajorVersion = 5`, `MinorVersion = 6`, `HotReloadKey = L` and `EnableHotReloadSystem = 1`. These survive the upgrade.
- The dev `Mods\mods.txt` enables `CheatManagerEnablerMod`, `ConsoleCommandsMod`, `ConsoleEnablerMod`, `LineTraceMod`, `BPML_GenericFunctions`, `BPModLoaderMod` and `Keybinds`. Those enable states survive the upgrade.
- The usmap file name carries the UE4SS commit hash. `build.ps1` takes the newest usmap in the UE4SS folder by write time.

### Users

- Users who installed before 2026-11-07 keep running f6d5f942 until they update UE4SS themselves. Users who install now get 1217. The mods run on both builds.
- The README links stay on `experimental-latest`. Ruled out: pinning the exact 1217 file in the `experimental2` archive. Users get whatever UE4SS pushes there next, untested.

### Ruled out

- Publishing to Nexus. The user runs `publish.ps1` once the verification passes.
- Updating `CODE_GUIDE.md` or earlier solution docs, `quick-slot-refill.md` and `inventory-swap.md` among them.
- Removing or backing up f6d5f942 files that 1217 doesn't ship, such as `ue4ss\CustomGameConfigs\Halo Campaign Evolved\`. They configure other games and don't affect this one.
- Verifying quick slot refill on 1217. Its own work covers that.
- Switching likhos-backpack to `GetContainerItemByQuickSlotIndex`, `GetContainerItemByUID` or `GetMainContainerByUID`. The mod would need 1217 and crash the game for users still on f6d5f942.

### Findings on 1217

1. `GetContainerItemByQuickSlotIndex` returns its `ContainerItem` to Lua without crashing, and `SoftItemDefinition` reads with its asset path. The f6d5f942 crash in `push_softobjectproperty` is gone.
2. A struct returned by a UFunction still crashes the game when passed into another UFunction. `GetMainContainerByUID`'s result passed to `IsContainerSupportingItem` is an `EXCEPTION_ACCESS_VIOLATION` in `convert_lua_table_to_struct`, called from `push_structproperty` in `call_ufunction_from_lua`. This is a different cause from the soft pointer crash.
3. 1217 generates a usmap for the current game build without aborting: `Test_C-5.6.1-0+UE5-4fb9b615.usmap`.
4. The rearmed pak staged with the 1217 usmap holds the same 169 files, byte for byte, as the one staged with the f6d5f942 usmap. The pak files themselves differ, because repak's output isn't byte-reproducible.

### Assumptions, unverified

1. 1217 still crashes on the first tick without `[EngineVersionOverride]` 5.6, so the README install step stays.

## Scope

Owned:

- The dev UE4SS install in `Test_C\Binaries\Win64`: `dwmapi.dll` and everything in `ue4ss\` that the UE4SS zip ships, `UE4SS-settings.ini` and `Mods\mods.txt`. Not the deployed `likhos-*` mod folders, dumps, crash files or usmaps.
- The backup of the f6d5f942 install in `tools\ue4ss-f6d5f942\`, which is gitignored.
- The usmap in the UE4SS folder.
- The Requirements section of `likhos-backpack/README.md` and `likhos-point-and-shoot/README.md`.
- The `ue4ss_version` field in `likhos-backpack/mod.txt` and `likhos-point-and-shoot/mod.txt`. No script reads it.
- The code comments in `likhos-backpack/Scripts/quick_slots.lua` that give the reason for reading `QuickSlots` and `MainContainers` directly.

Context only:

- `build.ps1` usmap lookup and `likhos-rearmed/pak.ps1`.
- All other mod code. It is exercised by the verification and left unchanged.

## Solution

### Dev install

The dev install runs 1217. `dwmapi.dll`, `UE4SS.dll` and every other file the 1217 zip ships replace their f6d5f942 counterparts, built-in mods included. `UE4SS-settings.ini` is 1217's shipped ini with the dev values listed under Install applied on top, so it has `PointerHash` and any other new keys. `mods.txt` keeps the dev enable states for existing built-ins. A built-in new in 1217 keeps the zip's default.

`tools\ue4ss-f6d5f942\` holds every f6d5f942 file that the upgrade replaced, in its original layout, so copying it back restores f6d5f942. It also holds the rearmed pak built with the f6d5f942 usmap, as `baseline.likhos_rearmed_P.pak`, for the usmap comparison.

### Usmap

The UE4SS folder holds a usmap generated by 1217 for the current game build. It is the newest one, so `build.ps1` picks it. The rearmed pak staged with it matches the one staged with the f6d5f942 usmap (finding 4).

### Verification on 1217

Both Lua mods are deployed with `build.ps1` and played on 1217 through:

- Hideout to raid to hideout, so every PlayerController acquire path runs.
- Three hot reloads of each mod mid-session, one of them while a game-thread action is pending, such as an auto low ready start.
- likhos-backpack: spent medical items dropping, whole use counts, quick sell and quick deliver.
- likhos-point-and-shoot: point aim bind, the keybind menu row and its saved key, tactical devices, magnifier fold with and without NVG, quick use, auto low ready, and the `kb_status` and `kb_dump_imc` console commands.
- `UE4SS.log` shows no Lua errors from either mod.

Findings 1 and 2 come from a temporary probe that is no longer in the code.

### READMEs

The Requirements line of both Lua mod READMEs keeps the `experimental-latest` link and names the release it was tested with as 2026-11-07 (`v3.0.1-1217`). `ue4ss_version` in both Lua mods' `mod.txt` reads `experimental v3.0.1-1217-g4fb9b615`. The install steps stay as they are, unless the remaining assumption is refuted, in which case step 2 goes.

### Backpack property reads

`quick_slots.lua` keeps reading the `QuickSlots` and `MainContainers` properties directly.

Its comments give reasons that hold on both builds:

- `QuickSlots`: on f6d5f942, `GetContainerItemByQuickSlotIndex` crashes the game converting the returned `ContainerItem` (finding 1).
- `MainContainers`: a struct returned by a UFunction crashes the game when passed into another UFunction, on both builds (finding 2).

## Tradeoffs

- Moving the dev install to an experimental build over staying on f6d5f942. The cost is following UE4SS's experimental churn. Staying would mean testing on a build new users can no longer get.
- `experimental-latest` over a pinned build in the README. The link stays simple, and users may run a build newer than the tested one.
- Property reads over UFunction calls in likhos-backpack. The mod keeps running on f6d5f942 and 1217. The cost is about 30 lines in `quick_slots.lua` (`locate`, `find_item`) that UFunction calls could replace on 1217. `find_replacement` and `root_key` walk `MainContainers` either way, since no UFunction finds an item by definition under an equipment root.
