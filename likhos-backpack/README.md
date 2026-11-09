# Likho's Backpack

This mod provides several QoL improvements to inventory management.

## Whole use counts

Use counter on inventory tiles of medical items, keys and quest items now shows as whole values, reducing the visual clutter. Single use items show no counter until used, then `0/1`. USB hacking devices show their remaining uses as a percentage, e.g. `75%`.

## Quick sell/deliver

`Shift+Click` an item while in the hideout to sell it, the same as Sell from its context menu. A mission item is delivered for its mission instead, the same as Deliver from its context menu. Items that can't be sold or delivered are not affected.

## Quick slot refill

A quick slot now holds an item type rather than a single item. When the item in a quick slot is used up, the slot picks the next item of the same type from the same equipment, e.g. the next Morphine on the chest rig. Partly used items go first. The slot empties once that equipment has none left. Items of the same type elsewhere, e.g. in the backpack for a slot filled from the chest rig, don't refill it. Dropping, discarding or selling the item in a quick slot leaves the slot empty.

A quick slot of a single use item, e.g. an injector, bandage or grenade, shows in the inventory screen how many of its type that equipment holds. With 3 injectors on the chest rig the slot shows 3, while each injector's own tile still shows 1/1.

## Known issues

* Delivering a mission item from the character inventory counts it for the mission but does not remove the item, so it can be delivered again. This is a vanilla bug and applies to Deliver from the context menu too. Deliver mission items from the stash.

## Requirements

- Incursion Red River, Steam version. Tested on build 26487830.
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) experimental release, installed separately. It is not included in the mod zip. Tested with the release of 2026-11-07 (v3.0.1-1217). The stable 3.0.1 does not work with this game. If you already have it installed for another mod, skip to step 4.

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
