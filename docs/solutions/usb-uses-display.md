# USB uses display

## Intent

The USB hacking devices' inventory tiles show only their remaining uses as a percentage of the maximum, e.g. `75%`, with no maximum text. Other items keep the whole number display from `docs/solutions/medic-uses-display.md`.

## Recon

From `UE4SS_ObjectDump.txt` (2026-11-08):

- The devices are `/Game/Blueprints/InventorySystem/Items/Barter/USB_Hacking_Device_IGC/ID_USB_Hacking_Device_IGC`, `.../USB_Hacking_Device_UICS/ID_USB_Hacking_Device_UICS` and `.../USB_Hacking_Device_VLF/ID_USB_Hacking_Device_VLF`, all `IRRItemDefinition`.
- Each owns `U_Battery_C_0`, `U_InspectItem_C_0` and `U_Weight_C_0` stat configs and no `U_Content_C`, so the existing filter skips them.
- `U_Battery_C` is `/Game/Blueprints/InventorySystem/Objects/Stats/U_Battery.U_Battery_C`. The three devices are the only items in the dump owning one. The dump lists only what was loaded when it was taken.

## Solution

`whole_uses.lua` maps a stat config class to a tile format: `U_Content_C` to whole numbers, `U_Battery_C` to percent. For percent, one tick after the native write, it reads the numbers the game drew in `ItemCapacity` and `ItemMaxCapacity`, sets `ItemCapacity` to `round(remaining / max * 100)%` and `ItemMaxCapacity` to empty. A tile already rewritten has no number in `ItemMaxCapacity`, so a repeat rewrite does nothing. README, `config.lua` comment and `CHANGELOG.md` describe the percentage.

Ruled out: hiding `ItemMaxCapacity` through visibility, which the native code may not reset for other items reusing the tile. An empty text is overwritten by the next native write.

## Assumptions the build checks

- A device tile draws its remaining and maximum uses in `ItemCapacity` and `ItemMaxCapacity`, like a medical tile, each holding one number.
- No other item uses `U_Battery_C` for a value that should keep decimals.
