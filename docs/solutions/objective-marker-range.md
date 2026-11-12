# Objective marker range and quest pickups

## Intent

The blue plant spot marker (`docs/solutions/plant-spot-marker.md`) is extended to every quest objective the player has to find in the world, and each shows from at least 10 m away (user request, 2026-11-11):

- Placement spots and mission phones, the gear icon targets. A mission phone's marker showed only within 3.5 m.
- Quest items to pick up, e.g. documents, USB drives and key cards.
- Mission boxes, the containers a mission spawns with its items inside.

The out-of-reach opacity floor is dropped (user decision). Every objective marker fades with distance as in vanilla.

## Constraints and assumptions

- Game names come from the UE4SS header dump and an in-game probe, recorded below (project rule).
- The marker widget has no link back to its target, and a target gets its widget only once the player is in range. So the range has to be set on the target, and so does the color, because a mission box shows the same icon as every loot container.
- The color is set through the options' `BorderColor`, which vanilla applies to the ring on every marker update (user decision). The icon has no tint in the display setting, so it stays white. Ruled out: tinting the widget from the target's `TargetMarker` each frame. Marker widgets may be pooled, so a widget could keep the color on an ordinary target.
- A quest item is one whose item tag starts with `Inventory.Items.Quest.` (user decision). Ruled out: `bQuestItem` on the item, which keys also carry. Key Cards are under the quest tag and are marked.
- The feature stays in `likhos-point-and-shoot` as Lua (user decision). Ruled out: a pak edit in `likhos-rearmed`. The pak tools edit item data, not blueprint components, a pak needs every pickup blueprint listed, and the mission phone's owner class doesn't resolve.

Names from `CXXHeaderDump` (Test_C.hpp, 2026-11-11):

- `/Script/Test_C.InteractionTarget` (`UInteractionTarget`): `TargetMarker`, `OuterInteractionRadius`, `InnerInteractionRadius`, `InteractionOptions` (`TArray<UInteractionOption*>`), `SphereComponent` (`USphereComponent`), `InteractionItem` (`FContainerItem`).
- `UInteractionOption`: `DefaultDisplaySetting`, `HoldDisplaySetting`, `RepeatDisplaySetting` and `WaitDisplaySetting`, each an `FInteractionDisplaySetting` holding `MarkerSetting` (`FInteractionMarkerDisplaySetting`: `Texture`, `BorderColor` and others, see the plant spot doc).
- `/Script/Test_C.PickUpActor` (`APickUpActor`): `InventoryComponent` (`UInventoryComponent`), whose `PickUpContainerItem` (`FPickUpContainerItem`) holds `ContainerItem` (`FContainerItem`: `ItemDefinition`, `bQuestItem`).
- `UIRRItemDefinition`: `ItemIdentifier` (`FGameplayTag`), `ItemProperties.bQuestItem`.
- Quest item tags, from the cooked `UISI_Intel_C` supported items list: `Inventory.Items.Quest.Defense.Intel A/B/C/Fang`, `.Operation Plans`, `.Shipping Manifest`, `.Troop Movement Paper`, `.USB Drive`, `.Classified Document-IGC`, `.Classified Document-UICS`, `.Construction HxAxS Blueprint Materials List`, `.Construction HxAxS Blueprint Layout Guide` and `.Key Cards`.

Probed in game (2026-11-11, temporary `NotifyOnNewObject` watch on `InteractionTarget`, read 2 s after construction, hideout and Quarry):

- `NotifyOnNewObject` on the native class catches `BP_InteractionTarget_C` components, including ones spawned mid-raid.
- Every option is a subobject of its own target, e.g. `<actor>.BP_InteractionTarget.IO_LootContainer_C_0`. 6391 options in one raid, every path distinct.
- Raising `OuterInteractionRadius` after spawn takes effect: the hideout mission phone (gear icon, `IO_LootContainer_C`, outer 350, no sphere of its own, owner not resolved by `GetOwner`) then showed its marker from much farther away.
- `BP_ItemPlacement_Bomb_C` (gear icon) and `BP_OperationInteractionPoint_Master_C` (gear icon) have outer 1000 and sphere 1000.
- `BP_MissionBox_C` spawns mid-raid together with the mission's `BP_ItemPlacement_Bomb_C` spots. Outer 400, sphere 400, option `IO_LootContainer_C` with texture `checked`, the one every loot container shows.
- Pickups (`BP_StaticMasterPickup_C` and per-item subclasses such as `BP_HAS_Large_Key_C`) have outer 350, `IO_Pickup_C` options with grab or weapon icons, and their item reachable through `InventoryComponent.PickUpContainerItem.ContainerItem`. HAS keys have `bQuestItem` true on the item and false on the definition, tag `Inventory.Items.Keys.HAS.*`.
- No `Inventory.Items.Quest.*` pickup was seen yet.

Assumptions the build checks in game:

- Documents and similar quest items lie in the world as `PickUpActor`s.
- Setting `BorderColor` on the options colors the ring blue, as the widget-side tint did.

## Scope

Owned: `likhos-point-and-shoot/Scripts/plant_marker.lua`, `main.lua` (the tick and reset calls for the opacity floor removed), `config.lua` (`plant_marker_range` added, `plant_marker_min_opacity` removed), `README.md` and `CHANGELOG.md`.

## Solution

`plant_marker.lua`:

- `install()` registers a `NotifyOnNewObject` watch on `InteractionTarget` once, and scans the targets that already exist so a hot reload covers the level it runs in. Each new target is read 2 s after construction, when its owner has set it up and a pickup has its item.
- A target is an objective when one of its options shows the gear icon, its owner's class is `BP_MissionBox_C`, or its owner is a `PickUpActor` whose item tag starts with `Inventory.Items.Quest.`.
- An objective's `OuterInteractionRadius`, and its sphere's radius when it has one, are raised to `plant_marker_range` when below it. Every display setting of every option gets the configured color as its `BorderColor`.
- The widget hook on `UpdateTargetMarker`, the per-frame opacity hold and the level-load reset are removed.

Names in `config.lua` keep the `plant_marker` prefix, so a player's edited values still apply.

## Result

A mission phone, quest item pickup and mission box show a blue ring from 10 m away. Placement spots keep their vanilla 10 m and the blue ring. Icons are white, and every marker fades with distance as in vanilla. Other markers are vanilla.

## Tradeoffs

- Target side over widget side: the only way to reach a target before its widget exists, and to tell a mission box from a loot container. The cost is a 2 s delayed read of every interaction target that spawns, a few hundred per level.
- `BorderColor` over a widget tint: vanilla does the drawing and a pooled widget can't carry the color over. The cost is the icon staying white.
