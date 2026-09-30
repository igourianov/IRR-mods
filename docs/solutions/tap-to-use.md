# Tap to use

## Intent

A new player-mappable key, **Interact (Instant)**, listed directly below the vanilla Interact row in the controls menu, uses the targeted interactable on a single tap: a loot container, a dead body, a safe, a terminal, a mission item placement, anything the vanilla Interact key (F) acts on. A hold interaction completes at once instead of after its hold time, and the key needn't stay down.

A key unlock of a locked door or safe starts on the tap too, but still takes its vanilla unlock time.

The vanilla Interact key keeps its vanilla behavior, holds included.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from a UE4SS dump, the cooked assets or a probe, and are recorded in the Recon section below (project rule).
- UObject access happens on the game thread only, UObjects are never cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The key is read the way the mod's other keys are: a runtime mapping in the mod's `InputMappingContext`, rebound from the controls menu and polled by `input.lua` (`docs/solutions/point-aim-keybind-menu.md`).
- A hold's duration is changed only on the live option objects of the target being used, and only for the length of that one interaction. No asset edits and no sweep over every interactable.
- The original hold settings go back only once the interaction has ended. The game reads `HoldTime` while the interaction runs, so an earlier restore brings the full hold back (Recon, Probe).
- The only reachable end signal is `InteractionManager:FinishInteractionWithTarget`. The target and option finish functions run natively and never reach a Lua hook (Recon, Probe).
- Ruled out: making F itself tap-to-use through a hook on `InteractionManager:RequestInteraction`. It works, but F would lose its hold behavior.
- Out of scope: shortening `Wait` options, which key-locked doors and safes use for their unlock. Their duration is the unlock action's run time, not the hold settings, so a zeroed hold leaves it unchanged (confirmed in game). Shortening it would mean changing the option's type or action, which risks skipping the unlock itself.
- Ruled out: a pak edit of `HoldTime` defaults. Actors placed in a map carry their own option instances with their own values, so an asset edit misses them.
- Interact (Instant) is refused wherever F is. It starts the same `SGA_Interact` ability F does, so the ability's activation checks apply unchanged.
- Ruled out: calling `InteractionManager:RequestInteraction` directly. It works, but skips the ability's activation checks.
- Ruled out: starting through a one-frame injection of `IA_Interact`. The injected release goes through `IH_Interact`'s Completed path, which cancels holds.
- A mod row's anchor is identified by the vanilla row's mapped name, not its widget name. The Interact row's widget is named `WB_SingleSettingBar`, the generic name other settings pages also use (Recon, Controls page).

Assumptions the build checks:

- A zero hold completes cleanly on every hold interaction type in the game, not just `IO_LootContainer`: the dead body loot, the safe (`UseActionExecutionTime` true), the terminal boot, item placement and revive. Only loot containers were probed.
- Three mod mappings coexist in the active key profile and each saves independently. Two are verified (`docs/solutions/flashlight-bind.md`).
- A row cloned from the vanilla Interact row works as one cloned from `PointShooting` does (`docs/solutions/point-aim-keybind-menu.md`, Recon). Both are single-entry keybinding rows on the same page.
- A row's `Keybindings` mapped name is readable in the post-hook on its `On_WidgetConstructed`.
- The local pawn owns a `GameplayAbilityComponent`, found with `GetComponentByClass`.
- `GameplayAbilityComponent:TryStartAbilityByClass(SGA_Interact_C)` starts the pawn's granted `SGA_Interact` instance through its activation checks, returns false when they refuse and runs the ability synchronously, so the interaction is `Ongoing` when it returns.
- Started without a key, `SGA_Interact` ends itself once the interaction finishes, as it does after a completed F hold, and never needs a release.
- A target that can't start (a failed condition, a disabled target) leaves the interaction state off `Ongoing` right after the ability starts, so its hold settings can go back at once. Only a successful start was probed.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/quick_use.lua`: the Interact (Instant) action and its hold override.
- `likhos-point-and-shoot/Scripts/actions.lua`: the `QuickUse` entry in `M.ACTIONS` and its reset on level load.
- `likhos-point-and-shoot/Scripts/keymap.lua`: the mod's mappings.
- `likhos-point-and-shoot/Scripts/menu.lua`: the mod's controls menu rows.
- `likhos-point-and-shoot/Scripts/config.lua`: the bind list.
- `likhos-point-and-shoot/Scripts/main.lua`: installing the mod's hooks.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description of the new key and the version it ships in.

Context only: `input.lua`, `triggers.lua` and `context.lua`, which already deliver a press per bind, gate it in UI and reset on level load; `lib/hook.lua`, `util.lua`, `log.lua`; the vanilla interaction system and `SGA_Interact`.

