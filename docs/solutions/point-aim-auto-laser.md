# Point aim auto laser

## Intent

While the Point Shooting (Direct) bind is held, the visible laser on the equipped weapon is on. Pressing the bind turns on a visible laser that is off. Releasing it turns that laser off again. A laser that was already on when the bind was pressed is left alone, and stays on after release.

Vanilla laser control is a single on/off key, a cycle key that steps through every combination of the weapon's tactical devices and a radial menu for toggling single devices. It resets on weapon switch. The bind gives point shooting a laser without going through any of that.

## Constraints and assumptions

Constraints:

- Game class, function and property names come from the UE4SS object dump or Live View and are recorded in this doc (project rule).
- UObject access happens on the game thread only, UObjects are never cached across a level load and validity is checked with `util.valid` (`CODE_GUIDE.md`).
- Only visible lasers are touched. Flashlights and IR lasers are left in whatever state they are in. The mod never switches a device's infrared mode.
- A laser is visible when its `LaserSettings.DefaultLaserMaterial.Laser` is the `MI_LaserRed` asset. Any other material, `MI_LaserGreen` (IR) or one added by a later patch, is not treated as visible.
- The infrared flags (`bHasInfraredMode`, `bDeviceInfraredOn`, `IsInInfraredMode()`) are ruled out as the tell: they read false on IR lasers. The component name (`Laser_A`, `Laser_B`) is ruled out too: single-laser devices name theirs `Laser`. The laser mesh's live material is ruled out in favour of the asset it is made from.
- The bind drives one laser: the first visible laser in the weapon's `TacticalAttachments` order. If that laser is already on at press time, the bind does nothing with lasers, even when another visible laser is off. Other visible lasers on the weapon are never touched. A laser the bind didn't turn on is never turned off by it.
- The feature is always on as part of the `PointAim` action. No config switch.
- A weapon switch during the hold is handled like the point sight mode in `docs/solutions/point-aim-bind.md`: release restores nothing on the new weapon and doesn't reach back to the old one. Vanilla resets tactical devices on weapon switch anyway (user report, unverified).
- With no visible laser on the weapon, the bind behaves exactly as without this feature.
- No hooks on `TacticalComponent` or `WeaponComponent` functions. Native hooks there crashed the game when the vanilla toggle fired.

Verified by recon (Recon below, Tactical devices):

- The equipped weapon's `WeaponComponent.TacticalAttachments` lists one component per emitter. Each laser emitter is its own `LaserComponent`, so a two-laser device (CQBL-1, PEQ-15) has a visible and an IR component.
- `SetDeviceState` on a single `LaserComponent` turns that emitter on and off on screen, alone.
- After the mod sets a laser's state directly, the vanilla toggle key, cycle key and radial menu keep working normally.
## Scope

Owned:

- `likhos-point-and-shoot/Scripts/actions.lua`: the laser part of the `PointAim` action.
- `likhos-point-and-shoot/Scripts/probe.lua`: throwaway recon console commands. Not part of the end state.
- The Recon section of this doc: recon results under Tactical devices.

Context only: the rest of `PointAim` (point sight mode and aim injection, `docs/solutions/point-aim-bind.md`), `triggers.lua` and `input.lua` (press, held and release events, level load reset), `util.lua`, `log.lua`, the vanilla tactical device controls.

## Solution

### Laser handling in `PointAim`

`actions.lua` resolves the laser from the same equipped weapon's `WeaponComponent` that the point sight mode already uses (`resolve_aim_objects`). It resolves it by name at call time and holds no UObject between press and release.

- Press: before aim is injected, the first visible `LaserComponent` in `TacticalAttachments` is found. If it is off, it is set to `On` and its full name is recorded in the existing per-hold state next to the point sight flag and weapon identity. If it is on, or there is none, nothing is recorded.
- Held: nothing laser related.
- Release: if the equipped weapon is still the one recorded at press, the recorded component, found again by full name, is set to `Off`. If the weapon changed, nothing is restored, as with the point sight mode. If the player turned it off mid-hold, release leaves it off.
- Level load clears the record with the rest of the per-hold state (`actions.reset`).
- A missing or renamed game name (the `LaserComponent` class, a property) makes the laser part do nothing: press still aims into point sight. The failure logs once per session. A moved `MI_LaserRed` asset path can't be told apart from a weapon with no visible laser, so it fails silently.

### Result

On a weapon with a visible laser, holding the bind aims into point sight with its first visible laser on, and releasing it drops aim with that laser off. If that laser was already on, it stays on through and after the hold. Further visible lasers, IR lasers and flashlights are unaffected. On a weapon without a visible laser, the bind works as before.

