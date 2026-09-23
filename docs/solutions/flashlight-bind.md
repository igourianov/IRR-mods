# Flashlight bind

## Intent

A second player-mappable key, **Flashlight (Hold/Toggle)**, turns the equipped weapon's flashlight on and off. It picks the light that suits the player's vision, the way the point aim bind picks the laser, and the one key serves both hold and toggle use.

- NVG off: the first visible light.
- NVG on: the first IR light. With no IR light on the weapon, the first visible light.

One key, two gestures, decided by how long it is held:

- Press turns the chosen light on.
- Released within the tap window it stays on. It is then an ordinary lit light, turned off by the next press of the key or by the vanilla controls.
- Held past the tap window it goes off on release.
- Pressed while the chosen light is already on, whoever turned it on, it goes off at once and that press does nothing further.

The point aim bind keeps its current behavior: it touches lasers only and never a light.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from a UE4SS dump or Live View and are recorded in a solution doc (project rule). The ones used here are in the Recon sections of `docs/solutions/point-aim-auto-laser.md` and `docs/solutions/point-aim-devices.md`.
- UObject access happens on the game thread only, UObjects are never cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The mod never switches a device's infrared mode (`SetInfraredMode`, `ToggleInfraredMode`). A light's class is read from what it is, never changed.
- A light is IR when `TacticalComponent.bHasInfraredMode` is true and visible when it is false. Per the user, the PEQ-15's light is the only IR light in the game and it is IR only, so no light changes class at runtime.
- "First" means first of that class in the weapon's `TacticalAttachments` order. Other lights of the same class are never touched.
- NVG state is read once, at press. Toggling NVG during a hold changes nothing until the next press.
- The light chosen at press is the one release turns off, found again by full name. A weapon switch during the hold is handled like the point sight mode in `docs/solutions/point-aim-bind.md`: release restores nothing on the new weapon and doesn't reach back to the old one.
- Ruled out: a separate toggle-off key, a double tap gesture and a fixed non-configurable tap window. The tap window is a config value.
- Ruled out for the flashlight action only: the laser rule that the mod never turns off a device it didn't turn on. The key is a flashlight switch, so a press on a lit light turns it off whatever lit it. The laser side of `PointAim` keeps that rule.
- No hooks on `TacticalComponent` or `WeaponComponent` functions. Native hooks there crashed the game when the vanilla toggle fired (`docs/solutions/point-aim-auto-laser.md`, Recon, Tactical devices).
- The controls menu row is anchored on the vanilla `PointShooting` row, the only anchor verified by recon. Both mod rows sit below it, in mapping order.

Verified by recon (`docs/solutions/point-aim-auto-laser.md` and `docs/solutions/point-aim-devices.md`, Recon):

- `WeaponComponent.TacticalAttachments` lists one component per emitter. Lights are `BP_FlashlightComponent_C`, whose native parent `/Script/Test_C.FlashlightComponent` matches both lights seen. Both lights and lasers derive from `TacticalComponent`, which carries `DeviceState` (`Off` = 0, `On` = 1) and `SetDeviceState`.
- `bHasInfraredMode` is true on the PEQ-15's light and false on the SureFire Mini Scout. Unlike on lasers, the flag is meaningful on lights.
- `SetDeviceState` on one light component turns that light on and off alone.
- `IRRNightVision_Subsystem:IsInfraredModeEnabledOnPlayer()` returns true while the local player's NVG is on. The subsystem is a per-level object, found with `FindFirstOf` at call time.
- A mod key row is built by cloning the vanilla `PointShooting` row, pointing it at a runtime `InputAction` registered through `EnhancedInputUserSettings` and inserting it into `SettingsContainer` (`docs/solutions/point-aim-keybind-menu.md`).

Assumptions the build checks:

