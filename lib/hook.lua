-- hook.lua : RegisterHook for a feature module, with log-once error guards and deferral until a Blueprint class loads.

local log  = require("lib.log")
local util = require("lib.util")

local M = {}

--- A hook group for one feature. `name` prefixes its log lines, `fallback` tells what the player gets when it fails.
--- Create it at module load, so its state survives a hot reload along with the module and nothing is hooked twice.
function M.new(name, fallback)
	local group = {}

	-- Failures log once per session, so a renamed game name doesn't flood the log on every call.
	local error_logged = false

	-- fn_path -> true once RegisterHook accepted it.
	local hooked = {}

	--- Call fn(...) and return its results, or nothing when it fails. Logs the group's first failure and swallows the rest.
	function group.try(fn, ...)
		local result = table.pack(pcall(fn, ...))
		if result[1] then return table.unpack(result, 2, result.n) end
		if not error_logged then
			error_logged = true
			log.error("%s failed, %s: %s", name, fallback, tostring(result[2]))
		end
	end

	--- Wrap fn in group.try. The wrapper returns nothing, since a hook callback's return value may reach UE4SS.
	function group.guard(fn)
		return function(...) group.try(fn, ...) end
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
