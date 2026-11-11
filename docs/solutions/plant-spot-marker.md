# Plant spot marker

## Intent

The marker on a quest placement spot, where the player plants a bomb, bug or similar item, is easy to find in the world without opening the map. In vanilla it is a pale grey ring around a gear icon that blends into bark, rock and foliage, and it shows at only 20% opacity until the player is close enough to plant. With the mod the ring and the gear are drawn in bright blue, a color rare in the game's world and UI, and the marker shows at 40% opacity while out of reach. The marker's size, the distance where it first appears, the range the player can plant from and its animations stay vanilla. Every other interaction marker, e.g. the magnifier on a container or a door, stays vanilla.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from the cooked assets, a UE4SS dump or Live View and are recorded in this doc (project rule).
- UObject access happens on the game thread only, no UObject is held across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- A marker counts as a plant spot by its icon texture alone. The user has seen the gear icon only on plant spots.
- A plant spot marker never switches to another icon (user decision). Nothing undoes the tint or the opacity floor, so a widget that did switch would keep both.
- The color is `#33B5FF` (sRGB), a bright sky blue (user decision). Ruled out: the map objective icon's yellow (`#ECCA52`, sampled from a screenshot), for a color not typically found in the game.
- Ruled out: raising the target's `InnerInteractionRadius` so the marker reaches full strength farther out. It is also the range the player can interact from (tested on the hideout stash, 2026-11-10). The user tried 3 m and dropped it once the opacity floor worked.
- Ruled out: a UE4SS hook on `InteractionWidgetInterface:UpdateTargetMarkerOpacity`. UE4SS registers it as a native hook, and the game crashed on the first call (2026-11-10, `EXCEPTION_ACCESS_VIOLATION` in `UObjectBase::IsA` from `RemoteUnrealParam::prepare_to_handle`, inside the pre callback): the call's context is not a valid UObject.
- Ruled out: a darker fill behind the icon. The ring and the fill are one image (`Background`), so they can't be colored apart.
- Ruled out: a glow. UMG has no blur glow, and a new halo texture would need a pak. A halo made from the widget's own pulse layer (`Background_Fade` tinted, at 0.45 render opacity and 1.35 render scale) was tried on the hideout stash marker and rejected by the user: it reads as a flat, faint disc.
- Ruled out: a pak edit of the plant spot's interaction option. The actor that owns it isn't identified, and the marker widget is shared with every other interaction.
- The feature lives in `likhos-point-and-shoot` as a Lua hook (user decision).
- UE4SS hooks a Blueprint function as a script hook, which runs a single callback and never a post callback (`docs/solutions/medic-drop.md`).

Names from `CXXHeaderDump`, `UE4SS_ObjectDump.txt` (2026-11-08, taken in the hideout) and the cooked `W_InteractionTargetMarker` asset (game build 26487830, read with UAssetGUI 2026-11-10):

- `/Game/Blueprints/InteractionSystem/Widgets/W_InteractionTargetMarker.W_InteractionTargetMarker_C` is the marker widget for every interaction target, a subclass of native `/Script/Test_C.InteractionWidgetIcon`. Its tree is `ContentBox` (HorizontalBox) holding `ProgressButtonBox` (SizeBox, 50 by 50) holding an overlay with, back to front:
  - `Background`: material `/Game/ThirdParty/CMG/Textures/ProgressCircle/M_ProgressCircle_Background`, the ring and the dark fill inside it. Its brush tint defaults to 0.094 gray.
  - `Background_Fade`: the same material at `RenderOpacity` 0, untinted. It is the only binding of the `Blink` and `Transition` animations, which key its `RenderOpacity` and 2D render transform.
  - `ProgressCircle`: material `M_ProgressCircle_Inst`, the hold progress arc.
  - `Icon`: the icon texture, padded 6 on each side.
- `W_InteractionTargetMarker_C:UpdateTargetMarker(FInteractionMarkerDisplaySetting NewInteractionMarkerDisplaySetting)` is the Blueprint implementation of `IInteractionWidgetInterface:UpdateTargetMarker`. It sets `ProgressButtonBox`'s size from `MarkerSize`, `Background`'s brush tint from `BorderColor`, `ProgressCircle`'s brush tint from `ProgressColor`, `Icon`'s padding from `MarginPadding` and `Icon`'s brush from `Texture` (`SetBrushFromTexture`) or `Material`.
- `FInteractionMarkerDisplaySetting` holds `UseMaterialAsTexture`, `Texture` (UTexture2D), `Material`, `MarkerSize`, `MarginPadding`, `BorderColor` and `ProgressColor` (FSlateColor).
- `IInteractionWidgetInterface:UpdateTargetMarkerOpacity(float)` drives the fade with distance. It is native and not overridden by the widget. The fade has two steps, not a gradient (probed on the hideout stash, 2026-11-10): the widget's `OpacityAlpha` is 0 beyond the outer radius, 0.2 within it but out of reach and 1 within the inner radius. `ContentBox`'s render opacity eases toward `OpacityAlpha` over a few frames and is what draws faded. The widget's own render opacity and color, and the images' colors, stay at 1.
- Raising `OpacityAlpha` and `ContentBox`'s render opacity from Lua once per frame holds without flicker (tested on the hideout stash, 2026-11-10).
- Marker widgets are outered to the game instance (`UMS_GameInstance_C`), and a target gets a new widget each time the player comes into range (seen in the log, 2026-11-10).
- `/Game/Blueprints/InteractionSystem/Framework/BP_InteractionTarget.BP_InteractionTarget_C` (native `UInteractionTarget`) holds `TargetMarker` (the widget), `OuterInteractionRadius`, `InnerInteractionRadius` and `SphereComponent`. The marker appears within the outer radius and is at full strength within the inner one, where the player can also interact.
- Interaction icon textures under `/Game/Blueprints/InteractionSystem/Textures/`: `T_IRR_Interaction_GrabIcon`, `T_IRR_Interaction_ItemInteractionIcon`, `T_IRR_Interaction_TerminalIcon` and `T_IRR_Interaction_UpgradeIcon`.
- Placing an item goes through `IA_UseInteractionItem_C` and `IC_HasInteractionItem_C`. The objective class is `/Game/Blueprints/MissionSystem/Objects/Objectives/SubClasses/BP_IRRObjectie_Place.BP_IRRObjectie_Place_C`.