## Tradeoffs

- Per component `SetDeviceState` over the vanilla toggle path (injected `IA_ToggleTacticalAttachments` or `WeaponComponent:ToggleCurrentTacticalOption`): only the visible laser changes, independent of which combination the vanilla cycle has selected, and the "already on" check is exact per device. The cost is bypassing the ability and option bookkeeping. The vanilla controls were seen to cope with it.
- Only the laser the bind turned on is turned off: a laser the player turns on mid-hold stays on after release. Matches "no action if it was already on" without tracking the player's own toggles.
- One laser, the first in attachment order, over every visible laser: a weapon with several visible lasers shows a single beam. Which one is picked follows the game's attachment order, not the player's choice.
- Matching the visible laser by the `MI_LaserRed` asset over "anything not `MI_LaserGreen`": an IR laser with a new material is never lit, at the cost of ignoring a visible laser of any other color until the rule is extended. It also ties the feature to a third-party asset path that a patch could move.
- An on laser is visible to other players and AI (`IRRBaseCharacter:ActiveTacticalDevices`). Accepted as the point of the feature.

## Recon

### Tactical devices

From the object dump and `kb_probe_laser` / `kb_probe_laser_set`, 2026-09-19 in the hideout, on an AUG A3 (CQBL-1 laser, APLc flashlight) and a SCAR-L (PEQ-15, Klesch 2IKS3, CQBL-1).

- `WeaponComponent:TacticalAttachments` on the equipped weapon's `BP_WeaponComponent` lists one component per emitter across all mounted devices. Lasers are `LaserComponent` (native, subclass of `TacticalComponent`). Lights are `BP_FlashlightComponent_C`.
- Each laser emitter is its own component. Two-laser devices name them `Laser_A` and `Laser_B`. The single-laser Klesch names it `Laser`.
- `TacticalComponent` state: `DeviceState` (`EIRRTacticalDeviceState`: `Off` = 0, `On` = 1), `GetDeviceState()`, `IsDeviceActive()`.
- The infrared flags don't mark IR lasers. `bHasInfraredMode`, `bDeviceInfraredOn` and `IsInInfraredMode()` read false on every laser, including the on IR ones. The PEQ-15's flashlight has `bHasInfraredMode = true` (IR illuminator mode).
- Visible vs IR laser shows in `LaserComponent.LaserSettings.DefaultLaserMaterial.Laser` (`IRRLaserSettings` → `IRRLaserMaterial`), an asset reference. `LaserSettings.InfraredLaserMaterial.Laser` is nil on all lasers seen.

| Device | Component | `DefaultLaserMaterial.Laser` | Seen in game |
|---|---|---|---|
| Steiner CQBL-1 | `Laser_A` | `MI_LaserGreen` | IR |
| Steiner CQBL-1 | `Laser_B` | `MI_LaserRed` | visible |
| PEQ-15 LA-5 | `Laser_A` | `MI_LaserGreen` | IR |
| PEQ-15 LA-5 | `Laser_B` | `MI_LaserRed` | visible |
| Zenitco Klesch 2IKS3 | `Laser` | `MI_LaserRed` | not checked |

Material paths: `/Game/ThirdParty/SKGShooterFramework/Assets/Firearm/FirearmParts/LightLaser/Materials/Red/MI_LaserRed.MI_LaserRed` and `.../Green/MI_LaserGreen.MI_LaserGreen`. The laser mesh itself carries a per-instance `MaterialInstanceDynamic` (`MID_MI_LaserRed_<n>`) made from it.

- `SetDeviceState(1)` / `SetDeviceState(0)` on one laser component, called from Lua, turns that emitter on and off on screen, alone. The vanilla toggle key, cycle key and radial menu keep working normally afterwards.
- `LocTacticalAttachmentOptions` is the vanilla cycle list: an array of `IRRTacticalAttachmentOption` (`TacticalAttachments`, `bEnabled`), one per combination of emitters (5 on the AUG, 35 on the SCAR). `GetCurrentTacticalOption().bEnabled` followed a probe `SetDeviceState` on the AUG.
- Native hooks (`RegisterHook`) on `TacticalComponent` and `WeaponComponent` functions registered fine, and the game crashed without a dump when the vanilla toggle fired `WeaponComponent:ToggleCurrentTacticalOption` with them active. The toggle didn't crash without the hooks. Don't hook these.
- Reading `LocalAttachmentBase.LaserIndex` / `FlashlightIndex` returned a `TrivialObject`, not a number. `GameplayTags` could not be enumerated with `ForEach`. Neither is needed.
