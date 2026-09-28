-- inventory_swap.lua : dropping a 1x1 item onto another 1x1 item it can't stack with or go into swaps the two (docs/solutions/inventory-swap.md).
--
-- Every game name here comes from docs/solutions/inventory-swap.md.
-- Vanilla returns the dragged item to its slot on such a drop. The swap runs a tick after vanilla's drop handler.
-- The game refuses a move onto an occupied slot, so the swap clears the target's slot occupancy, makes two validated moves and writes both slots' occupancy after.
-- Holds no UObject between calls.

local log  = require("log")
local util = require("util")
local hook = require("hook")

local M = {}

local hooks = hook.new("inventory swap", "drops onto items stay vanilla")

local HOOK_FN    = "/Script/Test_C.ContainerElementWidget:HandleItemDrop"
local GRID_CLASS = "/Script/Test_C.SpatialContainerWidget"
-- The game drags items with its Blueprint subclass, BP_InventoryDragDropOperation_C.
local DRAG_CLASS = "/Script/Test_C.ItemDragDropOperation"


local function guid(g)
    return { A = g.A, B = g.B, C = g.C, D = g.D }
end

local function same_guid(a, b)
    return a.A == b.A and a.B == b.B and a.C == b.C and a.D == b.D
end

local function guid_str(g)
    return string.format("%08x%08x%08x%08x", g.A & 0xffffffff, g.B & 0xffffffff, g.C & 0xffffffff, g.D & 0xffffffff)
end

local function item_str(item)
    return string.format("%s %s container=%d slot=%d", item.ItemDefinition:GetFName():ToString(), guid_str(item.ItemUID), item.ContainerIndex, item.SlotIndex)
end

local function is_a(obj, class_path)
    local class = StaticFindObject(class_path)
    return util.valid(class) and obj:IsA(class)
end

-- ItemDimensions X and Y are the item's (min, max) extents in slots, e.g. (-0.5, 0.5) for one slot.
local function is_1x1(item)
    local d = item.ItemDimensions
    return d.X.Y - d.X.X == 1 and d.Y.Y - d.Y.X == 1
end

-- Main containers and items are read from comp.MainContainers rather than GetMainContainerByUID / GetContainerItemByUID.
-- A struct returned by a UFunction call crashes the game when passed to another one. One read from a property passes fine.
-- The read points into the live array, so a move invalidates it.

--- The item of comp with uid and the main container holding it, or nil.
local function find_item(comp, uid)
    local containers = comp.MainContainers
    for i = 1, #containers do
        local container = containers[i]
        local items = container.ContainerItems
        for j = 1, #items do
            if same_guid(items[j].ItemUID, uid) then return items[j], container end
        end
    end
    return nil
end

--- The main container of comp with uid, or nil.
local function main_container(comp, uid)
    local containers = comp.MainContainers
    for i = 1, #containers do
        local container = containers[i]
        if same_guid(container.MainContainerUID, uid) then return container end
    end
    return nil
end

--- Whether the item with uid sits at pos in comp.
local function is_at(comp, uid, pos)
    local item, main = find_item(comp, uid)
    return item ~= nil and same_guid(main.MainContainerUID, pos.main) and item.ContainerIndex == pos.index and item.SlotIndex == pos.slot
end

--- Write uid as the occupant of the slot at pos in comp. Returns whether it took.
--- The game refuses a move onto a slot whose HostingUID is set, and only this table tracks occupancy (docs/solutions/inventory-swap.md).
local function set_host(comp, pos, uid)
    local main = main_container(comp, pos.main)
    if not main then return false end
    -- ContainerElements is indexed by container index.
    local slots = main.ContainerElements[pos.index + 1].ContainerSlots
    for i = 1, #slots do
        local s = slots[i]
        if s.Index == pos.slot then
            local host = s.HostingUID
            host.A, host.B, host.C, host.D = uid.A, uid.B, uid.C, uid.D
            return same_guid(s.HostingUID, uid)
        end
    end
    return false
end

--- Move the item with uid, owned by owner, into pos of target's inventory. Validated, so the game applies its own move rules.
local function move(owner, target, uid, pos)
    local item = find_item(owner, uid)
    owner:RequestMoveItem(owner, target, item, pos.main, pos.index, pos.slot, item.bRotated, true)
end

-- Ticks to wait for a move to show in MainContainers. Solo, moves show within one.
local SETTLE_TICKS = 5

--- Call done once check() holds, or failed after SETTLE_TICKS ticks.
local function await(check, done, failed, ticks)
    ticks = ticks or SETTLE_TICKS
    if check() then return done() end
    if ticks == 0 then return failed() end
    ExecuteInGameThreadWithDelay(1, hooks.guard(function() await(check, done, failed, ticks - 1) end))
end

local ZERO_UID = { A = 0, B = 0, C = 0, D = 0 }