Observed in game (2026-11-10): the plant spot marker first shows, faded, at about 10 m and is fully opaque at 1 to 2 m. Tinting `Background` and `Icon` colors the ring and the gear. The hideout stash (`BP_InventoryStash_C`, option `IO_Stash_C`) has `OuterInteractionRadius` 400 and a `SphereComponent` of radius 400.

Assumptions the build checks in game:

- The plant spot's gear icon is `T_IRR_Interaction_ItemInteractionIcon`, and no in-raid container or door marker uses it.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/plant_marker.lua`: the feature.
- `likhos-point-and-shoot/Scripts/main.lua`: installing the feature, calling it from the per-frame tick loop and resetting it on level load.
- `likhos-point-and-shoot/Scripts/config.lua`: the feature switch, color and minimum opacity.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description and the version it ships in.

Context only: `hook.lua` (hook install, guards and deferral until the Blueprint class loads), `util.lua`, `log.lua`, the vanilla `W_InteractionTargetMarker_C` and `BP_InteractionTarget_C`.

## Solution

### `plant_marker.lua`

Owns every game name to do with the marker. Holds no UObject between calls. Its only state is the set of decorated plant spot markers, by path.

- `install()` hooks `W_InteractionTargetMarker_C:UpdateTargetMarker` through `hook.lua`, which waits for the Blueprint class to load and logs a refusal once without failing the mod.
- On `UpdateTargetMarker` the hook reads the setting's `Texture`. When it is the plant spot icon, one tick later, once the vanilla function has run, the marker is found again by path, `Background`'s brush tint is set to white so vanilla's grey `BorderColor` doesn't dim the color, `Background` and `Icon` take the configured color, each keeping its alpha, and the marker's path joins the tracked set. The colors are absolute, so a repeated update gives the same marker.
- `tick()`, called every frame, holds each tracked marker that is showing out of reach at the configured minimum opacity: when its `OpacityAlpha` is above 0 and below the minimum, both `OpacityAlpha` and `ContentBox`'s render opacity are raised to it. Beyond the outer radius (`OpacityAlpha` 0) and within reach (1) the native fade runs as in vanilla. A path whose marker no longer exists drops out of the set. A failure logs once.
- `reset()` empties the set. It runs on level load.
- A marker whose texture is any other icon is left to vanilla. A marker that never showed the plant spot icon is never touched.
- At debug log level the hook logs each marker's texture name.
- A failure logs once per session and leaves the markers vanilla.

### `main.lua` and `config.lua`

`config.lua` has a top-level `plant_marker` switch, default true, documented as "the marker on a quest placement spot, where a bomb or bug is planted, is drawn in bright blue so it stands out", `plant_marker_color`, an sRGB hex string defaulting to `"#33B5FF"`, and `plant_marker_min_opacity`, default 0.4, the opacity out of reach, where vanilla is 0.2 and 0 keeps vanilla. `main.lua` installs `plant_marker.lua` when the mod is enabled and the switch is on, calls its `tick()` from the existing per-frame loop and its `reset()` with the other modules' resets when a new PlayerController appears. The loop also starts when the switch is on and no bind is active.

### README, CHANGELOG and `mod.txt`

The README has a section describing the plant spot marker and its settings. `CHANGELOG.md` has an entry for the version that ships it. It is a new feature, so the minor version in `mod.txt` goes up by one.

### Result

In a raid with a placement objective, the plant spot shows a blue ring and gear, visible against bark and foliage. It appears at the vanilla distance of about 10 m at 40% opacity instead of vanilla's 20%, and is fully opaque at the vanilla reach, where the player can plant. Its size and animations are vanilla. Container, door, pickup and every other interaction marker look vanilla. With `plant_marker = false` the plant spot marker is vanilla too.

## Tradeoffs

- A Lua hook over a pak edit: the widget is shared and the plant spot's owning asset isn't identified, so changing it at draw time is the only place that sees just this marker. The cost is a dependency on the widget's image names, and the marker shows vanilla colors for one frame after each update.
- Matching on the icon texture over checking the interaction option's actions and conditions: one name comparison per marker update and no walk through the interaction target. The cost is that any other interaction a patch gives the same icon gets the highlight too.
- Holding the opacity from the per-frame loop over a hook on the fade: the hook crashes. The cost is a Lua pass every frame over the tracked plant spot markers, usually none or one, and the tick loop running even with every bind off.
- A config switch, color and minimum opacity over always on, following the mod's other features.
