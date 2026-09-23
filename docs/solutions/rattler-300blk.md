# Rattler 300 BLK

## Intent

Chamber the Sig Sauer MCX Rattler in 300 BLK instead of 5.56x45, as part of the Likho's Reclass pak mod.

## Constraints and assumptions

Game internals, from the object dump and the cooked assets of game build 22417726:

- A weapon's caliber is its chamber, not a tag. `ID_Sig_Sauer_MCX_Rattler` (`/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/Sig_Sauer_MCX_Rattler/`) has a `U_Chamber_C_0` subobject holding an instanced `UISI_556_C_0`. An `InventorySupportedItems` subclass carries `SupportedItems`, a tag container, as a class default. `UISI_556_C` supports `Inventory.Items.Ammunition.Rounds.556x45` and `UISI_x300_Blackout_C` (`/Game/Blueprints/InventorySystem/Objects/InventorySupportedItems/General/Ammunition/UISI_x300_Blackout`) supports `Inventory.Items.Ammunition.Rounds.x300 Blackout`.
- The Rattler's `UISI_556_C_0` overrides no properties: its asset's name map holds no ammo tag. So switching its class and template to `UISI_x300_Blackout_C` gives it the 300 BLK set.
- The displayed caliber (`U_Caliber_C`, `W_InventoryItem_C:UpdateCaliber`) is the last segment of the chamber's supported tag, so it follows the chamber.
- The AR-15 mags (Colt A2 Stanag 20/30Rnd, MagPul PMAG 60rnd, SureFire MAG5 60Rnd) accept both `UISI_556` and `UISI_x300_Blackout` rounds.
- The weapon's mag well decides which loaded mags attach. The Rattler's `U_Mag_AR-15_C_0` is an instance of `U_Mag_AR-15_C` (`/Game/Blueprints/InventorySystem/Objects/ItemContainers/Plattforms/AR-15/U_Mag_AR-15`), a subclass of `U_Mag_C` and of `InventoryEquipToContainerSettings`. Every AR-15 weapon shares that class. Its instance holds `UISI_Mag_AR-15_C_0` (which mags fit) and overrides no tag: the Rattler's name map holds none. The class asset has three exports (class, CDO, `UISI_Mag_AR-15_C_0`) and exactly one gameplay tag, `Inventory.Items.Ammunition.Rounds.556x45`. In game, a mag loaded with 300 BLK won't attach to a Rattler whose chamber is 300 BLK.
- That tag is the mag well's filter on what an attached mag may hold, the class default of `InventoryEquipToContainerSettings.ChildSupportedItems`. A copy of `U_Mag_AR-15` under a new path, with the tag renamed to `Rounds.x300 Blackout`, lets 300 BLK-loaded mags attach to a Rattler pointed at it. The engine loads that class from the mod pak although the game's asset registry doesn't list it. Verified in game.
- Adding 300 BLK to the shared `U_Mag_AR-15_C` is ruled out: every 5.56 AR-15 weapon would then take 300 BLK mags.
- The weapon preset `DA_Sig_Sauer_MCX_Rattler` (`/Game/Blueprints/InventorySystem/Presets/Items/Weapons/`) loads the mag preset `DA_AR-15_Colt_A2_Stanag_556x45_30Rnd`. The game ships `DA_AR-15_Colt_A2_Stanag_x300_Blackout_30Rnd` in `/Game/Blueprints/InventorySystem/Presets/Items/Attachments/Mags/`.
- 300 BLK ammo (`ID_x300_Blackout_M62`, `ID_x300_Blackout_ME3`) can be bought or looted in the game. No vanilla weapon is chambered for it.
- All these assets are in `pakchunk6-Windows.pak` as `.uasset` + `.uexp`. The game has no IoStore, so a `_P` pak in `~mods` overrides a whole asset.
- The Rattler barrel's `U_Muzzle_556_C` controls which muzzle devices fit. It stays 5.56, so the Rattler keeps its muzzle devices. Ruled out as not part of the caliber.

- UAssetGUI v1.1.0 (UE 5.6 support) round-trips both assets byte for byte through `tojson` / `fromjson` with `VER_UE5_6` and no usmap, including a PowerShell `ConvertFrom-Json` / `ConvertTo-Json` pass. Exports stay raw, so edits are limited to the name map and the import table. `fromjson` doesn't add new names to the name map itself.

Assumptions, unverified:

- A Rattler already in the stash, with a 5.56 round in the chamber, loads and behaves like a vanilla weapon holding a mismatched round. The same applies to a 300 BLK round after uninstall.

## Scope

Owned:

- `likhos-reclass/`: `pak.ps1`, `clone.json`, `retarget.json`, `mod.txt`, `README.md`, `CHANGELOG.md`.
- `build.ps1`: tool fetching and the call into a mod's `pak.ps1`.

