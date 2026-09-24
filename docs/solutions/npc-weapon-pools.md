# NPC weapon pools

## Intent

Give each NPC faction a weapon pool that fits it. The Russian IGC carry 5.45 AKs, the NATO UICS carry NATO weapons and the Vietnamese VLF carry Chinese and 7.62x39 weapons. Each faction and role gets a target mix of calibers. The change ships in Likho's Rearmed.

A temporary probe shows in game which preset, weapon and mag ammo each NPC spawns with. It answers what the preset data alone can't: whether tier weights block items and how NPC mag ammo is chosen.

## Target pools

Weights are relative within a preset. Share is the chance of that weapon being the pick. Weapon names use their Rearmed class, e.g. SKS is a Rifle and SVDS a DMR.

### IGC (Russians)

| Preset (used for) | Target pool (weight, share) | Calibers |
|---|---|---|
| Patrol_IGC_A (Patrol and Guard) | AKS-74U 3.6 (23%), PP-19 Vityaz 3.2 (20%), Saiga-12K 2.5 (16%), AK-74M 2.4 (15%), AK-12 1.8 (11%), AK-105 1.25 (8%), AKS-74 1.25 (8%) | 5.45x39 64%, 9x19 20%, 12ga 16% |
| Sniper_IGC | SVDS 2 (100%) | 7.62x54R 100% |

### UICS (NATO)

| Preset (used for) | Target pool | Calibers |
|---|---|---|
| Patrol_UICS_A (Patrol and Guard) | M4A1 5 (52%), MP5 1.1 (11%), Benelli M2 1 (10%), MP5SD 0.8 (8%), AUG A3 0.7 (7%), MP5K 0.55 (6%), MPX 0.55 (6%) | 5.56x45 59%, 9x19 31%, 12ga 10% |
| Patrol_UICS_B (Patrol) | P320 1 (33%), Glock 19 1 (33%), M9A3 0.8 (27%), Five-seveN 0.2 (7%). Vanilla, not edited. | 9x19 93%, 5.7x28 7% |
| Guard_UICS (not used by UICS NPCs) | M4A1 3 (52.6%), MP5SD 1 (17.5%), AUG A3 0.3 (5.3%), SCAR-L, MCX Rattler, MCX Virtus, Vector, P90, VR80 and Honey Badger 0.2 each (3.5% each) | 5.56x45 64.9%, 9x19 17.5%, .300 BLK 7%, .45 ACP 3.5%, 5.7x28 3.5%, 12ga 3.5% |
| Sniper_UICS (Sniper) | Galil ACE 1 (50%), SCAR-H 1 (50%) | 7.62x51 100% |

### VLF (Vietnamese)

| Preset (used for) | Target pool | Calibers |
|---|---|---|
| Patrol_VLF_A (Patrol and Guard) | STV-380 6 (33%), QBZ-97 3.67 (20%), Norinco CQ 3.67 (20%), SKS 3 (16%), AK-103 1 (5%), AK-104 1 (5%) | 7.62x39 60%, 5.56x45 40% |
| Patrol_VLF_B (Patrol) | QSZ-92 2 (100%) | 9x19 100% |
| Sniper_VLF | FN FAL 2 (67%), SVDS 1 (33%) | 7.62x51 67%, 7.62x54R 33% |

Calibers follow each weapon's default mag preset (`Presets/Items/Weapons/DA_*` to `Presets/Items/Attachments/Mags/DA_*`). The Rattler is .300 BLK because Rearmed rechambers it. The Honey Badger's default mag is .300 BLK.

## Constraints and assumptions

