# Installation

**Not ready for end users yet.** These instructions are the intended final
form; the mod currently has no configured actions.

## 1. Install UE4SS

Download the latest release from
`https://github.com/UE4SS-RE/RE-UE4SS/releases` and extract it into:

```
...\steamapps\common\PROJECT QUARANTINE\Test_C\Binaries\Win64\
```

You should end up with `dwmapi.dll` and a `ue4ss` folder there.

Launch the game once. If `ue4ss\UE4SS.log` appears, it worked.

## 2. Install this mod

Drop the `likhos-keybinds` folder into:

```
...\Test_C\Binaries\Win64\ue4ss\Mods\
```

Add this line to `ue4ss\Mods\mods.txt`:

```
likhos-keybinds : 1
```

## 3. Configure

Open `likhos-keybinds\Scripts\config.lua` in a text editor. Each entry in
`binds` has an `enabled` flag, a `key`, and a `mode`. Set `enabled = true`
on the ones you want.

## Troubleshooting

**Nothing happens.** Enable the console in `ue4ss\UE4SS-settings.ini`
(`GuiConsoleEnabled = 1`), relaunch, and check for `[KeybindOverhaul]` lines.

**A bind fires while I'm typing in the stash search.** Report it — the
context gate is reading the wrong property for your build.

**It broke after a game update.** Expected. Check for a new version.

## Uninstall

Delete the `likhos-keybinds` folder and its line from `mods.txt`.
