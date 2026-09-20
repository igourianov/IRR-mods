# Likho's Point and Shoot

This mod reworks Point Shooting and tactical device activation. 

## Point Shooting

It is meant for close range engagement. Its advantage over gun sights is speed, which is sadly defeated by the vanilla's awkward control scheme.

This mod decouples point shooting from aiming. Adds a new keybind **Point Shooting (Direct)** that allows user to go directly into point shooting pose bypassing regular aim.  

Hold mode only (no toggle). Recommended to bind the new key to a mouse side button for quick access.

## Laser activation

**Point Shooting (Direct)** additionally activates first laser module it finds equipped on the gun.

Contextual to NVG:

- **NVG off:** the first visible laser.
- **NVG on:** the first IR laser. If the weapon has no IR laser, the first visible laser.

## Flashlight (Hold/Toggle)

New keybind to quickly access avilable light without searching through the radial menu or togglling gajillion modes.

Works as both momentary switch and toggle:

- **Tap** (under 250 ms): the light comes on and stays on. Tap again to put it out.
- **Hold:** the light is on while the key is down and goes out when you let go.
- Pressing the key while the light is already on always puts it out, including a light you turned on with the vanilla key.

Contextual to NVG:

- **NVG off:** the first visible flashlight.
- **NVG on:** the first IR illuminator. If the weapon has none, the first visible flashlight.


## Requirements

- Incursion Red River, Steam version. Tested on build 22417726.
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) experimental release, installed separately. It is not included in the mod zip. Tested with the release of 2026-09-16. The stable 3.0.1 does not work with this game. If you already have it installed for another mod, skip to step 4.

## Installation

1. Download the `UE4SS_v3.0.1-*.zip` file from `https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest` and extract it into `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\`. You should end up with `dwmapi.dll` and a `ue4ss` folder there.
2. In `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS-settings.ini` set the engine version. The game crashes on the first tick without it:

   ```ini
   [EngineVersionOverride]
   MajorVersion = 5
   MinorVersion = 6
   ```

3. Launch the game once. If `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` appears, UE4SS works.
4. Extract `likhos-point-and-shoot.zip` into `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\`. You should end up with a `likhos-point-and-shoot` folder there.
5. Launch the game and assign the new keys under Settings > Controls.

## Uninstall

Delete the `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\likhos-point-and-shoot` folder.

## Troubleshooting

- **Nothing happens.** Open `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` and look for `[PointAndShoot]` lines.
- **Broke after a game update.** Expected. Wait for the mod update.
