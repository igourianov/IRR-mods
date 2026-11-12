# Medical rework

## Intent

Game patch behavior: a new painkiller dose refreshes the temporary health pool and restarts its timer. Use Medical in Likho's Point and Shoot still gates every painkiller step on no dose being active, so a dose is never refreshed through the key. Likho's Rearmed rebalanced the doses for the old behavior, when a dose over an active one did nothing.

The user wants each gesture to do one predictable thing:

- **Tap** gives temporary health and nothing else. It takes a dose on every tap, whatever the health or an active dose.
- **Hold** treats conditions, then heals permanently with an IV. It never takes a painkiller.

Likho's Rearmed leaves the painkiller doses (Morphine, the MFAK's Inject, Painkiller) at their vanilla values.

## Constraints and assumptions

- Dose behavior, per the user: a new dose refreshes the pool and restarts the timer. A weaker dose over a stronger one keeps the larger pool. It matters only once the stronger pool has been damaged below the weaker dose's amount.
- Health has real health (`GetBaseValue` of the `HealthComponent`'s health attribute) and max health (`GetCurrentMaxValue`) (`docs/solutions/combat-heal.md`, Constraints). Only the hold reads them.
- Ruled out: gating the tap on health, on the temporary health left or on an active dose (user). A tap at full health or over a pool already larger than the dose wastes it. That is the player's choice.
- Among equally fast items, ranking serves inventory management, not healing (user). Two intents: a single-purpose item goes before a multi-purpose one, which frees slots and keeps the MFAK for what only it covers. Within one item type a started item goes before a fresh one, so a press finishes one item instead of taking a use from each of several. The rank is therefore fewest treatments (distinct treatment stat tags across the item's use contexts), then fewest uses left. A Bandage goes before an MFAK at any uses left, a 2/3 Alu Splint before a 3/3 one, a fresh Alu Splint before a started MFAK, and a 2/3 Alu Splint before an MFAK on its last use.
- Ruled out: an item on its last use going first across item types (user). It would spend the MFAK's last use on a fracture an Alu Splint can splint.
- Use Medical treats only what the item's use context stat tags say (`docs/solutions/combat-heal.md`). Every game name used by `combat_heal.lua` today stays. This solution adds none.
- Ruled out: the tap treating heavy bleeds, bleeds or fractures. The user chose a predictable tap over speed for conditions in a fight.
- Ruled out: the hold taking a painkiller, as a fallback or otherwise (supersedes `docs/solutions/combat-heal-hold-painkiller.md`). A hold with no condition and no usable IV does nothing.
- Ruled out, as before: telling a running IV apart, the Health Injector, steering vanilla Quick Heal.
- The Adrenaline Injector override in `stats.json` and Use Adrenaline stay as they are.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/combat_heal.lua`: the Use Medical tap and hold.
- `likhos-point-and-shoot/Scripts/config.lua`: the `tap_ms` and `combat_heal` bind comments.
- `likhos-point-and-shoot/Scripts/keymap.lua`: the `LikhosCombatHeal` display name, `Smart Heal (Tap/Hold)`. The mapping id stays, so a key players already set is kept.
- `likhos-point-and-shoot/mod.txt` (minor version), `README.md` (Smart Heal section) and `CHANGELOG.md`.
- `likhos-rearmed/stats.json`: the `ID_MFAK`, `ID_Morphine_Injector` and `ID_Painkiller` entries.
- `likhos-rearmed/README.md` and `CHANGELOG.md`.
- `tools/pak/pak.ps1`: the stats stage's per-stat branches.

Context only: `actions.lua` (tap and hold dispatch, unchanged), `input.lua`, `triggers.lua`, `menu.lua`, `lib/`, the vanilla health component and item contexts.

## Solution

### `combat_heal.lua`

Holds no state and no UObject between calls. `tap()` and `hold()` share the existing resolve, collect, pick and run path. `use_adrenaline()` keeps its behavior.

**Tap** resolves the pawn and inventory only, no health or tags. It runs one painkiller step (`Inventory.Stats.Pain Debuff`), ranked fastest first, then fewest treatments, then fewest uses left. With current items: Morphine (2 s), then the MFAK's Inject (5 s), then Painkiller (7 s). No usable candidate: nothing happens.

**Hold** runs, in order:

1. Heavy bleed (pawn has `Character.Effects.Heavy Wounded`).
2. Bleed (`Character.Effects.Wounded`).
3. Fracture (`Character.Effects.Fractured`).
4. Real health below max: the IV that best covers missing health, ranked by coverage as in `docs/solutions/combat-heal-hold-iv.md`.

Condition steps rank fastest first, then fewest treatments, then fewest uses left, the same rule as the tap. With current items: heavy bleed CAT Tourniquet (2 s), IFAK (4 s), MFAK (5 s), Compression Bandage (6 s). Bleed the same, with the Bandage (5 s) before the MFAK (5 s). Fracture Alu Splint (5 s), MFAK (5 s), Improv Splint (12 s). Fracture stays before the IV because health stays missing while an IV runs (`docs/solutions/combat-heal-hold-conditions.md`).

### `config.lua`, `mod.txt`, `README.md` and `CHANGELOG.md`

The comments and the README's Smart Heal section describe a tap that always takes the fastest painkiller carried, even over an active dose, and a hold that treats a heavy bleed, a bleed or a fracture, then starts the IV that best covers missing health. The changelog's `# Unreleased` entry says the keybind is renamed from Use Medical to Smart Heal with the saved key kept, that the tap now only takes painkillers and refreshes an active dose, and the hold now treats conditions and IVs only. `mod.txt` has the minor version bumped, since both gestures change behavior.

### `likhos-rearmed`

`stats.json` has no entry for `ID_MFAK`, `ID_Morphine_Injector` or `ID_Painkiller`. The README no longer lists the emergency and lasting dose changes or those three definitions under compatibility, and its summary line mentions adrenaline only. The changelog's `# Unreleased` entry says Morphine, the MFAK's Inject and Painkillers are back to vanilla, since the game now refreshes an active dose.

### `pak.ps1`

The stats stage sets an item stat `Value`, `BleedingChance` on the ChanceToWound effect and the stamina multipliers on the StaminaBoost effect's `Influence`. It has no PainDebuff branch. `Get-EffectProperty` stays for the stamina multipliers.

### Result

A tap injects Morphine, or the next fastest painkiller carried, refreshing an active dose. It does nothing only when no painkiller is carried or the item's context reports itself invalid. A hold stops a heavy bleed, then a bleed, splints a fracture, then starts an IV, one per hold. With the pak, the three doses show their vanilla values.

## Tradeoffs

- Tap is temporary health only over temporary health first, then conditions: one predictable result per tap, at the cost of conditions in a fight needing a hold.
- No gate on the tap: a tap always acts and needs no recon, at the cost of a dose wasted at full health or on a pool already larger than it.
- Fastest first for hold conditions over slowest first: the hold stops a heavy bleed in a fight as fast as the items allow and follows one rule with the tap, at the cost of fast items spent out of combat when a slow one would do.
- Vanilla doses over the 2.1.95 rebalance: no pak edits to keep up with across patches, at the cost of Morphine and Painkillers no longer having separate emergency and lasting roles.
