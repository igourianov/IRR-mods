# Likho's Point and Shoot

Tactical shortcuts for point shooting, lasers, lights, healing and consumables, all usable without opening the inventory or menus.

## Point Shooting

Point shooting is meant for close range engagement. Its advantage over gun sights is speed, which vanilla's awkward control scheme defeats.

This mod decouples point shooting from aiming. It adds a new keybind **Point Shooting + Laser (Hold)** that allows the user to go directly into point shooting pose, bypassing regular aim.

Hold mode only (no toggle). Recommended to bind the new key to a mouse side button for quick access.

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

In `Scripts\config.lua`, set `enabled = false` on the `hold_breath` bind to restore the vanilla toggle.

## Interact (Instant)

New keybind **Interact (Instant)** that mimics vanilla **Interact** behavior but without hold delay. Tap it to open containers instantly. Locked containers will still use unlock delay, but do not require holding the key. The vanilla binding is unaffected.

## Consume Food/Drink

New keybind **Consume Food/Drink** that works like vanilla **Quick Heal** but for food and drinks. Press it to eat or drink the first food or drink item found in your inventory, without opening it. Medical items are never used.

## Combat Heal

New keybind **Combat Heal (Tap/Hold)**, a smarter alternative for vanilla's **Quick Heal**. Quick Heal tends to get you killed in a firefight: it starts a 14-second IV when what you need is a 2-second morphine shot. Combat Heal treats whatever matters most right now, with items from anywhere in your inventory. Each tap does one thing, the first of these that applies:

1. Below 90% health with no painkiller/morphine dose active: takes it.
2. Heavy bleed: stops it.
3. Bleed: stops it.
4. Fracture: splints it.
5. Any health missing with no painkiller/morphine dose active: takes it.

For each it uses the fastest item that treats it. Among equally fast ones it picks the least wasteful: the item that treats the fewest other things. Tap again to move on to the next problem. A tap never heals and never starts an IV.

Hold the key to start an IV. It starts as soon as the key has been held for a quarter second, without waiting for release, and uses the IV that heals all missing health with the least overheal. With full health or no IV carried, a hold does nothing. In `Scripts\config.lua`, `tap_ms` (default 250) sets how long a press may last and still count as a tap.

## Use Adrenaline

New keybind **Use Adrenaline**. Press it to inject an Adrenaline Injector from anywhere in your inventory, without opening it. A press while a boost is still running restarts it, so the rest of the previous dose is lost.

## Magnifier binding

The EOTech+Magnifier combo now works using the mouse scroll, the same way an LPVO does. The old binding still works but is no longer needed.

## Low ready by default

Low ready is the resting position of the gun. As soon as aiming, sprinting, firing or any other action ends, the gun goes straight back to low ready, standing or moving, instead of after 10 seconds of idle. Reloading and interacting keep it in low ready. Holstering and drawing work as in vanilla.

Turn on auto low ready in the gameplay settings. That setting stays your switch for this feature. Your saved settings are not changed. With it on, the **Low Ready** keybind has no effect, since the gun lowers again right away.

In `Scripts\config.lua`, `low_ready_run_delay_ms` (default 150) sets how long after a run the gun lowers, and `low_ready_default = false` restores the game's own auto low ready.

## Plant spot marker

The marker on a quest placement spot, where you plant a bomb, bug or similar item, is drawn in bright blue, a color rare in the game's world and UI. In vanilla it is a pale grey ring that blends into bark and foliage and stays faint at 20% opacity until you are close enough to plant, so you had to use the map to find it. With the mod it shows at 40% from the moment it appears. Its size, the distance where it appears and the range you can plant from are unchanged. Container, door and every other interaction marker stay vanilla.

In `Scripts\config.lua`, `plant_marker_color` (default `#33B5FF`) sets the color, `plant_marker_min_opacity` (default 0.4, 0 for vanilla) sets the opacity out of reach and `plant_marker = false` restores the vanilla marker.

## Known issues

* **Consume Food/Drink** skips `Misprinted Condensed Milk`. *This is a vanilla bug.* The game tags it as a barter item rather than a food, although it can be consumed.

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
