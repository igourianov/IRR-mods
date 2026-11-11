# AK recoil per second against ARs

Follow-up to `docs/solutions/ak-556-recoil-balance.md` (commit `0fbac15`), which balanced on the recoil stat alone.

## Intent

In game, an average AK-105 build and an average M4A1 build showed about the same recoil stat (15.5 and 15), but the M4A1 climbed noticeably more. The M4A1 fires at 800 rounds per minute and the AK at 700. Per the user:

- Balance with weapon and attachment stats only.
- Raise the AKs rather than lower the ARs.
- Keep the earlier intent: an AK with a brake beats an AR with a flash hider, a suppressed AR beats a suppressed AK, and a brake brings a 7.62x39 AK to about AR level.

## Constraints and assumptions

- The game's recoil is the plain sum of the weapon's and every attachment's definition `Recoil` (`docs/solutions/debug-weapon-probe.md`, findings).
- Recoil per second is taken as recoil stat × RPM / 700. This assumes the kick per shot is linear in the stat. The `FRecoilMultiplier` curve is not sampled.
- Fire rate from `U_RoundsPerMinute_C` in the weapon definitions: every AK 700, M4A1, MCX Virtus, CQ and Rattler 800, QBZ-97 700, SCAR-L 650, AUG 715.
- The AK runs a brake or a suppressor. The M4 stacks a suppressor on its flash hider (the Hybrid 46 mounts alone). So the AK's loud lead plus the AR's suppressed lead add up to about the AK brake value plus the AR suppressor scaled by RPM, about 18 per second with the DTK-1. A base change only sets the split.
- Full builds come from the scratchpad best-build resolver, which now prints the RPM-adjusted value too.

## Solution

Split the gap evenly at full builds: a 5.45 or 5.56 AK at 6.5 loud and 19.5 suppressed, against the M4A1's 15.4 and 10.3 per second. 7.62x39 AKs with a brake at about M4A1 level. Each AK's base is set to hit that, since the variants reach different parts.

| AK | Base | Loud | Suppressed |
|---|---|---|---|
| AK-74M | 50 -> 55 | 6.5 | 19.5 |
| AK-12 | 46 -> 53 | 6.5 | 18 |
| AK-105 | 46 -> 55 | 6.5 | 19.5 |
| AK-101 | 47 -> 54.5 | 6.5 | 19.5 |
| AK-102 | 51 -> 54.5 | 6.5 | 19.5 |
| AKS-74 | 52 -> 55 | 6.5 | 19.5 |
| AK-103 | 56 -> 63.5 | 15.5 | 28.5 |
| AK-104 | 58 -> 63.5 | 15.5 | 28.5 |

The user's average suppressed builds go from AK-105 15.5 against M4A1 17.1 per second to 24.5 against 17.1.

Files: `likhos-rearmed/stats.json`, `README.md` (and the gitignored `README.bbcode`), `CHANGELOG.md`.

## Tradeoffs and open

- The leads are about 9 per second each way at full builds. Only weaker AK brakes narrow both.
- QBZ-97, SCAR-L and AUG full builds sit far behind the M4A1 (27, 20.5 and 23 loud). The resolver reaches few recoil parts for them, which is unchecked.
- The AKS-74U (SMG class) and RPK-74 (LMG class) are left out.
