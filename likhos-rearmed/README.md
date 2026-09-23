# Likho's Rearmed

This mod moves weapons to a different weapon class and applies minor weapon fixes.

| Weapon | Vanilla class | New class |
|---|---|---|
| FN FAL | Assault rifle | DMR |
| AKS-74U | Assault rifle | SMG |
| Honey Badger | Assault rifle | SMG |
| Sig Sauer MCX Rattler | Assault rifle | SMG |
| SKS | DMR | Assault rifle |
| SVDS | Sniper rifle | DMR |

The class decides where the weapon is listed at the vendor and in the gunsmith.

It also rechambers weapons in a different caliber.

| Weapon | Vanilla caliber | New caliber |
|---|---|---|
| Sig Sauer MCX Rattler | 5.56x45 | 300 BLK |

The Rattler still takes the same AR-15 mags, but only when they're loaded with 300 BLK. When bought as a complete weapon, it comes with a full 300 BLK Colt A2 30 round mag.

## Installation

Extract the zip into `PROJECT QUARANTINE\Test_C\Content\Paks`. It places `likhos_rearmed_P.pak` in `Paks\~mods`. When updating from Likho's Reclass, delete `Paks\~mods\likhos_reclass_P.pak` (1.0.6) or `Paks\~mods\zz_likhos_reclass_P.pak` (1.0.5 or older) first.

The mod doesn't need UE4SS.

## Uninstall

Delete `Paks\~mods\likhos_rearmed_P.pak`. Weapons already in your stash stay there and go back to their vanilla class and caliber.

## Compatibility

The mod replaces the game's `DefaultGameplayTags.ini` and the Rattler's item definition (`ID_Sig_Sauer_MCX_Rattler`) and preset (`DA_Sig_Sauer_MCX_Rattler`). It conflicts with any other mod that replaces those files, and it needs an update after every game patch that changes them.
