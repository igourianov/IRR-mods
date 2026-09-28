-- log.lua : leveled logging. UE4SS print() goes to the GUI console.
local M = {}

local LEVELS = { error = 1, warn = 2, info = 3, debug = 4 }

M.level = LEVELS.info
M.prefix = ""

--- `mod` names the mod on every log line. Shared by all mods, so the name comes from the caller.
function M.setup(mod, level)
    M.prefix = "[" .. mod .. "] "
    M.level = LEVELS[level] or LEVELS.info
end

local function emit(lvl, name, fmt, ...)
    if lvl > M.level then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    print(M.prefix .. name .. ": " .. msg .. "\n")
end

function M.error(fmt, ...) emit(LEVELS.error, "ERROR", fmt, ...) end
function M.warn(fmt, ...)  emit(LEVELS.warn,  "WARN",  fmt, ...) end
function M.info(fmt, ...)  emit(LEVELS.info,  "INFO",  fmt, ...) end
function M.debug(fmt, ...) emit(LEVELS.debug, "DEBUG", fmt, ...) end

return M
