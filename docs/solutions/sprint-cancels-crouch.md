# Sprint cancels crouch

## Intent

Sprinting from a crouch currently behaves like running from a crouch: the player stays crouched and moves somewhat faster. The user wants Sprint to end the crouch, so the player stands up and sprints at full speed.

## Constraints and assumptions

### Decided behavior

- Sprint is a double tap of the key bound to Run (`IA_Run`), whatever that key is.
- A single press or hold of Run while crouched keeps its vanilla behavior, the faster crouch walk.
- The crouch ends only when a sprint really starts. A double tap with too little stamina or while standing still leaves the player crouched.
- A cancelled crouch stays cancelled. With hold to crouch, a Crouch key still held when the sprint ends does not crouch the player again. Only a new Crouch press does.

### Game facts

From the UE4SS object dump, the ability assets and in-game tag logs of game build 26761568:

- Standing, a double tap keeps Run active through the first release, whose grace is `RunReleaseGraceTime` (0.12 s) on `SimpleGameplayAbility_Run`. The second press adds `Character.Abilities.Active.Sprinting.Wants To Sprint`, and `Running.Is Running` becomes `Sprinting.Is Sprinting`.
- A standing Run released just before a crouch can still be active, within that grace, when `Crouching` appears.
- A Run started while crouched ends on release without that grace. The second press starts a new Run and `Wants To Sprint` is never added.
- The player's double tap does not activate `SGA_Sprint_C`, so that ability cannot serve as the trigger.
- `Running.Wants To Run` only means Run is held. `Running.Is Running` follows it when the character really runs, and is absent while standing still or with too little stamina.
- `SGA_Run_C` grants `Character.Abilities.Active.Running.Wants To Run`. Its `CanStartAbility` requires stamina above `MinStamina` (10). Its event graph references `Wants To Sprint` through `GameplayTagsComponent:UpdateGameplayTags`.
- `SGA_Crouch_C` derives from `SimpleGameplayAbility_Toggleable` and grants `Character.Abilities.Active.Crouching`. Its start removes `Sprinting.Is Sprinting` and `Sprinting.Wants To Sprint`. Its `FinishAbility` runs the graph that calls the character's `UnCrouch`, and waits while the inventory is open.
- `AdvancedMovementComponent:OnOwnedGameplayTagsUpdated` receives the character's tags on every change, for the player and NPCs alike.
- `GameplayTagsComponent:UpdateGameplayTags` takes `ToAddAbilities` and `ToRemoveAbilities`. `IRRBaseCharacter:GetGameplayTagsComponent` returns the component. A tag container built as a Lua table adds nothing and raises no error. The containers in `SGA_Sprint_C`'s class defaults work: `GrantedAbilityTags` holds only `Wants To Sprint` and `BlockAbilitiesWithTags` is empty.
- Adding `Wants To Sprint` during an active Run, once the crouch has ended, produces a real sprint, and Run's own end removes the tag.
- `GameplayAbilityComponent:ActiveAbilities` lists the running ability instances. `StopAbilitiesByTag` with `bHoldReleased` false leaves an active crouch running. `FinishAbility` on the active `SGA_Crouch_C` instance ends the crouch and stands the player up.
- `IA_Sprint` carries an `InputTrigger_DoubleTap` whose `Delay`, 0.25 s, is the game's double tap window. Crouched double taps measured 0.06 to 0.13 s from the end of one Run to the start of the next, so `RunReleaseGraceTime` (0.12 s) is too short to detect them.

### Unverified assumptions

1. Under a low ceiling, finishing the crouch keeps the player crouched until there is room.
2. With hold to crouch, releasing a Crouch key still held through the sprint does not start a new crouch.

### Ruled out

- A pak edit of the Run or Sprint abilities. The feature belongs in Point and Shoot, which is a Lua mod with no pak, and not in Rearmed.
- Hooking `FirstPersonAutoLowReady:OnAbilityStarted`. That component belongs to the auto low ready feature, which the player can turn off in the gameplay settings.
- Requiring the first tap's Run to have started crouched. A standing Run released just before a crouch stays active through its grace time and counts as the first tap, so a quick Run press after that crouch sprints. The user accepts this for simplicity.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/movement/sprint_stand.lua`, a module in the `movement/` domain folder.
- The feature's install line in `likhos-point-and-shoot/Scripts/main.lua`.
- The feature's switch in `likhos-point-and-shoot/Scripts/config.lua`.
- The feature's entries in the mod's `README.md`, `CHANGELOG.md` and the minor version in `mod.txt`.

Context only:

- `lib/hook.lua` and `core/player.lua`, used as they are.
- The game's crouch, run and sprint abilities, which are not modified.

## Solution

`movement/sprint_stand.lua` owns the rule that a double tap of Run while crouched ends the crouch and starts a sprint. It holds no UObject between calls. Its only state is whether Run is held, whether the character is really running and when a Run last ended while crouched.

It installs a hook group from `lib/hook.lua` on `AdvancedMovementComponent:OnOwnedGameplayTagsUpdated`. A failed hook logs once and leaves vanilla crouch and run in place.

The flow:

1. The game reports a change of the character's tags. The module ignores any change that is not the local player's, resolved through `core/player.lua`.
2. A Run that ends with `Crouching` present is a first tap, and the module records when it ended.
3. When `Wants To Run` appears while `Crouching` is present, and a first tap ended within the `Delay` of `IA_Sprint`'s double tap trigger, the input is a double tap.
4. A frame later, the module checks that Run is still held and `Running.Is Running` is present, which covers standing still and too little stamina.
5. If so, the module finishes the active `SGA_Crouch_C` instance found in the pawn's `GameplayAbilityComponent` and adds `Wants To Sprint` through the pawn's `GameplayTagsComponent`, using the containers in `SGA_Sprint_C`'s class defaults.
6. The game stands the player up and moves them at sprint speed. Releasing the key ends Run and the sprint as in vanilla.

`config.sprint_cancels_crouch` defaults to true. False leaves the module uninstalled and the game's behavior vanilla. `main.lua` installs the module behind this switch, like the mod's other optional features.

The player sees: a double tap of Run while crouched and moving stands them up into a full sprint. Holding Run while crouched stays a crouch walk. A double tap that cannot start a sprint changes nothing.

## Tradeoffs

- Detecting the double tap from the Run tag over reading keys. It works with any key binding and follows the game's own timing. The cost is a hook that also fires for NPC tag changes and has to filter them out.
- Adding the game's own `Wants To Sprint` tag over calling `AdvancedMovementComponent:SetTacSprinting`. It leaves the sprint's state and end to the game's Run ability. The cost is a dependency on the tag name, which fails safe to a crouched run after a game patch that renames it.
- A Lua hook over a pak edit. It keeps the feature in Point and Shoot, the mod that owns control changes, and allows the check that the character is really running.
- Reusing the game's crouch end over forcing the stand through the movement component. It keeps the ability state consistent. Under a low ceiling the player stands only once there is room.
