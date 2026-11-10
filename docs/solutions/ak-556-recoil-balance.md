# AK and 5.56 rifle recoil balance

## Intent

Rebalance AK and 5.56 rifle recoil in Likho's Rearmed:
- An AK with a muzzle brake performs somewhat better than an AR with a flash hider.
- With suppressors on both, the AK performs somewhat worse.
- A fully built AK no longer goes below zero recoil.
- 7.62x39 AKs recoil more than 5.45 ones. A brake brings them back to about AR level, not below it.

## Constraints and assumptions

Recon from the game paks of build 26487830 (2026-11-10), read with UAssetGUI and the current usmap.

- A weapon's base recoil is the `U_Recoil_C` entry in its item definition's `ItemStats` (`ID_<weapon>` under `/Game/Blueprints/InventorySystem/Items/Weapons/<Class>/<folder>/`). The stats stage edits it the same way it edits an attachment. Every weapon definition parses with the current usmap.
- Displayed recoil is the weapon's base plus every attached item's recoil (`docs/solutions/muzzle-recoil-rebalance.md`).
- Muzzle compatibility:
	- A muzzle slot is an `ItemContainers` subobject of class `U_Muzzle_C` or a child. Its supported items are `UISI_Muzzle_*` instances (`Objects/InventorySupportedItems/General/Muzzle/`) or inline tag lists on the host.
	- AKs carry the muzzle slot on the weapon. Every other rifle platform carries it on the barrel, and some muzzle devices carry a second slot.
	- `UISI_Muzzle_556` lists the Gate-LOK, Colt USGI A2, SCAR-L AAC SD 51T and Surefire SD3P-556 flash hiders and the SilencerCo Hybrid 46 suppressor. It has no brake.
	- The AR-15, MCX and SCAR-L barrels use `U_Muzzle_556` with `UISI_Muzzle_556`. The AUG reaches the same list through the RAT Worx adapter and the KAC LAMG through its QDC 3-Prong device. The QBZ-97 fits only its own suppressor.
	- The Gate-LOK and Colt A2 flash hiders take the M4SD II suppressor. The SD3P takes the SOCOM556-MONSTER.
	- AK-74M, AK-105, AKS-74 and RPK-74 use `UISI_Muzzle_545` plus the AK-74M brake. AK-103 and AK-104 use `UISI_Muzzle_762x39` plus the AK-74M brake. AK-101 and AK-102 list the AK-74M brake, RRD-4C, RS Putnik and Hybrid 46 inline. The AK-12 lists its own muzzle and the Hybrid 46. The AKS-74U uses `UISI_Muzzle_545` plus its own muzzle.
	- AK brakes have no slot of their own, so an AK runs either a brake or a suppressor.
- Assumed without a compatibility check: which stocks, handguards and grips fit each weapon, taken from item names. The Norinco CQ has no barrels of its own and is assumed to use the AR-15 barrels.
- The Rattler is left out. It is an SMG at .300 BLK in Rearmed, and `retarget.json` already edits `ID_Sig_Sauer_MCX_Rattler`. The stats stage rejects an asset listed in retarget too.
- Brakes on other platforms keep their values. Changing only the AK brakes breaks the single brake scale of the muzzle rebalance. That question is still open.

Vanilla base recoil:

| Weapon | Recoil |
|---|---|
| AK-12 | 42 |
| AK-105 | 46 |
| AK-101 | 47 |
| AK-103 | 48 |
| AK-74M | 50 |
| AK-104 | 50 |
| AK-102 | 51 |
| AKS-74 | 52 |
| AKS-74U | 56 |
| RPK-74 | 56 |
| FN SCAR-L | 36 |
| KAC LAMG | 38 |
| AUG A3 | 40 |
| QBZ-97 | 54 |
| MCX Rattler | 56 |
| MCX Virtus | 58 |
| Colt M4A1 | 62 |
| Norinco CQ | 68 |

Full build parts used for the totals below (Rearmed values): best barrel (AR-15 20" -4), best stock (AK SAG ACR -17, AK-12 Collapsible -16, AR-15 VLTOR IMOD -16), a railed handguard (AK -2, AK-12 -0.5, AR-15 Geissele MK8 13" -3.5) and the Stark SE3 grip (-9). Muzzle: AK brake or best AK suppressor (-4.5). AR: Gate-LOK flash hider (-4) or Gate-LOK with M4SD II (-8.5).

Before this change:

| Build | Loud | Suppressed |
|---|---|---|
| AK-74M, 74M brake / DTK-1 | 0.5 / -3 | 17.5 |
| AK-12 | -6 | 12.5 |
| M4A1 | 25.5 | 21 |

A base value moves the loud and the suppressed totals by the same amount. The gap between the two is set by the muzzle values: an AK loses its brake for a suppressor, while an AR gains 4.5 from stacking the M4SD II on its flash hider. Base values alone can't make the AK both somewhat better loud and somewhat worse suppressed, so the AK brakes come down too.

## Scope

Owned:
- `likhos-rearmed/stats.json`
- `likhos-rearmed/README.md` and `likhos-rearmed/README.bbcode`
- `likhos-rearmed/CHANGELOG.md`
- `likhos-rearmed/mod.txt` (minor version)

Context only: `tools/pak/pak.ps1` (the stats stage).

## Solution

AK brakes are scaled by 0.7 and rounded to 0.5. The AK-12 muzzle is set to -15.5. Ergonomics stays as it is.

| Attachment | Recoil before | Recoil |
|---|---|---|
| AK-74M Muzzle Brake | -21.5 | -15 |
| AK-12 5.45x39 Muzzle | -22.5 | -15.5 |
| AKS-74U Muzzle | -17.5 | -12 |
| Jmac Customs RRD-4C | -24.5 | -17 |
| Zenitco DTK-1 | -25 | -17.5 |

Weapon base recoil:

| Weapon | Vanilla | Recoil |
|---|---|---|
| AK-12 | 42 | 46 |
| AK-103 | 48 | 56 |
| AK-104 | 50 | 58 |
| Colt M4A1 | 62 | 50 |
| MCX Virtus | 58 | 47 |
| Norinco CQ | 68 | 56 |
| QBZ-97 | 54 | 46 |

After this change:

| Build | Loud | Suppressed |
|---|---|---|
| AK-74M, 74M brake / DTK-1 | 7 / 4.5 | 17.5 |
| AK-12 | 5 | 16.5 |
| AK-103, RRD-4C | 11 | 23.5 |
| M4A1 | 13.5 | 9 |

The README describes the change in its own section and lists the weapon item definitions under Compatibility. The changelog records it under the next version.

## Tradeoffs

- The RRD-4C also fits the FAL, SCAR-H, SR-25, Honey Badger, Galil and RFB. Its cut weakens it there too.
- SCAR-L, AUG and LAMG keep their base. They already match the AKs loud and beat them suppressed.
- Suppressed 5.56 rifles now beat suppressed AKs by more than loud AKs beat 5.56 rifles with flash hiders. The muzzle values set that gap. Narrowing it further would need weaker AK brakes or stronger AK suppressors.
