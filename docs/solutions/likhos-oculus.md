# Likho's Oculus

## Intent

A new pak mod, Likho's Oculus (`likhos-oculus`), that removes the chromatic aberration magnified and thermal scopes show while aiming and keeps their edge tint close to the rim. The values were settled in game with a test pak: aberration off on every scope, edge tint falloff 8 on every scope.

## Recon

All names below come from the CXXHeaderDump and from cooked assets read with UAssetGUI and the game's usmap.

How a scope's lens effect reaches the screen:

* A scope's sight component is a `BP_SightComponent_C` (`USightComponent`). Its `CameraBlendables` (`TArray<FWeightedBlendable>`) holds one entry with weight 1: the scope's post-process material instance.
* `BP_SightComponent.K2_TriggerSight` loops over `CameraBlendables` and calls `UGeneralFunctionLibrary::AddCameraBlendable(WorldContextObject, Blendable, Weight, BlendTime)` on aim in and `RemoveCameraBlendable(WorldContextObject, Blendable, BlendTime)` on aim out.
* Every such instance has the parent `/Game/Scopes/PPM_ScopePostProcess`, an `MD_PostProcess` material. The cook strips its graph. Only parameter names survive: `AberrationAmount`, `AberrationPower`, `AberrationHueShift`, `Distortion`, `DistortionFalloff`, `BlurAmount`, `BlurBlendDistance`, `LensTint`, `LensTintOuter`, `TintGradientPower`, `ReticuleTexture`, `ReticuleScale`, `ReticuleIntensity`, `ReticuleDistance`, `Recticle Color`, `Recticle Glow`, `UseReticleScale`, `UseReticuleInPostProcess`, `UseStencilMask`.
* The material reads the eyepiece's screen position and size from `/Game/ThirdParty/InfimaGames/AnimatedLowPolyWeapons/Materials/MPC_Viewmodel`. The sight mode (`FSightData`) names the parameters: `ScopeWorldLocation`, `ScopeScreenLocation`, `ScopeForward`, `ScopeRadius`, `ScopeRotation`.
* `UFirstPersonWeaponADS` blends the sight mode's `GlobalMaterialParameters` on `MPC_Viewmodel` with aim alpha. Scopes set only `OpcaityMask` (sic) and `Vignette` there.
* Red dots, holographic sights and iron sights have no `CameraBlendables`.

Observed in game:

* `AberrationAmount` sets the color split. 0 removes it. Every scope ships a negative value.
* `AberrationPower` is the falloff of the split toward the rim. Raising it pushes the split outward.
* The split is sized in screen space, so it covers a larger share of a small eyepiece: at equal values the HAMR showed it out to a third of its radius, the Vudu barely at all.
* `TintGradientPower` is the falloff of the `LensTintOuter` edge tint toward the rim.
* `FSightData.FixedDistance` is eye relief. Lowering it brings the eyepiece closer and enlarges the scope shadow.

The scope instances, with the game's values:

| Instance | AberrationAmount | AberrationPower | TintGradientPower |
|---|---|---|---|
| `/Game/Blueprints/InventorySystem/Items/Attachments/Rail/AUG_A3_M1_1x5_Optic_Sight/Material/AUG_A3_M1_1x5_Optic_Sight_PP` | -0.05 | 4 | 2 |
| `.../Sight/Elcan_SpecterDR_15x_6x_Scope/Material/MI_Elcan_SpecterDR_15x_6x_Scope_reticle_PP` | -0.03 | 4 | 2 |
| `.../Sight/Elcan_SpecterDR_1x-4x_Scope/Material/MI_Elcan_SpecterDR_1x-4x_Scope_PP` | -0.03 | 4 | 2 |
| `.../Sight/EOTech_CNVDT_1x_Thermal_Scope/Material/MI_EOTech_CNVDT_1x_Thermal_Scope_PP` | 0 | 0 | not set |
| `.../Sight/EOTECH_HHS-1_Hybrid_Sight/Material/MI_EOTECH_HHS-1_Hybrid_Sight_PP` | -0.05 | 4 | 4 |
| `.../Sight/EOTECH_Vudu_1-6x_Scope/Material/MI_EOTECH_Vudu_1-6x_Reticle_PP` | -0.075 | 3 | 8 |
| `.../Sight/Hensoldt_Wetzlar_Fero-Z_4x24_Scope/Material/MI_Hensoldt_Wetzlar_Fero-Z_4x24_Scope_PP` | -0.03 | 2 | 8 |
| `.../Sight/Leupold_HAMR_4x24_Hybrid_Scope/Materials/MI_Leupold_HAMR_4x24_Hybrid_Scope_PP` | -0.03 | 2 | 4 |
| `.../Sight/Nightforce_ATACR_4-16x42_Scope/Material/MI_Nightforce_ATACR_4-16x42_Scope_Reticle_PP` | -0.04 | 2 | 2 |
| `.../Sight/PSO-1_4x24_Scope/Material/PSO-1_4x24_Scope_PP` | -0.05 | 4 | 4 |
| `.../Sight/QBZ-97_Y-MA-95-1-600_3x_Scope/Material/MI_QBZ-97_Y-MA-95-1-600_3x_Scope_PP` | -0.04 | 4 | 2 |
| `.../Sight/Schmidt_and_Bender_1-8x24_PM_II_ShortDot_Scope/Material/MI_Schmidt_and_Bender_1-8x24_PM_II_ShortDot_Scope_Reticle_PP` | -0.04 | 2 | 2 |
| `.../Sight/SIG_Sauer_BRAVO4_4x30_Scope/Material/MI_Bravo4_Reticle_PP` | -0.03 | 2 | 8 |
| `.../Sight/Trijicon_ACOG_4x24_Scope/Material/MI_Trijicon_ACOG_4x24_Scope_PP` | -0.02 | 4 | 8 |
| `.../Sight/Trijicon_ACOG_6x48_Scope/Material/MI_ACOG_6x_Reticle_PP` | -0.05 | 4 | 4 |
| `.../Sight/Trijicon_SkeetIR_1x_Thermal_Scope/Material/MI_Trijicon_SkeetIR_1x_Thermal_Scope_PP` | -0.01 | 12 | 8 |