- A preset's weapon pool is its weapon container's `IRRRandomItemParameters.ItemSpawnChances` map: weapon gameplay tag to float weight. Every NPC preset has exactly one container whose keys are all weapon tags. Only that map changes. Rarity weights, the other containers and every other field stay vanilla.
- The presets are parsed with the game's usmap, the same way the stats stage parses item definitions. UAssetGUI round-trips `DA_Inventory_AI_Patrol_VLF_A` byte for byte with it. Parsing means entries are deleted and added outright, rather than patched in place.
- Ruled out: editing the raw export bytes in place with removed weapons set to weight 0. The vanilla presets give every single-entry gear container (plate carrier, rig, helmet, backpack) a weight of 0, so weight 0 doesn't clearly mean "never picked". It also needs a slot trick to add the SKS.
- Tags are written as the staged `DefaultGameplayTags.ini` defines them, i.e. with Rearmed's reclass applied (`Rifle.SKS`, `Dmr.SVDS`, `Dmr.FN FAL`, `Smg.AKS-74U`, `Smg.Sig Sauer MCX Rattler`, `Smg.Honey Badger`). Every NPC preset that names a reclassed weapon is in the edit set, so the result doesn't depend on whether tag redirects reach NPC presets. Unverified: the user expects that they don't.
- Ruled out for now: pointing the UICS NPC's Guard role at Guard_UICS. A UICS Guard keeps using Patrol_UICS_A. Guard_UICS is still edited, so it is correct if it is wired up later.
- Out of scope: ammo, tier weights, gear and loot containers, boss presets (`DA_Inventory_AI_Boss_*`) and the base `BP_IRR_AI_BaseCharacter`'s preset map.
- Unverified: a tier weight of 0 in the weapon container (Tier 3 and 4 in patrol presets) may block that tier's weapons. If it does, MP5SD in Patrol_UICS_A never spawns and FN FAL in Sniper_VLF spawns far below its share. The probe answers this. The pools don't change until it does.
- Unverified: after `InitInventory` returns, the weapon and its mag ammo can be read from the NPC by reflection. The build establishes the property paths in Live View.
- The presets are replaced whole. Rearmed conflicts with any other mod that replaces them and needs a rebuild after a game patch that changes them, like its other assets.

## Scope

Owned:

- `likhos-rearmed/pak.ps1`: its loadouts stage.
- `likhos-rearmed/loadouts.json`.
- `likhos-rearmed/README.md`, `README.bbcode`, `CHANGELOG.md` and the `mod.txt` description.
- `likhos-loadout-probe/`: a temporary UE4SS mod.

Context only: `build.ps1`, which installs the usmap and calls `pak.ps1`, and the other `pak.ps1` stages. The loadouts stage reads the reclass stage's staged ini.

## Solution

### loadouts.json

Maps each NPC preset package to its full target weapon pool: weapon tag relative to `Inventory.Items.Weapons` to weight. Tag keys follow `reclass.json`'s `<Class>.<Name>` form. It lists the eight edited presets from the tables above. Patrol_UICS_B isn't listed.

### pak.ps1 loadouts stage

Runs after the stats stage. For each preset in `loadouts.json`, it:

1. Reads the game's copy through `Read-Asset -Parse`, including its round-trip check.
2. Finds the weapon container.
3. Replaces that container's `ItemSpawnChances` with the listed pool. It keeps the key struct shape of the existing entries and adds any new tag to the name map.
4. Stages the preset through `Save-Asset -Parse`.

The stage rejects:

- a tag the staged ini doesn't list;
- a preset without exactly one weapon container;
- a preset that another stage also writes.

It prints one line per preset with its weapon count.

### likhos-loadout-probe

A UE4SS Lua mod laid out like `likhos-point-and-shoot`. It isn't listed in `publish.config.json`, so it is never published. It is deleted once the open questions are answered.

It hooks `BP_IRR_AI_BaseCharacter_C:GetLoadout` for the role and chosen preset, and `InitInventory` for the result. For each spawned NPC it logs one line with:

- the NPC class
- the role
- the preset
- the weapon tag
- the mag's ammo item

A console command `probe_stats` prints spawn counts per preset and weapon, and per weapon and ammo. It follows `CODE_GUIDE.md`: game-thread hooks, `util.valid`, `util.safe` and names resolved by reflection.

### Result

