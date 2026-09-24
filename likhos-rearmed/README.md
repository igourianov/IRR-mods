# Likho's Rearmed

This mod adjusts various weapon stats

## Classification

* FAL: Rifle -> DMR
* SVD: Sniper -> DMR
* SKS: DMR -> Rifle
* AKS-74U, Rattler, Honey Badger: Rifle -> SMG

## Caliber

Rechambered Rattler from 5.56 to 300BLK

## Ammo

7.62x39 HP:

* Damage: 48 -> 52
* Penetration: 16 -> 10
* Piercing level: 2 -> 1
* Bleeding chance: 10% -> 40%

## Installation

Extract the zip into `PROJECT QUARANTINE\Test_C\Content\Paks`. It places `likhos_rearmed_P.pak` in `Paks\~mods`.

The mod doesn't need UE4SS.

## Uninstall

Delete `Paks\~mods\likhos_rearmed_P.pak`. Weapons and ammo already in your stash stay there and go back to their vanilla class, caliber and stats.

## Compatibility

The mod replaces the game's `DefaultGameplayTags.ini`, the Rattler's item definition (`ID_Sig_Sauer_MCX_Rattler`) and preset (`DA_Sig_Sauer_MCX_Rattler`) and the 7.62x39 HP round's item definition (`ID_762x39_HP`). It conflicts with any other mod that replaces those files, and it needs an update after every game patch that changes them.
