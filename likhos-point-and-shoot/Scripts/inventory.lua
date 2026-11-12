-- inventory.lua : inventory reads shared by the consumable binds.

local M = {}

--- The main container's items sorted by sub-grid ascending, then by slot descending.
--- ContainerItems is not kept in grid order, so walking it as is picks an item seemingly at random.
--- The items are the ones read from the property, so they can still be passed to a use context.
function M.grid_order(container)
	local sorted = {}
	local items = container.ContainerItems
	for i = 1, #items do sorted[i] = items[i] end
	table.sort(sorted, function(a, b)
		local a_grid, b_grid = a.ContainerIndex, b.ContainerIndex
		if a_grid ~= b_grid then return a_grid < b_grid end
		return a.SlotIndex > b.SlotIndex
	end)
	return sorted
end

return M
