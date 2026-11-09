-- util.lua : small helpers.
local log = require("log")
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

--- A plain Lua copy of an FGuid, which stays valid after the struct it was read from is gone.
function M.guid(g)
	return { A = g.A, B = g.B, C = g.C, D = g.D }
end

function M.same_guid(a, b)
	return a.A == b.A and a.B == b.B and a.C == b.C and a.D == b.D
end

return M
