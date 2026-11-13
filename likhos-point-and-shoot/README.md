# Likho's Point and Shoot

Tactical shortcuts and control tweaks, all usable without opening the inventory or menus.

## Point Shooting

Point shooting is faster than gun sights at close range, but vanilla's controls make it slow to enter.

Adds **Point Shooting + Laser (Hold)** keybind, which goes straight into the point shooting pose without aiming. Hold only. Binding it to a mouse side button works well.

## Laser activation

**Point Shooting + Laser (Hold)** additionally activates the first laser module it finds equipped on the gun.

Contextual to NVG:

- **NVG off:** the first visible laser.
- **NVG on:** the first IR laser. If the weapon has no IR laser, the first visible laser.

## Flashlight (Hold/Toggle)

New keybind to turn on your weapon light without opening the radial menu or cycling through activation modes.

Works as both momentary switch and toggle. Follows the same NVG rules as the laser.

## Hold Breath

Vanilla **Hold Breath** is toggle only. The mod adds hold: keep the key down and releasing it lets the breath out. A tap still toggles.

## Interact (Instant)

New keybind **Interact (Instant)** that mimics vanilla **Interact** behavior but without hold delay. Tap it to open containers instantly. Locked containers will still use unlock delay, but do not require holding the key. The vanilla binding is unaffected.

## Smart Heal

New keybind **Smart Heal (Tap/Hold)**, a smarter alternative for vanilla's **Quick Heal**, which tends to start a 14-second IV when you need a 2-second morphine shot. Uses items from anywhere in your inventory.

Each press uses one item and picks the fastest one for the job. Among equally fast items it uses single-purpose items before the MFAK, and partly used items before fresh ones.

**Tap** takes a painkiller: morphine, the MFAK's injection or Painkillers. It works even with a dose active, refreshing it.

**Hold** treats the first that applies. Hold again for the next problem.

1. Heavy bleed.
2. Bleed.
3. Fracture.
4. Any health missing: the IV that best covers it.

## Use Adrenaline

New keybind **Use Adrenaline**. Press it to inject an Adrenaline Injector from anywhere in your inventory, without opening it. Pressing during an active boost restarts it.

## Consume Food/Drink

New keybind **Consume Food/Drink** that works like vanilla **Quick Heal** but for food and drinks. Press it to eat or drink the first food or drink item found in your inventory, without opening it. Medical items are never used.

## Magnifier binding

The EOTech+Magnifier combo now works using the mouse scroll, the same way an LPVO does. The old binding still works but is no longer needed.

## Low ready by default

Vanilla auto low ready waits 10 seconds after aiming or running before lowering the gun, so it rarely engages. The mod removes that delay: the gun lowers as soon as aiming, sprinting, firing or any other action ends. Reloading and interacting keeps it lowered.

Turn on auto low ready in the gameplay settings. That setting stays your switch for this feature, and your saved settings are not changed. With it on, the **Low Ready** keybind has no effect, since the gun lowers again right away.

## Objective markers

Quest objectives are marked with a bright blue ring instead of vanilla's pale grey one, which blends into foliage. Their marker shows from at least 10 m away, where vanilla shows some only within 3.5 m. You no longer need the map to find them. Marked:

- Placement spots, where you plant a bomb, bug or similar item.
- Mission phones.
- Quest items to pick up, such as documents, USB drives and key cards.
- Mission boxes, which hold a mission's items.

Other interaction markers stay vanilla.

## Configuration

Options are in `Scripts\config.lua`.

- `hold_breath`: set `enabled = false` to restore the vanilla toggle.
- `low_ready_default`: `false` restores the game's own auto low ready.
- `plant_marker`: `false` restores the vanilla objective markers.
- `plant_marker_color`: ring color. Default `#33B5FF`.
- `plant_marker_range`: distance in meters where an objective marker first shows. Default 10, 0 for vanilla.

## Requirements

- Incursion Red River, Steam version. Tested on build 26487830.
- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) experimental release, installed separately. It is not included in the mod zip. Tested with the release of 2026-11-07 (v3.0.1-1217). The stable 3.0.1 does not work with this game. If you already have it installed for another mod, skip to step 4.

## Installation

1. Download the `UE4SS_v3.0.1-*.zip` file from the [UE4SS experimental release](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) and extract it into `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\`. You should end up with `dwmapi.dll` and a `ue4ss` folder there.
2. In `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS-settings.ini` set the engine version. The game crashes on the first tick without it:

   ```ini
   [EngineVersionOverride]
   MajorVersion = 5
   MinorVersion = 6
   ```

3. Launch the game once. If `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` appears, UE4SS works.
4. Extract `likhos-point-and-shoot.zip` into `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\`. You should end up with a `likhos-point-and-shoot` folder there.
5. Launch the game and assign the new keys under Settings > Controls, in the **Likho's Actions** section at the top.

## Uninstall

Delete the `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\likhos-point-and-shoot` folder.

## Troubleshooting

- **Nothing happens.** Open `steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` and look for `[PointAndShoot]` lines.
- **Broke after a game update.** Expected. Wait for the mod update.
