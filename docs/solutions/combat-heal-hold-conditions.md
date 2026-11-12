# Combat Heal hold treats conditions

## Intent

Combat Heal's tap and hold serve two situations (user decision, 2026-11-11):

- Tap is for getting health back in the middle of a fight. Health comes before conditions and speed matters most. Above 90% health the missing health is a scratch and matters less than a bleed or fracture, so conditions go first there.
- Hold is for healing out of combat, with the focus on lasting recovery.

Before this change a hold only started an IV, or took Painkillers without one, and did nothing at full health. With it a hold also treats conditions, one item per press like the tap:

1. Heavy bleed.
2. Bleed.
3. Fracture.
4. Any health missing: the IV that best covers it.
5. No usable IV and no painkiller dose active: Painkillers.

## Constraints and assumptions

- Every game name comes from `docs/solutions/combat-heal.md` (Recon). This change adds none.
- Fracture goes before the IV (user decision). Health stays missing while an IV heals, so with fracture after the IV every hold would start another IV or take Painkillers, and the fracture would come up only once both were used. Ruled out: keeping fracture after health and skipping the IV step while one heals, as no way to detect a running IV is known.
- A condition step picks the slowest item first, then the fewest uses left (user decision). The tap ranks fastest first, so the slow items are the ones to spend out of combat.
- Every IV has a 14 s use time (user), so the IV step's speed rank never decides between IVs and coverage does.
- A heavy bleed removes a bleed when applied, and no item treats more than one condition (user). The fewest treatments part of the rank, kept from the tap's ranking, never changes a hold pick.

## Solution

`combat_heal.lua`:

- `pick` takes a `slowest` flag on the step, which ranks use time slowest first.
- `resolve_condition` resolves the health attribute and the owned tags for both tap and hold.
- `hold()` builds a condition step for each owned condition tag in `CONDITIONS` order with `slowest` set, then, when health is missing, the IV step and the Painkillers step as before.

`README.md`, `config.lua` comments and `CHANGELOG.md` describe the tap and hold intent and the hold order.

## Result

A hold with a bleed treats the bleed with the slowest bandage carried. A hold at full health with a fracture treats the fracture. A hold with no condition and health missing starts the IV as before. The tap is unchanged.
