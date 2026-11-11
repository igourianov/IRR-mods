# Bullpup ergonomics

Follow-up to `docs/solutions/suppressor-recoil.md`.

## Intent

Bullpups should handle better than ARs. In the game they didn't: the AUG A3 had the highest base ergonomics of the 5.56 rifles, but an AR gains up to 24 from its stock slot, which the bullpups and the SCAR-L lack. The QBZ-97 had the lowest base ergonomics and lost to every rifle on both stats. Its cheek rest reduced recoil by 10, which the user called nonsense: a cheek rest helps aiming, not recoil control.

Per the user, assume ergonomics and weight are the only handling stats, with no hidden multipliers. The header dump lists `FQUA_WeaponInfluenceSettings.WeaponLengthCurveMultiplier`, which is left unchecked.

## Recon

- Ergonomics reach the character through `UWeaponComponent.FErgonomicsMultiplier` (curve), `GetErgonomicsMultiplier()` and `AQUA_Character.ErgonomicsMultiplier` (`UpdateErgonomics()`). The one native consumer is `FIRRStaminaInfluence.bUseWeaponErgonomicsMultiplier`. Everything else reading it is in Blueprint.
- Built-in stock: the QBZ-97, AUG A3 and SCAR-L have no stock slot. The QBZ-97 has `ID_QBZ-97_Cheek_Rest` under `Items/Attachments/Stock` (vanilla -10 recoil, +6 ergonomics).
- Asset paths: `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/AUG/A3/ID_AUG_A3`, `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/QBZ-97/ID_QBZ-97`, `/Game/Blueprints/InventorySystem/Items/Attachments/Stock/QBZ-97_Cheek_Rest/ID_QBZ-97_Cheek_Rest`.

## Solution

Bullpups get top ergonomics with middling recoil. ARs keep the lowest recoil through their stocks.

In `likhos-rearmed/stats.json`:

- QBZ-97 cheek rest recoil 0, ergonomics unchanged.
- QBZ-97 base recoil 46 -> 34, ergonomics 41 -> 80.
- AUG A3 base ergonomics 65 -> 85.

Full builds from the scratchpad resolver (`best-builds2.ps1`, which can rank by recoil or ergonomics), recoil per second as stat × RPM / 700:

| | Lowest-recoil build: recoil / ergo | Best-ergo build: ergo / recoil |
|---|---|---|
| M4A1 | 15.4 / 70.8 | 91.3 / 32.6 |
| AUG A3 | 23.5 / 91 | 94 / 29.6 |
| QBZ-97 | 25 / 90 | 91 / 29 |

Files: `likhos-rearmed/stats.json`, `README.md` (and the gitignored `README.bbcode`), `CHANGELOG.md`.

## Tradeoffs and open

- The QBZ-97's only muzzle device is its own suppressor, so suppressed it beats the suppressed AUG (25 against 27.6).
- The SCAR-L also lacks a stock slot. Its base recoil (36, 14 below the M4A1) already accounted for a stock, its base ergonomics (56, 4 above the M4A1) didn't. Per the user its base ergonomics go 56 -> 70, the ergonomics of the Daniel Defense stock (-13 / +14), so it matches an M4A1 with that stock: 19.0 per second / 76.8 at its lowest-recoil build, 79.8 / 24.1 at best ergo. Path `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/FN_SCAR-L/ID_FN_SCAR-L`.
- The STV-380 has a built-in stock and flash hider. Its only slot that affects recoil is the foregrip, and it can't take a brake or suppressor. Its base recoil (44) matched an AK-103 with stock and handguard (64 - 17 - 5 = 42), its base ergonomics (53) were about 12 short of the same AK-103 with pistol grip (65). Per the user its base counts a mid AK stock and a flash hider (about -4 / +5, the Gate-LOK on the mod's scale): recoil 44 -> 40, ergonomics 53 -> 70. Builds land at 31 per second / 74 and 35 / 75, between an AK-103 with a brake (16 / 64.8) and a suppressed one (33 / 51.8). Path `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/STV-380/ID_STV-380`.
- The MK-47 reaches -9.5 loud through the 7.62x51 brakes it takes (Galil ACE II -23.5). It is semi-auto only, so its RPM stat doesn't apply. Parked until the battle rifles are reviewed.
- The resolver treats parts that change neither stat as free, so ergo totals can run 1 to 3 high.
- Whether the cheek rest can be removed in the gunsmith screen is unchecked.
