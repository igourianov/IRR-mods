# Temp health color

## Intent

The temporary health a painkiller adds shows on the player HUD's health bar in a faint pink, barely distinguishable from the solid red of permanent health. The user wants it in a configurable color that clearly sets it apart.

## Constraints and assumptions

### Recon

From the UE4SS object dump and the cooked assets in `pakchunk0-Windows.pak`, read with UAssetGUI.

- The HUD health bar is `W_HealthBar`, a `W_GeneralStatBar_C` (`/Game/Blueprints/UICore/Widgets/Base/W_GeneralStatBar`) in the widget tree of `W_StaminaAndHealthBars_C` (`/Game/Blueprints/InventorySystem/Widgets/WeaponUI/W_StaminaAndHealthBars`). The same widget holds `W_StaminaArm` and `W_StaminaBody`, both `W_GeneralStatBar_C` as well.
- `W_StaminaAndHealthBars_C` reads the `Character.Attributes.Health` attribute set and calls `W_HealthBar.UpdateStat(CurrentValue, BaseValue, MaxValue)` with the attribute's modified value as current and its base value as base. A painkiller dose raises the modified value above the base, so temp health is the span from base to current.
- `W_GeneralStatBar_C` overlays three `ProgressBar`s, drawn bottom to top: `PB_ProgressBar_Positive`, `PB_ProgressBar_Base`, `PB_ProgressBar_Negative`.
	- `UpdateStat` sets Positive to current / max, Base to base / max and Negative to min(base, current) / max.
	- Its `PreConstruct` copies the instance's style properties into the bars' `WidgetStyle`: `PositiveStyle` into Positive, `NegativeStyle` into Base, `BaseStyle` into Negative. The names cross over.
	- `UpdateFillColor` calls `SetFillColorAndOpacity` on Positive and Base. `W_StaminaAndHealthBars_C` never calls it on `W_HealthBar`.
- `W_HealthBar`'s `PositiveStyle.FillImage.TintColor` is red (linear 1, 0.042, 0.042, alpha 0.8), the same as its `BaseStyle` fill, which paints permanent health on the top bar. The top bar's `BaseStyle.BackgroundImage` is white at alpha 0.2 and covers the temp health span, which turns the red pink.
- A ProgressBar draws its fill as the brush tint multiplied by `FillColorAndOpacity`. A red tint can't be multiplied into another hue, so the recolor sets the brush tint itself.

Confirmed in game:

- For a Blueprint (`/Game/...`) function, `RegisterHook`'s first callback runs after the function and a second callback is never called, per the UE4SS docs. Only a `/Script/...` native function gets a pre and a post callback. The `PreConstruct` hook therefore takes its recolor as the first callback.
- The `W_GeneralStatBar_C:PreConstruct` function object stays the same across level loads, so a hook registered once keeps firing. With the recolor as its first callback, it fires for each new HUD health bar after the style copy, after a level load as well.
- The HUD is a `W_InGame_C` owned by the game instance. A level load builds a new one, and old ones linger until garbage collected, so several HUD health bars can exist at once.
- A tint written through reflection into `PB_ProgressBar_Positive.WidgetStyle` shows on screen without any further call.
- The HUD health bar is told apart from other stat bars by its name `W_HealthBar` and its owning user widget being a `W_StaminaAndHealthBars_C`. The inventory screen's `W_PlayerInventory_C` has a `W_HealthBar` of its own, which this check leaves out.

### Ruled out

- A pak edit of `W_StaminaAndHealthBars` in Likho's Rearmed. The user chose Point and Shoot, so the color needs no pak and survives a game patch to the widget.
- Recoloring through `FillColorAndOpacity`, for the reason above.
- Recoloring the stamina bars or any other `W_GeneralStatBar_C`, such as the inventory's stat bars. Only the HUD health bar changes.
- Changing the white overlay. The new color sits under it as in vanilla and reads paler than the configured color. The default color is picked with that in mind.

## Scope

Owned, all in `likhos-point-and-shoot`:

- `Scripts/hud/temp_health.lua`, a new module in a new `hud/` domain folder.
- `Scripts/config.lua`: the `temp_health_color` setting.
- `Scripts/main.lua`: installing the module.
- `README.md`, `CHANGELOG.md` and the minor version in `mod.txt`.

Context only: `lib/hook.lua` and `lib/util.lua`, used as they are. `world/objective_marker.lua`, whose color parsing and struct writes the module follows.

## Solution

### hud/temp_health.lua

Recolors the temp health span of the HUD health bar.

- `install()` parses `config.temp_health_color`, hooks `W_GeneralStatBar_C:PreConstruct` through a `lib/hook` group with the class path so the hook waits for the Blueprint class to load, then recolors every HUD health bar that already exists. A hot reload or an init after the HUD was built recolors the live bars. The hook group lives at module load, so a reload doesn't hook twice.
- The hook's one callback, which runs after `PreConstruct`, recolors only HUD health bars. Every other stat bar passes through untouched.
- Recoloring writes the parsed color into the fill brush tint of the bar's `PB_ProgressBar_Positive`, keeping the vanilla alpha. Since the hook runs after every `PreConstruct`, a rebuild that copies the vanilla style back is recolored again.
- The color is a `"#RRGGBB"` sRGB string converted to linear, as `world/objective_marker.lua` does for the marker ring. That module and this one each keep their own small parser. An invalid string logs one error and leaves the bar vanilla.
- Holds no UObject between calls.

### config.lua

`temp_health_color = "#ffaa55"` with a comment saying what it colors and that `nil` keeps the vanilla color. With `nil` or `false`, `main.lua` doesn't install the module.

### main.lua

Requires and installs `hud.temp_health` next to the other feature modules, when `config.temp_health_color` is set.

### Result

During a painkiller dose the HUD health bar shows permanent health in vanilla red and the temporary span above it in the configured color. Damaged health, the stamina bars and every other stat bar look as in vanilla.

### Docs

- `README.md` lists the recolored temp health. Its config setting is covered by the README's general note that every feature can be turned off in `config.lua`.
- `CHANGELOG.md` has the feature under `# Unreleased`.
- `mod.txt` minor version is one above the last release, patch kept.

## Tradeoffs

- Lua over pak: no pak to rebuild after a game patch and no whole widget asset shipped, at the cost of a hook on every stat bar's `PreConstruct` and a reflection write into a nested Slate style struct, which a game patch renaming a property breaks. The hook group logs that once and the bar stays vanilla.
- Hooking `PreConstruct` of the shared stat bar class over the HUD widget's `Construct`: it runs for every stat bar, but it is the one point that runs after each style copy, so a rebuild can't restore the pink.
