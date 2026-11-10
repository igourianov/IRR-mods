# Likho's Oculus

Removes chromatic aberration and thins the lens edge tint in magnified and thermal scopes.

## Chromatic aberration

Removes the red and blue color fringing inside the scope while aiming. Thermal scopes lose their aberration too, since a digital display has no lens to split colors.

## Lens edge tint

Reduces the width of the edge tint. The tint colors are unchanged.

## Installation

Extract the zip into `PROJECT QUARANTINE\Test_C\Content\Paks`. It places `likhos_oculus_P.pak` in `Paks\~mods`.

The mod doesn't need UE4SS.

## Uninstall

Delete `Paks\~mods\likhos_oculus_P.pak`.

## Compatibility

The mod replaces the scope view material of these scopes (`*_PP` material instances under `Items/Attachments/Sight` and `Items/Attachments/Rail`):

- AUG A3 M1 1.5x optic
- Elcan SpecterDR 1.5x/6x and 1x-4x
- EOTech HHS-1 and Vudu 1-6x
- Hensoldt Wetzlar Fero-Z 4x24
- Leupold HAMR 4x24
- Nightforce ATACR 4-16x42
- PSO-1 4x24
- QBZ-97 3x
- Schmidt & Bender 1-8x24 PM II ShortDot
- SIG Sauer BRAVO4 4x30
- Trijicon ACOG 4x24, ACOG 6x48 and SkeetIR 1x thermal

It conflicts with any other mod that replaces those files, and it needs an update after every game patch that changes them.
