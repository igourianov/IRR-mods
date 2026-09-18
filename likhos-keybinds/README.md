# Likho's Keybinds

Keybinding behaviour overhaul for Incursion Red River.

**Status: pre-alpha.** The scaffold is complete; the game-specific action
table is empty pending recon. It loads and logs, but does nothing yet.

## What it will do

| Mode | Behaviour |
|---|---|
| `passthrough` | Fire once per press. Remap only. |
| `toggle` | Press flips a latched state — hold-to-sprint becomes toggle-sprint. |
| `hold` | Active only while held. |
| `double_tap` | Fires only on two presses inside the window. |
| `tap_hold` | Short press → one action, long press → another. |

All binds are context-gated: they will not fire while a menu is open or a
text field has focus.

## Config

Edit `Scripts/config.lua`. Hot-reloadable — Ctrl+R in the UE4SS console
reloads it without restarting the game.

## Console commands

| Command | Effect |
|---|---|
| `kb_status` | List binds and whether the PlayerController is acquired |
| `kb_dump_imc` | Print every loaded InputMappingContext and its mappings |

## Co-op

Client-side and local only. Input is unreplicated, so this produces the same
server calls the vanilla binding would. Other players do not need it
installed, and there is no host requirement.

## Requirements

- UE4SS (see the workspace README)
- Incursion Red River — build recorded in `mod.txt`
