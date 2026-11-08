# Adrenaline injector stamina boost

## Intent

Raise the adrenaline injector's stamina boost, shown in game as "Stamina boost 10%", to 50% through the Likho's Rearmed pak. Only the injector changes. Food and drinks that carry the same stat keep their vanilla values.

## Recon

Read from the game's cooked assets with repak and UAssetGUI (usmap of game build 26487830).

* Item definition: `/Game/Blueprints/InventorySystem/Items/Medical/Adrenaline_Injector/ID_Adrenaline_Injector` (`pakchunk6-Windows.pak`). Its `ItemStats` entries reference `U_Weight_C_0`, `U_Content_C_0`, `U_UsageTime_C_0` and `U_StaminaBoost_C_0`. The `StaminaBoost` entry holds `StatModifyType = None`, `Value = -1`, so the boost isn't an `ItemStats` value.
* `U_StaminaBoost_C_0.StatEffect` points at `SGE_Stamina_Influence_C_0` (class `SGE_Stamina_Influence_C`, `/Game/Blueprints/SimpleGameplayAbilitySystem/Effects/SGE_Stamina_Influence`, `pakchunk0`). In the injector it sets only `DurationMagnitude = 180`. Its template is `Default__U_StaminaBoost_C.SGE_Stamina_Influence_C_0` in `/Game/Blueprints/InventorySystem/Objects/Stats/U_StaminaBoost` (`pakchunk6`), so every other value is inherited from there.
* That template sets `Stamina Identifier = Character.Attributes.Stamina.Body`, `Influence` (struct `IRRStaminaInfluence`) with `Tag = Character.Attributes.Stamina.Influences.Digesting`, `DrainMultiplier = 0.9`, `RecoverMultiplier = 1.1`, then `DigestTime = 10`, `DurationMagnitude = 120`.
* `SGE_Stamina_Influence_C`'s class default: `Influence.Value = 1`, `DrainMultiplier = 1`, `RecoverMultiplier = 1`, the three `bUse...Multiplier` flags false, `DigestTime = 15`, `Duration = Duration`, `DurationMagnitude = 60`, `TickInterval = 10`, `StackingBehaviour = Replace`.
* `U_StaminaBoost_C.GetStatValueText` builds the label with a subtract and a multiply. Which multiplier it reads wasn't decoded. Both give 10% in vanilla.
* Of the 840 item definitions (`ID_*` under `InventorySystem/Items`), 17 reference `U_StaminaBoost`: the injector and 16 food and drink items under `Items/Provisions`. Every food and drink effect has `Default__SGE_Stamina_Influence_C` as its template and sets its own `Stamina Identifier`, `Influence`, `DigestTime` and `DurationMagnitude`. Recover ranges from 0.98 to 1.1, drain is 2 minus recover. Only the injector inherits from the `U_StaminaBoost` template.

## Solution

The injector's own effect object gets an `Influence` override with `RecoverMultiplier = 1.5` and `DrainMultiplier = 0.5`. Editing the `U_StaminaBoost` template would also reach the injector, and no scanned item definition would change, but it can't rule out other objects built from that template, so the override stays inside `ID_Adrenaline_Injector`.

`stats.json` takes two keys, `RecoverMultiplier` and `DrainMultiplier`, handled in the stats stage like `BleedingChance`: the stage follows the `StaminaBoost` stat's `StatEffect` to the effect object. When the effect has no `Influence` of its own, the stage reads the effect's template package, copies the template's `Influence` into the effect, then sets the two floats. A struct override replaces the whole inherited struct, so a struct built from scratch would lose the tag.

* Property order doesn't matter: the struct placed before or after `DurationMagnitude` produced identical bytes, so UAssetAPI writes unversioned properties in schema order.
* Property names don't need name map entries, since `U_StaminaBoost`'s own name map lacks `Tag`, `TagName` and `DrainMultiplier`. FName values do, so the copied struct's name values (the tag) are added to the injector's name map.

## Result

The built pak's `ID_Adrenaline_Injector` parses with `Influence.Tag = Character.Attributes.Stamina.Influences.Digesting`, `DrainMultiplier = 0.5`, `RecoverMultiplier = 1.5`, `DurationMagnitude = 180`.

Verified in game: the injector's label reads 50%, and stamina recovers faster and drains slower while the effect is active.
