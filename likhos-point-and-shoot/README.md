# Likho's Point and Shoot

Tactical shortcuts, control tweaks and inventory management improvements.

## Features

- **Point Shooting + Laser (Hold):** new keybind that goes straight into point shooting and turns on the laser.
- **Flashlight (Hold/Toggle):** new keybind for the weapon light, without the radial menu. Follows the same NVG rules as the laser.
- **Hold Breath:** adds hold to the vanilla toggle key. Releasing it lets the breath out, and a tap still toggles.
- **Interact (Instant):** new keybind that opens containers without the hold delay. Locked containers still take the unlock time, but without holding the key. The vanilla **Interact** is unaffected.
- **Smart Heal (Tap/Hold):** new keybind: tap for the fastest painkiller, hold to treat bleeds, fractures and missing health.
- **Use Adrenaline:** new keybind that injects adrenaline from anywhere in the inventory.
- **Consume Food/Drink:** new keybind to consume first food or drink item from anywhere in the inventory.
- **Quick sell:** `Shift+Click` sells an item in the hideout.
- **Quick slot auto refill:** a quick slot refills with the same item type after use.
- **Magnifier binding:** mouse scroll folds and unfolds the EOTech+Magnifier combo, the same way it zooms an LPVO.
- **Low ready by default:** the gun lowers as soon as an action ends.
- **Objective markers:** bright, longer range markers on quest objectives.
- **Item use counts:** less visual clutter in the inventory.

## Point Shooting

Point shooting is faster than gun sights at close range, but vanilla's controls make it slow to enter.

Adds **Point Shooting + Laser (Hold)** keybind, which goes straight into the point shooting pose without aiming. Hold only. Binding it to a mouse side button works well.

It additionally activates the first laser module it finds equipped on the gun. Contextual to NVG:

- **NVG off:** the first visible laser.
- **NVG on:** the first IR laser. If the weapon has no IR laser, the first visible laser.

## Smart Heal

New keybind **Smart Heal (Tap/Hold)**, a smarter alternative for vanilla's **Quick Heal**, which tends to start a 14-second IV when you need a 2-second morphine shot. Uses items from anywhere in your inventory.

Each press uses one item and picks the fastest one for the job. Among equally fast items it uses single-purpose items before the MFAK, and partly used items before fresh ones.

**Tap** takes a painkiller: morphine, the MFAK's injection or Painkillers. It works even with a dose active, refreshing it.

**Hold** treats the first that applies. Hold again for the next problem.

1. Heavy bleed.
2. Bleed.
3. Fracture.
4. Any health missing: the IV that best covers it.

## Quick slot auto refill

Less inventory management: a quick slot refills automatically with an item of the same type after use. It empties once none are left.

For single-use items (injectors, bandages, grenades, etc.), the slot shows how many your inventory holds.

`Click` a quick slot in the inventory screen to clear it. Its item can no longer be dragged out of the slot.

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

# Install UE4SS (required)

The mod runs on the UE4SS experimental release, which is not included in the mod zip. Tested with the release of 2026-11-07 (v3.0.1-1217). The stable 3.0.1 does not work with this game. If you already have it installed for another mod, skip to the mod installation.

1. Download the `UE4SS_v3.0.1-*.zip` file from the [UE4SS experimental release](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) and extract it into `PROJECT QUARANTINE\Test_C\Binaries\Win64\`. You should end up with `dwmapi.dll` and a `ue4ss` folder there.
2. In `PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS-settings.ini` set the engine version. The game crashes on the first tick without it:

   ```ini
   [EngineVersionOverride]
   MajorVersion = 5
   MinorVersion = 6
   ```

3. Launch the game once. If `PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\UE4SS.log` appears, UE4SS works.

# Install this mod

1. Extract `likhos-point-and-shoot.zip` into `PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\`. You should end up with a `likhos-point-and-shoot` folder there.
2. Launch the game and assign the new keys under Settings > Controls, in the **Likho's Actions** section at the top.

To uninstall delete the `PROJECT QUARANTINE\Test_C\Binaries\Win64\ue4ss\Mods\likhos-point-and-shoot` folder.

Every feature added by this mod can be disabled in `Scripts\config.lua`.
