# Objective markers through walls

## Intent

Quest objective markers in Point and Shoot (placement spots, mission phones, quest item pickups and mission boxes) show through walls and the surfaces they sit on. Quest items often clip into the table or shelf they are placed on, which hides their marker. The 10 m marker range from `plant_marker_range` does not help, because the marker is still hidden whenever geometry is between the camera and the item.

## Constraints and assumptions

- Game names come from the 2026-11-12 CXXHeaderDump or the in-game probes listed under Recon. Anything not listed there is unknown.
- No pak edits. The fix uses runtime properties on live objects, like the rest of `world/objective_marker.lua`.
- Occlusion is decided by the player's `UInteractionManager`, not by rendering. Marker widgets are already in screen space, so the widget space has no effect on it.
- The occlusion tolerance is one value per manager, so it cannot be raised for objectives alone. The user accepted the global effect: every interaction marker shows through walls within its own radius, and F interacts through walls with whatever the manager selects.
- Through walls is part of the `plant_marker` feature, with no config switch of its own. Turning `plant_marker` off leaves occlusion vanilla too.
- Ruled out: keeping vanilla tolerance and forcing objective markers visible from a tick loop. The manager collapses them natively every 0.2 s with no hook point, so the loop would fight it and the marker could flicker.
- Ruled out: raising the marker above the surface the item sits on. It fixes clipping but not walls.
- Ruled out: the actor outline (`UInteractionOption.ActorHighlightSetting`). It is a different visual, and whether it shows through walls depends on the game's post process.
- **Assumption, unverified:** the raid's PlayerController carries an `InteractionManager` with the same tolerance behavior as the hideout's. The probe ran only in the hideout.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/world/objective_marker.lua`.
- The `plant_marker` comment block in `likhos-point-and-shoot/Scripts/config.lua`.
- The objective marker paragraph in `likhos-point-and-shoot/README.md` and the `# Unreleased` entry in `likhos-point-and-shoot/CHANGELOG.md`.

Context only: `UInteractionManager`'s native occlusion trace, `UInteractionTarget`'s marker update and `lib/util.lua`.

## Solution

`world/objective_marker.lua` stays the one module for objective markers. It decorates objective targets as before: a wider radius and the tinted ring.

It also owns the occlusion tolerance of every interaction manager. It watches `InteractionManager` construction the same way it watches `InteractionTarget` construction, with the same delay before it acts. On install it also sets every live manager, so a hot reload applies at once. Each manager's `TolerateHitDistance` is set to at least the farthest marker radius in play, the objective range from `plant_marker_range` or the vanilla radii, whichever is larger. No wall inside any marker's radius can then hide that marker. The manager is a component of the PlayerController and is rebuilt with it on every level load, so the watch reaches each new one.

Result: within its radius, every interaction marker shows at its position with walls, floors or the item's own table in the way. Objectives keep the blue ring and show from up to `plant_marker_range`. F reaches the selected target through walls the same way.

`config.lua`'s `plant_marker` comment says markers show through walls and F interacts through them, for every interactable and not only objectives. The README's objective marker paragraph says the same, and the changelog has one `# Unreleased` line for it.

## Tradeoffs

- Global tolerance over per-objective forcing: one property per level, no tick loop and no flicker. The cost is that every marker shows through walls, which reveals loot containers, bodies and doors behind walls at their vanilla 3.5 to 4 m, and F works through walls.
- Folded into `plant_marker`: one switch, no new config. A player who wants the color and range but vanilla occlusion cannot have that.

## Recon

From the 2026-11-12 CXXHeaderDump (`Test_C.hpp`):

- `UInteractionManager` fields: `CheckInteractionInterval`, `MaxDistanceToCenterOfScreen`, `TolerateHitDistance`, `bTraceComplex`. Blueprint subclass `BP_InteractionManager_C`.
- `UInteractionTarget.WidgetComponent` holds the marker and `UInteractionTarget.TargetMarker` is its widget, class `W_InteractionTargetMarker_C`, a `UInteractionWidgetIcon` with `OpacityAlpha`.

From probes in the hideout, 2026-11-16:

- The manager is a `BP_InteractionManager` component owned by `BP_HideoutPlayerController_C`. Vanilla values: `CheckInteractionInterval` 0.2, `MaxDistanceToCenterOfScreen` 60, `TolerateHitDistance` 40, `bTraceComplex` false.
- Every marker `WidgetComponent` has `Space` 1 (screen) in vanilla.
- A marker in view has `TargetMarker` visibility 4 (SelfHitTestInvisible) and `OpacityAlpha` 1. The same marker behind a wall has visibility 1 (Collapsed) and `OpacityAlpha` 0. The component itself stays visible.
- With `TolerateHitDistance` set to 2000, the stash marker showed through a wall and F opened the stash through it.
- A pickup's `WidgetComponent` does not exist yet 2 s after the target spawns.
