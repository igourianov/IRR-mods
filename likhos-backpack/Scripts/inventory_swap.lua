-- inventory_swap.lua : dropping an item onto another item of the same size, rotated or not, that it can't stack with or go into swaps the two (docs/solutions/inventory-swap.md).
--
-- Every game name here comes from docs/solutions/inventory-swap.md.
-- Vanilla returns the dragged item to its slot on such a drop. The swap runs a tick after vanilla's drop handler.
-- The game refuses a move onto an occupied slot, so the swap clears the target's slots' occupancy, makes two validated moves and writes both slot sets' occupancy after.
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
local QUICK_SLOT_CLASS = "/Script/Test_C.QuickSlotContainerWidget"


local function guid(g)
    return { A = g.A, B = g.B, C = g.C, D = g.D }
end

local function same_guid(a, b)
    return a.A == b.A and a.B == b.B and a.C == b.C and a.D == b.D
end

local function guid_str(g)
    return string.format("%08x%08x%08x%08x", g.A & 0xffffffff, g.B & 0xffffffff, g.C & 0xffffffff, g.D & 0xffffffff)
end

-- ItemDimensions X and Y are the item's (min, max) extents in slots, e.g. (-0.5, 0.5) for one slot.
-- Taken as the footprint in the item's current orientation, unverified (docs/solutions/inventory-swap.md, assumption 4).
local function footprint(item)
    local d = item.ItemDimensions
    return math.floor(d.X.Y - d.X.X + 0.5), math.floor(d.Y.Y - d.Y.X + 0.5)
end

local function item_str(item)
    local w, h = footprint(item)
    return string.format("%s %s container=%d slot=%d %dx%d rotated=%s", item.ItemDefinition:GetFName():ToString(), guid_str(item.ItemUID),
        item.ContainerIndex, item.SlotIndex, w, h, tostring(item.bRotated))
end

local function is_a(obj, class_path)
    local class = StaticFindObject(class_path)
    return util.valid(class) and obj:IsA(class)
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

-- ContainerElements is indexed by container index.
local function element(main, index)
    return main.ContainerElements[index + 1]
end

-- EContainerType: EquipTo = 0, Container = 1, Storage = 2. Equipment and attachment slots are EquipTo.
local EQUIP_TO = 0

--- Whether the container at index of main is a grid, not an equipment or attachment slot.
local function is_grid(main, index)
    local settings = element(main, index).ContainerSettings
    return util.valid(settings) and settings:GetContainerType() ~= EQUIP_TO
end

-- Containers nest a few levels deep. The cap only guards against a cycle in bad data.
local MAX_DEPTH = 16

--- Whether main, a main container of comp, sits at any depth inside the item with uid.
--- A container item's own grids are main containers whose MainContainerUID is its ItemUID (docs/solutions/inventory-swap.md, assumption 8).
local function is_inside(comp, main, uid)
    for _ = 1, MAX_DEPTH do
        if same_guid(main.MainContainerUID, uid) then return true end
        local _, parent = find_item(comp, main.MainContainerUID)
        if not parent then return false end
        main = parent
    end
    return false
end

--- The slot indexes of the container at index of main that uid occupies, as a set.
local function hosted(main, index, uid)
    local set, slots = {}, element(main, index).ContainerSlots
    for i = 1, #slots do
        local s = slots[i]
        if same_guid(s.HostingUID, uid) then set[s.Index] = true end
    end
    return set
end

