# Hot reload init race

## Intent

Ctrl+R hot reload of Point and Shoot no longer crashes the game. The mod's init never runs at the same time as its own game-thread callbacks, at cold start or on reload.

## Constraints and assumptions

* Evidence. Crash reports in `%LOCALAPPDATA%\Test_C\Saved\Crashes` from 2026-11-15 10:50, 2026-11-16 09:53 and 2026-11-16 10:09 all crash in `process_simple_actions` -> `engine_tick_hook` inside a UE4SS Lua call (`luaH_set`, `lua_getiuservalue`). In the 10:09 run, `UE4SS.log` shows `objective marker: decorated ...` lines from the scan that `world/objective_marker.lua` queues with `ExecuteInGameThread`, logged after `item tile click: hooked` and before `quick slot refill: polling`, about 5 ms after the queue. The log ends at `7 of 7 bind(s) active`, before `ready`.
* On Ctrl+R, UE4SS runs `main.lua` on a thread other than the game thread while the game keeps ticking, and the game thread runs the mod's queued actions against the same Lua state. Observed with debug output: an action queued at file load logged while the file was still in a one-second wait, on every reload.
* `ExecuteInGameThread`, `RegisterHook`, `NotifyOnNewObject`, `LoopInGameThread*` and `RegisterConsoleCommandHandler` all work when called from inside a game-thread action. Observed: every install logs and init reaches `ready` on cold start and reload.
* At cold start the game thread runs queued actions only about 5 s after `main.lua` loads, after the menu's PlayerController is constructed. Observed: init's `loading` line came after that, and the controller was picked up as already live. The solution does not depend on init running before the first controller.
* Every source of game-thread Lua work races an off-thread init, not only the actions init queues: hooks and `NotifyOnNewObject` callbacks registered early in init fire on the game thread while later installs still run. Ruled out for that reason: deferring each module's queued actions until init ends.
* Ruled out: running init on the game thread only on reload. Nothing tells a reload from a cold start reliably, and one path for both is simpler.
* Out of scope: crashes inside UE4SS's own teardown of the old Lua state on Ctrl+R. Nothing in the mod controls that.
* `likhos-debug` queues game-thread work only from its console command, not from init, so it is not affected.

## Scope

Owned:

* `likhos-point-and-shoot/Scripts/main.lua`: how init is entered.
* `likhos-point-and-shoot/Scripts/core/player.lua`: `player.watch`.
* `likhos-point-and-shoot/Scripts/world/objective_marker.lua`: its `install` only.
* `CODE_GUIDE.md`: the Hot reload section.

Context only, unchanged: the other modules whose install starts game-thread work, `controls/menu.lua`, `controls/keymap.lua`, `items/quick_slots.lua`, and the hook group in `lib/hook.lua`.

## Solution

* `main.lua` queues the whole of init as one `ExecuteInGameThread` action, wrapped in `util.safe` as today. Nothing else runs at file load. Init, every install it calls and every registration it makes run on the game thread, so no game-thread callback can run until init returns. The work init queues (tick loop, quick slot poll, objective marker scan, keymap retries) starts on a later tick, after init.
* `player.watch(on_ready)` calls `on_ready` for every live PlayerController: each one constructed after watching starts, and the one already live when it starts, if any. This covers a cold start where init runs after the menu controller exists, and a reload, where `keymap.when_live` re-runs harmlessly since `keymap.register` is idempotent.
* `objective_marker.install` scans the existing targets and managers directly, under its hook group's guard, since install already runs on the game thread.
* `CODE_GUIDE.md`'s Hot reload section states the rule: `main.lua` runs init as one game-thread action, because UE4SS runs `main.lua` off the game thread on Ctrl+R while the game thread runs the mod's callbacks against the same Lua state.
* The result the user observes: Ctrl+R reloads the mod without crashing, and the log shows each install in order with no line from a queued action before `ready`.

## Tradeoffs

* Init on reload runs one tick later than today, and at cold start possibly after the first level has loaded. Nothing in init needs to run earlier: deferred hooks in `lib/hook.lua` already wait for their class, and `player.watch` covers a controller that already exists.
* Init now holds the game thread for its full duration, about 50 ms per the log, on load and reload. That is one hitch at a point where the game is already loading or the user is reloading.