Context only: the class move path in `pak.ps1` / `reclass.json`, `publish.ps1` and the game's assets.

## Solution

- `clone.json` maps a new `/Game/...` package path to the game asset it copies and the names to replace in the copy. It holds one entry: `U_Mag_AR-15_x300_Blackout`, next to `U_Mag_AR-15` in `ItemContainers/Plattforms/AR-15/`, copied from `U_Mag_AR-15` with `Inventory.Items.Ammunition.Rounds.556x45` → `Inventory.Items.Ammunition.Rounds.x300 Blackout`.
- `retarget.json` maps a game asset to the asset references to swap inside it. Both are `/Game/...` package paths. It holds two entries:
	- `ID_Sig_Sauer_MCX_Rattler`: `UISI_556` → `UISI_x300_Blackout` and `U_Mag_AR-15` → `U_Mag_AR-15_x300_Blackout`.
	- `DA_Sig_Sauer_MCX_Rattler`: `DA_AR-15_Colt_A2_Stanag_556x45_30Rnd` → `DA_AR-15_Colt_A2_Stanag_x300_Blackout_30Rnd`.
- `pak.ps1` stages the ini class moves as before, then the clones, then the retargets. Clones and retargets share one asset pipeline. It finds the one top-level game pak holding the source asset, extracts its `.uasset` and `.uexp` with repak, converts them to JSON with UAssetGUI and runs an unedited round trip, which must reproduce the extracted bytes. It then converts the edited JSON back into the stage. A failed round trip means UAssetGUI can't be trusted with that asset.
	- A clone is staged under its new path. The copy's own package path, asset name, Blueprint `_C` class and `Default__..._C` object take the new asset's name wherever they appear, in the name map and in the export and import tables. Each listed name is replaced in the name map, so the raw export data that refers to it follows. It fails when the new path already exists in the game's paks, or when a listed name isn't in the source's name map.
	- A retarget rewrites every import that belongs to the old package so it names the new one: the package import, the asset object and a Blueprint's `_C` class and `Default__..._C` template. Exports and properties that reference those imports follow without edits. It fails when an asset or a reference to swap is missing, or when the new asset is neither in the game's paks nor a clone.
- `build.ps1` fetches pinned tools into `tools\` on first use, each checked against a SHA256: repak into `tools\repak` and UAssetGUI into `tools\UAssetGUI`. It passes both to `pak.ps1`.
- The built `zz_likhos_reclass_P.pak` holds the edited `DefaultGameplayTags.ini`, the two edited assets and the cloned mag well.
- In game, the Rattler shows caliber x300 Blackout and takes 300 BLK ammo in its chamber. It takes AR-15 mags loaded with 300 BLK and rejects ones loaded with 5.56. A Rattler bought as the preset comes with a full 300 BLK Colt A2 30Rnd mag attached. Other AR-15 weapons keep the vanilla mag well.
- `README.md` lists the caliber change next to the class table. Its Compatibility section says the pak also replaces `ID_Sig_Sauer_MCX_Rattler` and `DA_Sig_Sauer_MCX_Rattler` and conflicts with any mod that replaces them. `mod.txt`'s description covers class and caliber changes, and its `game_build` note says the pak carries that build's copies of the ini and the edited assets.

## Tradeoffs

- Cooked asset edit in the pak over a UE4SS Lua change at runtime: the mod stays pak-only and needs no UE4SS. The cost is that the build depends on UAssetGUI reading UE 5.6 assets, and the pak replaces two whole assets, so it conflicts with other mods touching them and needs a rebuild after every patch, like the ini.
- Import retargeting over changing `SupportedItems` on the instance: the swap uses the game's own 300 BLK class, so the result matches how the developers wire a caliber and needs no tag names in the pak. It relies on the swapped instances (`UISI_556_C_0`, `U_Mag_AR-15_C_0`) overriding no tag. The build doesn't check this, so after a patch that adds such an override, the build still passes and only in-game testing shows the swap no longer takes effect.
- A cloned mag well class over a `ChildSupportedItems` override on the Rattler's instance: the edit stays within the name map and import table, so the build needs no usmap and UAssetAPI never has to parse properties. The cost is a new class that exists only in the pak, which the game's asset registry doesn't know. A patch that changes `U_Mag_AR-15` also needs a rebuild to carry the change into the clone.
- A generic `retarget.json` over a caliber-specific config: the preset's mag swap and the chamber swap use one mechanism. The cost is that the file speaks in asset paths rather than calibers.
- Tool fetching stays in `build.ps1` and is passed to `pak.ps1`, over `pak.ps1` fetching its own tools: one pinned download path. The cost is that `pak.ps1`'s parameters grow with every tool a pak mod needs.
