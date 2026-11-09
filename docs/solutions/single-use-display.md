# Single use display

## Intent

An unused single use item's inventory tile shows no use count. A spent one keeps `0/1`. Other items keep the display from `docs/solutions/medic-uses-display.md` and `docs/solutions/usb-uses-display.md`.

## Solution

In `whole_uses.lua`, a `U_Content_C` tile whose drawn maximum in `ItemMaxCapacity` is 1 and whose drawn remaining in `ItemCapacity` is above 0 gets both texts set to empty, one tick after the native write. Any other `U_Content_C` tile is rounded as before. A tile already emptied has no number, so a repeat rewrite falls through to rounding, which changes nothing. README, `config.lua` comment and `CHANGELOG.md` describe it.

No new game names. The tile and text blocks come from the two solution docs above.

## Assumptions the build checks

- A single use item's tile draws its maximum as 1 in `ItemMaxCapacity` (e.g. `/ 1.0`).
- A quick slot tile of a single use item still shows the count from `quick_slots.lua`, since its poll rewrites the tile after this rewrite empties it.