## Solution

### `quick_use.lua`

Owns every interaction system name. Holds no UObject between calls: the override record is plain values, the paths of the options it changed and their original `HoldTime` and `UseActionExecutionTime`, plus the target's path.

- Press: resolves the local `InteractionManager` through `InteractionFunctionLibrary:GetLocalInteractionManager` and its `SelectedTarget`, and the pawn's `GameplayAbilityComponent`. With no target or component, nothing happens. Otherwise it puts back any override still outstanding, records and zeroes the hold settings (`HoldTime` 0, `UseActionExecutionTime` false) on every option of the target and starts `SGA_Interact_C` through `TryStartAbilityByClass`. The ability runs F's checks and requests the interaction as F does. If the ability is refused or the target isn't `Ongoing` when the call returns, it puts the settings back at once.
- A hook on `InteractionManager:FinishInteractionWithTarget`, installed through a `lib/hook.lua` group, puts the settings back when the finished target is the overridden one. It fires for completed and cancelled interactions alike.
- Level load drops the record without writing: the options it names are gone with the level.
- A failure logs once per session through the hook group's guard and leaves the key inert. Vanilla F is unaffected either way.

### `actions.lua`

`M.ACTIONS` gains `QuickUse`, with a press side only, calling into `quick_use.lua`. `M.reset` also resets `quick_use.lua`.

### `keymap.lua` and `menu.lua`

`keymap.MAPPINGS` gains `LikhosInteractInstant`, displayed as "Interact (Instant)". Registration is unchanged.

`menu.lua` maps each vanilla anchor row, identified by its `Keybindings` mapped name, to the mod rows placed directly under it in declared order: `IA_PointShooting` anchors Point Shooting (Direct) and Flashlight (Hold/Toggle), `IA_Interact` anchors Interact (Instant). Each mod row is cloned from its own anchor.

### `config.lua` and `main.lua`

`config.lua` gains a `quick_use` bind on the `LikhosInteractInstant` mapping and the `QuickUse` action, blocked in UI like the other binds. `main.lua` installs the `quick_use.lua` hook at init, like `magnifier.lua`'s.

### Result

The player binds a key under Settings > Controls > "Interact (Instant)", directly below Interact. Tapping it while looking at a container opens the container at once. On a dead body, a safe, a terminal or a placement spot, it completes the use at once. On a locked door or safe with its key in hand, the tap starts the unlock, which takes its vanilla time. Holding F on the same targets takes as long as in vanilla, before and after an instant use.

## Recon

From the UE4SS header dump (`Test_C.hpp`, `Test_C_enums.hpp`, `SGA_Interact.hpp`), cooked assets extracted with repak and read with UAssetGUI, and a probe bind on game build 22417726.

### Classes and members

