# NPC loadout tiers

## Intent

Rework how Likho's Rearmed sets NPC weapon pools so that:

1. The game's intent of heavier guards and lighter patrols holds within each faction.
2. The mod's intent holds: each faction carries weapons of its own type and ammo, with weights. IGC: mostly the 5.45x39 platform with some Vityaz and Saiga, SVD snipers. UICS: mostly M4 and MP5 with a low chance of exotic NATO weapons, SCAR-H and Galil snipers. VLF: 7.62x39 rifles and Chinese 5.56 rifles, FAL snipers.
3. IGC guards, today a weapon and gear copy of IGC patrols, become the heavier tier in the same way.

Weights are kept as one weighted pool per faction, and each preset's pool comes from it, so every role in a faction draws on the same weapons in consistent proportions.

## Constraints and assumptions

* Names below come from UAssetGUI dumps with the usmap UE4SS generated for build 26437642.
* Each faction's character blueprint has a `LoadoutsByBehaviour` map from an `E_AI_Behaviour` value to a weighted set of presets. The enum's display names are localization keys only, so the roles are named after the presets they map to:
	* `BP_IRR_AI_BaseCharacter_IGC`: patrol `DA_Inventory_AI_Patrol_IGC_A`, guard `DA_Inventory_AI_Guard_IGC`, sniper `DA_Inventory_AI_Sniper_IGC`. A fourth behaviour also maps to `Patrol_IGC_A`.
	* `BP_IRR_AI_BaseCharacter_VLF_NEW`: patrol `DA_Inventory_AI_Patrol_VLF_A` at 1 and `DA_Inventory_AI_Patrol_VLF_B` at 0.2, guard `DA_Inventory_AI_Guard_VLF`, sniper `DA_Inventory_AI_Sniper_VLF`. The fourth behaviour maps to `Patrol_VLF_A`.
	* `BP_IRR_AI_BaseCharacter_UICS`: patrol `DA_Inventory_AI_Patrol_UICS_A` at 1 and `DA_Inventory_AI_Patrol_UICS_B` at 0.5. The fourth behaviour maps to `Patrol_UICS_A`.
	* `BP_IRR_AI_BaseCharacter`, the base class: patrol `Patrol_UICS_A`, guard `DA_Inventory_AI_Guard_UICS`, sniper `DA_Inventory_AI_Sniper_UICS`.
	* `BP_IRR_AI_BaseCharacter_UICS_Spy`: guard `DA_Inventory_AI_Guard_UICS_Spy`.
* UICS snipers spawn in raid with `Sniper_UICS`, which only the base class map names. UICS units therefore also spawn through the base class or a path outside `Blueprints/AI`. Unverified assumption: UICS guards spawn with `Guard_UICS` the same way.
* Vanilla tiers, compared slot by slot. The weapon is slot 0, or slot 2 for pistol presets:
	* Patrol A: a primary weapon. Plate carrier and unarmored rig at tier 1 and 2, helmet 40%, backpack 60% (UICS 30%), 33% chance of a grenade.
	* Patrol B (UICS, VLF): the patrol A gear with a pistol and no primary. The lighter patrol variant.
	* Guard (UICS, VLF): armored rig up to tier 3, helmet always, backpack with ammo, better pocket loot. The weapon mix leans to full rifles over SMGs and shotguns.
	* Sniper: one template in all factions. Armored rig, helmet always, no backpack, best pocket loot and a DMR pool.
	* `Guard_IGC` has patrol A gear exactly, and the patrol A weapon pool minus the AS Val.
* Ruled out: changing NPC gear. `Guard_IGC` keeps its patrol-grade gear, and only weapons express the tiers.
* Ruled out: editing the character blueprints, their behaviour to preset maps or the patrol A to B weights. The tiers are expressed through the presets alone.
* Weapon item definitions (`ID_*` under `Items/Weapons`) carry no rarity tag in their name maps. Unverified assumption: a weapon slot's `RaritySpawnWeights` doesn't filter which weapon spawns, so a preset's weapon odds are its `ItemTypeSpawnWeights` alone.
* A preset's weapon slot is the one slot whose settings' `ItemTypeSpawnWeights` keys are all `Inventory.Items.Weapons.*` tags, with the same tag to relative weight meaning the loadouts stage already relies on.
* A weapon's class is the parent of its item tag after reclass, e.g. `Smg.AKS-74U`, since `reclass.json` moves the AKS-74U from Rifle to SMG. `reclass.json` makes the VSS a DMR, so it goes to the IGC sniper and not to the IGC guard's rifles.
* The VLF pool's primaries are all rifles (7.62x39 rifles, Chinese 5.56 rifles, the SKS, which reclass makes a rifle), plus pistols and the FAL. Selecting by class can't separate a VLF guard from a VLF patrol, so a preset can also select single weapons.

## Scope

Owned:

