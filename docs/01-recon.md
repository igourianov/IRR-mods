# Recon

Everything the mod needs to know about the game, and how to find it.
Redo the dumps after every game patch.

## Step 0 — freeze the build

Steam → game → Properties → Updates → **Only update when launched**.
Back up `%LocalAppData%\Test_C\Saved\`. Record the build ID in
`likhos-keybinds/mod.txt` under `game_build`.

## Step 1 — does UE4SS inject?

This decides the project. Do it before writing any code.

1. Download the **zDev** build of the latest UE4SS release.
2. Extract into `PROJECT QUARANTINE\Test_C\Binaries\Win64\`.
   Recent releases put only `dwmapi.dll` there and everything else in
   `ue4ss\`. Both layouts work.
3. In `ue4ss\UE4SS-settings.ini`:
   ```ini
   [Debug]
   ConsoleEnabled    = 1
   GuiConsoleEnabled = 1
   GuiConsoleVisible = 1
   GraphicsAPI       = dx12
   ```
   Valid values are only `dx11`, `d3d11`, `opengl`. There is no dx12 option;
   `opengl` works.
4. Launch. A separate console window should appear.

**If it does not**, read `ue4ss\UE4SS.log`:

| Symptom | Cause | Action |
|---|---|---|
| No log at all | Proxy DLL not loaded | Wrong folder, or another `dwmapi.dll` already present |
| Log exists, "failed to find AOB" | Signature mismatch | Patch `ue4ss\UE4SS_Signatures\` |
| Crash on launch | Engine version detection | Set `[EngineVersionOverride] MajorVersion=5 / MinorVersion=4` |

RESOLVED 2026-09-18: the game is **UE 5.6**, not 5.4. Stable 3.0.1 cannot scan
it at all; the experimental build can. `MinorVersion` must be 6 — setting 4
produces a deterministic access violation at the first tick. See
`03-findings.md` for the working config.

## Step 2 — dumps

UE4SS GUI → Dumpers tab:

- **Dump CXX headers** → class/function/property names
- **Dump usmap** → needed by FModel to read the cooked assets
- **Dump all objects** → snapshot of the live object graph

Move the output into `tools/dumps/` (gitignored).

## Step 3 — which input stack?

This is the decision that shapes everything else.

In Live View, search for:

| Object | If present |
|---|---|
| `EnhancedInputLocalPlayerSubsystem` | UE5 Enhanced Input → IMC interception is viable |
| `EnhancedInputUserSettings` | Sanctioned runtime rebind API (`MapPlayerKey`) exists |
| `PlayerInput` with `ActionMappings` / `AxisMappings` | Legacy input; different approach entirely |

Record the answer in `03-findings.md`.

## Step 4 — enumerate mappings

Once the mod loads, in the UE4SS console:

```
kb_dump_imc
```

This prints every loaded `InputMappingContext`, its mappings, and the key
each one is bound to. Note:

- the IMC asset path(s) actually in use during a raid
- which `InputAction` assets already carry `Hold` / `Tap` triggers
  (some of what you want may already exist, unused)
- the exact property names on `FEnhancedActionKeyMapping` in this build

## Step 5 — find the handlers

In Live View, expand the PlayerController and the pawn. Grep the CXX dump
for candidate names:

```
Sprint  Crouch  Lean  Interact  Aim  Fire  Reload
*Pressed  *Released  Input*  Toggle*
```

For each action you want to control, write down:

- the owning class name
- the press function name
- the release function name (if any)
- any arguments

Then fill in `ACTIONS` in `likhos-keybinds/Scripts/actions.lua`.

## Step 6 — verify the context gate

With the mod loaded and a bind enabled, open the stash and type in the
search box. The bind must **not** fire. If it does, `context.lua`'s
`ui_has_focus()` is reading the wrong property — find the right one in
Live View while a menu is open (compare property values menu-open vs
menu-closed).
