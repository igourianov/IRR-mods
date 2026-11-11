# Painkiller and morphine balance

## Intent

In Likho's Rearmed, morphine is the emergency dose in combat: a large temporary health buff for a short time. Painkillers keep health up over time while slow regeneration does its work.

- Morphine and the MFAK's Inject: +60 temporary health for 60 s. The MFAK's Inject is the same injector taken from the bag. Its longer animation (4 to 5 s against 2 s) stays as the kit's cost.
- Painkillers: +20 temporary health for 300 s.

A dose over an active one must apply. A lasting pill dose that blocks morphine for up to 5 minutes defeats the design.

## Constraints and assumptions

- Seen in game by the user before patch 26596277: a dose over an active one did nothing until the active one expired, even with its temporary health used up.
- Game patch 26596277 (2026-11-11) lets morphine override painkillers (user, from the patch). In its assets `ID_Morphine_Injector` and `ID_Painkiller` set `StackingBehaviour = Replace` on their effects. `ID_MFAK` doesn't and inherits the class default `ReInit`.
- Seen in game by the user on 26596277 without the pak: the MFAK's Inject over active pills replaces their dose, and morphine over an active MFAK Inject refreshes the dose to +50, although the MFAK's effect inherits `ReInit`. A dose replaces the active one whatever either effect's `StackingBehaviour` is, so the pak sets no stacking. `SGE_Attribute_Buff_C` still has no `K2_Replace`, so whatever changed is native.
- Unverified: pills taken over active morphine replace it, cutting 60 down to 20. Accepted as the cost of replacing both ways.
- The in-game label follows the effect: `U_PainDebuff_C.GetStatValueText` casts `StatEffect` to `SGE_Attribute_Buff` and formats `Data` and `DurationMagnitude`. The ItemStats `Value` (Painkiller 160, others -1) isn't the dose.
- Combat Heal (`likhos-point-and-shoot`) ranks painkiller items by use speed and checks `Character.Buffs.Medic.Painkiller` for an active dose. Neither changes.

## Solution

- `stats.json`: `BaseValue` and `DurationMagnitude` per item, set on the effect under the item's `U_PainDebuff_C` stat. Morphine and the MFAK 60 and 60, Painkiller `DurationMagnitude` 300 (its `BaseValue` is already 20).
- `pak.ps1` stats stage: `BaseValue` sets `Data.BaseValue`, `DurationMagnitude` the effect's own float, both on the `PainDebuff` stat's effect. Morphine and the MFAK inherit `Data` from the template, so the template's struct is copied in first. That copy, used by the stamina `Influence` already, is now `Get-EffectProperty`.
- `effects.json` unchanged: the template's `GrantedGameplayTags` stays for the MFAK, which still grants no Painkiller tag on its own.
- `mod.txt` `game_build` 26596277, README and changelog.

## Recon

Cooked assets of game build 26596277 read with repak and UAssetGUI (usmap `Test_C-5.6.1-0+UE5-4fb9b615`, dumped 2026-11-11).

- Items using `U_PainDebuff_C`: `ID_Morphine_Injector`, `ID_MFAK` and `ID_Painkiller` only (IFAK, Health Injector, Revive Syringe, Saline IV, Blood IV and Bandage checked on build 26487830).
- `U_PainDebuff` template `SGE_Attribute_Buff_C_0`: `Attribute = Character.Attributes.Health`, `Buff = Character.Buffs.Medic.Painkiller`, `Data.BaseValue = 50`, `DurationMagnitude = 120`.
- `ID_Morphine_Injector`: `DurationMagnitude = 180`, `GrantedGameplayTags = [Character.Effects.Painkiller]`, `StackingBehaviour = Replace`. The last two are new in 26596277.
- `ID_Painkiller`: `Data.BaseValue = 20`, `DurationMagnitude = 100`, `GrantedGameplayTags = [Character.Effects.Painkiller]`, `StackingBehaviour = Replace` (new in 26596277).
- `ID_MFAK`: `DurationMagnitude = 380` only.
- `Default__SGE_Attribute_Buff_C`: `Data` is `SimpleAttributeData` (`BaseValue`, `MinValue`, `MaxValue`, all 0), `DurationMagnitude = 60`, `StackingBehaviour = ReInit`. Functions: `K2_Activate`, `K2_Finish`, `K2_ReInit`.
- `UGameplayAbilityComponent` (`CXXHeaderDump`) has `TryStopGameplayEffectByRef`, `TryStopGameplayEffectByClass` and `StopGameplayEffect`.

## Result

The pak stage logs `ID_MFAK` and `ID_Morphine_Injector` `BaseValue 50 -> 60`, `DurationMagnitude` 380 and 180 -> 60, `ID_Painkiller` `DurationMagnitude 100 -> 300`.

To check in game: the item labels and the new values after a dose replaces another, pills over active morphine.
