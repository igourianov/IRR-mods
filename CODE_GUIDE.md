# Code guide

Rules that exist because breaking them causes crashes or silent breakage
after a game patch.

## Threading

`RegisterKeyBind` and `LoopAsync` callbacks run on UE4SS's own thread.
Touching a `UObject` from there crashes the game, often not immediately.

```lua
RegisterKeyBind(Key.F2, function()
    ExecuteInGameThread(function()
        -- UObject access is only safe in here
    end)
end)
```

## Object lifetime

Never hold a `UObject` across a level load. The pawn is destroyed on every
raid transition and respawn; the reference becomes a dangling pointer.

- Cache the **PlayerController**, not the pawn — it survives respawns.
- Re-acquire via `FindFirstOf` at call time; it is cheap enough.
- Always check `util.valid(obj)` — UE4SS returns an invalid-object stub,
  not `nil`, so a plain `if obj then` check passes on a dead object.

## Reflection, never offsets

Bind by name (`/Script/Test_C.SomeClass:SomeFunction`), resolved lazily.
A game patch that renames a handler should log once and disable that single
bind, not error out of the whole mod. See `actions.lua` for the pattern.

## Hot reload

`main.lua` is re-executed on Ctrl+R. Guard anything that must happen once
(key registration, the tick loop) so a reload does not double-register.

## Error handling

Wrap every boundary — key handler, tick, hook body — in `util.safe`. An
uncaught Lua error inside a hook can take the game down with it.

## Logging

Use `log.info` for lifecycle, `log.debug` for per-keypress detail (off by
default — it is per-frame noise otherwise), `log.error` only for a genuine
failure the user can act on.
