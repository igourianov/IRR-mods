# Painkiller fracture mask

## Intent

In Likho's Rearmed, morphine and the MFAK's Inject hide a fracture's screen distortion, as the Painkiller item already does. All three are painkillers: they apply the game's Painkiller buff.

## Constraints and assumptions

- Every painkiller's buff is an `SGE_Attribute_Buff_C` instanced under the item's `U_PainDebuff_C` stat. Only the Painkiller item sets `GrantedGameplayTags`. Every value an item doesn't set comes from its template: the effect under the `U_PainDebuff_C` class default object, in `/Game/Blueprints/InventorySystem/Objects/Stats/U_PainDebuff` (see Recon). One edit of that template therefore reaches all three items, and an item that sets a value keeps its own.
- `SGE_Fractured_C` lists `Character.Effects.Painkiller` in `MaskingTags`, and the Painkiller item's buff grants that tag. The mask hides only the fracture's screen distortion; the fracture effect and its icon stay (seen in game by the user). With the tag granted by the template, morphine and the MFAK's Inject hide it too (seen in game by the user, 2026-11-09).
- Assumed, unverified: `Character.Effects.Painkiller` does nothing else that would change morphine or the MFAK's Inject beyond the fracture mask. The tag already comes with every Painkiller item dose.
- The template effect doesn't set `GrantedGameplayTags`, so the edit adds it to its unversioned export. UAssetAPI writes unversioned properties in schema order, so an added property lands in place, and the names it uses must be in the asset's name map. `pak.ps1`'s stats stage already adds an inherited `Influence` this way.
- Ruled out: making a stronger dose replace a weaker active one with the game's `Replace` stacking on the template. The live effect took `Replace`, but morphine taken over an active Painkiller item dose still left the pills' 20 temporary health (seen in game 2026-11-09). `SGE_Attribute_Buff_C` has no `K2_Replace`, and the native replace alone keeps the active dose. The template keeps the game's `ReInit`.
- Ruled out: a stamina-style merge that keeps the strongest dose. `SGE_Attribute_Buff_C` would need a new `K2_Replace` in Blueprint bytecode, a kind of edit this pak has never made and the most fragile across game patches. A stronger dose replacing a weaker one belongs to a Lua mod and its own solution.
- The painkillers bind (`docs/solutions/painkillers-bind.md`) is outside this solution.

## Scope

Owned, all in `likhos-rearmed/`:

- `effects.json` (new): the stat config effect templates the pak edits and their values.
- `pak.ps1`: an effects stage.
- `README.md` and `CHANGELOG.md`.

Context only: `build.ps1` (packs the staged tree), the game's `U_PainDebuff`, `SGE_Attribute_Buff` and `SGE_Fractured` assets.

## Solution

### `effects.json`

Keyed by the stat config asset's package path, each entry lists property values for the effect under that stat class's default object, the template every item's effect of that stat inherits from:

- `/Game/Blueprints/InventorySystem/Objects/Stats/U_PainDebuff`: `GrantedGameplayTags` `Character.Effects.Painkiller`.

### `pak.ps1` effects stage

Extracts every asset listed in `effects.json`, finds the effect its stat config's default object points at through `StatEffect`, and sets each listed property on it, adding the property when the effect doesn't set it yet and the names it needs to the name map. A value of the form `Enum::Member` sets an enum property, an array of strings a gameplay tag container. The stage follows the stats stage: the same asset reading and saving, the same error on anything it can't find, one log line per value set. It runs after the stats stage and fails when an asset is also listed in another stage's JSON, since both stages start from the game's copy. The synopsis lists the stage.

### `README.md` and `CHANGELOG.md`

The README has a painkiller entry in the style of its other changes: morphine and the MFAK's Inject hide the fracture screen distortion like painkillers do, and the fracture itself stays until splinted. Its compatibility list names `U_PainDebuff`. The changelog has the entry under the version of the build, with the minor version bumped for the new feature.

### Result

With the pak installed, fractured, then morphine or the MFAK's Inject: the fracture's screen distortion goes away for the dose's duration, as with the Painkiller item. The fracture and its icon stay until splinted. A second dose over an active one behaves as in vanilla.

## Recon

Sources: cooked assets read with repak and UAssetGUI (usmap `Test_C-5.6.1-0+UE5-4fb9b615`, 2026-11-08) and `CXXHeaderDump` of 2026-11-06.

### Templates

- `U_PainDebuff` exports `Default__U_PainDebuff_C`, whose `StatEffect` is its subobject `SGE_Attribute_Buff_C_0`: `Attribute = Character.Attributes.Health`, `Buff = Character.Buffs.Medic.Painkiller`, `Data.BaseValue = 50`, `DurationMagnitude = 120`. It sets no `StackingBehaviour` or `GrantedGameplayTags`.
- Item effects under their `U_PainDebuff_C_*` stat: `ID_Morphine_Injector` sets `DurationMagnitude = 180`. `ID_MFAK` sets `DurationMagnitude = 380`. `ID_Painkiller` sets `Data.BaseValue = 20`, `DurationMagnitude = 100`, `GrantedGameplayTags = [Character.Effects.Painkiller]`. In game the morphine gives 50, the template's value.
- UAssetGUI JSON for the added property, as `ID_Painkiller` has it: a `StructPropertyData` with `StructType = GameplayTagContainer` holding one `GameplayTagContainerPropertyData` whose `Value` is the tag names. An enum property, as `SGE_Stamina_Influence_C`'s `StackingBehaviour`: `EnumPropertyData` with `EnumType`, `InnerType = ByteProperty` and the member name as `Value`. UAssetGUI reads `$type` only as an object's first key.

### Effects

- `/Game/Blueprints/SimpleGameplayAbilitySystem/Effects/SGE_Attribute_Buff.SGE_Attribute_Buff_C` class default: `StackingBehaviour = ReInit`. Its graph: `K2_Activate` builds an `FSimpleAttributeBuff` from `Buff` and `Data` and calls `AddAttributeBuff(Instigator, Attribute, buff, true)`. `K2_Finish` calls `RemoveAttributeBuff` the same way. `K2_ReInit` does nothing. No `K2_Replace`.
- `SGE_Stamina_Influence_C` class default: `StackingBehaviour = Replace`. `K2_Replace(NewEffect)` sets its own `Influence.Value` and `RecoverMultiplier` to the maximum and `DrainMultiplier` to the minimum of the two, then re-adds the influence.
- `SGE_Fractured_C` class default: `MaskingTags = [Character.Effects.Painkiller]`.
- `ESimpleGameplayEffectStackingBehaviour`: `SingleInstance = 0`, `ReInit = 1`, `Replace = 2`, `Ignore = 3`.
- In game, 2026-11-09, with the template at `Replace`: the pawn's `GameplayAbilityComponent.ActiveEffects` held one `SGE_Attribute_Buff_C` with `StackingBehaviour = 2`, `GrantedGameplayTags = [Character.Effects.Painkiller]` and `DurationMagnitude = 100` after a Painkiller item and then morphine.

## Tradeoffs

- Editing the stat config's template over each item's effect: one edit covers all three items and any new item using the stat, at the cost of every Pain Debuff effect taking the change, including ones added by a game patch.
- A generic effects stage over a one-off edit: the next effect template tweak is a line in `effects.json`, at the cost of a stage for a single entry today.
