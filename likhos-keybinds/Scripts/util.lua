-- util.lua : small helpers. No UObject access here.
local log = require("log")
local M = {}

--- Monotonic-ish milliseconds. os.clock() is CPU time on some builds, so
--- prefer os.time() * 1000 plus a high-res source when available.
--- UE4SS ships Lua 5.4; os.clock() has been reliable as wall-ish time in
--- practice, but verify during recon and swap if it drifts.
function M.now_ms()
    return math.floor(os.clock() * 1000)
end

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
