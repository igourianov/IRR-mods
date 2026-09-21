# 1.0.53
* fixed occasional crash on mod hot reload

# 1.0.50
* new keybind for flashlight activation

# 1.0.49
* direct point aim no longer turns on flashlights; it turns on the first visible laser with NVG off, or the first IR laser (falling back to the first visible laser) with NVG on

# 1.0.48
* fixed a crash after reloading mods from the UE4SS console

# 1.0.47
* direct point aim picks the aiming device by night vision state:
  * NVG off: the first visible laser, or the first visible flashlight if the weapon has no visible laser
  * NVG on: the first IR laser and the first IR light, or the first visible laser if the weapon has neither; a visible flashlight is never turned on
* devices the hold turned on are turned off on release; a device that was already on is left on

# 1.0.45
* direct point aim turns on the weapon's visible laser while held and turns it off on release; a laser that was already on is left on
* fixed the mod failing to load when the controls menu was not ready at game start

# 1.0.36
* zip now holds the bare mod folder: extract it straight into `ue4ss\Mods`

# 1.0.35
* initial release
* added key binding for direct point aim access
