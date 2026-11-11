# SMG balance

Follow-up to `docs/solutions/full-caliber-rifle-balance.md`. Separate from the earlier parked `docs/solutions/smg-recoil-balance.md`, which this work didn't read.

## Intent

Per the user, SMGs are close range weapons and not very accurate: they should recoil more than rifles and handle better. The AKS-74U should recoil more than the other SMGs, the Vector less.

## Recon

- Every SMG has `Weapon.FireMode.Auto`, so recoil is judged per second (stat × RPM / 700).
- No loud muzzle device: MP5, MP5K and Vector take only suppressors. The MP5SD has an integral suppressor and only a stock slot.
- SMG-only brakes: `ID_PP-19_Muzzle`, `ID_P90_Flash_Hider` (a brake), `ID_Honey_Badger_Cherry_Bomb_Muzzle_Brake`. The AKS-74U shares the AK brakes (DTK-1 -17.5).
- The Honey Badger barrels (`/Game/Blueprints/InventorySystem/Items/Attachments/Barrel/Honey_Badger_{7,9,12}_Inch_barrel/ID_Honey_Badger_*_barrel`) import both `/Game/Blueprints/InventorySystem/Objects/InventorySupportedItems/General/Muzzle/UISI_Muzzle_300BLK` and `.../UISI_Muzzle_762x51`. `UISI_Muzzle_300BLK` lists the Cherry Bomb, Whistletip and Honey Badger Standard suppressor. The 7.62x51 list brought the Galil ACE II (-23.5).
- The Rattler's definition is in `retarget.json`, and `pak.ps1` refuses an asset listed in both `retarget.json` and `stats.json`.

## Solution

Targets at full builds: suppressed or without a loud device about 30 per second, with a brake about 20, best-ergo builds about 100.

- `stats.json` brakes: PP-19 muzzle -22.5 -> -10, P90 flash hider -22 -> -8. The Cherry Bomb was cut to -8.5 (Trash PANDA +8.5) while the barrel retarget was planned, then put back to -17 (+17) per the user once the Galil ACE II was the Honey Badger's best brake again.
- The Honey Badger keeps the 7.62x51 brakes. A barrel retarget from `UISI_Muzzle_762x51` to `UISI_Muzzle_300BLK` was tried and reverted per the user: the real gun takes 5/8x24 devices, and the double import was untested. Its base splits the 27 per second brake gap: 12 loud, 38.9 suppressed.
- `stats.json` bases:

| SMG | Recoil | Ergonomics | Loud / s | Suppressed / s | Ergo range |
|---|---|---|---|---|---|
| AKS-74U | 56 -> 67.5 | 58 -> 67 | 20 | 37.5 | 79.8 to 99.8 |
| PP-19 Vityaz | 62 -> 60 | 58 -> 65 | 20 | 30 | 79.8 to 99.8 |
| P90 | 42 -> 40 | 70 -> 93 | 19.3 | 29.6 | 93 to 100 |
| MPX | 52 -> 61 | 62 | 26.1 | 29.8 | 70.8 to 99.8 |
| Vector | 48 -> 47.5 | 70 | none | 25.1 | 82 to 100 |
| MP5 | 55 -> 49 | 68 -> 85 | none | 29.9 | 99 to 100 |
| MP5K | 58 -> 51 | 70 -> 84 | none | 32.6 | 99 to 100 |
| MP5SD | 40 -> 38 | 62.5 -> 83 | integral | 29.9 | 90 |
| Honey Badger | 52 -> 66.5 | 55 -> 63 | 12 | 38.9 | 72.3 to 99.8 |
| Rattler | 56 -> 55 | 45 -> 61 | 25.4 | 30 | 81 to 100 |

Values from the scratchpad resolver (`best-builds2.ps1`).

The Rattler needed a `tools/pak/pak.ps1` change. Every stage starts from the game's copy and writes the same staged file, so an asset in both `retarget.json` and `stats.json` was refused. The retarget loop body is now `Set-Retarget`, which only touches the import table and the name map and so works on a parsed or unparsed read. The retarget stage skips assets that also have stats, and the stats stage calls `Set-Retarget` on its parsed copy before setting the stats. Checked by staging into the scratchpad and reading back the staged Rattler: 300 BLK chamber and magazine imports, recoil 55, ergonomics 61.

Files: `likhos-rearmed/stats.json`, `README.md` (and the gitignored `README.bbcode`), `CHANGELOG.md`, `tools/pak/pak.ps1`.

## Tradeoffs and open

- The AKS-74U and Honey Badger keep shared rifle brake gaps, so suppressed they recoil more than a suppressed AK-103 (37.5 and 38.9 against 33).
