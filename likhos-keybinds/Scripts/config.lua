-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).
--
-- mode:
--   "passthrough" - fire the action once per press. Remap only.
--   "toggle"      - press flips a latched state; sends press or release.
--   "hold"        - action stays active only while the key is physically down.
--   "double_tap"  - fires only on two presses inside double_tap_window_ms.
--   "tap_hold"    - short press => action_tap, long press => action_hold.
--
-- key: a name from the UE4SS `Key` table (Key.F2, Key.LEFT_SHIFT, ...).
--      Given here as a string; input.lua resolves it and disables the bind
--      if the name does not exist, rather than erroring the whole mod.

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
            id      = "example_sprint_toggle",
            enabled = false,          -- turn on after filling in `action`
            key     = "LEFT_SHIFT",
            modifiers = {},           -- e.g. { "CONTROL" }, { "SHIFT", "ALT" }
            mode    = "toggle",
            action  = "Sprint",       -- key into actions.lua ACTIONS table
            block_in_ui = true,
        },
        {
            id      = "example_lean_double_tap",
            enabled = false,
            key     = "Q",
            modifiers = {},
            mode    = "double_tap",
            action  = "LeanLeft",
            double_tap_window_ms = 250,
            block_in_ui = true,
        },
        {
            id      = "example_use_tap_hold",
            enabled = false,
            key     = "F",
            modifiers = {},
            mode    = "tap_hold",
            action_tap  = "Interact",
            action_hold = "InteractAlt",
            hold_threshold_ms = 300,
            block_in_ui = true,
        },
    },
}
