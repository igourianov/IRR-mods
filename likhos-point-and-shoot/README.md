# Likho's Point and Shoot

Hold a key to aim straight into point shooting in Incursion Red River.

**Status: pre-alpha.** Tested on Steam build 22417726 with UE4SS experimental `v3.0.1-1136-g35d1795d`.

## Features

**Point Shooting (Direct).** Hold a key to aim straight into point shooting. Release it to stop. Adds a row to Settings > Controls, directly under "Point Shooting". The row is unbound until you assign a key. It is saved with your other bindings and cleared by "reset to defaults".

## Requirements

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases) experimental release, installed separately. It is not included in the mod zip. Tested with `v3.0.1-1136-g35d1795d`. The stable 3.0.1 does not work with this game.

## Installation

1. Download the UE4SS experimental release from `https://github.com/UE4SS-RE/RE-UE4SS/releases` (the stable 3.0.1 cannot scan this game) and extract it into `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\`. You should end up with `dwmapi.dll` and a `ue4ss` folder there.
2. In `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS-settings.ini` set the engine version. The game crashes on the first tick without it:

   ```ini
   [EngineVersionOverride]
   MajorVersion = 5
   MinorVersion = 6
   ```

3. Launch the game once. If `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` appears, UE4SS works.
4. Extract `likhos-point-and-shoot.zip` into `steamapps\common\PROJECT QUARANTINE\`. It places the mod in `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\likhos-point-and-shoot\`.
5. Launch the game and assign a key under Settings > Controls > "Point Shooting (Direct)".

## Uninstall

Delete the `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\likhos-point-and-shoot` folder.

## Troubleshooting

- **Nothing happens.** Set `GuiConsoleEnabled = 1` in `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS-settings.ini`, relaunch and look for `[PointAndShoot]` lines.
- **Broke after a game update.** Expected. Check for a new version.
