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

## Muzzle devices

Each type of muzzle device has its own role.

* Suppressors reduce recoil about 60% less than before and keep their heavy ergonomics penalty. Their real benefit is sound suppression.
* Muzzle brakes / compensators reduce recoil by 12 to 25%, at a small ergonomics cost.
* Flash hiders improve ergonomics and slightly reduce recoil.
* Thread protectors and adapters no longer reduce recoil.

*Known issues:* 
* Some devices are misnamed in the vanilla game. E.g. `P90 flash hider` is actually a muzzle brake / compensator. This mod only changes stats, not names.
* Vanilla does simple sum when multiple muzzle devices equipped. E.g. a suppressor over a muzzle brake. This is not a realistic behavior, but it is hardcoded and I can't easily fix this.

## NPC loadouts

Each faction's NPCs now carry weapons that fit the faction.

* IGC: mostly 5.45x39 platform with some Vityaz, Saiga and SVD
* UICS: mostly M4 and MP5 with low chance of exotic NATO weapons
* VLF: 7.62x39 rifles and Chinese 5.56 rifles

## Installation

Extract the zip into `PROJECT QUARANTINE\Test_C\Content\Paks`. It places `likhos_rearmed_P.pak` in `Paks\~mods`.

The mod doesn't need UE4SS.

## Uninstall

Delete `Paks\~mods\likhos_rearmed_P.pak`. Weapons, ammo and attachments already in your stash stay there and go back to their vanilla class, caliber and stats.

## Compatibility

The mod replaces these game files:

- `DefaultGameplayTags.ini`
- The Rattler's item definition (`ID_Sig_Sauer_MCX_Rattler`)
- The Rattler's preset (`DA_Sig_Sauer_MCX_Rattler`)
- The 7.62x39 HP round's item definition (`ID_762x39_HP`)
- The item definitions of every muzzle device except the AUG RAT Worx adapter (`ID_*` under `Items/Attachments/Muzzle`)
- Seven NPC loadout presets:
  - `DA_Inventory_AI_Patrol_IGC_A`
  - `DA_Inventory_AI_Sniper_IGC`
  - `DA_Inventory_AI_Patrol_UICS_A`
  - `DA_Inventory_AI_Sniper_UICS`
  - `DA_Inventory_AI_Patrol_VLF_A`
  - `DA_Inventory_AI_Patrol_VLF_B`
  - `DA_Inventory_AI_Sniper_VLF`

It conflicts with any other mod that replaces those files, and it needs an update after every game patch that changes them.

## Known issues

* A suppressor mounted on a muzzle brake keeps the brake's recoil reduction on top of its own. In reality the suppressor would cancel the brake. This affects the DT338 and Surefire SOCOM338-TI suppressors on their brakes and the Honey Badger Trash PANDA on the Cherry Bomb.