- Two mod mappings coexist: each gets its own row in the active key profile, each row rebinds and saves independently and both keys come back after a game restart. Recon only ever put one mod row on the page, and a duplicate row for the *same* mapping lost its key that session (`docs/solutions/point-aim-keybind-menu.md`, Recon, Controls menu).
- The vanilla flashlight controls (toggle key, cycle key, radial menu) keep working after the mod sets a light's state, as they do after it sets a laser's state. Recon confirmed this for lasers only.
- The 16 ms poll interval resolves the tap window closely enough that a deliberate tap and a deliberate hold are never confused.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/devices.lua`: device classification, NVG state, selection and device state reads and writes, for lights as well as lasers.
- `likhos-point-and-shoot/Scripts/actions.lua`: the `Flashlight` action and the device part of `PointAim`.
- `likhos-point-and-shoot/Scripts/keymap.lua`: the mod's mappings.
- `likhos-point-and-shoot/Scripts/menu.lua`: the mod's controls menu rows.
- `likhos-point-and-shoot/Scripts/config.lua`: the bind list and the tap window.
- `likhos-point-and-shoot/README.md`, `CHANGELOG.md`, `mod.txt`: the user-facing description of the new key and the version it ships in.

Context only: `input.lua` and `triggers.lua`, which already deliver press, held and release per bind and reset on level load, `context.lua`'s UI gate, `util.lua`, `log.lua`, the point sight and aim injection half of `PointAim` (`docs/solutions/point-aim-bind.md`), the vanilla tactical device and NVG controls.

## Solution

### `devices.lua`

Owns every game name to do with tactical devices and NVG. Works on a `WeaponComponent` handed in by the caller and holds no UObject between calls. A missing or renamed game name raises; the caller decides what a failure means.

- Classifies each `TacticalAttachments` entry by kind and vision class: lasers by their `LaserSettings.DefaultLaserMaterial.Laser` asset (`MI_LaserRed` visible, `MI_LaserGreen` IR, anything else neither), lights by `bHasInfraredMode`.
- Reads NVG state from `IRRNightVision_Subsystem`.
- Selection, given a weapon component and a kind: with NVG on, the first IR device of that kind, falling back to the first visible one; with NVG off, the first visible one. The same rule for lasers and lights. Nil when the weapon has neither.
- Reads and sets a device's on/off state, and finds a device again on a weapon component by the full name a caller recorded earlier.

### `actions.lua`

Holds no knowledge of device classes, materials or NVG. Each action keeps a per-hold record of plain values only, cleared by `M.reset` on level load.

`PointAim` is unchanged in behavior: press selects the laser and turns it on if it is off, release turns off only a laser that same press turned on, and a device failure never fails the action. Its record carries the point sight flag, the weapon identity and the full name of the laser the press turned on, if any.

`Flashlight` is a new entry in `M.ACTIONS` with a press and a release side and nothing on held.

- Press: selects the light for the current NVG state on the equipped weapon's component. A light already on is turned off and the press ends there, leaving a record that release ignores. A light that is off is turned on, and the record carries its full name, the weapon identity and the moment of the press.
- Release: with a light this press turned on, still on the same weapon, and the press held longer than the tap window, the light goes off. Otherwise nothing happens and the light stays on.
- The tap window comes from `config.lua`. The elapsed time is measured in `actions.lua`, since `triggers.lua` reports the press and release without timing them.
- A device failure logs once per session, as the `PointAim` device failure does, and leaves the key inert rather than failing the tick.

### `keymap.lua` and `menu.lua`

`keymap.MAPPINGS` gains a second entry, `LikhosFlashlight`, displayed as "Flashlight (Hold/Toggle)". Everything else about registration is unchanged: both actions and both mappings are built into the single mod `InputMappingContext`, registered with `EnhancedInputUserSettings` and added to the input stack at the lowest priority.

`menu.lua` places several mod rows under one vanilla anchor row. The `PointShooting` row anchors both, and they appear below it in the order the mod declares them. A row already present for a mapping is not added twice.

### `config.lua`

Gains a `flashlight` bind on the `LikhosFlashlight` mapping and the `Flashlight` action, blocked in UI like `point_aim`, and a top-level tap window in milliseconds, documented as the line between a tap that leaves the light on and a hold that ends with it off. Default 250.

### Result

The player binds a key under Settings > Controls > "Flashlight (Hold/Toggle)". Tapping it lights the weapon's flashlight and leaves it lit; tapping again puts it out. Holding it lights the flashlight for as long as the key is down. Under NVG it lights the IR illuminator instead when the weapon has one. Pressing it while the light is already on always puts it out. The point aim key is unaffected and still turns on a laser only.

## Tradeoffs

- One key with a timed gesture over two keys: one binding covers both use cases, at the cost of a tap window the player can't feel and a very short hold that reads as a tap.
- True toggle over the laser rule for lights: the key always does something visible, at the cost of the two binds following different rules about devices the player turned on.
- Visible light fallback under NVG over doing nothing: the key is never silent, at the cost of blooming the goggles when the weapon has no IR illuminator.
- NVG read at press only, as for lasers: the per-tick path stays device free, and toggling NVG mid-hold leaves the wrong light on until release.
- Per component `SetDeviceState` over the vanilla toggle path: exact per device and independent of the vanilla cycle selection, at the cost of bypassing the option bookkeeping.
- An on light is visible to other players and AI, an IR one to those with NVG. Accepted as the point of the feature.
