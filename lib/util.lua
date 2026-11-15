-- util.lua : small helpers.
local log = require("lib.log")
local M = {}

--- pcall wrapper that logs and swallows. Returns ok, result.
function M.safe(context, fn, ...)
	local ok, res = pcall(fn, ...)
	if not ok then
		log.error("%s failed: %s", context, tostring(res))
		return false, nil
	end
	return true, res
end

--- UObject validity: UE4SS returns an invalid-object stub rather than nil.
function M.valid(obj)
	return obj ~= nil and obj.IsValid ~= nil and obj:IsValid()
end

--- Object path for StaticFindObject: the full name without its class prefix.
function M.path(obj)
	return obj:GetFullName():match("^%S+ (.+)$")
end

--- The component of actor whose class is at class_path, or nil when actor is invalid, the class isn't loaded or actor has none.
function M.component(actor, class_path)
	local class = StaticFindObject(class_path)
	if not (M.valid(actor) and M.valid(class)) then return nil end
	local comp = actor:GetComponentByClass(class)
	return M.valid(comp) and comp or nil
end

--- The short name of obj's class, the form FindAllOf and FindFirstOf take.
function M.class_name(obj)
	return obj:GetClass():GetFName():ToString()
end

--- The first valid object of tarray for which pred(obj) is true, or nil.
function M.find(tarray, pred)
	local found = nil
	tarray:ForEach(function(_, elem)
		local obj = elem:get()
		if M.valid(obj) and pred(obj) then
			found = obj
			return true
		end
	end)
	return found
end

--- A plain Lua copy of an FGuid, which stays valid after the struct it was read from is gone.
function M.guid(g)
	return { A = g.A, B = g.B, C = g.C, D = g.D }
end

function M.same_guid(a, b)
	return a.A == b.A and a.B == b.B and a.C == b.C and a.D == b.D
end

function M.is_zero_guid(g)
	return g.A == 0 and g.B == 0 and g.C == 0 and g.D == 0
end

--- An FGuid as 32 hex digits, for log lines.
function M.guid_str(g)
	return string.format("%08x%08x%08x%08x", g.A & 0xffffffff, g.B & 0xffffffff, g.C & 0xffffffff, g.D & 0xffffffff)
end

return M
