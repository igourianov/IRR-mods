# LAMG muzzle fix

## Intent

Vanilla bug: the KAC QDC 3-Prong Eliminator's own muzzle slot takes the whole 5.56 muzzle list, so the LAMG stacks the QDC, a flash hider and a suppressor. No KAC suppressor exists in the game files (no item definition, blueprint or mesh), so the list most likely stands in for one so the LAMG can be suppressed. Per the user:

- The LAMG takes the 5.56 muzzle devices directly, plus the QDC.
- The QDC takes nothing: the Hybrid 46 threads onto a bare muzzle only.
- Other 5.56 guns don't need the QDC, which keeps the shared list untouched.
- No hardcoded copies of game lists, so a game patch that changes a list still reaches the result.
- Documented as a fix.

## Recon

Found with `tools/gunsmith/gunsmith.ps1` (`docs/solutions/gunsmith.md` for the slot layout):

- `ID_KAC_LAMG` export `U_Muzzle_C_0` (class `U_Muzzle_C`): `SupportedItems` references an `InventorySupportedItems` export whose tag container holds only `Inventory.Items.Attachments.Muzzle.KAC QDC 3-Prong Eliminator 556x45 Muzzle Device`.
- `ID_KAC_QDC_3-Prong_Eliminator_556x45_Muzzle_Device` export `U_Muzzle_C_0`: `SupportedItems` references a `UISI_Muzzle_556_C` instance with no data, so it takes the class's list from `Default__UISI_Muzzle_556_C.SupportedItems` in `/Game/Blueprints/InventorySystem/Objects/InventorySupportedItems/General/Muzzle/UISI_Muzzle_556`: Hybrid 46, SCAR-L AAC SD 51T, Gate-LOK, SD3P-556 and Colt A2.
- A slot's `SupportedItems` is an `ArrayPropertyData` of `ObjectPropertyData` references. A tag list is a `StructPropertyData` (`GameplayTagContainer`) named `SupportedItems` holding a `GameplayTagContainerPropertyData` of FNames.

## Solution

- New `tools/pak/pak.ps1` stage and edit list `supported.json`: asset → export → edit. The export is a slot or a list class's default object.
  - `unlink`: list class names whose references the slot drops, e.g. `UISI_Muzzle_556`. Not combined with tag edits.
  - Tag edits: start from the supported-items object's current tags or `from` another list class's (read from the game's copy), then `keep` and `remove` (wildcards) and `add`. For a slot, its single supported-items object is edited. An object with no `SupportedItems` gets its class default object's property copied in first. An edit that leaves no tags is refused; `unlink` empties a slot.
  - An asset also in `stats.json` is edited in the stats stage, one also in `retarget.json` gets its retarget in this stage, since every stage writes the same staged file.
- `likhos-rearmed/supported.json`:
  - LAMG `U_Muzzle_C_0`: `from` `UISI_Muzzle_556`, `add` the QDC.
  - QDC `U_Muzzle_C_0`: `unlink` `UISI_Muzzle_556`.
- `tools/gunsmith/gunsmith.ps1` applies `supported.json` the same way. Its index now records each slot's export name.

Checked by staging into the scratchpad and reading back: QDC slot `SupportedItems` an empty array, LAMG slot [the five 5.56 devices, QDC]. Gunsmith: LAMG 3.7 per second loud (Gate-LOK), 7 suppressed (Gate-LOK + M4SD II), best ergo 72.8. Vanilla with the bug: 1.2 and -6.6.

Files: `tools/pak/pak.ps1`, `tools/gunsmith/gunsmith.ps1`, `tools/gunsmith/gunsmith.json`, `likhos-rearmed/supported.json`, `README.md` (and the gitignored `README.bbcode`), `CHANGELOG.md`, `CLAUDE.md`.

## Tradeoffs and open

- The LAMG's list is built at pak build time from the game's 5.56 list, so a game patch to that list needs a rebuild of the pak, as every other edit does.
- The QDC is now a plain muzzle device (-2 / +2), weaker than the Gate-LOK (-4 / +5) on the LAMG.
- Afterwards, per the user, LMGs recoil less than the rifle they're built on and handle worse: about 3 to 4 per second below it loud and suppressed, 12 to 18 ergonomics below. LAMG base recoil 38 -> 48 (11.9 / 15.2 per second against the M4A1's 15.4 / 20, ergonomics 57.8 to 72.8 against 70.8 to 91.3). RPK-74 base recoil 56 -> 53 and ergonomics 41 -> 36 (7.3 / 22.3 against the AK-74M's 9.5 / 27, ergonomics 52.8 to 63.8 against 64.8 to 81.8).
- Untested in game: the empty slot and the LAMG's longer list. Check the gunsmith screen after the next build.
