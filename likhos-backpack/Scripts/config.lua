-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).

return {
    -- "error" | "warn" | "info" | "debug"
    log_level = "debug",

    -- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
    enabled = true,

    -- A bandage or painkiller pack with no uses left drops on the floor, like a used health injector.
    -- Set false to keep them in the inventory at 0 uses.
    medic_drop = true,

    -- Items that count uses, like medical items and keys, show them as whole numbers on inventory tiles.
    -- Set false for the vanilla decimals.
    whole_uses = true,

    -- Shift+Click on an item in the hideout sells it, like Sell from its context menu. A mission item is delivered instead, like Deliver.
    -- Set false for the vanilla behavior, where it does nothing.
    quick_sell = true,
}
