# Muzzle recoil rebalance

## Intent

Rebalance muzzle devices in Likho's Rearmed so each type has its own role:
- Suppressors slightly reduce recoil, about 60% less than now, and drastically reduce ergonomics. Their sound suppression is their main benefit.
- Muzzle brakes drastically reduce recoil, in the 15 to 25% range, and slightly reduce ergonomics.
- Flash hiders slightly improve ergonomics instead of costing it, and slightly reduce recoil.
- Thread adapters and protectors have no recoil effect and slightly reduce ergonomics.

Some exceptions to these roles are intentional: the Saiga Tromix and GK-02, FAL and Galil ACE II brakes carry heavier ergonomics penalties, and the SCAR-H AAC SD 51T flash hider costs ergonomics.

## Constraints and assumptions

- Each stat is one `ItemStats` entry on the item definition (`ID_<name>`). Its `StatItemConfig` points at a stat object exported by the same asset, of class `U_Recoil_C` or `U_Ergonomics_C`.
	- Recoil is `Multiply` with a negative value. More negative means more recoil reduction.
	- Ergonomics is `Add`. Negative is a penalty, positive a bonus.
- Muzzle velocity is out of scope. Attachments carry a token `Add` of 0.5 to 1 m/s and it likely has no gameplay effect.
- Vanilla values come from game build 22417726.
- Suppressors are the 26 items with Suppressor or Silencer in the name.
	- Recoil = vanilla × 0.4, rounded to the nearest 0.5, with ties rounded away from zero.
	- Ergonomics stays vanilla.
- The brake and flash hider values are hand-set targets.
- Muzzle brakes are the listed 17 devices: the items with Muzzle Brake in the name except the AR-10 M110 and the Whistletip, plus the Jmac RRD-4C, the Saiga Tromix Monster Claw and GK-02, both pistol compensators, the P90 flash hider and the stock FAL, AKS-74U, PP-19 and Galil ACE II muzzles.
- Flash hiders are the other 7 Flash Hider items plus the AR-10 M110 7.62x51 Muzzle Brake and the Honey Badger Whistletip Muzzle Brake.
- Thread adapters and protectors (M9A3 Thread Protector, SVD Rotor43 Thread Adapter, Saiga-12K 12ga Muzzle Device) have recoil 0 and keep their vanilla ergonomics. The AUG RAT Worx Muzzle Adapter has no recoil entry in vanilla and stays untouched, since the stats stage requires the entry to exist.
- A weapon's displayed recoil and ergonomics are its own `Base` value plus the values of every attached item, nested devices included. Recoil is a percentage stat (`U_Recoil` has `MaxValue` 100). An item's recoil value is in percentage points, and the game adds them up despite the `Multiply` type: a -3 item lowers a weapon's recoil from 46% to 43%.
	- Observed in game (vanilla) on the DT SRS A2 with the DT338 brake (recoil -3, ergo -2) and the DT338 suppressor mounted on it (recoil -14, ergo -17). Bare: ergo 44, recoil 46. Brake only: 42, 43. Both: 25, 29.
	- So a suppressor on a brake or flash hider adds to the base device. This applies to the DT338, SOCOM338-TI and Trash PANDA suppressors on brakes, and the M4SD II, SOCOM556-MONSTER, AAC 762-SDN-6 and Rotor43 suppressors on flash hiders or adapters.
	- Ruled out: making a suppressor cancel the recoil of the brake it mounts on. The sum is native and stat values are per item. It is accepted as a known issue.
- UAssetGUI must convert one asset at a time. Parallel conversions intermittently leave every export of a package as `RawExport`. `pak.ps1` already runs it serially.
- None of the listed item definitions is edited by another stage of `pak.ps1` (`clone.json`, `retarget.json`, `loadouts.json`). The stats stage rejects an asset listed in retarget as well.
- The pak carries the edited item definitions whole, so each game patch that touches them needs a rebuild. This already applies to Rearmed.

## Scope

Owned:
- `likhos-rearmed/stats.json`
- `likhos-rearmed/README.md` and `likhos-rearmed/README.bbcode`
- `likhos-rearmed/CHANGELOG.md`

Context only: `likhos-rearmed/pak.ps1` (the stats stage), `build.ps1`.

## Solution

`stats.json` maps each item definition's package path (`/Game/Blueprints/InventorySystem/Items/Attachments/Muzzle/<folder>/ID_<name>`) to the stats its table below sets: `Recoil` and, where it differs from vanilla, `Ergonomics`. The existing stats stage in `pak.ps1` extracts each definition, finds each named stat's entry and writes its value. `build.ps1` packs the definitions into `likhos_rearmed_P.pak`. No `pak.ps1` change is needed.

Suppressors. Ergonomics stays vanilla and is listed for reference.

