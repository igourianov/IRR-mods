-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).
--
-- Binds are held keys. The key is set in the game's controls menu under the mapping's name (keymap.lua) and polled every
-- tick, so the action gets a real release. The action runs from press until release.
--
-- mapping: a player-mappable key name from keymap.lua.
-- action:  a key into the ACTIONS table in actions.lua.

return {
    -- "error" | "warn" | "info" | "debug"
    log_level = "info",

    -- Master switch. Set false to load the mod inert (useful when bisecting
    -- a crash after a game patch).
    enabled = true,

    -- Poll interval for the trigger state machine, milliseconds.
    -- 16ms ~= one frame at 60fps. Raise if you see CPU cost in the console.
    tick_ms = 16,

    binds = {
        {
            id      = "point_aim",
            enabled = true,
            mapping = "LikhosPointShootingDirect",   -- Settings > Controls > Point Shooting (Direct)
            action  = "PointAim",     -- hold to aim straight into point sight
            block_in_ui = true,
        },
    },
}
