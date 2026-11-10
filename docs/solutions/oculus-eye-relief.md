# Oculus eye relief

## Intent

Likho's Oculus (`likhos-oculus`) was to set every magnified, non-thermal scope's eye relief to its real optic's published eye relief. Per the user: a range takes its middle value, and every value rounds to the nearest 0.5 cm.

## Outcome

Abandoned on 2026-11-09 and reverted, per the user, as too complicated. The eye relief itself looked right in game. But moving the camera mistunes the effects the lens glass fakes, the scope tube interior and the shadow ring, and every scope then needs its lens values retuned by eye.

Nothing of it ships. `sights.json`, the `sights` stage of `tools/pak/pak.ps1`, the lens values in `materials.json` and the temporary `likhos-lens-probe` mod are deleted. Likho's Oculus stays at its aberration and tint changes. The findings below are kept for a revisit.

## Sight data

All names come from the CXXHeaderDump and from cooked assets read with UAssetGUI and the game's usmap (`Test_C-5.6.1-0+UE5-4fb9b615.usmap`), game build 26487830.

* `FSightData` (`/Script/Test_C`, a `FTableRowBase`) holds a sight mode: `SightSocket`, `bIsScope`, `ScopeMaterialParameterCollection`, `ScopeWorldLocationParameterName`, `ScopeScreenLocationParameterName`, `ScopeForwardParameterName`, `ScopeRadiusParameterName`, `ScopeRotationParameterName`, `ScopeRadiusMargin`, `ScopeRadiusTransitionGraph`, `MagnificationLevels`, `DefaultLevelIndex`, `FixedDistance`, `HandsFOV`, `MinimumDistance`, `CameraIndependentFOV`, `CameraAffectedFOVPercentage`, `HandsZoomIn`, `SightingRange`, `TransitionMultiplier`, `SensitivityMultiplier`, `GlobalMaterialParameters`.
* `USightComponent` holds `SightModes` (`TMap<FName, FSightData>`), `LocalMaterialParameters`, `CameraBlendables`, `SightTransform`, `MagnificationIndex`, `SightModeKey`, and the functions `GetSightData`, `SetSightMode`, `TryCycleSightMode`, `TrySwitchMagnificationLevel`, `GetTargetFOV`.
* A sight blueprint exports each sight component's template as `<Component>_GEN_VARIABLE`, with its `SightModes`. The component is `BP_Scope`, `BP_SightComponent` or, on the HHS-1, `BP_HybridSightComponent`.
* The Elcan SpecterDR 1x-4x has a second component, `BP_IronSight`, whose `SightModes` also has a `default` key. The HHS-1's `BP_HybridSightComponent` has `default` (3x, magnifier up) and `folded` (1x), both at 16. Its class default object also holds `SightData_Folded` and `SightData_UnFolded` at 10, outside `SightModes`.
* `FixedDistance` is in cm and is the eye relief, measured from the sight socket. Whether the socket sits at the eyepiece is unknown.
* `USightComponent.LocalMaterialParameters` is set only on the ACOG 6x48, for `Lens` `FadeMaxOpacity`.

Magnified non-thermal sight modes, with game values, real eye relief and the values tried:

