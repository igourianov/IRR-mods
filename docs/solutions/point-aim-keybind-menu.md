# Point aim keybind in the controls menu

## Intent

Make the key for the mod's point aim bind configurable through the game's own controls menu. A row labelled "Point Shooting (Direct)" sits in the vanilla keyboard bindings list, directly under the vanilla "Point Shooting" row. The label tells it apart from the vanilla row, which is the point aim mode switch. The user rebinds it like any vanilla row. The key persists with the rest of the user's bindings and is reset by the page's reset to defaults.

It replaces the fixed H key in `config.lua`. The bind's behaviour (hold to aim straight into point aim, restore the sticky mode on release) is unchanged and stays as `docs/solutions/point-aim-bind.md` describes it.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from recon recorded in `docs/solutions/findings.md` (project rule). Engine names (Enhanced Input, UMG) are not game internals and may be used directly.
- UObject access happens on the game thread only. UObjects are never cached across a level load, and validity is checked with `util.valid` (`CODE_GUIDE.md`). The mod holds no reference to a page or row.
- Nothing runs Lua off the game thread. The tick is a game-thread timer (`docs/solutions/point-aim-bind.md`). `LoopAsync` crashed the game (`docs/solutions/findings.md`, Lua threading).
- The bind is unbound by default. It does nothing until the user assigns a key. So it never collides with a vanilla binding on first install.
- The key is not consumed. If the user assigns a key that a vanilla action also uses, both fire. The mod adds no conflict check of its own beyond what the vanilla row logic does.
- Keyboard and mouse only. A gamepad row is out of scope.
- A mod-side key setting in `config.lua` is ruled out. The controls menu is the one place the key is set, so the two can't disagree.
- A pak or Blueprint asset override of the controls page is ruled out. It breaks on every game patch that touches the page and needs a cooked asset toolchain the project doesn't have.
- A page holds at most one mod row. Two rows on one mapping name lost the bound key.

Verified by recon (`docs/solutions/findings.md`, Enhanced Input user settings and Controls menu):

- The mod's `InputAction`, its `PlayerMappableKeySettings` and an `InputMappingContext` with one unbound mapping can be built at runtime in `/Engine/Transient`. Registering the context with `EnhancedInputUserSettings` adds a row for the mapping name to the active key profile. The objects survive hot reload and are found again by path.
- A `WB_SingleSettingBar_C` created at runtime becomes a working keybinding row when its setup is copied from the `PointShooting` row, its label and `Keybindings` entry point at the mod's action and mapping name, and it runs its own `On_WidgetConstructed` and `Toggle_Widget(false, 0)` after being added. The vanilla row logic then shows, rebinds, applies and saves the key under the mod's mapping name.
- The saved key survives a game restart. Re-registering the context restores it.
- A row can be placed right after `PointShooting` by detaching the rows below it and re-adding them with their slot layout. `PanelWidget` has no insert-at-index function. Layout and navigation are unaffected.
- Several live controls pages exist per session, and only one is on screen. The others' rows are never constructed.
- A post-hook on `WB_SingleSettingBar_C:On_WidgetConstructed` fires when the on-screen page builds its `PointShooting` row. The hook needs the row class loaded, so it is registered once the class exists. The list is changed one timer tick after the hook, not inside it, because the page may still be building its rows.
- With the mod's context active at the lowest priority, the row shows the saved key after a restart, and a vanilla action bound to the same key still fires alongside the mod's bind.


## Scope

Owned:

- `likhos-point-and-shoot/Scripts/keymap.lua`: the mod's Enhanced Input mapping (new module).
- `likhos-point-and-shoot/Scripts/menu.lua`: the controls menu row (new module).
- `likhos-point-and-shoot/Scripts/input.lua`: key resolution for mapped binds.
- `likhos-point-and-shoot/Scripts/triggers.lua`: recognising mapped binds as polled, so `hold` gets a real release.
- `likhos-point-and-shoot/Scripts/config.lua`: the `point_aim` bind entry.
- `likhos-point-and-shoot/Scripts/main.lua`: startup wiring.
- `likhos-point-and-shoot/README.md`: how the user sets the key.
- `docs/solutions/findings.md`: recon results.

Context only: `actions.lua` (`PointAim`, unchanged), `context.lua` (UI gate, unchanged), `util.lua`, `log.lua`, the tick loop in `main.lua` (`docs/solutions/point-aim-bind.md`), the vanilla controls page and Enhanced Input user settings.

## Solution

### Mapping: `keymap.lua`