- `/Script/Test_C.InteractionFunctionLibrary`: `GetLocalInteractionManager(WorldContextObject)`, `GetInteractionTarget(Owner)`, `GetInteractionManager(Owner)`.
- `/Script/Test_C.InteractionManager` (the player's is `BP_InteractionManager_C`): `SelectedTarget`, `InteractedTarget`, `RequestInteraction()`, `StopInteraction()`, `StartInteractionWithTarget(Target)`, `FinishInteractionWithTarget(Target, bSuccess)`, `ExecuteInteractionAction(Target, InteractionAction, bDoubleTab)`.
- `/Script/Test_C.InteractionTarget` (`BP_InteractionTarget_C` and door presets): `InteractionOptions: TArray<InteractionOption*>`, `ActiveInteractionOption`, `InteractionState: EInteractionState`, `GetInteractionOption()`, `GetOwner()`.
- `/Script/Test_C.InteractionOption` (Blueprint subclasses `IO_LootContainer_C`, `IO_Revive_C`, `IO_Pickup_C`, `IO_Stash_C`, `IO_MoveTarget_Up_C`, `IO_MoveTarget_Down_C`): `InteractionType: EInteractionType`, `HoldInteractionSetting: FInteractionHoldingSettings { HoldTime: float, UseActionExecutionTime: bool, Action: InteractionAction* }`, `RepeatInteractionSetting`, `WaitInteractionSetting { Action }`, `OnFinishedActions`.
- `/Script/Test_C.InteractionAction`: `GetExecutionTime(OwnerComp, InteractingActor)`, `Execute(OwnerComp, InteractingActor, bDoubleTab)`. The hold animation action is `IA_PlayMontage_C`.
- `/Script/Test_C.GameplayAbilityComponent`: `GrantedAbilities`, `ActiveAbilities`, `TryStartAbilityByClass(AbilityClass)`, `TryStartAbilitiesByTag(AbilityTag)`, `CanStartAbility(GameplayAbility, bForcedGranted)`, `CanStartAbilityByTag(AbilityTag, bForcedGranted)`, `IsAbilityActiveByTag(AbilityTag)`.
- `/Script/Test_C.SimpleGameplayAbility` (`SGA_Interact_C` derives from it): `ActivationBlockedTags`, `BlockAbilitiesWithTags`, `TagToTriggerAbility`, `Instigator`, `AbilityComponent`, `CanStartAbility()`, `ActivateAbility()`, `DeactivateAbility()`, `IsAbilityActive()`.
- `EInteractionType`: `Tab` 0, `Hold` 1, `Repeat` 2, `Wait` 3. `EInteractionState`: `NONE` 0, `Enabled` 1, `Disabled` 2, `Ongoing` 3.

### Input path

`IA_Interact` has Pressed and Released triggers. `IH_Interact_C` fires `Character.Abilities.Allowed.Interact` on both Started and Completed, which runs `SGA_Interact_C`. F press: `SGA_Interact:CanStartAbility`, `InteractionManager:RequestInteraction`, `StartInteractionWithTarget`, `SGA_Interact:ActivateAbility`. F release: `InteractionManager:StopInteraction`, `SGA_Interact:DeactivateAbility`. A release before a hold completes ends in `FinishInteractionWithTarget` with `bSuccess` false. A completed hold is followed about 18 ms later by `StopInteraction` and `SGA_Interact:DeactivateAbility` with the key still held, so the ability ends itself on completion.

### Hold values in assets

- `IO_LootContainer` default: `Hold`, `HoldTime` 0.5, hold action `IA_PlayMontage` (0.84 s montage, not used for timing). Loot containers inherit it.
- `IO_Revive`: `Hold`, 1.0. Operation start point, terminal boot, warehouse door unlock: `Hold`, 1.0.
- Item placement, item usage: 1.0. Bomb 0.9, jammer 0.75, bug 0.5.
- Safe open: `Hold`, 1.0, `UseActionExecutionTime` true. Door and safe key unlock: `Wait`, `UseActionExecutionTime` true, `IA_PlayMontage_Unlock`.
- Doors (open, close, peek, kick), pickups, switches and the stash: `Tab`.

### Controls page

`WB_KeyboardSoldierBindings` (cooked asset) holds its rows in `SettingsContainer`, a `VerticalBox`. The Interact row is child 29: widget `WB_SingleSettingBar`, action `IA_Interact`, mapped name `IA_Interact`, directly above `WB_Inventory`. `PointShooting` is child 22 with mapped name `IA_PointShooting`. Of the other rows, only some carry a descriptive widget name (`Fire`, `Aim`, `FreeLook` and so on). The rest are numbered `WB_SingleSettingBar_N`. The other settings pages (`WB_AudioSettingsPanel`, `WB_GameplaySettings`, `WB_GraphicSettings_Backup`, `WB_AISettings`) are built from the same row class.

### Probe

- Real durations from F press to `FinishInteractionWithTarget`: loot containers about 535 ms, AI bodies (`BP_IRR_AI_BaseCharacter_UICS_C`) about 1050 ms, `Tab` targets about 205 ms through `StartInteraction_Delayed`, which a release before then does not cancel.
- `RequestInteraction()` called from Lua starts the selected target's interaction without `SGA_Interact` and completes a hold with no key held.
- Writing `HoldInteractionSetting.HoldTime` and `UseActionExecutionTime` through the struct accessor reaches the object. With 0, a loot container finished 44 ms after the call.
- The interaction state reads `Ongoing` synchronously after `RequestInteraction` returns.
- Restoring `HoldTime` right after `RequestInteraction` returned brought the full 530 ms hold back, so the value is read while the interaction runs.
- Lua hooks fire on `InteractionManager` functions and `SGA_Interact_C` functions. Hooks on `InteractionTarget:StartInteraction`, `UpdateInteractionProgress`, `UpdateInteractionState`, `FinishInteraction`, `InteractionOption:FinishInteraction` and `InteractionAction:Execute` never fired.

## Tradeoffs

- A separate key over making F tap-to-use: F keeps its hold behavior, at the cost of a second interact key to bind.
- Starting `SGA_Interact` by class over injecting `IA_Interact`: the same checks and path as F without the release that cancels a hold, at the cost of depending on the ability ending itself.
- Overriding the live target for one interaction over editing assets: covers map-placed overrides and leaves F untouched, at the cost of relying on the finish hook to put the values back. A missed finish leaves one target instant for F until the next Interact (Instant) press or level load.
- Anchoring rows by mapped name over widget name: the Interact row can be found at all, at the cost of anchors depending on the game's mapped names rather than its widget layout.
