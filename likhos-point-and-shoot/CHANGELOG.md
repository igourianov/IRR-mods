# Unreleased
* removed the `low_ready_run_delay_ms` option. The gun lowers 150 ms after a run as before

# 1.7.176
* updated for game version 1.4.0.3
* renamed the Use Medical (Tap/Hold) keybind to Smart Heal (Tap/Hold). A key already set on it is kept
* tapping Smart Heal takes the fastest painkiller at any health, even with a dose active, since the game now refreshes the dose
* holding Smart Heal treats a heavy bleed, bleed or fracture, then starts an IV. It uses the fastest item and no longer takes Painkillers
* Consume Food/Drink picks the food or drink by grid position in each container, instead of one from the middle. Smart Heal and Use Adrenaline do the same between items they rank equal

# 1.6.172
* renamed the Combat Heal (Tap/Hold) keybind to Use Medical (Tap/Hold). A key already set on it is kept
* holding Use Medical with no IV and no active dose takes Painkillers. Morphine and the MFAK are left for a tap
* holding Use Medical treats a heavy bleed, bleed or fracture before starting an IV, using the slowest item for it so the fast ones are kept for a fight. It also works at full health
* the blue objective marker also covers mission phones, quest pickups and mission boxes, and shows from at least 10 m away (`plant_marker_range`)
* the objective marker's gear icon stays white and fades out of reach as in vanilla. Only the ring is blue. `plant_marker_min_opacity` is removed

# 1.6.164
* Combat Heal no longer heals or starts an IV on a press. Hold the key to start an IV. The keybind is renamed to Combat Heal (Tap/Hold) and a key already set on it is kept
* Combat Heal takes a painkiller at any missing health when there is nothing else to treat and no dose is active
* the vanilla Hold Breath key also works as hold: keep it down and releasing it lets the breath out. A tap still toggles

# 1.5.161
* the marker on a quest placement spot, where a bomb or bug is planted, is drawn in bright blue so it stands out and stays clearly visible while out of reach. Other interaction markers stay vanilla

# 1.4.144
* added the `Use Adrenaline` keybind: injects an Adrenaline Injector from anywhere in the inventory
* added the `Combat Heal` keybind that intelligently picks a medical item to use

# 1.2.132
* added the Consume Food/Drink keybind: uses the first food or drink item in the inventory, like Quick Heal does for medical items

# 1.1.129
* renamed the Point Shooting (Direct) keybind to Point Shooting + Laser (Hold). A key already set on it is kept

# 1.1.128
* moved the mod's keybinds to their own Likho's Actions section at the top of the controls page

# 1.1.123
* verified on UE4SS experimental v3.0.1-1217 (2026-11-07)

# 1.1.122
* fixed the mod's keybinds sometimes showing as None in the controls menu while still working

# 1.1.117
* fixed the zoom input not folding the magnifier while NVG is on

# 1.1.115
* auto low ready lowers the gun while walking after running
* reduced animation transition jitter

# 1.1.92
* auto low ready lowers the gun right after aiming, sprinting or any other action instead of after 10 seconds of idle

# 1.0.82
* fixed direct point shooting jittering above 60 fps

# 1.0.81
* fixed instant interact softlocking on locked doors/containers after picking up world item

# 1.0.80
* fixed instant interact softlocking after picking up world item

# 1.0.77
* new Interact (Instant) keybind to open containers without hold

# 1.0.73
* moved med item drop on use and whole number item tags out into backpack mod

# 1.0.63
* use counts of medical items, keys and other items with uses show as whole numbers on inventory tiles

# 1.0.60
* spent bandages and painkillers drop on the floor at the end of their use animation, like used health injectors

# 1.0.57
* hooked up magnifier flip to the zoom (mouse scroll) action

# 1.0.53
* fixed occasional crash on mod hot reload

# 1.0.50
* new keybind for flashlight activation

# 1.0.49
* removed flashlights from auto activation

# 1.0.48
* fixed a crash after reloading mods from the UE4SS console

# 1.0.47
* direct point aim picks now picks laser module contextual to NVG

# 1.0.45
* direct point aim turns on the weapon's visible laser while held and turns it off on release; a laser that was already on is left on
* fixed the mod failing to load when the controls menu was not ready at game start

# 1.0.36
* zip now holds the bare mod folder: extract it straight into `ue4ss\Mods`

# 1.0.35
* initial release
* added key binding for direct point aim access