`keymap.lua` owns the mod's player-mappable mapping. It holds one entry per mapped bind: a mapping name (`LikhosPointShootingDirect`), a display name ("Point Shooting (Direct)") and no default key.

- On each PlayerController acquire it makes sure the mod's `InputAction` and `InputMappingContext` exist in `/Engine/Transient`, that the context is registered with the local player's `EnhancedInputUserSettings`, and that it is in the local player's active input stack. The objects are looked up by path first and constructed only if missing, so a level load or hot reload creates no duplicates. Registration also restores the user's saved key.
- The context sits in the input stack at the lowest priority, below every vanilla context. The controls menu's key buttons show only keys from active contexts (`WB_KeyBindingButton_C:FindInputActionKey` reads `QueryKeysMappedToAction`), so without it the row shows None after a restart even though the key is saved. Nothing listens to the mod's action. The mod reads the key and polls it itself.
- It answers "which keys are mapped to this name right now" from the active key profile, at call time. `None` counts as unbound. Nothing is cached, so a rebind in the menu takes effect on the next poll.
- It exposes the action for `menu.lua` to point its row at.

### Bind definition: `config.lua` and `input.lua`

The `point_aim` bind in `config.lua` names its mapping (`mapping = "LikhosPointShootingDirect"`) instead of a key. `engine_key` is gone.

`input.lua` polls mapped binds every tick. It asks `keymap.lua` for the bind's keys and checks each with `IsInputKeyDown` on the PlayerController. The bind is down while any mapped key is down. With no key mapped, the bind is idle. Press, release, the UI gate and the forced release when a menu opens mid-hold go into `triggers.lua`, which treats mapped binds as polled: its hold mode runs the held side every tick and ends on the real release, not on a timeout.

Binds with a UE4SS `key` keep using `RegisterKeyBind`.

### Menu row: `menu.lua`

`menu.lua` adds the mod row to each controls page when that page's `PointShooting` row finishes its own setup. For that page it:

- skips the page if its `SettingsContainer` already holds a mod row,
- creates a `WB_SingleSettingBar_C` for the page and copies the `PointShooting` row's bar type, `SettingBar` and `Keybindings`,
- sets the label to "Point Shooting (Direct)" and the `Keybindings` entry's action and mapped name to the mod's,
- places it in `SettingsContainer` directly after `PointShooting`, carrying the slot layout of each row it moves,
- runs the row's own `On_WidgetConstructed` and `Toggle_Widget(false, 0)`.

From there the vanilla row logic owns it: showing the key, capturing a new one, `MapPlayerKey`, apply, save and reset to defaults. The mod doesn't hook those.

If the page's container, the `PointShooting` row or the mod's mapping can't be found, the row is skipped with one log line, and the bind keeps whatever key is saved.

### Startup: `main.lua`

`main.lua` registers the mapping through `keymap.lua` on PlayerController acquire and sets up the `menu.lua` hook once. Both are idempotent under hot reload.

`kb_status` shows each mapped bind's current keys, or "unbound".

### Instructions: `README.md`

Tells the user to set the key under Settings, Controls, "Point Shooting (Direct)", and that it's unbound until they do.

### Result

The vanilla keyboard bindings list shows "Point Shooting (Direct)" under "Point Shooting". It starts unbound. The user assigns a key, applies, and holding that key aims straight into point aim. The choice survives a restart and is cleared by the page's reset to defaults. Removing the mod removes the row. The saved key stays in the user's settings file and does nothing.

## Tradeoffs

- Enhanced Input user settings over a mod-side key store: the vanilla row, save and reset work without the mod reimplementing them, at the cost of runtime-constructed input objects and an orphaned saved row after uninstall.
- Adding the context to the input stack at the lowest priority, over registering it with user settings only: the row shows the saved key like a vanilla row, at the cost of an Enhanced Input action firing on the key with no listener, and of re-adding the context on each PlayerController acquire. The key is still not consumed, so a vanilla action on the same key fires too.
- Cloning the vanilla row over building a new widget: it looks and behaves exactly like vanilla rows, at the cost of depending on `WB_SingleSettingBar_C`'s variables (`BarType`, `SettingBar`, `Keybindings`) and events (`On_WidgetConstructed`, `Toggle_Widget`), which a game patch can rename.
- Placing the row under Point Shooting over appending it to the list: it sits in the right section, at the cost of detaching and re-adding every row below it on each page build.
- Polling the mapped key over reading the action's value: `FInputActionValue` can't be read from UE4SS Lua (`docs/solutions/findings.md`), so polling is the only option. It keeps the one-tick latency of the current bind.
