# Stock scale outliers

Follow-up to `docs/solutions/smg-balance.md` and `docs/solutions/full-caliber-rifle-balance.md`.

## Intent

A scan of attachments other than muzzle devices with recoil beyond ±5 showed stocks the mod never touched beating the rescaled aftermarket ones. Per the user, vanilla stocks beating aftermarket is not good. On the FAL, factory stocks should be worse than an AR stock on the buffer tube, and aftermarket FAL stocks better.

## Recon

- The mod's AR stock scale follows ergo ≈ 40 − 2 × recoil reduction, from the ACE (-8 / +24) to the VLTOR (-16 / +8).
- Above that line among untouched stocks: FAL Series X (-20 / +16), SKS ATI Monte Carlo (-18 / +18), FAL Folding Para (-18 / +14). The SKS SAGE SKSALCS stock (-20 / +14) belongs to the SAGE chassis, and the user said not to compare it with other stocks.
- The FAL folding buffer tube is 0 / -3 in the mod, so an AR stock on a FAL costs 3 ergonomics against the same stock on an AR.
- The SKS stock slot takes the wooden stock (-10 / +7, no slots), the ATI Monte Carlo (no slots) and the SAGE chassis (0 / 0, with AR pistol grip, foregrip and AR buffer tube slots, and the SAGE stock). The ATI is SKS-only and sits between the wooden stock and a SAGE build, so it was left.
- The AR-10 CMMG MK3 RML15 Ghillie handguard (-12 / +10) has no slots. Per the user its grip is built in, so it matches a handguard plus a top grip and was left.
- Asset paths: `/Game/Blueprints/InventorySystem/Items/Attachments/Stock/FAL_Series_X_Stock/ID_FAL_Series_X_Stock`, `/Game/Blueprints/InventorySystem/Items/Attachments/Stock/FAL_Folding_Para_Stock/ID_FAL_Folding_Para_Stock`.

## Resolver fix

The scratchpad resolver (`best-builds2.ps1`) read every attachment tag in an item's name map as a supported item. Some are `ItemRelations.ConflictingItemsQuery` tags, items that can't be fitted together with it. The AK Zenitco B-13 rail lists the SAG MK3 dust covers that way, so the resolver built a chain the game doesn't allow (SKS → EST Tula dovetail → B-13 → SAG MK3 dust cover → WASR handguard). It now drops conflict tags. Rerunning every gun moved four builds: AKS-74U, PP-19, SVDS and SKS.

## Solution

In `likhos-rearmed/stats.json`:

- FAL Series X -20 / +16 -> -16 / +8 (on the line, 3 ergonomics ahead of the VLTOR on the buffer tube). FAL Folding Para -18 / +14 -> -9 / +16 (3 behind the Ripstock on the buffer tube). FAL Standard (-11.5 / +10) and Wooden (-10.5 / +12) already trail the buffer tube options.
- FAL base recoil 80.5 -> 76.5, back to 20 loud and 43.5 suppressed.
- After the resolver fix: AKS-74U 67.5 -> 65.5 (20 / 37.5), PP-19 60 -> 57 (20 / 30), SVDS 60 -> 58 (30). The SKS moved from 18 to 23 and needed no change: the MK-47 now beats it suppressed (18 against 23).

Files: `likhos-rearmed/stats.json`, `README.md` (and the gitignored `README.bbcode`), `CHANGELOG.md`.

## Open

- The M14 Troy SASS chassis has its own AR buffer tube, pistol grip and foregrip slots, so its -14 / +8 stacked with the AR stock on it, like the SKS SAGE chassis did. The scratchpad resolver allowed one part per category and missed it. Found with `tools/gunsmith/gunsmith.ps1` and set to 0 / 0 per the user (`/Game/Blueprints/InventorySystem/Items/Attachments/Stock/M14_Troy_SASS_Chassis/ID_M14_Troy_SASS_Chassis`): the M14 went from 6.7 to 21.2 per second loud, the M305 from 7.5 to 21.5. Bases then -1 per the user, M14 74 -> 73 and M305 75 -> 74.
- The resolver leaves out required parts with no recoil and negative ergonomics (e.g. the FAL buffer tube), so best-ergo builds can run a few ergonomics high.
