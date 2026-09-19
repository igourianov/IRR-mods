-- log.lua : leveled logging. UE4SS print() goes to the GUI console.
local M = {}

local PREFIX = "[PointAndShoot] "
local LEVELS = { error = 1, warn = 2, info = 3, debug = 4 }

M.level = LEVELS.info

function M.set_level(name)
    M.level = LEVELS[name] or LEVELS.info
end

local function emit(lvl, name, fmt, ...)
    if lvl > M.level then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    print(PREFIX .. name .. ": " .. msg .. "\n")
end

function M.error(fmt, ...) emit(LEVELS.error, "ERROR", fmt, ...) end
function M.warn(fmt, ...)  emit(LEVELS.warn,  "WARN",  fmt, ...) end
function M.info(fmt, ...)  emit(LEVELS.info,  "INFO",  fmt, ...) end
function M.debug(fmt, ...) emit(LEVELS.debug, "DEBUG", fmt, ...) end

return M
