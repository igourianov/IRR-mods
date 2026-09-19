# Likho's Point and Shoot

Adds a keybinding, **Point Shooting (Direct)**, that goes straight into point aim without passing through regular aim.

Point aim is a quick aiming mode for close range engagement. Its advantage over gun sights is speed, which is lost when it takes an extra step through regular aim. This mod restores that use case.

Hold mode only (no toggle). Recommended to bind the new key to a mouse side button for quick access.

While the key is held, the weapon's laser is turned on and turned off again on release. A laser that was already on is left alone.

- **NVG off:** the first visible laser.
- **NVG on:** the first IR laser. If the weapon has no IR laser, the first visible laser.

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
5. Launch the game and assign a key under Settings > Controls > "Point Shooting (Direct)".

## Uninstall

Delete the `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\likhos-point-and-shoot` folder.

## Troubleshooting

- **Nothing happens.** Open `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` and look for `[PointAndShoot]` lines.
- **Broke after a game update.** Expected. Wait for the mod update.
