# Full caliber rifle balance

Follow-up to `docs/solutions/bullpup-ergonomics.md`, which parked the MK-47.

## Intent

Per the user:

- 7.62x51 and 7.62x54R rifles are long and heavy, so they should have low ergonomics. The RFB bullpup is the exception, with its best build at 85.
- Their recoil should be fixed. The SR-25 and Galil ACE went below zero because every 7.62x51 rifle takes the Galil ACE II brake (-23.5).
- The MK-47 should be an all-around better SKS, with much more ergonomics. Its loud build may go below zero (-5.5).

## Recon

- Fire modes come from the `U_FireModes_C` stat's tags in each item definition (`Weapon.FireMode.Auto`, `Weapon.FireMode.Semi`). Full auto: FAL, M14, SCAR-H (and the M4A1). Semi only: SR-25, Galil ACE, SVDS, M305, RFB, MK-47. The SKS and M305 also carry `U_RoundsPerMinute_C` 30.
- Every 7.62x51 rifle and the MK-47 take the `UISI_Muzzle_762x51` list. Its strongest brake is the Galil ACE II (-23.5 in the mod), so the suppressed build sits about 23.5 above the loud one. The SVDS takes no brake, only the Rotor43 adapter and suppressor.
- Built-in stock: SCAR-H and RFB. The SKS takes stocks through its SAGE chassis.
- Asset paths: `/Game/Blueprints/InventorySystem/Items/Weapons/DMR/{SR-25,Galil_Ace,SVDS,Norinco_M305,M14,Kel_Tec_RFB,FN_SCAR-H}/ID_<Name>`, `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/FN_FAL/ID_FN_FAL`, `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/MK-47/ID_MK-47`, `/Game/Blueprints/InventorySystem/Items/Weapons/SniperRifle/Simonov_SKS/ID_Simonov_SKS`.

## Solution

- The brakes stay. The base of each rifle is set so its full loud build lands at about 20, a bit above the AK-103's 16. Full auto rifles hit that per second of fire (stat × RPM / 700), semi-auto rifles per shot. The SVDS, with no brake, lands at 30.
- Base ergonomics put every long rifle's best-ergo build at about 70, the RFB's at 85.
- The MK-47's lowest-recoil loud build goes to -5.5, suppressed 18, tying the SKS's 18. Base ergonomics put the MK-47's best-ergo build at about the M4A1's 91 and the SKS's at the long rifle cap of 70.

| Rifle | Recoil | Ergonomics |
|---|---|---|
| FAL | 70 -> 80.5 | 45 -> 38 |
| M14 | 60 -> 74 | 44 -> 40 |
| SCAR-H | 44 -> 58 | 55 |
| SR-25 | 38 -> 78 | 60 -> 36 |
| Galil ACE | 48 -> 69 | 60 -> 40 |
| M305 | 66 -> 75 | 46 -> 40 |
| RFB | 54 -> 58 | 58 -> 83 |
| SVDS | 36 -> 60 | 45 -> 30 |
| MK-47 | 46 -> 50 | 50 -> 56 |
| SKS | 52 | 43 -> 35 |

Full builds from the scratchpad resolver (`best-builds2.ps1`):

| Rifle | Loud | Suppressed | Lowest-recoil build ergo | Best-ergo build: ergo / recoil |
|---|---|---|---|---|
| FAL | 20 / s | 43.5 / s | 48.4 | 70.4 / 60 / s |
| M14 | 20.2 / s | 44.5 / s | 41.3 | 70.3 / 58 / s |
| SCAR-H | 20.1 / s | 40.3 / s | 50.8 | 59.8 / 42 / s |
| SR-25 | 20.5 | 44 | 39.8 | 69.8 / 54 |
| Galil ACE | 20.5 | 44 | 45 | 70 / 54 |
| M305 | 20.5 | 44 | 41.3 | 70.3 / 57 |
| RFB | 20.5 | 44 | 72 | 85 / 48 |
| SVDS | 30 | 30 | 45.5 | 69.5 / 44 |
| MK-47 | -5.5 | 18 | 61.8 | 90.8 / 27 |
| SKS | 18 (no brake) | 18 | 57.8 | 69.8 / 37 |

Files: `likhos-rearmed/stats.json`, `README.md` (and the gitignored `README.bbcode`), `CHANGELOG.md`.

## Tradeoffs and open

- One recoil level for the whole group: the M305 recoils as much as the SR-25. Differences come from ergonomics, weight and price.
- The MK-47 ties the SKS suppressed (18). Base 49.5 would give it a 0.5 edge.
- The MK-47 is the one rifle allowed below zero.
- The SCAR-H's best-ergo build (59.8) sits under the long rifle cap and was left.
