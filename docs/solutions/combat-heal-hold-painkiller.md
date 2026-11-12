# Combat Heal hold falls back to Painkillers

## Intent

Holding the Combat Heal key in Likho's Point and Shoot still starts the IV that best covers missing health. When no IV can be started, the hold takes a Painkiller instead, provided no painkiller dose is active. The hold then always does something when hurt and an item for it is carried.

## Constraints and assumptions

- Everything in `docs/solutions/combat-heal-hold-iv.md` stands except its "never falls back to the tap's steps" and "Ruled out: a hold that also treats pain" points. Per the user, 2026-11-11: the painkiller follows the IV as a fallback only. One item per hold, as before.
- The fallback uses the Painkiller item only, never Morphine or the MFAK's Inject (per the user, 2026-11-11). Those are the tap's fast doses. The item is matched by its identifier tag `Inventory.Items.Medical.Painkiller` (Recon), not by its treatment tag, since Morphine and the MFAK carry the same `Inventory.Stats.Pain Debuff`.
- The step applies when real health is below max, which the hold already requires, and no dose is active (`Character.Buffs.Medic.Painkiller` in the health attribute's `Buffs`, as for the tap).
- "No IV can be started" is what the pick already reports: no IV carried, or every IV's context reports itself invalid.
- Ruled out: queueing a Painkiller after the IV finishes.

## Scope

Owned, all in `likhos-point-and-shoot/`:

- `Scripts/combat_heal.lua`: the hold's steps and an optional item filter on a step.
- `Scripts/config.lua`: the `combat_heal` bind comment.
- `README.md` (the Combat Heal section) and `CHANGELOG.md`.

## Solution

- A collected candidate keeps its item identifier tag. A step may name an item identifier, and the pick then considers only candidates with that identifier. Steps without one pick as before.
- The hold runs the heal step, then, with no dose active, a painkiller step limited to `Inventory.Items.Medical.Painkiller`, ranked like the tap's painkiller steps. The existing run path executes the first step with a usable pick.
- The minor version stays: a tweak to an existing feature.

## Recon

From `docs/solutions/combat-heal.md` (Recon, item table):

| Item | Identifier | Use time | Treatment tag |
| --- | --- | --- | --- |
| `Painkiller` | `Inventory.Items.Medical.Painkiller` | 7 s | Pain Debuff |

## Tradeoffs

- Painkiller only over any painkiller treatment: a hold without an IV gets the lasting dose and leaves the fast Morphine and MFAK for a tap, at the cost of doing nothing when those are the only pain items carried.
- Fallback over a queued dose after the IV: one item per gesture and no tracking of a running IV, at the cost of no temporary health while an IV runs.
