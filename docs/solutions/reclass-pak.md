# Reclass pak

## Intent

Move chosen weapons to a different weapon class, e.g. the FN FAL from assault rifles to DMRs, as a mod users install and uninstall without touching their saves.

## Constraints and assumptions

- A weapon's class is the parent of its item ID tag (`Inventory.Items.Weapons.<Class>.<Name>`). See Recon below.
- Lua can't register a GameplayTag at runtime, so a Lua mod can't create the new tag. The tag list comes from `DefaultGameplayTags.ini`.
- A `+GameplayTagRedirects` entry in that ini is applied at runtime to cooked assets and saves, so the item definition, AI loadouts and gunsmith presets that name the old tag all follow it without being patched. The redirect source must not stay in the tag list.
- A pak can only replace the ini as a whole. The shipped ini is a copy of one game build's.
- Stash saves reference items by asset path, so removing the mod loses no items.

## Solution

`likhos-reclass/` is a pak mod: `mod.txt` names the pak (`pak="zz_likhos_reclass_P.pak"`) and there are no Lua scripts.

- `reclass.json` maps `<Class>.<Name>` to a new class.
- `pak.ps1` finds the one top-level game pak holding `Test_C/Config/DefaultGameplayTags.ini`, extracts it with repak into a stage folder, and for each entry renames the tag list line to the new class and appends a redirect from the old tag after the last existing redirect. A game redirect from the new tag straight back to the old one is the developers' own reclass being reverted (SVDS), so it is removed. It fails on an unknown class, a missing old tag, an existing new tag or a new tag that is still a redirect source. BOM and line endings are kept.
- A move of a tag that is itself a redirect target (SKS: `SniperRifle.SKS` to `Dmr.SKS`) chains the game's redirect into the mod's. Cooked assets already hold the target tag, so only data still holding the oldest tag depends on the engine following the chain.
- `build.ps1` treats a mod with a `pak=` line in `mod.txt` as a pak mod: it runs the mod's `pak.ps1`, packs the stage with repak (V11, mount point `../../../`) into `dist\<pak>` and copies it into `Content\Paks\~mods`. repak v0.2.3 is downloaded into `tools\repak` (gitignored) on first use and checked against a pinned SHA256.
- `publish.ps1` zips `dist\<pak>` as `~mods/<pak>`, so extracting into `Content\Paks` installs it. It refuses a pak older than any file in the mod folder.

## Tradeoffs

- Building from the installed game's ini over a checked-in copy: a rebuild after a game patch picks up the patched ini, at the cost of needing the game installed to build.
- Whole-ini replacement: the pak conflicts with any other mod that ships the file, and a game patch that changes the ini needs a rebuild and republish before the mod is safe to use.
- In-place rename over a sorted insert: fewer moving parts. The engine sorts tags itself.

## Recon

### Weapon classification

From the object dump, save files and pak index, 2026-09-23, game build 22417726.

- Items are `IRRItemDefinition` data assets (`/Game/Blueprints/InventorySystem/Items/<Category>/<Class folder>/<Name>/ID_<Name>`). `ItemIdentifier` is one `GameplayTag`, the item's ID.
- Weapon tags are `Inventory.Items.Weapons.<Class>.<Name>`, e.g. `Inventory.Items.Weapons.Rifle.FN FAL`. Classes: `Dmr`, `Lmg`, `Pistol`, `Rifle`, `Shotgun`, `Smg`, `SniperRifle`. The class is the tag's parent, so reclassing a weapon renames its ID tag. Asset folders don't always follow the tag: `ID_SVDS` sits under `Weapons/DMR` with tag `SniperRifle.SVDS`.
- Tags are declared in `Test_C/Config/DefaultGameplayTags.ini`, stored uncompressed in `pakchunk0-Windows.pak`, with `+GameplayTagList` and `+GameplayTagRedirects` entries. The developers moved SVDS and SKS between classes with redirects.
- Game paks: version V11 (`Fnv64BugFix`), no compression, no index encryption, no `.sig`, no IoStore. The engine mounts every `.pak` under `Content\Paks`, subfolders included.
- Class tag consumers in the dump: `IRRAIWeaponSettings.WeaponClassSettingsMap` (`IRRAIWeaponClassSettings`: aim delay, recovery, spread), `IRRAIWeaponData.WeaponClass`, `IRRGunShotEvent.WeaponClass`, the vendor category filter (`W_VendorCategoryFilter_C.CategoryTag`), `InventoryEnhancedUISettings.ItemCategoryItems`. Tag-keyed maps that may be class or item level: `IRRRandomItemParameters.ItemSpawnChances`, `RepairSettings.RepairRules`, `VendorSettings.VendorSellMultiplierMap`.
- Item tag references: `IRRGunsmithSaveGame.PresetMap` is keyed by the full item tag. AI loadouts name weapons by item tag (`DA_Inventory_AI_Sniper_VLF` lists `Rifle.FN FAL`). Stash and inventory saves reference items by definition asset path only, with no tag.

Tested in game with a `_P` pak in `Paks\~mods` holding an edited `DefaultGameplayTags.ini` (`Rifle.FN FAL` removed from the list, `Dmr.FN FAL` added, a redirect from the old to the new):

- The pak's ini replaces the game's. The redirect applies at runtime to cooked assets: the inventory logs `Received Snap for Item: Inventory.Items.Weapons.Dmr.FN FAL`, with no `LogGameplayTags` warnings.
- The vendor and gunsmith list the FAL as a DMR.
- A FAL bought with the pak installed stays in the stash after the pak is removed and loads as `Rifle.FN FAL`.
- Not tested: AI loadouts, a FAL owned before the pak is installed.
