-- config.lua : USER-EDITABLE. Hot-reloadable (Ctrl+R in the UE4SS console).

return {
    -- "error" | "warn" | "info" | "debug"
    log_level = "debug",

    -- Master switch. Set false to load the mod inert (useful when bisecting a crash after a game patch).
    enabled = true,

    -- Dropping an item onto another item of the same size, rotated or not, that it can't stack with or go into swaps the two.
    -- Set false for the vanilla behavior, where the dragged item returns to its slot.
    inventory_swap = true,

    -- A bandage or painkiller pack with no uses left drops on the floor, like a used health injector.
    -- Set false to keep them in the inventory at 0 uses.
    medic_drop = true,

    -- Items that count uses, like medical items and keys, show them as whole numbers on inventory tiles.
    -- Set false for the vanilla decimals.
    whole_uses = true,

    -- Shift+Click on an item in the hideout sells it, like Sell from its context menu.
    -- Set false for the vanilla behavior, where it does nothing.
    quick_sell = true,
}
