# Suppressor noise and NPC hearing

Question: do suppressors reduce how far NPCs hear a shot? The in-game item view lists only recoil and ergonomics for suppressors.

Status: static recon done (2026-09-24). The real range values sit in native C++ defaults and still need a runtime read.

## Findings

- A suppressor is a binary switch. Every suppressor attachment sets `bUseSuppressedAudio = true` on its muzzle component. Flash hiders and brakes do not. No suppressor item has a loudness stat, so all suppressors behave the same.
- The weapon has two separate shot noise ranges: `ShotFiredNoiseRange_Unsuppressed` and `ShotFiredNoiseRange_Suppressed`. So the game does model a suppressed shot as a different noise, not only as a different sound.
- No blueprint overrides those two ranges. Their values are the C++ constructor defaults of `WeaponComponent`, which no asset stores. How much a suppressor shortens detection is unknown until they are read at runtime.
- NPC gunfire hearing (SenseSystem `SensorGunfire_1`) is capped at 150 m and loses 0.2 score for each occluding hit. The AIModule hearing on the AI controllers is capped at 80 m.
- Which of the two hearing systems reads `ShotFiredNoiseRange_*` is decided in native code and is not visible in assets.

## Recon

Sources: `UE4SS_ObjectDump.txt` (2026-09-22) and assets unpacked with repak from `pakchunk0-Windows.pak` and `pakchunk6-Windows.pak`, converted to JSON with UAssetGUI (`VER_UE5_6`, `Test_C.usmap`).

### Weapon side (reflected, native `/Script/Test_C`)

- `WeaponComponent:ShotFiredNoiseRange_Unsuppressed` (float)
- `WeaponComponent:ShotFiredNoiseRange_Suppressed` (float)
- `WeaponComponent:ShotFiredNoiseTag` (name)
- `WeaponComponent:IsSuppressed()` returns bool
- `WeaponComponent:OnShotFired` multicast delegate
- `MuzzleComponent:bUseSuppressedAudio` (bool)
- `WeaponDataAsset:SuppressedAudioSettings_FP/_TP`, `UnSuppressedAudioSettings_FP/_TP`
- `IRRAIDataComponent:OnShotFired` function
- `ScriptStruct IRRGunShotEvent`: `BulletID`, `Bullet`, `Instigator`, `ShotOrigin`, `WeaponClass`, `BulletCaliber`, `TimeOccurred`. No suppressed flag.

`Default__BP_WeaponComponent_C` sets no noise property. Across all 576 weapon `.uasset` files in `Blueprints/InventorySystem/Items/Weapons`, none has `ShotFiredNoise` in its name table.

### Suppressor attachments

`BP_MuzzleComponent_Suppressor` CDO: `bUseSuppressedAudio = true`, plus muzzle flash, fumes and overheat settings.

Attachments using `BP_MuzzleComponent_Suppressor`: AAC 762-SDN-6, AK-74 Steel PATRIOT, AR-15 M4SD II, AUG SL7i, DT338, KVP XL 45ACP, M700 Timberwolf, MP5 PDW, MPX Ronin 8 and 12 inch, PBS-4, QBZ-97, RS Putnik, Sig SRD762, SilencerCo Hybrid 46, Omega 45k, Osprey 45K, Salvo12, SKS OSS HX-QD, Surefire Ryder 9M TI, SOCOM338-TI, SVD Rotor43, TGP-A.

Attachments using plain `MuzzleComponent` with `Muzzle_GEN_VARIABLE.bUseSuppressedAudio = true`: Honey Badger Standard, Honey Badger Trash PANDA, Surefire SOCOM556-MONSTER. `BP_MP5SD` (integral suppressor) sets the same flag on its own muzzle.

Suppressor item stats (`ID_PBS-4_545x39_Suppressor`): `U_Weight`, `U_Ergonomics`, `U_Recoil`, `U_MuzzleVelocity`, `U_CompatibleItems`. No noise stat.

### NPC hearing

`BP_IRR_AI_BaseCharacter` `SenseReceiver` passive sensors:

