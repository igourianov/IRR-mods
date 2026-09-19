-- util.lua : small helpers. No UObject access here.
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

return M
