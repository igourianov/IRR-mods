# Likho's Point and Shoot

Hold a key to aim straight into point shooting in Incursion Red River.

**Status: pre-alpha.** Tested on Steam build 22417726 with UE4SS experimental `v3.0.1-1136-g35d1795d`.

## Features

**Point Shooting (Direct).** Hold a key to aim straight into point shooting. Release it to stop. Adds a row to Settings > Controls, directly under "Point Shooting". The row is unbound until you assign a key. It is saved with your other bindings and cleared by "reset to defaults".

## Installation

1. Download the UE4SS experimental release from `https://github.com/UE4SS-RE/RE-UE4SS/releases` (the stable 3.0.1 cannot scan this game) and extract it into `...\steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\`. You should end up with `dwmapi.dll` and a `ue4ss` folder there.
2. In `ue4ss\UE4SS-settings.ini` set the engine version. The game crashes on the first tick without it:

   ```ini
   [EngineVersionOverride]
   MajorVersion = 5
   MinorVersion = 6
   ```

3. Launch the game once. If `ue4ss\UE4SS.log` appears, UE4SS works.
4. Copy the `likhos-point-and-shoot` folder into `ue4ss\Mods\`.
5. Add this line to `ue4ss\Mods\mods.txt`:

   ```
   likhos-point-and-shoot : 1
   ```

6. Launch the game and assign a key under Settings > Controls > "Point Shooting (Direct)".

## Uninstall

Delete the `likhos-point-and-shoot` folder and its line from `mods.txt`.

## Troubleshooting

- **Nothing happens.** Set `GuiConsoleEnabled = 1` in `ue4ss\UE4SS-settings.ini`, relaunch and look for `[PointAndShoot]` lines.
- **Broke after a game update.** Expected. Check for a new version.