| Attachment | Recoil | Ergonomics |
|---|---|---|
| AAC 762-SDN-6 | -3 | -16 |
| AK-74 Steel PATRIOT Silencer | -4.5 | -19 |
| AR-15 Griffin M4SD II Silencer | -4.5 | -18 |
| AUG Ase Utra SL7i | -3 | -12 |
| DT338 | -5.5 | -17 |
| Honey Badger Suppressor | -4.5 | -16 |
| Honey Badger Trash PANDA | -5.5 | -10 |
| KVP XL 45ACP | -2.5 | -12 |
| M700 PGW Timberwolf | -4 | -15 |
| MP5 PDW | -3.5 | -12 |
| MPX Ronin 12 Inch 9x19 | -6 | -18 |
| MPX Ronin 8 Inch 9x19 | -5 | -12 |
| PBS-4 5.45x39 | -3.5 | -18 |
| QBZ-97 5.56x45 | -4 | -17 |
| RS Putnik Multi-Caliber | -4 | -20 |
| Sig Sauer SRD762 | -4 | -22 |
| SilencerCo Hybrid 46 | -4 | -17 |
| SilencerCo Omega 45k | -3 | -15 |
| SilencerCo Osprey 45K | -4 | -17 |
| SilencerCo Salvo12 | -4 | -17 |
| SKS OSS HX-QD 762 | -4 | -17 |
| Surefire Ryder 9M TI | -3 | -20 |
| Surefire SOCOM338-TI | -5 | -24 |
| Surefire SOCOM556-MONSTER | -5 | -18 |
| SVD Rotor43 762x54 | -4 | -13 |
| TGP-A 5.45x39 | -4 | -17 |

Muzzle brakes:

| Attachment | Recoil | Ergonomics |
|---|---|---|
| AK-12 5.45x39 Muzzle Brake | -17.5 | -5 |
| AK-74M Muzzle Brake | -16.5 | -5 |
| AKS-74U Muzzle | -12.5 | -3 |
| DT338 Muzzle Brake | -17 | -3 |
| FAL Standard Muzzle | -14 | -7.5 |
| Galil ACE II 7.62x51 Muzzle | -18.5 | -7 |
| Honey Badger Cherry Bomb | -12 | -1 |
| Jmac Customs RRD-4C | -19.5 | -4 |
| M700 PGW Timberwolf Muzzle Brake | -17 | -5 |
| M9A3 Compensator | -18 | -2 |
| P320 Compact Compensator | -17.5 | -2 |
| P90 Flash Hider | -17 | -2 |
| PP-19 Muzzle | -17.5 | -3 |
| Saiga-12K GK-02 12ga Muzzle Device | -21 | -10 |
| Saiga-12K Tromix Monster Claw 12ga Muzzle Device | -25 | -12 |
| Surefire SOCOM338-TI Muzzle Brake | -17.5 | -6 |
| Zenitco DTK-1 | -20 | -4 |

Flash hiders:

| Attachment | Recoil | Ergonomics |
|---|---|---|
| AR-10 M110 7.62x51 Muzzle Brake | -2 | 1 |
| AR-15 Griffin Gate-LOK Hammer Flash Hider | -4 | 5 |
| AUG A3 Flash Hider | -2 | 1 |
| Colt USGI A2 Flash Hider | -2 | 4 |
| Honey Badger Whistletip Muzzle Brake | -3 | 1.5 |
| MPX 9x19 Flash Hider | -2 | 4 |
| SCAR-H AAC SD 51T Flash Hider | -2 | -2 |
| SCAR-L AAC SD 51T Flash Hider | -2 | 1 |
| Surefire SD3P-556 3 Flash Hider | -1 | 1 |

Thread adapters and protectors. Ergonomics stays vanilla and is listed for reference.

| Attachment | Recoil | Ergonomics |
|---|---|---|
| M9A3 Thread Protector | 0 | -1 |
| Saiga-12K 12ga Muzzle Device | 0 | -1 |
| SVD Rotor43 Thread Adapter | 0 | -2 |

The README describes the rebalance under its own heading and lists the replaced item definitions under Compatibility. A Known issues section says that a suppressor mounted on a muzzle brake keeps the brake's recoil reduction on top of its own, where in reality the suppressor would cancel the brake's effect, and names the three affected pairs: DT338, Surefire SOCOM338-TI, and Honey Badger Cherry Bomb with Trash PANDA. The changelog records it under the next version.

In game, every listed attachment shows its new stats, and a weapon's totals change accordingly when one is attached.

## Tradeoffs

- Every brake outperforms every suppressor on recoil. Suppressors keep their noise benefit (see `docs/solutions/suppressor-noise.md`).
- The Jmac RRD-4C (-19.5) fits every AK as well as the FAL, SCAR-H, SR-25, Honey Badger and Galil. It is the strongest brake on all five 7.62x51 / .300 weapons. The Galil ACE II muzzle (-18.5) fits the same five and comes second.
- Nested devices stack, so a suppressor on a brake keeps the brake's full recoil reduction. `stats.json` sets per-item values only, so it can't make a suppressor cancel its base device.
