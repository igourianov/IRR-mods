# Unreleased
* a spent single use item shows `~` instead of `0/1` in the inventory

# 1.4.71
* fixed one or two inventory tiles sometimes showing a decimal use count, or a count on an unused single use item, when many are on screen

# 1.4.65
* quick slots hold an item type and refill from anywhere in the inventory until none is left
* click a quick slot to clear it

# 1.3.58
* fixed quick slot staying bound after its item's container is stashed or dropped (vanilla bug)
* fixed quick slot count showing late for a newly slotted item
* fixed quick slot count missing after a level load
* optimized quick slot count lookup
* reduced log output noise

# 1.3.51
* quick slots no longer empty out if there is an item of the same type in the same container as the one that was just used
* single use items show total count in the quick slot
* single use items show no use count in the inventory until used
* USB hacking devices show their remaining uses as a percentage
* removed item swap and spent medical item drop features, the vanilla game now does both natively
* verified on UE4SS experimental v3.0.1-1217 (2026-11-07)

# 1.0.25
* quick sell delivers mission items for their mission instead (Shift+Click)

# 1.0.24
* item swap works for items of the same size, rotated or not, not just 1x1

# 1.0.20
* quick sell feature (Shift+Click)

# 1.0.18
* moved med item drop on use and whole number item tags from the point-and-shoot mod

# 1.0.17
* implemented item swap in place
