# Debug weapon probe

Status: built and run in game on 2026-11-10.

## Intent

A dev-only Lua mod, `likhos-debug`, with read-only recon console commands. The first one, `dbg_weapons`, logs the player's primary, secondary and pistol weapons: the game's computed stats, every attachment as a tree with its definition stats, and the definition stat sums. It serves the Likho's Rearmed recoil balance (`docs/solutions/ak-556-recoil-balance.md`): it checks in game whether displayed recoil is the plain sum of item definition values that the scratchpad resolver assumes.

## Constraints

- Not published. `likhos-debug` is not in `tools\publish\publish.config.json`.
- Read only. No UFunction gets a struct argument: on UE4SS 1217 a struct returned by one UFunction crashes the game when passed into another (`docs/solutions/ue4ss-upgrade.md`, finding 2). A struct returned to Lua reads fine on 1217 (finding 1).
- The console handler hops to the game thread with `ExecuteInGameThread` before touching UObjects.

## Recon

From the CXXHeaderDump of 2026-11-06 (`Test_C.hpp`), the object dump of 2026-11-08 and `Test_C/Config/DefaultGameplayTags.ini` from `pakchunk0-Windows.pak`, game build 26487830.

- `UInventoryFunctionLibrary` (CDO `/Script/Test_C.Default__InventoryFunctionLibrary`): `GetEquipmentComponent(const AActor*)`, `GetWeaponClassTag(const UWeaponComponent*)`.
- `UEquipmentComponent`: `LocEquipmentData`, `RepEquipmentData` (`TArray<FEquipmentData>`), `LocEquippedItem` (`FEquipmentData`).
- `FEquipmentData`: `Item` (`FContainerItem`), `Slot` (`FGameplayTag`).
- `FContainerItem`: `ItemDefinition`, `ItemUID`, `MotherUID`, `CurrentStats` (`TArray<FCurrentStatItem>`: `Tag`, `Value`, `MaxValue`).
- `UIRRItemDefinition.ItemStats`: `FBaseStatItem` with `Value` and `StatItemConfig`, whose class names the stat (`U_Recoil_C`, `U_Ergonomics_C`).
- `UEquippableComponent`: `GetContainerItem()`, `GetAttachments(bool bIncludeRoot)`, `GetErgonomics()`, `GetErgonomicsMultiplier()`, `GetWeight()`, `GetWeightMultiplier()`.
- `UWeaponComponent : UEquippableComponent`: `GetRecoil()`, `GetRecoilMultiplier()`, `GetSpread()`, `GetFireRate()`, `IsSuppressed()`.
- Every weapon component in the hideout object dump is `BP_WeaponComponent_C` (97 instances), on rack and vendor weapons as well as the player's. The probe matches components to equipment slots by the root item's `ItemUID`.
- Slot tags: `Inventory.Equipment Slots.Primary`, `.Secondary`, `.Pistol`.

## Solution

- `likhos-debug/Scripts/main.lua`: `dbg_weapons`.
- `likhos-debug/Scripts/config.lua`: `log_level`.

## Findings

Run in the hideout on 2026-11-10, with an AK-105 in Primary, an M4A1 in Secondary and the Pistol slot empty.

- A holstered weapon has a live `BP_WeaponComponent_C`. The Secondary M4A1 matched by UID.
- `GetAttachments(true)` returns a Lua table of `LocalUnrealParam`. Each element reads through `:get()`, which gives the `FContainerItem` struct. The struct `GetContainerItem()` returns reads directly.
- The list holds the root weapon, every attachment and also the rounds: the magazine's rounds and the chambered round each show up as an item.
- `GetRecoil()` and `GetErgonomics()` equal the plain sum of definition `Recoil` and `Ergonomics` values over the root and every attachment. The same values sit in the root item's `CurrentStats` (`Inventory.Stats.Recoil`, `Inventory.Stats.Ergonomics`).
	- AK-105: 46 + B-10 handguard -0.5 + Stark SE3 -9 + SAG ACR -17 + TGP-A -4 = 15.5.
	- M4A1: 50 + VLTOR IMOD -16 + 14.5" barrel -2 + SD3P -1 + SOCOM556-MONSTER -5 + MK8 9.5" -2 + Stark SE3 -9 = 15.
- `GetRecoilMultiplier()` (0.62 at 15.5, 0.61 at 15) and `GetErgonomicsMultiplier()` (0.62 at 47.5, 0.56 at 39) are separate from the sums. They look like the `FRecoilMultiplier` and `FErgonomicsMultiplier` curves evaluated at the sum. Not verified.
- `IsSuppressed()` reads false on both, though each carries a suppressor.

## Open

- What the recoil multiplier curve gives below zero recoil, which decides whether a below-zero build gains anything.
- What `IsSuppressed()` checks.
