-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).
--
-- The key is set in the game's controls menu under the mapping's name (keymap.lua) and polled every tick, so the action gets a real press and release.
-- What the action does with them is its own: PointAim runs from press until release, Flashlight tells a tap from a hold.
--
-- mapping: a player-mappable key name from keymap.lua.
-- action:  a key into the ACTIONS table in actions.lua.

return {
    -- "error" | "warn" | "info" | "debug"
    log_level = "info",

    -- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
    enabled = true,

    -- Tick loop interval, milliseconds.
    -- 16ms ~= one frame at 60fps. Raise if you see CPU cost in the console.
    tick_ms = 16,

    -- How long a hold-or-toggle key may be held and still count as a tap, milliseconds.
    -- Released inside this window, the light it turned on stays on until the next press. Held past it, the light goes off on release.
    tap_ms = 250,

    -- The zoom input folds and unfolds the magnifier on a hybrid sight: scroll forward unfolds, scroll back folds.
    -- Set false for vanilla zoom.
    magnifier_zoom = true,

    binds = {
        {
            id      = "point_aim",
            enabled = true,
            mapping = "LikhosPointShootingDirect",   -- Settings > Controls > Point Shooting (Direct)
            action  = "PointAim",     -- hold to aim straight into point sight
            block_in_ui = true,
        },
        {
            id      = "flashlight",
            enabled = true,
            mapping = "LikhosFlashlight",   -- Settings > Controls > Flashlight (Hold/Toggle)
            action  = "Flashlight",   -- tap to leave the light on, hold to light it while held
            block_in_ui = true,
        },
    },
}
