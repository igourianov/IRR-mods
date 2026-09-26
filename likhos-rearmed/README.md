# Likho's Rearmed

This mod rebalances various weapon stats and adjusts faction weapon pools.

## Classification

* FAL: Rifle -> DMR.
* SVD: Sniper -> DMR.
* SKS: DMR -> Rifle.
* AKS-74U, Rattler, Honey Badger: Rifle -> SMG.

## Caliber/Ammo

* Rechambered Rattler from 5.56 to 300 BLK.
* Increased bleed chance on 7.62 HP ammo from 10 to 40%.

## Muzzle device rebalance

Each type of muzzle device now has its own role instead of suppressors being the do-all choice.

* Suppressor recoil reduction nerfed by about 60% across the board. Their real benefit is sound suppression.
* Muzzle brake and compensator recoil reduction buffed to 12 to 25%, at a small ergonomics cost. Now they're a tangible alternative to using a suppressor.
* Flash hiders improve ergonomics and slightly reduce recoil. Default middle ground between the two above.
* Thread protectors and adapters no longer reduce recoil. These serve only a cosmetic purpose.

## Stocks rebalance

The fixed buffer tube + Viper combination being the overpowered choice on every gun. Fixed a couple of odd outliers.

* Removed recoil bonuses from buffer tubes and nerfed their ergonomics, since their stats stacked with the stock on top.
* Removed bonuses from the SKS SAGE chassis. Like the M700 chassis, it has no built-in grip or stock, which are added separately, so the stats stacked.
* Shifted ACE and UBR stocks into ergos instead of recoil.
* Buffed recoil bonus on AK SAG ACR stock.
* Nerfed recoil bonus on Viper stock.

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
- The item definitions of these stocks (`ID_*` under `Items/Attachments/Stock`):
  - Buffer tubes: AR-15 PWS Enhanced, AK SAG, AR-15 Colt A2, FAL Folding and AR-15 Strike SI AR Advanced
  - AR-15 ACE Ultra Lite, AR-15 Magpul UBR and AR-15 Strike Industries Viper Mod 1
  - AK SAG ACR
  - SKS SAGE International SKSALCV chassis
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

* Some devices are misnamed in the vanilla game. E.g. `P90 flash hider` is actually a muzzle brake / compensator. This mod only changes stats, not names.
* Vanilla does a simple sum of ergos and recoil stats when multiple muzzle devices equipped (e.g. a suppressor over a muzzle brake). This is not a realistic behavior, but it is hardcoded and I can't easily fix this.