| Blueprint | Component | Magnification | FixedDistance | Real eye relief | Source | Tried |
|---|---|---|---|---|---|---|
| `Rail/AUG_A3_M1_1x5_Optic_Sight/BP_AUG_A3_M1_1x5_Optic_Sight` | `BP_SightComponent` | 1.5 | 10 | 70 mm | Steyr AUG A3 optic manual | 7 |
| `Sight/Elcan_SpecterDR_15x_6x_Scope/BP_Elcan_SpecterDR_15x_6x_Scope` | `BP_SightComponent` | 1.5/6 | 12 | 70 mm | Elcan spec sheet | 7 |
| `Sight/Elcan_SpecterDR_1x-4x_Scope/BP_Elcan_SpecterDR_1x-4x_Scope` | `BP_SightComponent` | 1.1/4 | 12 | 70 mm | Elcan catalog 2019 | 7 |
| `Sight/EOTECH_HHS-1_Hybrid_Sight/BP_EOTECH_HHS-1_Hybrid_Sight` | `BP_HybridSightComponent` | 3 | 16 | 55.9 mm (G33) | EOTech G33 listings | 5.5 |
| `Sight/EOTECH_Vudu_1-6x_Scope/BP_EOTECH_Vudu_1-6x_Scope` | `BP_SightComponent` | 1.5/3/6 | 6 | 82 to 100 mm | EOTech Vudu listings | 9 |
| `Sight/Hensoldt_Wetzlar_Fero-Z_4x24_Scope/BP_Hensoldt_Wetzlar_Fero-Z_4x24_Scope` | `BP_Scope` | 4 | 8 | ~60 mm | Hensoldt 1985 manual scan (a blog says 75 mm) | 6 |
| `Sight/Leupold_HAMR_4x24_Hybrid_Scope/BP_Leupold_HAMR_4x24_Hybrid_Scope` | `BP_SightComponent` | 4 | 10 | 69 mm | Leupold listings | 7 |
| `Sight/Nightforce_ATACR_4-16x42_Scope/BP_Nightforce_ATACR_4-16x42_Scope` | `BP_SightComponent` | 4/8/16 | 12 | 85 to 90 mm | Nightforce spec sheet | 9 |
| `Sight/PSO-1_4x24_Scope/BP_PSO-1_4x24_Scope` | `BP_Scope` | 4 | 8 | 68 mm | POSP manual | 7 |
| `Sight/QBZ-97_Y-MA-95-1-600_3x_Scope/BP_QBZ-97_Y-MA-95-1-600_3x_Scope` | `BP_Scope` | 3 | 8 | 50 mm (YMA95-1-600) | Chinese spec table (gearkr.com) | 5 |
| `Sight/Schmidt_and_Bender_1-8x24_PM_II_ShortDot_Scope/BP_Schmidt_and_Bender_1-8x24_PM_II_ShortDot_Scope` | `BP_SightComponent` | 1.1 to 8 | 12 | 90 mm | S&B datasheet | 9 |
| `Sight/SIG_Sauer_BRAVO4_4x30_Scope/BP_SIG_Sauer_BRAVO4_4x30_Scope` | `BP_SightComponent` | 4 | 12 | 55 mm | SIG owner's manual | 5.5 |
| `Sight/Trijicon_ACOG_4x24_Scope/BP_Trijicon_ACOG_4x24_Scope` | `BP_Scope` | 4 | 8 | no real 4x24. 4x32: 38 mm | Trijicon listings | 4 |
| `Sight/Trijicon_ACOG_6x48_Scope/BP_Trijicon_ACOG_6x48_Scope` | `BP_Scope` | 6 | 10 | 69 mm | Trijicon listings | 7 |

Paths are under `/Game/Blueprints/InventorySystem/Items/Attachments/`. Every mode is `default`.

## What draws the view through a scope

The view is plain geometry plus effects faked in the lens glass. Real optics don't carry over: a closer camera sees more of the scope, where a real eye at the right eye relief sees a full image.

### Lens glass

The lens glass mesh's material, an instance of `/Game/Environment/Materials/Scope/M_Scope_NEW`, draws the reticle and fakes two effects inside the lens. The cook strips its graph and defaults.

* **Tube interior**: `FrontGradientRadius`, with `FrontGradientDensity`, `FrontGradientOffset` and `FrontGradientSize`. A higher radius hides more of the tube.
* **Shadow ring** that moves with the eye: `RenderRadiusSens` sizes it, higher shrinking it. `RenderRadiusSize`, `RenderRadiusDensity`, `RenderRadiusShadow`, `RenderPositionSens`, `RenderPosition_X` and `RenderPosition_Y` belong to it too.

A scope blueprint overrides its glass mesh's material slot with a `*_Glass` instance. The QBZ-97 and ACOG 6x48 use the mesh's own slot, which holds the same `*_Glass` instance. The AUG's lens instance is `MI_AUG_A3_M1_Reticle_NEW_Inst`. At runtime the game runs every slot as its own `MaterialInstanceDynamic` (`MID_<instance>_<n>`).

