# USB uses display

## Intent

The USB hacking devices' inventory tiles show their use count as whole numbers, like medical items, keys and the quest poison already do (`docs/solutions/medic-uses-display.md`).

## Recon

From `UE4SS_ObjectDump.txt` (2026-11-08):

- The devices are `/Game/Blueprints/InventorySystem/Items/Barter/USB_Hacking_Device_IGC/ID_USB_Hacking_Device_IGC`, `.../USB_Hacking_Device_UICS/ID_USB_Hacking_Device_UICS` and `.../USB_Hacking_Device_VLF/ID_USB_Hacking_Device_VLF`, all `IRRItemDefinition`.
- Each owns `U_Battery_C_0`, `U_InspectItem_C_0` and `U_Weight_C_0` stat configs and no `U_Content_C`, so the existing filter skips them.
- `U_Battery_C` is `/Game/Blueprints/InventorySystem/Objects/Stats/U_Battery.U_Battery_C`. The three devices are the only items in the dump owning one. The dump lists only what was loaded when it was taken.

## Solution

`whole_uses.lua` matches a tile's item when its definition has a stat config of class `U_Content_C` or `U_Battery_C`. Everything else in the feature is unchanged. README, `config.lua` comment and `CHANGELOG.md` name the devices.

## Assumptions the build checks

- A device tile draws its uses in `ItemCapacity` and `ItemMaxCapacity` with decimals, like a medical tile.
- No other item uses `U_Battery_C` for a value that should keep decimals.
