# Magnifier zoom under NVG

## Intent

With NVG on, the zoom input folds the magnifier as well as unfolds it, the same as the vanilla Toggle Magnifier key. Aiming is not involved: the player flips the magnifier without aiming through it.

Before this fix, under NVG scroll forward unfolded the magnifier, but scroll back never folded it. The vanilla key worked both ways.

## Cause

The 2026-11-04 game update bans aiming through a magnified optic under NVG (per the user). The trace from 2026-11-07 in the hideout, on an AKS-74U with the EOTech HHS-1, shows the effect on zoom:

- Once the HHS-1 is unfolded, `WeaponComponent:GetCurrentSightComponent()` returns the weapon's point sight, `BP_PointSight` (`BP_SightComponent_C`, `SightModeKey` `point aim`), not `BP_HybridSightComponent`. Every wheel notch then calls `TrySwitchMagnificationLevel` on `BP_PointSight`.
- `BP_PointSight` has no `Folded` mode, so `magnifier.lua` (docs/solutions/magnifier-zoom.md) took the notch for one on a sight without a magnifier and did nothing.
- While folded, the HHS-1 stays the current sight, so the unfold path kept working.

Names from `UE4SS_ObjectDump.txt` (2026-11-06):

- `WeaponComponent:LocSightComponents`: array of objects, the weapon's sight components.
- `WeaponComponent:LocPointSightComponent`: object, separate from `LocSightComponents`. `LocSightIndex` (int) and `bIsPointSight` (bool) sit next to them.

## Solution

`magnifier.lua`: when a notch at the end stop lands on the current sight and that sight has no `Folded` mode, the magnifier is looked up in the equipped weapon's `LocSightComponents`, the first entry with a `Folded` mode. The fold state, the pending flip and the injected `IA_ToggleMagnifier` press then use that sight. The direction and the end stop still come from the called sight.

The current sight check now applies to the called sight, since the magnifier is no longer the current sight under NVG.

## Tradeoffs

- No NVG check: the redirect applies whenever the wheel lands on a sight without a magnifier on a weapon that has one. In point aim mode without NVG, the wheel now folds and unfolds the main optic's magnifier too, the same as the vanilla Toggle Magnifier key. It needs no NVG game names.
- First magnifier in `LocSightComponents` over the one at `LocSightIndex`: the index's base and meaning are unverified. A weapon with two magnifier sights is not expected.

## Verification

Verified 2026-11-07 in the hideout, on the AKS-74U with the HHS-1, NVG on, confirmed by the user in game:

- With the HHS-1 unfolded, scroll back landed on `BP_PointSight`, was redirected to `BP_HybridSightComponent` in `Default` and flipped it to `Folded`. Scroll forward on the folded HHS-1 flipped it to `Default`, as before.
- `WeaponComponent.bIsPointSight` read `false` throughout, including while the game forced the point sight under NVG. The forced point sight doesn't set the player's point aim mode.