`...` is `/Game/Blueprints/InventorySystem/Items/Attachments`. Every instance overrides `AberrationAmount`, `AberrationPower` and, except the CNVDT, `TintGradientPower` in its `ScalarParameterValues`, so the master material's defaults never apply.

## Constraints and assumptions

* The edit is data only: scalar parameter overrides in material instance constants. They are runtime uniforms, so no shader is rebuilt and the pak carries no material graph.
* Each edited instance ships whole, from the current game build. A game patch that changes one needs a rebuild.
* `likhos-rearmed` edits none of these assets, so the two paks don't overlap.
* Ruled out: a Lua mod that swaps each sight's blendable for a dynamic material instance at aim time. It needs UE4SS, a hook per sight and runtime state, for a result a static edit gives.
* Ruled out: lowering `FixedDistance` to shrink the fringe. It changes eye relief, a separate concern the user may tune later.
* Ruled out: per-scope aberration amounts scaled to eyepiece size. The user prefers aberration off on every scope.
* Ruled out: adding a scalar override an instance doesn't already have. Every value this mod sets is already overridden by its instance.

## Scope

Owned:

* `likhos-oculus/`: the new mod folder.
* `tools/pak/pak.ps1`: stage selection and the new material stage.
* `tools/build/build.ps1`: which changes bump a mod's version.
* `CLAUDE.md`: its build command notes, which state what bumps a mod's version.

Context only: `build.ps1`'s pak path (runs any folder with `pak=` in `mod.txt` through `pak.ps1`, packs into `dist\` and installs into `Content\Paks\~mods`) and `tools/publish/publish.ps1` (publishes the pak mod from `dist\`, refusing a pak older than the mod folder or `tools\pak\`).

Outside this solution: the root `README.md` and the rest of `CLAUDE.md`. `tools/publish/publish.config.json` gets the mod's entry after the user creates its Nexus page and first file by hand.

## Solution

### likhos-oculus

A pak mod folder laid out like `likhos-rearmed`:

* `mod.txt` with `version`, `pak="likhos_oculus_P.pak"` and the `[game]` section recording the game build and engine version the pak was built from.
* `materials.json`, the mod's only edit list. It is keyed by material instance package path. Each value maps scalar parameter names to the value to set. It lists the 15 scope instances whose game values differ from the end state: every instance ends with `AberrationAmount` 0 and, where it overrides it, `TintGradientPower` 8. The CNVDT already matches and is not listed.
* `README.md` describing the effect for players: what changes through a scope, that thermal scopes lose their aberration too, install and uninstall steps for the pak, compatibility (pak only, no UE4SS needed, no overlap with Likho's Rearmed). `README.bbcode` is its Nexus conversion.
* `CHANGELOG.md` with the first release under a bare version heading.

### pak.ps1

`pak.ps1` stages a pak mod from whichever edit lists its folder has. Each stage runs only when its list exists. A mod with `materials.json` alone stages only the edited material instances.

* `DefaultGameplayTags.ini` is staged only when `reclass.json` exists. The loadouts stage still reads the game's tag list, with reclass applied when there is one.
* The checks that stop two stages writing the same asset cover every stage that ran, the material stage included.
* The material stage reads each listed instance parsed, as the stats stage does. For each listed parameter, it finds the instance's own entry in `ScalarParameterValues` by parameter name and sets its value. A missing instance, an asset without `ScalarParameterValues` or a parameter the instance doesn't override fails the build, naming the asset and parameter. It logs each change as old value to new value, like the other stages.
* The script header describes the stages, the optional lists and the material stage.

### build.ps1 version bump

A pak mod's version reflects changes to the mod itself. `build.ps1` bumps a pak mod's patch number only when its own folder has uncommitted changes. A change in `tools\pak\` doesn't bump any mod. A Lua mod still counts a change in `lib\`, since `lib\` ships inside it.

### Result

`.\tools\build\build.ps1 likhos-oculus` builds `dist\likhos_oculus_P.pak` and installs it into `Content\Paks\~mods`. In game, no scope shows color fringing, and the edge tint stays in a thin band at the rim. `likhos-rearmed` builds to the same pak as before.

## Tradeoffs

* An explicit list of instances over discovering every child of `PPM_ScopePostProcess`. It matches the other stages and fails loudly when a patch renames or removes a scope. The cost: a scope added by a patch keeps its aberration until it is listed.
* Optional edit lists over a separate script per mod. One script keeps the shared asset handling in one place.
* A pak mod's version bumps from its folder only, not from `tools\pak\`. A version then means a change to that mod's own edits. The cost: a `tools\pak\` fix that changes what a pak ships leaves the version alone until the mod folder changes too.
* A separate mod over a Rearmed stage. Players can take the visual change without Rearmed's balance changes. The cost is one more Nexus page.