With Rearmed installed, NPCs of each faction and role spawn with weapons from the target pools. Across enough spawns, the probe's `probe_stats` shows the weapon mix per preset. From that mix you can see whether tier weights block MP5SD or FAL and which ammo NPC mags carry.

### README

The Rearmed README has an NPC loadouts section that describes each faction's weapons in a sentence or two, without weights. Its Compatibility section lists the eight replaced presets.

## Tradeoffs

- **Parsed edit over raw bytes.** It relies on the usmap being current, which the stats stage already requires. In return, entries are removed and added cleanly and nothing depends on what weight 0 means.
- **Whole pool per preset in json over a list of changes.** The json restates the vanilla weapons that stay. The file reads as the end state and doesn't break if a patch reorders entries.
- **Editing Guard_UICS although unused.** One more replaced asset and one more possible conflict, for a pool that is ready if it's wired up later.

## Open questions

- Do tier weights of 0 block weapons? If so, raise Tier 3 in Patrol_UICS_A and Sniper_VLF, or drop MP5SD and FAL.
- How is NPC mag ammo chosen: the mag preset's default round or a tier roll?

## Recon

From the UE4SS object dump and cooked assets of game build 22417726.

- `/Game/Blueprints/AI/Characters/BP_IRR_AI_BaseCharacter.BP_IRR_AI_BaseCharacter_C` has `LoadoutsByBehaviour`: a map from `E_AI_Behaviour` to `S_IRR_AI_Loadouts`. `S_IRR_AI_Loadouts.LoadoutMap` maps a double weight to an `IRRItemsPreset`. `GetLoadout(Behaviour) -> Loadout` makes a weighted pick. `InitInventory` fills the inventory from the pick. The base class maps Patrol to Patrol_UICS_A, Guard to Guard_UICS and Sniper to Sniper_UICS.
- A child blueprint's map is saved as a delta against its parent's: keys to remove, then only the entries it overrides. A role the child doesn't list is inherited, as confirmed in game by a UICS NPC carrying a Galil.
- `/Game/Blueprints/AI/E_AI_Behaviour`: `NewEnumerator0` is Patrol, `NewEnumerator1` Guard and `NewEnumerator2` Sniper.
- Faction NPC blueprints are under `/Game/Blueprints/AI/Characters/Standard/`:
  - `BP_IRR_AI_BaseCharacter_IGC` has `FactionTag` `Mission.Faction.OPFOR`.
  - `BP_IRR_AI_BaseCharacter_UICS` has `Mission.Faction.BLUEFOR`. It overrides Patrol (Patrol_UICS_A 1, Patrol_UICS_B 0.5) and Guard (Patrol_UICS_A) and inherits Sniper.
  - `BP_IRR_AI_BaseCharacter_VLF_NEW` has `Mission.Faction.GREYFOR`.
- `/Game/Blueprints/AI/Spawning/BP_RandomSpawnLocation_AI` sets `SpawnClass` and `Behaviour` for each placed spawn point.
- The presets are `/Game/Blueprints/InventorySystem/Presets/Container/AI/<IGC|UICS|VLF>/DA_Inventory_AI_*`, class `/Script/Test_C.IRRItemsPreset`.
  - `DefaultItemsContainers` is an array of `DefaultItemsContainer` with `ContainerType`, `bTryAddWeaponMags`, `bAddRandomItems`, `RandomItemSpawnChances`, `RandomItemParameters` and `DefaultItems`.
  - `IRRRandomItemParameters` holds `ItemSpawnChances` and `RarityChanceDrop` (GameplayTag to float), plus `SupportedFactions`, which is all three factions in every NPC container.
  - The weapon container is `ContainerIndex` 0 (`EquipTo`). The rig container sets `bTryAddWeaponMags`.
- Item tiers are `IRRVendorDefaultItem.ItemRarityTag` in `/Game/Blueprints/InventorySystem/Vendor/DT_Vendor`, as `Inventory.Rarity Types.Tier 1..4`.