| Sensor | Tag | MaxHearingDistance | Other |
|---|---|---|---|
| `SensorGunfire_1` | `Gunfire` | 15000 (150 m) | `ScoreReductionPerHit = 0.2`, `MultiTraceTest`, test `AdvancedHearingTest` with `TestMode = Gunshot` |
| `SensorFootsteps_1` | `Footsteps` | 6000 (60 m) | `MultiTraceTest` |

Sensor class `/Script/Test_C.SensorAdvancedHearing`, test class `/Script/Test_C.SensorAdvancedHearingTest`. `EAdvancedHearingTestMode`: `Footsteps`, `Gunshot`, `Generic`.

`BP_IRR_PlayerCharacter` `SenseStimulus` answers the `Gunfire` tag with a flat `Score = 1.0`.

`BP_BaseAIController` `AISenseConfig_Hearing_0.HearingRange = 8000` (80 m), consumed by `AIPerception_Hearing`.

Native-only, with no reflected property using them:

- `EIRRAIHearingStimulusType`: `Noise`, `Voice`, `Footstep`, `Gunshot`, `GunshotSuppressed`, `Explosion`, `Other`
- `IRRAISenseBlueprintFunctionLibrary:EvaluateStimulus(Owner, OutResult, SourceLocation, ListenerPosition, Loudness, Config)` with `IRRAIHearingOcclusionConfig` (`HearingThreshold`, `AttenuationPerHit`, `OcclusionChannel`, `bTraceComplex`, `bDebug`, `DebugDuration`)
- `/Script/Test_C.AISense_AdvancedHearing`
- `IRRBaseCharacter:BroadcastAINoise(Tag, Location)`, `GetAINoiseLocation(Tag)`, `AINoiseCache`
- `IRRWeatherSettings:AIHearingFactor` (weather scales AI hearing)

`DefaultGameplayTags.ini` only has a redirect `GunShotSuppressed` to `AI.Target.SoundType.GunShotSuppressed`. That tag is not in the tag list, so the old tag-based suppressed sound type is retired.

### Muzzle compatibility data model

Added 2026-09-24 for the muzzle attachment list.

- An item definition `ID_<name>` has `ItemIdentifier` (gameplay tag) and `ItemContainers`, an array of slot subobjects.
- A muzzle slot is a subobject of class `U_Muzzle_C` or a child: `U_Muzzle_556`, `_762`, `_300`, `_338`, `_57x28`, `_Handgun`, `_Shotgun`, `_AUG_A3`, `_Remington_M700`, `_MP5` (under `Objects/ItemContainers`).
- A slot's `SupportedItems` is an array of objects holding a gameplay tag container `SupportedItems`. These are either inline `InventorySupportedItems` subobjects or `UISI_*` class instances (`Objects/InventorySupportedItems`, e.g. `UISI_Muzzle_556`). An inline subobject with no override takes its tags from its archetype, the same-named subobject in the slot class CDO.
- Muzzle slots sit on weapons (AK family, RPK, SVDS, Galil, SKS, QBZ-97, Saiga, MP5, MP5K, PP-19), on barrels (every other platform) and on some muzzle devices, which makes those devices a base for a second muzzle device.
- UAssetGUI leaves 29 item packages as `RawExport`, for example `ID_Glock_19`, `ID_AK-101`, `ID_AK-12`, `ID_Honey_Badger` and `ID_FN_SCAR-H`. Their unversioned `InventorySupportedItems` data is property index 0: int32 count, then (int32 name index, int32 number) pairs into the package name map.

## Open: runtime read

1. `ShotFiredNoiseRange_Unsuppressed`, `ShotFiredNoiseRange_Suppressed` and `ShotFiredNoiseTag` on `/Script/Test_C.Default__WeaponComponent`, and on the player's live weapon component.
2. `IsSuppressed()` on the live weapon component with and without a suppressor, to confirm the muzzle flag drives it.
3. `AIHearingFactor` on the live `IRRWeatherSettings`.
