# Likho's Backpack

This mod improves inventory handling.

## Item swap

Dropping a 1x1 item onto another 1x1 item swaps the two, where vanilla returns the dragged item to its slot. Works within a grid, between grids and between your inventory and a stash, loot container or body.

Drops that stack, put the item inside the target or place it on free space work as in vanilla. Larger items, equipment slots, quick slots and weapon attachments are not affected.

Set `inventory_swap = false` in `Scripts\config.lua` to turn it off.

## Spent medical items

Bandages and Painkillers now drop automatically after exhausting their use count. Set `medic_drop = false` in `Scripts\config.lua` to turn it off.

## Whole use counts

Use counter on inventory tiles of medical items, keys and quest items now shows as whole values, reducing the visual clutter. Set `whole_uses = false` in `Scripts\config.lua` to turn it off.

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
