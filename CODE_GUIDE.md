# Code guide

Rules that exist because breaking them causes crashes or silent breakage after a game patch.

## Threading

`RegisterKeyBind` callbacks run on UE4SS's own thread. Touching a `UObject` from there crashes the game, often not immediately.

```lua
RegisterKeyBind(Key.F2, function()
	ExecuteInGameThread(function()
		-- UObject access is only safe in here
	end)
end)
```

Never use `LoopAsync` or `ExecuteAsync`. A `LoopAsync` callback that calls `ExecuteInGameThread` every tick corrupts the Lua state and crashes the game at random call sites. Use `LoopInGameThreadWithDelay` for per-tick work.

## Object lifetime

Never hold a `UObject` across a level load. The pawn is destroyed on every raid transition and respawn; the reference becomes a dangling pointer.

- Cache the **PlayerController**, not the pawn. It survives respawns.
- Re-acquire via `FindFirstOf` at call time; it is cheap enough.
- Always check `util.valid(obj)`. UE4SS returns an invalid-object stub, not `nil`, so a plain `if obj then` check passes on a dead object.

## Reflection, never offsets

Bind by name (`/Script/Test_C.SomeClass:SomeFunction`), resolved lazily. A game patch that renames a handler should log once and disable that single bind, not error out of the whole mod.

## Hot reload

Executed by Ctrl + a key defind in `UE4SS-settings.ini` as `HotReloadKey` (default R).

`main.lua` is re-executed on Ctrl+R. Guard anything that must happen once (registrations, the tick loop) so a reload does not double-register.

On Ctrl+R UE4SS runs `main.lua` off the game thread while the game thread keeps running the mod's hooks and queued actions against the same Lua state. Init that runs there races them and corrupts the state. `main.lua` runs init as one game-thread action:

```lua
ExecuteInGameThread(function() util.safe("init", init) end)
```

Init therefore can run after the first PlayerController is built, so code that waits for one also handles one that already exists.

## Error handling

Wrap every boundary (key handler, tick, hook body) in `util.safe`. An uncaught Lua error inside a hook can take the game down with it.

## Logging

Use `log.info` for lifecycle, `log.debug` for per-keypress detail (off by default, since it is per-frame noise otherwise), `log.error` only for a genuine failure the user can act on.