* `likhos-rearmed/loadouts.json`.
* `likhos-rearmed/pak.ps1`: the loadouts stage and the description line naming it.
* `likhos-rearmed/README.md`: the NPC loadouts section and the presets in the compatibility list.

Context only: the faction character blueprints; `reclass.json`; the reclass, clone, retarget, stats and loot stages; `Get-SlotSettings`, `Read-Assets`, `Save-Asset` and `Find-Tag` in `pak.ps1`; `build.ps1`; the changelog.

## Solution

### `loadouts.json`

The file maps a faction name to two things:

* `pool`: the faction's weapons, each a post-reclass `<Class>.<Name>` tag suffix with a weight. The pool holds every weapon any of the faction's presets carries: primaries, pistols and DMRs. It is the only place weights are set.
* `presets`: each preset's `/Game/` path mapped to its selection, a list of tag prefixes. A prefix is a class (`Smg`) or a single weapon (`Rifle.AK-103`).

A preset carries the pool weapons that some prefix in its selection matches, each at its pool weight. A pool weapon no prefix matches stays out of that preset. So a weapon has the same weight in every preset that carries it, and a preset's odds are its selected weapons' weights over their sum. A sniper preset selecting `Dmr` takes only the faction's DMRs, a pistol preset selecting `Pistol` takes only its pistols.

Factions and presets:

* IGC: `Patrol_IGC_A`, `Guard_IGC`, `Sniper_IGC`.
* UICS: `Patrol_UICS_A`, `Patrol_UICS_B`, `Guard_UICS`, `Sniper_UICS`. `Guard_UICS_Spy` stays vanilla. Its pistol pool already fits the faction.
* VLF: `Patrol_VLF_A`, `Patrol_VLF_B`, `Guard_VLF`, `Sniper_VLF`.

The faction pools are the current `loadouts.json` weights: each faction's patrol A pool, its sniper pool and its pistol pool merged. UICS adds the vanilla `Patrol_UICS_B` pistols (P320, Glock 19, M9A3, FN Five Seven), so that preset keeps its pistols and joins the mod's list.

Role selections:

* Patrol A selects the faction's lighter primaries. IGC and UICS: `Smg`, `Shotgun`, leaving their rifles and the IGC RPK to guards. VLF, whose primaries are all rifles, selects its Chinese 5.56 rifles: `Rifle.Norinco QBZ-97`, `Rifle.Norinco CQ`.
* Guard selects the full rifles and LMGs, dropping SMGs and shotguns. IGC and UICS: `Rifle`, `Lmg`. VLF selects the rifles its patrols don't carry: `Rifle.STV-380`, `Rifle.SKS`, `Rifle.AK-103`, `Rifle.AK-104`.
* Patrol B selects `Pistol`.
* Sniper selects `Dmr`.

### Loadouts stage

For each faction and each of its presets, the stage builds the preset's pool from the faction pool and the preset's selection, then replaces the preset's weapon slot map with it, as the current stage does with a listed pool. Tags are checked against the staged tag list and added to the name map, as before.

The build fails when:

* A preset has no weapon slot, or more than one.
* A selection prefix matches no weapon in its faction's pool.
* A pool weapon is selected by no preset.
* A preset is listed under two factions, or in `loadouts.json` and another stage.

The stage logs each preset's pool as percentages that sum to 100, so the effective odds of every role can be read from the build output.

### README

The NPC loadouts section describes each faction's weapons as today, and says that guards carry only full rifles and LMGs, patrols carry the faction's lighter weapons and some patrols carry only a pistol. IGC and UICS patrols carry only SMGs and shotguns, VLF patrols only the QBZ-97 and CQ. The compatibility list names the eleven replaced presets.

### Result

`.\build.ps1` prints each preset's weapon odds. In game, IGC and UICS patrols carry their faction's SMGs and shotguns, VLF patrols carry the QBZ-97 and CQ, guards of all three factions carry the heavier part of the same faction weapons, pistol patrols carry the faction's pistols and snipers carry the faction's DMRs. IGC guards no longer roll 7.62 AKs.

## Tradeoffs

* One pool per faction with per-preset selections, over an explicit pool per preset: a weapon's weight is set once, and roles can't drift apart. The cost is that a role's odds are no longer written out in the file, which the build log makes up for.
* Selection only, over per-preset multipliers on the pool weights: one weight per weapon, no weight math across two places. The cost is that guard and patrol differ only by which weapons they carry, never by how often a shared weapon rolls. A guard tier is a narrower pool, not a reweighted one.
* Prefixes at class or weapon level, over class only: VLF needs a guard and patrol split inside one class.
* Weapons only, over also giving `Guard_IGC` guard gear: it stays inside the existing stage's kind of edit. IGC guards are heavier by weapon only, not by armor.

## Open questions

* The guard selections are starting values: whether UICS guards should keep some SMGs, e.g. the MP5SD. Check them against the logged percentages.
