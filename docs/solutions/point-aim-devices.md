# Point aim devices

## Intent

While the Point Shooting (Direct) bind is held, the equipped weapon shows the aiming device that suits the player's vision, not a hardcoded visible laser.

- NVG off: the first visible laser. With no visible laser on the weapon, the first visible flashlight.
- NVG on: the first IR laser and the first IR light, whichever of the two the weapon has. With neither on the weapon, the first visible laser. A visible flashlight is never touched while NVG is on.

Pressing the bind turns the chosen devices on. Releasing it turns off the ones the press turned on. A chosen device that was already on at press time is left alone and stays on after release.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from the UE4SS object dump or Live View and are recorded in `docs/solutions/findings.md` (project rule).
- UObject access happens on the game thread only, UObjects are never cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- The mod never switches a device's infrared mode (`SetInfraredMode`, `ToggleInfraredMode`). A device's class is read from what it is, never changed.
- A laser is visible when its `LaserSettings.DefaultLaserMaterial.Laser` is the `MI_LaserRed` asset, and IR when it is `MI_LaserGreen`. A laser with any other material, e.g. one added by a later patch, is neither and is never chosen. The infrared flags are ruled out for lasers: they read false on IR lasers (`findings.md`, Tactical devices).
- "First" means first of that class in the weapon's `TacticalAttachments` order. Other devices of the same class are never touched.
- Selection is by presence, not by state. A class counts as found when the weapon has a device of it, on or off. So with NVG on, an IR laser that is already on still counts, and the visible laser fallback does not happen. The same holds for the visible flashlight fallback when NVG is off.
- NVG state is read once, at press. Toggling NVG during the hold changes nothing until the next press.
- A device the bind didn't turn on is never turned off by it. A device the player turns off mid-hold stays off after release.
- A weapon switch during the hold is handled like the point sight mode in `docs/solutions/point-aim-bind.md`: release restores nothing on the new weapon and doesn't reach back to the old one.
- The feature is always on as part of the `PointAim` action. No config switch.
- No hooks on `TacticalComponent` or `WeaponComponent` functions. Native hooks there crashed the game when the vanilla toggle fired.

Verified by recon (`docs/solutions/findings.md`, Tactical devices):

- `WeaponComponent.TacticalAttachments` lists one component per emitter. Lasers are `LaserComponent`, lights are `BP_FlashlightComponent_C` (native parent `FlashlightComponent`). Both derive from `TacticalComponent`, which carries `DeviceState` and `SetDeviceState`.
- `SetDeviceState` on one laser component turns that emitter on and off alone, and the vanilla toggle, cycle key and radial menu keep working afterwards. On a light component it turns that light on and off too. Vanilla controls after it weren't checked for lights.
- Lights: `TacticalComponent.bHasInfraredMode` tells IR from visible on lights: true on the PEQ-15's light, false on a visible flashlight (SureFire Mini Scout). Unlike on lasers, the flag is meaningful on lights.
- NVG state: `IRRNightVision_Subsystem:IsInfraredModeEnabledOnPlayer()` returns true while the local player's NVG is on. The subsystem is a per-level object, found with `FindFirstOf("IRRNightVision_Subsystem")` at call time (`findings.md`, Night vision).

Known from the game (user):

- The PEQ-15 is the only device whose light is not a visible flashlight. Its light is IR only. Every other light is a visible flashlight, and no light switches between visible and IR. The mod never switching infrared mode therefore loses nothing.

## Scope

Owned:

- `likhos-point-and-shoot/Scripts/devices.lua`: device classification, NVG state and selection.
- `likhos-point-and-shoot/Scripts/actions.lua`: the device part of the `PointAim` action.
- `likhos-point-and-shoot/Scripts/probe.lua`: throwaway recon console commands. Not part of the end state.
- `docs/solutions/findings.md`: recon results under the Tactical devices section and a night vision section.

Context only: the rest of `PointAim` (point sight mode and aim injection, `docs/solutions/point-aim-bind.md`), `triggers.lua` and `input.lua` (press, held and release events, level load reset), `util.lua`, `log.lua`, the vanilla tactical device and NVG controls.

## Solution

### `devices.lua`

Owns every game name to do with tactical devices and NVG. Works on a `WeaponComponent` handed in by the caller and holds no UObject between calls.

- Classifies each `TacticalAttachments` entry as one of: visible laser, IR laser, visible light, IR light, or none of these.
- Reads NVG state from `IRRNightVision_Subsystem`.
- Activation, given the weapon component: picks the target classes from NVG state per the Intent rules, finds the first device of each target class, sets each one that is off to `On` and returns the full names of the devices it switched on. An empty list when nothing was switched.
- Deactivation, given the weapon component and such a list: finds each named device again by full name and sets it to `Off` if it is on.
- A missing or renamed game name makes the call fail as a whole. The caller turns that into doing nothing.

### Device handling in `PointAim`

`actions.lua` keeps its per-hold record of plain values: the point sight flag, the weapon identity and now the list of device names from activation, in place of the single laser name. It holds no knowledge of device classes, materials or NVG.

- Press: before aim is injected, activation runs on the weapon component from `resolve_aim_objects`, and its list goes into the per-hold record.
- Held: nothing device related.
- Release: if the equipped weapon is still the one recorded at press and the list isn't empty, deactivation runs with it. If the weapon changed, nothing is restored.
- Level load clears the record with the rest of the per-hold state (`actions.reset`).
- A device failure never fails the action: press still aims into point sight. The failure logs once per session, as the laser failure does today.

### Result

With NVG off, holding the bind aims into point sight with the first visible laser on, or the first visible flashlight if the weapon has no visible laser. With NVG on, it lights the first IR laser and the first IR light the weapon has, or the first visible laser if it has neither, and never a visible flashlight. Releasing turns off only what the press turned on. On a weapon with nothing matching, the bind works as plain point aim.

## Tradeoffs

- Presence over state for the fallbacks: an IR laser the player already has on still suppresses the visible laser under NVG. The bind never adds a second, redundant device next to one the player chose, at the cost of doing nothing when the player's own device is already on.
- NVG read at press only over following it mid-hold: the held phase stays device free and the per-tick path does no extra reflection. Toggling NVG mid-hold leaves the wrong device on until release.
- Per component `SetDeviceState` over the vanilla toggle path: exact per device and independent of the vanilla cycle selection, at the cost of bypassing the option bookkeeping. The vanilla controls coped with it for lasers.
- Material match for lasers ties the feature to two third-party asset paths a patch could move. A moved path can't be told apart from a weapon without that laser class, so it fails silently.
- An on device is visible to other players and AI, IR devices to those with NVG. Accepted as the point of the feature.
