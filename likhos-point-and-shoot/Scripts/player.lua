-- player.lua : the local player's controller, pawn and the parts features act on, resolved per call.
-- Only the PlayerController is cached: it survives respawns and the pawn does not.

local log  = require("log")
local util = require("util")

local M = {}

local INVENTORY_LIB   = "/Script/Test_C.Default__InventoryFunctionLibrary"
local WEAPON_COMP     = "/Script/Test_C.WeaponComponent"
local INPUT_SUBSYSTEM = "EnhancedInputLocalPlayerSubsystem"

local controller = nil

--- Call on_ready(pc) for every live PlayerController as it is constructed.
function M.watch(on_ready)
	-- The callback receives the UObject itself, not a RemoteUnrealParam. No :get().
	-- It also fires for each Blueprint subclass's class default object as the class loads.
	-- Those are templates, not live controllers, so skip them by name.
	NotifyOnNewObject("/Script/Engine.PlayerController", function(pc)
		if not util.valid(pc) then return end
		if pc:GetFName():ToString():find("^Default__") then return end

		controller = pc
		log.info("PlayerController acquired: %s", pc:GetFullName())
		util.safe("on_ready", on_ready, pc)
	end)
end

--- The local PlayerController, or nil.
function M.controller()
	if util.valid(controller) then return controller end
	local pc = FindFirstOf("PlayerController")
	if not util.valid(pc) then return nil end
	controller = pc
	return pc
end

--- The local player's pawn, or nil.
function M.pawn()
	local pc = M.controller()
	local pawn = pc and pc.Pawn
	return util.valid(pawn) and pawn or nil
end

--- The player's inventory component, which holds the main containers and the quick slots, or nil outside a level with a player.
function M.inventory()
	local pc = M.controller()
	local library = StaticFindObject(INVENTORY_LIB)
	if not (pc and util.valid(library)) then return nil end
	local comp = library:GetPlayerInventoryComponent(pc)
	return util.valid(comp) and comp or nil
end

--- The equipped weapon's WeaponComponent, or nil.
function M.weapon_component()
	local pawn = M.pawn()
	local library = StaticFindObject(INVENTORY_LIB)
	if not (pawn and util.valid(library)) then return nil end
	return util.component(library:GetEquippedWeapon(pawn), WEAPON_COMP)
end

--- The local player's Enhanced Input subsystem, or nil.
function M.input_subsystem()
	local subsystem = FindFirstOf(INPUT_SUBSYSTEM)
	return util.valid(subsystem) and subsystem or nil
end

local PRESS_VALUE = { X = 1.0, Y = 0.0, Z = 0.0 }

--- A one-frame press of the input action at `path`, as if its key went down for one frame.
--- Continuous injection can't be used: its FInputActionValue parameter can't be built from UE4SS Lua.
function M.inject_press(path)
	local subsystem = M.input_subsystem()
	local ia = StaticFindObject(path)
	if not (subsystem and util.valid(ia)) then return end
	subsystem:InjectInputVectorForAction(ia, PRESS_VALUE, {}, {})
end

return M
