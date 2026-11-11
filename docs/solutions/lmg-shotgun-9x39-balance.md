# LMG, shotgun and 9x39 balance

Follow-up to `docs/solutions/lamg-muzzle-fix.md`. Numbers from `tools/gunsmith/gunsmith.ps1`, recoil per second for full auto weapons.

## Intent

Per the user, after a gunsmith run over every weapon:

- LMGs recoil less than the rifle they're built on and handle worse.
- Shotgun recoil is fine. The VR80's ergonomics were far too high; its best build caps at 80.
- The AS VAL and VSS can't fire without their integral suppressors. They are light guns firing heavy 9x39 rounds, so they recoil about like a suppressed 7.62x39 AK and handle well. Change as little as possible: bases only.

## Recon

- The AS VAL and VSS integral suppressors (`ID_AS_VAL_Integral_Suppressor` -12 / -9, `ID_VSS_Integral_Suppressor` -13 / -10, both fit both guns) were left out of the suppressor rule, so their suppressed builds sat at 0 recoil. That is vanilla: the VSS builds use no part the mod changes, and the mod's stock rescale had already made the AS VAL worse than vanilla (-10.9 per second). Every other suppressed gun rose 10 to 20 per second with the suppressor rule.
- `gunsmith.json` `requiredSlots` marks their muzzle slots as required, so the tool shows only suppressed builds for them.
- Asset paths: `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/AS_Val/ID_AS_Val`, `/Game/Blueprints/InventorySystem/Items/Weapons/Rifle/VSS_Vintorez/ID_VSS_Vintorez`, and the `Path` of `ID_RPK-74` and `ID_RIA_VR80` in the gunsmith index.

## Solution

In `likhos-rearmed/stats.json`:

| Weapon | Change | Result | Against |
|---|---|---|---|
| KAC LAMG | recoil 38 -> 48 | 11.9 / 15.2 per second, ergonomics 57.8 to 72.8 | M4A1 15.4 / 20, 70.8 to 91.3 |
| RPK-74 | recoil 56 -> 53, ergonomics 41 -> 36 | 7.3 / 22.3 per second, ergonomics 52.8 to 63.8 | AK-74M 9.5 / 27, 64.8 to 81.8 |
| RIA VR80 | ergonomics 55 -> 39 | 63 to 80 | M2 54 to 67, Saiga-12K 37.8 to 64.8 |
| AS VAL | recoil 40 -> 65.5 | 32.8 per second suppressed, ergonomics 63 to 81 | AK-103 suppressed 33, 53.8 to 70.8 |
| VSS | recoil 36 -> 67, ergonomics 52 -> 66 | 33.2 per second suppressed, ergonomics 70 to 72 | same |

The integral suppressors keep their vanilla -13 / -12. They are always fitted, so the bases carry the 13 that setting them to 0 would have moved, and the suppressor definitions stay out of the mod.

Files: `likhos-rearmed/stats.json`, `README.md`, `CHANGELOG.md`, `tools/gunsmith/gunsmith.json` (`requiredSlots`), `tools/gunsmith/gunsmith.ps1` (`requiredSlots`, best-ergonomics column for suppressed-only weapons, `-Class` variable clash).

## Tradeoffs and open

- The integral suppressors still show -12 / -13 recoil in the gunsmith screen, unlike every other suppressor.
- Shotgun brakes keep the mod's buff (CMB -20, GK-02 -26, Tromix -30), so the Saiga-12K stays below zero loud (-6).
- Pistols and snipers are not reviewed.
