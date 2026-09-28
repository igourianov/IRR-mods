-- hook.lua : RegisterHook for a feature module, with log-once error guards and deferral until a Blueprint class loads.

local log  = require("log")
local util = require("util")

local M = {}

--- A hook group for one feature. `name` prefixes its log lines, `fallback` tells what the player gets when it fails.
--- Create it at module load, so its state survives a hot reload along with the module and nothing is hooked twice.
function M.new(name, fallback)
    local group = {}

    -- Failures log once per session, so a renamed game name doesn't flood the log on every call.
    local error_logged = false

    -- fn_path -> true once RegisterHook accepted it.
    local hooked = {}

    --- Wrap fn in a pcall that logs the group's first failure and swallows the rest.
    function group.guard(fn)
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok and not error_logged then
                error_logged = true
                log.error("%s failed, %s: %s", name, fallback, tostring(err))
            end
        end
    end

    --- Hook fn_path with guarded pre and optional post callbacks.
    --- class_path names the Blueprint class that owns the function, and the hook waits for it to load. Nil for a native class, which is loaded before any mod runs.
    function group.install(fn_path, class_path, pre, post)
        if hooked[fn_path] then return end

        local function register()
            local ok, err
            if post then
                ok, err = pcall(RegisterHook, fn_path, group.guard(pre), group.guard(post))
            else
                ok, err = pcall(RegisterHook, fn_path, group.guard(pre))
            end
            if not ok then return false, err end
            hooked[fn_path] = true
            log.info("%s: hooked %s", name, fn_path)
            return true
        end

        if not class_path then
            local ok, err = register()
            if not ok then log.error("%s: could not hook %s, %s: %s", name, fn_path, fallback, tostring(err)) end
            return
        end

        -- At startup the function can be found while its class is still loading. Its Func pointer is still null then and RegisterHook throws.
        local function try()
            local ok, err = register()
            if not ok then log.debug("%s: %s not hookable yet: %s", name, fn_path, tostring(err)) end
            return ok
        end

        if util.valid(StaticFindObject(fn_path)) and try() then return end
        -- RegisterHook needs the function in memory and linked.
        NotifyOnNewObject(class_path, function()
            if not hooked[fn_path] then try() end
            return true
        end)
    end

    return group
end

return M
