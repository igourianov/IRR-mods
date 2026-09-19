# Likho's Point and Shoot

Hold a key to aim straight into point shooting in Incursion Red River.

**Status: pre-alpha.** Tested on Steam build 22417726 with UE4SS experimental build `f6d5f942`.

## Features

**Point Shooting (Direct).** Hold a key to aim straight into point shooting. Release it to stop. Adds a row to Settings > Controls, directly under "Point Shooting". The row is unbound until you assign a key. It is saved with your other bindings and cleared by "reset to defaults".

## Requirements

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) experimental release, installed separately. It is not included in the mod zip. Tested with build `f6d5f942` (UE4SS.log reports `v3.0.1 Beta #0 - Git SHA #f6d5f942`). The stable 3.0.1 does not work with this game. This is the same UE4SS setup the other IRR Lua mods on Nexus use, described on [UE4SS Experimental for Incursion Red River](https://www.nexusmods.com/incursionredriver/mods/42). If you already have it installed for another mod, skip to step 4.

## Installation

1. Download the `UE4SS_v3.0.1-*.zip` file from `https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest` (the stable 3.0.1 cannot scan this game) and extract it into `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\`. You should end up with `dwmapi.dll` and a `ue4ss` folder there.
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