local function set_str(set)
    local list = {}
    for index in pairs(set) do list[#list + 1] = index end
    table.sort(list)
    return "{" .. table.concat(list, ",") .. "}"
end

--- Write uid as the occupant of every slot in the set at pos in comp. Returns whether it took.
--- The game refuses a move onto a slot whose HostingUID is set, and only this table tracks occupancy (docs/solutions/inventory-swap.md).
local function set_host(comp, pos, set, uid)
    local main = main_container(comp, pos.main)
    if not main then return false end
    local slots = element(main, pos.index).ContainerSlots
    local ok = true
    for i = 1, #slots do
        local s = slots[i]
        if set[s.Index] then
            local host = s.HostingUID
            host.A, host.B, host.C, host.D = uid.A, uid.B, uid.C, uid.D
            ok = ok and same_guid(s.HostingUID, uid)
        end
    end
    return ok
end

--- Move the item with uid, owned by owner, into pos of target's inventory. Validated, so the game applies its own move rules.
local function move(owner, target, uid, pos, rotated)
    local item = find_item(owner, uid)
    owner:RequestMoveItem(owner, target, item, pos.main, pos.index, pos.slot, rotated, true)
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

--- Swap a and b: clear b's slots, move a onto b's position, move b onto a's old position, then write both slot sets' occupants.
--- The owners are looked up by path at every step, so no UObject is held across ticks.
local function swap(plan)
    local function owners()
        local a_owner, b_owner = StaticFindObject(plan.a_owner), StaticFindObject(plan.b_owner)
        if util.valid(a_owner) and util.valid(b_owner) then return a_owner, b_owner end
        error("an inventory is gone mid-swap")
    end
    local a_uid, b_uid, a_pos, b_pos, a_slots, b_slots = plan.a_uid, plan.b_uid, plan.a_pos, plan.b_pos, plan.a_slots, plan.b_slots
    local names = guid_str(a_uid) .. " and " .. guid_str(b_uid)

    -- a sits in a_owner before move 1 and after an undo, in b_owner in between. b moves into a_owner.
    local function a_at(pos) local ao, bo = owners() return is_at(pos == a_pos and ao or bo, a_uid, pos) end
    local function b_at(pos) local ao = owners() return is_at(ao, b_uid, pos) end

    local function finish()
        local ao, bo = owners()
        -- Leaving slots clears them, even the ones b shared with a, so both occupants are written last.
        local a_ok = set_host(bo, b_pos, b_slots, a_uid)
        local b_ok = set_host(ao, a_pos, a_slots, b_uid)
        if a_ok and b_ok then
            log.debug("swapped %s", names)
        else
            log.error("swapped %s, but could not write their slots' occupancy", names)
        end
    end

    local function restore_b(reason)
        local _, bo = owners()
        set_host(bo, b_pos, b_slots, b_uid)
        log.error("swap of %s failed: %s, undone", names, reason)
    end

    local function undo_move_1()
        -- a's old slots are still free, so a goes back by a plain validated move.
        local ao, bo = owners()
        move(bo, ao, a_uid, a_pos, plan.a_rot)
        await(function() return a_at(a_pos) end,
            function() restore_b("the target's move didn't land") end,
            function() log.error("swap of %s failed: the target's move didn't land and the dragged item couldn't go back, it shares the target's slots", names) end)
    end

    local function move_2()
        local ao, bo = owners()
        move(bo, ao, b_uid, a_pos, plan.b_dest_rot)
        await(function() return b_at(a_pos) end, finish, undo_move_1)
    end

    local a_owner, b_owner = owners()
    if not is_at(a_owner, a_uid, a_pos) or not is_at(b_owner, b_uid, b_pos) then
        log.debug("swap of %s cancelled: an item moved", names)
        return
    end
    if not set_host(b_owner, b_pos, b_slots, ZERO_UID) then
        log.error("swap of %s failed: could not clear the target's slots", names)
        return
    end
    move(a_owner, b_owner, a_uid, b_pos, plan.a_dest_rot)
    await(function() return a_at(b_pos) end, move_2, function() restore_b("the dragged item's move didn't land") end)
end

-- Runs before vanilla's handler: the grid's drop state still holds vanilla's decision, and HandleItemDrop resets it.
local function on_drop(context, operation)
    local grid = context:get()
    local op = operation:get()
    if not is_a(grid, GRID_CLASS) or not is_a(op, DRAG_CLASS) then return end
    if grid.bCanBeDropped then return end

    -- A drag out of the quick slot bar only removes the reference there, as in vanilla.
    local tile = op.ItemWidgetRef
    local source = util.valid(tile) and tile.BaseContainerElementRef or nil
    if util.valid(source) and is_a(source, QUICK_SLOT_CLASS) then
        log.debug("no swap: dragged out of the quick slot bar")
        return
    end

    -- Both positions come from the items, not the widgets.
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
    local aw, ah = footprint(a)
    local bw, bh = footprint(b)
    local same = aw == bw and ah == bh
    if not same and not (aw == bh and ah == bw) then
        log.debug("no swap: %s and %s differ in size", item_str(a), item_str(b))
        return
    end
    if not is_grid(a_main, a.ContainerIndex) or not is_grid(b_main, b.ContainerIndex) then
        log.debug("no swap: %s or %s is not in a grid", item_str(a), item_str(b))
        return
    end
    if is_inside(a_owner, a_main, b.ItemUID) or is_inside(b_owner, b_main, a.ItemUID) then
        log.debug("no swap: %s and %s sit one inside the other", item_str(a), item_str(b))
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

    -- Each item takes the other's footprint: transposed footprints rotate both, equal ones keep both orientations.
    local plan = {
        a_owner = util.path(a_owner), a_uid = guid(a.ItemUID), a_pos = { main = guid(a_main.MainContainerUID), index = a.ContainerIndex, slot = a.SlotIndex },
        a_slots = hosted(a_main, a.ContainerIndex, a.ItemUID), a_rot = a.bRotated, a_dest_rot = a.bRotated ~= not same,
        b_owner = util.path(b_owner), b_uid = guid(b.ItemUID), b_pos = { main = guid(b_main.MainContainerUID), index = b.ContainerIndex, slot = b.SlotIndex },
        b_slots = hosted(b_main, b.ContainerIndex, b.ItemUID), b_dest_rot = b.bRotated ~= not same,
    }
    if next(plan.a_slots) == nil or next(plan.b_slots) == nil then
        log.error("no swap: %s or %s occupies no slots", item_str(a), item_str(b))
        return
    end
    log.debug("swapping %s slots %s and %s slots %s, rotated to %s / %s", item_str(a), set_str(plan.a_slots), item_str(b), set_str(plan.b_slots),
        tostring(plan.a_dest_rot), tostring(plan.b_dest_rot))
    ExecuteInGameThreadWithDelay(1, hooks.guard(function() swap(plan) end))
end

--- Hook the grid's native drop handler.
function M.install()
    hooks.install(HOOK_FN, nil, on_drop)
end

return M
