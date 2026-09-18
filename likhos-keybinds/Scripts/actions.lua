-- actions.lua : action name -> how to invoke it on the pawn / controller.
--
-- EVERY PATH BELOW IS A PLACEHOLDER. Fill them in from recon (docs/01-recon.md)
-- before enabling a bind. Nothing here is guessed from the real game.
--
-- Design rule: resolve lazily, per call, and never cache a UObject across a
-- level load. Caching the *name* is fine; caching the object is what crashes.

local log  = require("log")
local util = require("util")

local M = {}

--- Each entry describes one logical action.
---   class   : object class to search for at call time ("PlayerController",
---             the pawn class, whatever owns the handler).
---   press   : UFunction name to call on press.
---   release : UFunction name to call on release. nil for fire-and-forget.
---   args    : optional function returning the argument table for the call.
M.ACTIONS = {
    -- ["Sprint"] = {
    --     class   = "TODO_PawnClassName",
    --     press   = "TODO_StartSprint",
    --     release = "TODO_StopSprint",
    -- },
}

--- Track which actions have been permanently disabled this session so we log
--- the failure once rather than every keypress.
local disabled = {}

--- Find the live object that owns an action's handler.
local function resolve_owner(spec)
    local obj = FindFirstOf(spec.class)
    if not util.valid(obj) then return nil end
    return obj
end

--- Invoke one side of an action. `phase` is "press" or "release".
--- MUST be called from the game thread - see input.lua.
function M.invoke(name, phase)
    if disabled[name] then return false end

    local spec = M.ACTIONS[name]
    if not spec then
        log.error("action '%s' is not defined in actions.lua - bind disabled", name)
        disabled[name] = true
        return false
    end

    local fn_name = spec[phase]
    if not fn_name then
        -- Legitimately nothing to do on this phase.
        return true
    end

    local owner = resolve_owner(spec)
    if not owner then
        log.debug("action '%s': no live '%s' right now", name, spec.class)
        return false
    end

    local fn = owner[fn_name]
    if fn == nil then
        log.error("action '%s': '%s' has no function '%s' - bind disabled " ..
                  "(likely renamed by a game patch)", name, spec.class, fn_name)
        disabled[name] = true
        return false
    end

    local args = spec.args and spec.args() or nil
    local ok = util.safe(("action %s:%s"):format(name, phase), function()
        if args then owner[fn_name](owner, table.unpack(args))
        else owner[fn_name](owner) end
    end)
    return ok
end

--- Clear the permanent-disable list. Called on level load so a transient
--- failure does not kill a bind for the rest of the session.
function M.reset()
    disabled = {}
end

--- Sanity check used at startup: report which configured actions are missing
--- a definition, without touching the game.
function M.audit(binds)
    local missing = {}
    for _, b in ipairs(binds) do
        for _, key in ipairs({ "action", "action_tap", "action_hold" }) do
            local a = b[key]
            if a and not M.ACTIONS[a] then
                missing[a] = true
            end
        end
    end
    return missing
end

return M