--- Swap a and b: clear b's slot, move a onto it, move b onto a's old slot, then write both slots' occupants.
--- The owners are looked up by path at every step, so no UObject is held across ticks.
local function swap(plan)
    local function owners()
        local a_owner, b_owner = StaticFindObject(plan.a_owner), StaticFindObject(plan.b_owner)
        if util.valid(a_owner) and util.valid(b_owner) then return a_owner, b_owner end
        error("an inventory is gone mid-swap")
    end
    local a_uid, b_uid, a_pos, b_pos = plan.a_uid, plan.b_uid, plan.a_pos, plan.b_pos
    local names = guid_str(a_uid) .. " and " .. guid_str(b_uid)

    -- a sits in a_owner before move 1 and after an undo, in b_owner in between. b moves into a_owner.
    local function a_at(pos) local ao, bo = owners() return is_at(pos == a_pos and ao or bo, a_uid, pos) end
    local function b_at(pos) local ao = owners() return is_at(ao, b_uid, pos) end

    local function finish()
        local ao, bo = owners()
        -- Leaving a slot clears it, even the one b shared with a, so both occupants are written last.
        local a_ok = set_host(bo, b_pos, a_uid)
        local b_ok = set_host(ao, a_pos, b_uid)
        if a_ok and b_ok then
            log.debug("swapped %s", names)
        else
            log.error("swapped %s, but could not write their slots' occupancy", names)
        end
    end

    local function restore_b(reason)
        local _, bo = owners()
        set_host(bo, b_pos, b_uid)
        log.error("swap of %s failed: %s, undone", names, reason)
    end

    local function undo_move_1()
        -- a's old slot is still free, so a goes back by a plain validated move.
        local ao, bo = owners()
        move(bo, ao, a_uid, a_pos)
        await(function() return a_at(a_pos) end,
            function() restore_b("the target's move didn't land") end,
            function() log.error("swap of %s failed: the target's move didn't land and the dragged item couldn't go back, it shares the target's slot", names) end)
    end

    local function move_2()
        local ao, bo = owners()
        move(bo, ao, b_uid, a_pos)
        await(function() return b_at(a_pos) end, finish, undo_move_1)
    end

    local a_owner, b_owner = owners()
    if not is_at(a_owner, a_uid, a_pos) or not is_at(b_owner, b_uid, b_pos) then
        log.debug("swap of %s cancelled: an item moved", names)
        return
    end
    if not set_host(b_owner, b_pos, ZERO_UID) then
        log.error("swap of %s failed: could not clear the target's slot", names)
        return
    end
    move(a_owner, b_owner, a_uid, b_pos)
    await(function() return a_at(b_pos) end, move_2, function() restore_b("the dragged item's move didn't land") end)
end

-- Runs before vanilla's handler: the grid's drop state still holds vanilla's decision, and HandleItemDrop resets it.
local function on_drop(context, operation)
    local grid = context:get()
    local op = operation:get()
    if not is_a(grid, GRID_CLASS) or not is_a(op, DRAG_CLASS) then return end
    if grid.bCanBeDropped then return end

    -- Both positions come from the items, not the widgets. Dragged out of a quick slot, which only references it, the item is still in its own grid.
    local a_owner = op.ItemOwnerComp
    local a, a_main = find_item(a_owner, op.Item.ItemUID)
    if not a then
        log.debug("no swap: dragged %s is not in its owner's inventory", item_str(op.Item))
        return
    end
    -- DropToContainerUID names the item under the cursor, whatever vanilla means to do with it.
    local b_owner = grid.InventoryComponent
    local b, b_main = find_item(b_owner, grid.DropToContainerUID)
    if not b or same_guid(a.ItemUID, b.ItemUID) then
        log.debug("no swap: no other item under the cursor")
        return
    end
    if not is_1x1(a) or not is_1x1(b) then
        log.debug("no swap: %s and %s are not both 1x1", item_str(a), item_str(b))
        return
    end

    local a_fits = b_owner:IsContainerSupportingItem(b_main, b.ContainerIndex, a)
    local b_fits = a_owner:IsContainerSupportingItem(a_main, a.ContainerIndex, b)
    log.debug("candidate: %s -> %s, owners %s / %s, fits %s / %s", item_str(a), item_str(b),
        util.path(a_owner), util.path(b_owner), tostring(a_fits), tostring(b_fits))
    if not a_fits or not b_fits then
        log.debug("no swap: a grid refuses the other item")
        return
    end

    local plan = {
        a_owner = util.path(a_owner), a_uid = guid(a.ItemUID), a_pos = { main = guid(a_main.MainContainerUID), index = a.ContainerIndex, slot = a.SlotIndex },
        b_owner = util.path(b_owner), b_uid = guid(b.ItemUID), b_pos = { main = guid(b_main.MainContainerUID), index = b.ContainerIndex, slot = b.SlotIndex },
    }
    log.debug("swapping %s and %s", item_str(a), item_str(b))
    ExecuteInGameThreadWithDelay(1, hooks.guard(function() swap(plan) end))
end

--- Hook the grid's native drop handler.
function M.install()
    hooks.install(HOOK_FN, nil, on_drop)
end

return M