Vanilla lens values (empty: the instance keeps the master's default, read in game where noted):

| Lens instance | RenderRadiusSize | RenderRadiusSens | RenderRadiusDensity | RenderPositionSens | RenderRadiusShadow | FrontGradientRadius |
|---|---|---|---|---|---|---|
| `Rail/AUG_A3_M1_1x5_Optic_Sight/Material/MI_AUG_A3_M1_Reticle_NEW_Inst` | 1 | 19 | 8 | 0.1 | 1.8 | 0.11 |
| `Sight/Elcan_SpecterDR_15x_6x_Scope/Material/MI_Elcan_SpecterDR_15x_6x_Scope_Glass` | 1 | 24 | 6 | 0.15 | | 0.15 |
| `Sight/Elcan_SpecterDR_1x-4x_Scope/Material/MI_Elcan_SpecterDR_1x-4x_Scope_Glass` | 1 | 24 | 8 | 0.15 | | 0.125 |
| `Sight/EOTECH_HHS-1_Hybrid_Sight/Material/MI_EOTECH_HHS-1_Hybrid_Sight_Glass` | 1 | 22 | 12 | | | 0.09 |
| `Sight/EOTECH_Vudu_1-6x_Scope/Material/MI_EOTECH_Vudu_1-6x_Scope_Glass` | 0.9 | (18 in game) | 8 | 0.2 | (1.8 in game) | 0.18 |
| `Sight/Hensoldt_Wetzlar_Fero-Z_4x24_Scope/Material/MI_Hensoldt_Wetzlar_Fero-Z_4x24_Scope_Glass` | 1 | 20 | 6 | 0.15 | | 0.15 |
| `Sight/Leupold_HAMR_4x24_Hybrid_Scope/Materials/MI_Leupold_HAMR_4x24_Hybrid_Scope_Glass` | 1 | 22 | 8 | 0.15 | | 0.13 |
| `Sight/Nightforce_ATACR_4-16x42_Scope/Material/MI_Nightforce_ATACR_4-16x42_Scope_Glass` | 1 | 42 | 8 | 0.15 | | 0.125 |
| `Sight/PSO-1_4x24_Scope/Material/MI_PSO-1_4x24_Scope_Glass` | 1 | 19 | 8 | 0.2 | | 0.13 |
| `Sight/QBZ-97_Y-MA-95-1-600_3x_Scope/Material/MI_QBZ-97_Y-MA-95-1-600_3x_Scope_Glass` | 1 | 19 | 8 | 0.2 | | 0.1 |
| `Sight/Schmidt_and_Bender_1-8x24_PM_II_ShortDot_Scope/Material/MI_Schmidt_and_Bender_1-8x24_PM_II_ShortDot_Scope_Glass` | 1 | 24 | 8 | 0.15 | | 0.125 |
| `Sight/SIG_Sauer_BRAVO4_4x30_Scope/Material/MI_Bravo4_Glass` | 1 | 23 | 8 | | 1.8 | 0.13 |
| `Sight/Trijicon_ACOG_4x24_Scope/Material/MI_ACOG_4x_Glass` | 1 | 18 | 8 | (0.1 in game) | (1.8 in game) | 0.12 |
| `Sight/Trijicon_ACOG_6x48_Scope/Material/MI_ACOG_6x_Glass` | 1 | 19 | 8 | 0.2 | | 0.18 |

In vanilla, `RenderRadiusSens` rises with `FixedDistance`: 18 to 20 at 8, 19 to 22 at 10, 23 to 24 at 12, 42 on the ATACR.

### Other layers

* **Body mesh**: slots on `M_IRR_Viewmodel` plus one `MI_IRR_Base_Lens_Scope` slot on `M_IRR_Base_Lens`. The ACOG 4x24's body is `StaticMesh`, slots 0 to 3 (`_ard`, `_Mount`, `_RMR_Mount`, `MI_Trijicon_ACOG_4x24_Scope`) and slot 4 the base lens. The body has its own dark rim around the eyepiece, which a closer eye sees more of. No value tested changes it.
* **Body scope masking**: `M_IRR_Viewmodel` and `M_IRR_Base_Lens` name `Use Scope Masking`, `UseOpacityMask`, `MF_OpacityMask` and `MPC_Viewmodel`. Vanilla body instances set `Mask Depth Fade Offset`: AUG -10, Vudu -9, Fero-Z -6.2, HHS-1 -5, HAMR -4.5, ATACR -4, Elcan -3. The ACOG 4x24's inherit -4 to -5. On the ACOG, values from -10 to 5 changed nothing visible.
* **Sight post-process**: the sight's `CameraBlendables`, children of `/Game/Scopes/PPM_ScopePostProcess` (docs/solutions/likhos-oculus.md), added and removed with `UGeneralFunctionLibrary::AddCameraBlendable` and `RemoveCameraBlendable`. Removing it takes away only the depth of field.
* **`MPC_Viewmodel`**: `Field Of View`, `Separate View Alpha`, `Alpha`, `Vignette`, `OpcaityMask`, `ScopeRadius`, `ScopeRotation`, `ResolutionScale`, `OutOfBounds`, `SightAlpha`, `Offset`, `ScopeWorldLocation`, `ScopeScreenLocation`, `ScopeForward`. Native code writes `ScopeRadius` every frame from the mode's `ScopeRadiusMargin`. On the ACOG 4x24 at 4, margin 0.05 gave 0.372 and 0.2 gave 0.531. It sizes the reticle, not the shadow.

## Observed in game

Per the user, unless a log value is quoted.

* With the eye relief applied (1.1.2), the eye position looked right on every scope, but the scope view was badly off on all of them, the Vudu included, though it is the only one moved further out.
* Scaling every lens's `RenderRadiusSens` by new over old `FixedDistance` made the ACOG 4x24 (18 to 9) much worse. Scaling by old over new (18 to 36) looked like no change. `RenderRadiusSens` sizes the shadow ring, not the tube.
* **ACOG 4x24 at 4** (moved closer): the problem is the tube interior. `FrontGradientRadius` hides it: 0.159 is the lowest value that does with the body hidden, 0.135 with the body showing, against 0.12 vanilla at 8. 8 is the closest `FixedDistance` that hides the tube with vanilla values.
* **Vudu at 9** (moved further out): no tube problem. The shadow ring is off. Untuned.
* `RenderRadiusSize` 1.2 and 1.5 on the ACOG: nothing visible, with the body showing.
* `RenderRadiusSens` 10 on the ACOG with the body hidden: a larger dark area. 100: none.
* `ScopeRadiusMargin`: changes the reticle size.
* `FixedDistance` written into `SightModes` at runtime applies on switching weapons and back, not on re-aiming.
* `HandsFOV` applies at once and zooms the whole view, the world included, so it changes magnification. `CameraIndependentFOV` 40 and `HandsZoomIn` 20, through a weapon swap: nothing visible.
* Hiding the lens glass and showing it again brings back the faked tube and shadow but not the reticle, until the scope is reattached.

## Picking it up again

Per scope, after setting its `FixedDistance`:

1. With the body hidden, raise the glass's `FrontGradientRadius` until the tube is gone at rest.
2. Tune `RenderRadiusSens`, then `RenderPositionSens`, so the shadow ring sits on the lens edge at rest and shows only when the eye moves.
3. Check the body's own dark rim with the body showing. Nothing found so far changes it.

No rule across scopes was found. On the ACOG, halving the distance took the tube's `FrontGradientRadius` up 1.325 times.

Tooling to rebuild:

* **Sights stage** in `pak.ps1`, last stage: reads `sights.json`, keyed by blueprint package, mapping a component name (without `_GEN_VARIABLE`) to mode names to `FSightData` float fields. It reads the blueprint parsed, finds `<Component>_GEN_VARIABLE`, its `SightModes` pair by key (FNames compare case-insensitively) and sets the float with `IsZero` kept in step. It fails on a missing component, mode or float, or an asset another stage lists. The edited blueprints passed the unchanged round trip check.
* **Materials stage**: it sets only scalars an instance already overrides. The Vudu's glass has no `RenderRadiusSens` override and the ACOG 4x24's none for `RenderPositionSens`, so tuning those needs the stage to add an override: a full `ParameterInfo` entry and its names in the name map.
* **Lens probe** (a temporary UE4SS mod), techniques that worked:
  * Current sight: `InventoryFunctionLibrary:GetEquippedWeapon(pawn)`, its `WeaponComponent`, then `GetCurrentSightComponent()`. The sight's actor is `GetOwner()`.
  * `K2_GetComponentsByClass` returned an empty array in this UE4SS build. The actor's meshes come from `FindAllOf("StaticMeshComponent")` and `FindAllOf("SkeletalMeshComponent")` filtered by `GetOwner()`.
  * Lens slots: `GetMaterial(i)` whose `GetBaseMaterial()` is `M_Scope_NEW`. Values are read with `K2_GetScalarParameterValue` and set with `SetScalarParameterValue` on the game's own dynamic copy. The packed values come from a throwaway `KismetMaterialLibrary:CreateDynamicMaterialInstance` of the copy's `Parent`.
  * Sight data: the `SightModes` value from `ForEach` writes in place. `SetSightMode` and `GetSightData()` read it back, and a weapon swap applies it.
  * `SetVisibility` on a mesh hides it. `MPC_Viewmodel` values read through `KismetMaterialLibrary:GetScalarParameterValue`.
  * `RegisterConsoleCommandHandler` commands run, but the game's console reports them as unknown. Output goes to the UE4SS console.
