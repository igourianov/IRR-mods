# Combat Heal tap and hold

## Intent

The Combat Heal key in Likho's Point and Shoot tells a tap from a hold. A tap does what a press does today, except that it never heals: it takes a painkiller or treats a heavy bleed, a bleed or a fracture, and with none of those to treat it takes a painkiller whenever health is missing. Holding the key starts an IV, the one that best covers the missing health, whatever else the player has. A 14-second IV becomes a deliberate choice, never something a quick press in a firefight falls into.

## Constraints and assumptions

- Item selection, the tap's painkiller and condition steps and every game name stay as `docs/solutions/combat-heal.md` describes them (Solution and Recon). Its heal step is not part of the tap.
- The Health Injector, the only `Inventory.Stats.Heal Instant` item, is deprecated (per the user, 2026-11-10). Ruled out: supporting instant heals. The instant heal tag is no treatment, so neither gesture uses an item that carries only it.
- The heal over time tag decides what a hold uses, not the item's name: `Inventory.Stats.Heal Over Time` items, today the Saline and Blood IVs. A new item with the tag is picked up without a code change.
- The tap window is the existing `tap_ms` config value (default 250), shared with the Flashlight key. A key released inside it is a tap, a key still down when it passes is a hold.
- The hold fires once, the moment the window passes, while the key is still down. Release after that does nothing.
- A tap fires on release, so its item starts up to one tap window later than a press did before.
- A hold does nothing when no health is missing, when no IV is carried or when the IV's context reports itself invalid. It never falls back to the tap's steps.
- A tap is a request for something to happen. With the Health Injector gone, the painkiller is the only fast item left for missing health, so the tap's last step is a painkiller at any missing health. A tap does nothing only at full health with no condition, or with a dose active and only health missing.
- Ruled out: falling back to an IV on a tap.
- Ruled out: a hold that also treats bleeds, fractures or pain first. Hold is the IV only.
- Ruled out: telling a real key release from one forced by a menu opening mid-press. A menu opened within the tap window counts as a tap and may use an item. `input.lua` and `triggers.lua` stay as they are.
- Ruled out, as before: checking for an IV still running. A hold during one starts another.
- The mapping id stays `LikhosCombatHeal`, so a key players already set on it is kept. Only its display name changes.
- Assumed, unverified, as in `docs/solutions/combat-heal.md`: an IV's context's `IsValidContext(pawn, nil, item)` and `Execute(pawn, nil, item)` work without an item widget.
- Assumed, unverified, as for the Flashlight key: the per-frame poll resolves the tap window closely enough that a deliberate tap and a deliberate hold are never confused.

## Scope

Owned, all in `likhos-point-and-shoot/`:

- `Scripts/combat_heal.lua`: the Combat Heal tap and hold entry points and the heal treatment. Use Adrenaline keeps its behavior (`docs/solutions/adrenaline-bind.md`).
- `Scripts/actions.lua`: the `CombatHeal` entry in `ACTIONS` and its per-press record.
- `Scripts/keymap.lua`: the `LikhosCombatHeal` display name.
- `Scripts/config.lua`: the `tap_ms` comment and the `combat_heal` bind comment.
- `mod.txt` (minor version), `README.md` (the Combat Heal section) and `CHANGELOG.md`.

Context only: `input.lua` and `triggers.lua` (press, held every frame and release per bind, reset on level load), `context.lua` (`block_in_ui`), the `Flashlight` action in `actions.lua` (the tap window pattern this follows), `menu.lua` (the controls row reads the display name from `keymap.lua`), `lib/util.lua`, `lib/log.lua`.

## Solution

### `combat_heal.lua`

Owns what each gesture uses. Holds no state and no UObject between calls. Exposes two Combat Heal entry points, run on the game thread by the action, plus `use_adrenaline` unchanged.

- The heal treatment is `Inventory.Stats.Heal Over Time` alone. The treatment count used to rank waste is the same as before for every supported item.
- **Tap** resolves the pawn, health, owned tags and inventory and walks the painkiller, heavy bleed, bleed and fracture steps of `docs/solutions/combat-heal.md` with the same applies-when rules and ranks, then a closing painkiller step. The closing step applies when real health is below max and no dose is active, and ranks like the first painkiller step. Below 90% the first painkiller step has already been tried, so the closing one only matters between 90% and max.
- **Hold** resolves the pawn, health and inventory and runs a single heal step, applying when real health is below max. It ranks candidates by speed, then a heal that covers all missing health over one that falls short, least overheal among covering ones and the bigger heal among short ones, then fewest uses left. With the current items: Saline (65) when it covers the missing health, otherwise Blood (85).
- Both share the existing resolve, collect, pick and run path, so both log their bind's steps at debug the same way and the pick's context is executed as before.

### `actions.lua`

`ACTIONS.CombatHeal` has press, held and release sides, following the `Flashlight` pattern of timing the gesture in `actions.lua` with `os.clock` and the shared `TAP_MS`.

- Press records the moment of the press and that nothing has fired yet. It uses nothing.
- Held, every frame while the key is down: once the tap window has passed and nothing has fired, runs the hold and marks the record fired.
- Release: when nothing has fired, runs the tap. Then clears the record.
- The record holds plain values only and is cleared by `M.reset` on level load, with the other per-hold records.

### `keymap.lua`

`LikhosCombatHeal` is displayed as `Combat Heal (Tap/Hold)`, matching the `Flashlight (Hold/Toggle)` naming.

### `config.lua`

The `tap_ms` comment describes the window for both keys: for the flashlight, a light left on or put out on release; for Combat Heal, a tap that treats or a hold that starts an IV. The `combat_heal` bind's comment names both gestures.

### `mod.txt`, `README.md` and `CHANGELOG.md`

`mod.txt` has the minor version bumped. The README's Combat Heal section names the key `Combat Heal (Tap/Hold)`, briefly lists the tap's steps with the closing painkiller at any missing health, and says that holding the key starts the IV that best covers missing health. The changelog entry, under the version of the build, says Combat Heal no longer heals or starts an IV on a press, that holding the key starts an IV and that a tap with nothing else to treat takes a painkiller at any missing health.

### Result

The player taps Combat Heal and gets the same one-thing-per-press treatment as before for pain, bleeds and fractures. With none of those, a tap takes a painkiller whenever health is missing and no dose is active. A tap never heals and never starts an IV. Holding the key for a quarter second starts the best IV for the missing health as soon as the window passes, with no need to let go. The saved key carries over, and the controls row reads `Combat Heal (Tap/Hold)`.

## Tradeoffs

- One key with a timed gesture over a second IV key: no new binding to set, at the cost of the tap's item starting up to 250 ms later than a press did.
- Hold fires at the window over on release: the IV starts without waiting for the player to let go, at the cost of a long tap meant as a tap starting an IV.
- Hold is the IV only over the full step list with an IV heal: one predictable result for the hold, at the cost of starting an IV while bleeding if the player holds instead of tapping.
- No IV fallback on a tap: a tap never commits the player to 14 seconds, at the cost of a tap doing nothing for missing health while a dose is active.
- Closing painkiller at any missing health over doing nothing above 90%: a tap always acts when hurt, at the cost of painkiller uses spent on scratches and a dose taken above 90% blocking a fresh one after a heavy hit until it ends.
- Shared `tap_ms` over a Combat Heal window of its own: one setting for every tap/hold key, at the cost of not tuning them apart.
- Menu-forced release counted as a tap: `input.lua` and `triggers.lua` stay untouched, at the cost of a possible item use when a menu opens within the tap window of a press.
