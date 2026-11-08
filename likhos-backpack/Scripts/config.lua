-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).

return {
    -- "error" | "warn" | "info" | "debug"
    log_level = "debug",

    -- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
    enabled = true,

    -- Items that count uses, like medical items and keys, show them as whole numbers on inventory tiles.
    -- USB hacking devices show their remaining uses as a percentage.
    -- Set false for the vanilla decimals.
    whole_uses = true,

    -- Shift+Click on an item in the hideout sells it, like Sell from its context menu. A mission item is delivered instead, like Deliver.
    -- Set false for the vanilla behavior, where it does nothing.
    quick_sell = true,
}
