# Likho's Rearmed

This mod rebalances various weapon stats, and adjusts faction weapon pool.

## Classification

* FAL: Rifle -> DMR.
* SVD: Sniper -> DMR.
* SKS: DMR -> Rifle.
* AKS-74U, Rattler, Honey Badger: Rifle -> SMG.

## Caliber/Ammo

* Rechambered Rattler from 5.56 to 300BLK.
* Increased bleed chance on 7.62 HP ammo from 10 to 40%.

## NPC loadouts

Each faction's NPCs carry weapons that fit the faction.

* IGC patrols carry mostly 5.45 AKs, with some PP-19 Vityaz and Saiga shotguns.
* IGC snipers use only SVD.
* UICS patrols carry mostly M4s, with some MP5s and Benelli shotguns.
* UICS guards use an assortment of exotic NATO weapons.
* UICS snipers use Galil or SCAR-H.
* VLF patrols use 7.62x39 rifles or Chinese 5.56 rifles.
* VLF pistol patrols carry only the QSZ-92.
* VLF snipers mostly use FAL and sometimes the SVD.

## Installation

Extract the zip into `PROJECT QUARANTINE\Test_C\Content\Paks`. It places `likhos_rearmed_P.pak` in `Paks\~mods`.

The mod doesn't need UE4SS.

## Uninstall

Delete `Paks\~mods\likhos_rearmed_P.pak`. Weapons and ammo already in your stash stay there and go back to their vanilla class, caliber and stats.

## Compatibility

The mod replaces these game files:

- `DefaultGameplayTags.ini`
- The Rattler's item definition (`ID_Sig_Sauer_MCX_Rattler`)
- The Rattler's preset (`DA_Sig_Sauer_MCX_Rattler`)
- The 7.62x39 HP round's item definition (`ID_762x39_HP`)
- Eight NPC loadout presets:
  - `DA_Inventory_AI_Patrol_IGC_A`
  - `DA_Inventory_AI_Sniper_IGC`
  - `DA_Inventory_AI_Patrol_UICS_A`
  - `DA_Inventory_AI_Guard_UICS`
  - `DA_Inventory_AI_Sniper_UICS`
  - `DA_Inventory_AI_Patrol_VLF_A`
  - `DA_Inventory_AI_Patrol_VLF_B`
  - `DA_Inventory_AI_Sniper_VLF`

It conflicts with any other mod that replaces those files, and it needs an update after every game patch that changes them.
