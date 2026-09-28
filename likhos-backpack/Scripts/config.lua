-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).

return {
    -- "error" | "warn" | "info" | "debug"
    log_level = "debug",

    -- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
    enabled = true,

    -- Dropping a 1x1 item onto another 1x1 item it can't stack with or go into swaps the two.
    -- Set false for the vanilla behavior, where the dragged item returns to its slot.
    inventory_swap = true,
}
