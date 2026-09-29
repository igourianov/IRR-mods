# Likho's Backpack

This mod provides several QoL improvements to inventory management.

## Item swap

Items in the inventory grids can now be swapped via drag and drop without moving the target item to a third spot first.
Equipment and attachment slots not supported
Source and target item must be the same size (rotation supported)

## Spent medical items

Bandages and Painkillers now drop automatically after exhausting their use count.

## Whole use counts

Use counter on inventory tiles of medical items, keys and quest items now shows as whole values, reducing the visual clutter.

## Quick sell

`Shift+Click` an item while in the hideout to sell it, the same as Sell from its context menu. Items that can't be sold are not affected.

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
4. Extract `likhos-backpack.zip` into `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\`. You should end up with a `likhos-backpack` folder there.

## Uninstall

Delete the `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\likhos-backpack` folder.

## Troubleshooting

- **Nothing happens.** Open `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` and look for `[Backpack]` lines.
- **Broke after a game update.** Expected. Wait for the mod update.
