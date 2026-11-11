# Likho's Rearmed

Rebalances weapons and attachments, reworks NPC loadouts and in-raid loot, and tweaks adrenaline and painkillers.

## Classification

* FAL: Rifle -> DMR.
* SVD: Sniper -> DMR.
* VSS: Rifle -> DMR.
* SKS: DMR -> Rifle.
* AKS-74U, Rattler, Honey Badger: Rifle -> SMG.

## Caliber/Ammo

* Rechambered Rattler from 5.56 to 300 BLK.
* Increased bleed chance on 7.62 HP ammo from 10 to 40%.

## Recoil and ergonomics

Each attachment type and weapon group has its own role instead of one do-all pick. Weapon figures are for fully built weapons.

### Attachments

* Suppressors only suppress sound. One mounted on a flash hider or brake cancels that device's recoil bonus, so a suppressed build recoils as if it had no muzzle device.
* The AS VAL and VSS can't fire without their integral suppressors, which keep their vanilla stats. Their base recoil is raised instead, so they recoil about like a suppressed 7.62x39 AK and handle better.
* Brakes and compensators reduce recoil much more at a small ergonomics cost. Flash hiders improve ergonomics and slightly reduce recoil. Thread protectors and adapters no longer affect recoil.
* Stocks are rescaled by build. Lightweight and skeletonized stocks give the most ergonomics and the least recoil reduction, heavy padded stocks the opposite. AR, MCX/MPX, AK and FAL stocks follow this scale, with MCX, MPX and FAL on the AR scale.
* Buffer tubes, the SKS SAGE and M14 Troy SASS chassis and the QBZ-97 cheek rest lose their recoil bonuses, since they stacked with the stock mounted on them. Buffer tubes also lose some ergonomics. The cheek rest keeps its ergonomics.
* The Stark SE3 loses ergonomics and the Troy Modular Combat Grip loses recoil reduction, so no foregrip beats the others on every stat.

### Weapons

* AKs recoil more per shot to offset the ARs' higher fire rate. An AK with a brake recoils less than an AR with a flash hider. With suppressors on both, the AR is ahead.
* 7.62x39 AKs recoil more than 5.45 ones. A brake brings them to about AR level.
* 5.56 rifles that fit no brake (M4A1, MCX Virtus, CQ, QBZ-97) recoil less.
* LMGs recoil less than the rifle they're built on and handle worse.
* Bullpups (AUG A3, QBZ-97) have much better ergonomics and handle as well as the best AR. ARs keep the lowest recoil through their stocks.
* The SCAR-L and STV-380 built-in stocks count as mid-range AR and AK stocks. The STV-380 recoils between a braked and a suppressed AK-103 and can't take a brake or a suppressor.
* 7.62x51 and 7.62x54R battle rifles and DMRs have much lower ergonomics and recoil a bit more than a braked 7.62x39 AK. The full auto FAL, M14 and SCAR-H match that per second of fire, the semi-auto ones per shot. The RFB handles about like an AR. The SVDS fits no brake, so it sits between braked and suppressed recoil.
* The MK-47 is an all-around better SKS: it recoils less and handles much better.
* SMGs recoil more than rifles, about as much as a suppressed AK, and reach the best ergonomics in the game. The AKS-74U recoils the most and the Vector the least. The PP-19 brake and P90 "flash hider" reduce much less recoil, while the AKS-74U and Honey Badger take rifle brakes and keep a bigger gap between braked and suppressed recoil.

## NPC loadouts

Each faction's NPCs now carry weapons that fit the faction. Within each role, pricier weapons spawn less often.

Guards are the heavier tier. They carry only full rifles and LMGs. Patrols carry lighter weapons such as SMGs and shotguns, and some UICS and VLF patrols carry only a pistol.

* IGC: mostly 5.45x39 platform.
  * Patrols: AKS-74U, Vityaz and Saiga.
  * Guards: AK rifles, AS Val and RPK.
  * Snipers: SVD and VSS.
* UICS: mostly M4 and the MP5 family, low chance of exotic NATO weapons.
  * Patrols: MP5 family, MPX, P90, Vector and shotguns.
  * Guards: M4A1, AUG, SCAR-L, MCX Virtus and KAC LAMG.
  * Snipers: M14, RFB and SCAR-H.
* VLF: 7.62x39 rifles and Chinese 5.56 rifles.
  * Patrols: QBZ-97 and CQ.
  * Guards: STV-380, SKS, AK-103 and AK-104.
  * Snipers: M305 and FAL.

## Ammo boxes

In-raid ammo boxes now make it easier to find the ammo type your equipped gun uses. They hold more ammo and lean towards better rounds.

* 2-5 stacks per box instead of 1-3.
* 30-90 rounds per stack instead of 10-40. Stacks cap at 60, so any roll above 60 gives a full stack.
* Tier 1 rounds (5.56 FMJ, 9x19 PSO, 5.45 PS, 12ga buckshot, 7.62x39 HP) roll about a third less often, effectively making higher tiers more common.

## Medical balance

* Adrenaline injector: stamina boost raised from 10% to 50%. Stamina recovers 50% faster and drains 50% slower for the 3 minutes the effect lasts. Food and drinks keep their vanilla stamina boosts.
* Morphine and the MFAK's Inject are the emergency dose: +60 temporary health for 1 minute (vanilla +50 for 3 minutes, MFAK for 6 minutes 20 seconds).
* Painkillers are the lasting dose: +20 temporary health for 5 minutes (vanilla 1 minute 40 seconds).
* Fixed a vanilla inconsistency: the MFAK's Inject now hides the fracture screen distortion, the same as Morphine and Painkillers do.
* In-raid med boxes hold only medical items. Nylon and polyester fabric no longer take up loot slots, so more medical items spawn.

## Installation

Extract the zip into `PROJECT QUARANTINE\Test_C\Content\Paks`. It places `likhos_rearmed_P.pak` in `Paks\~mods`.

The mod doesn't need UE4SS.

## Uninstall

Delete `Paks\~mods\likhos_rearmed_P.pak`. Weapons, ammo and attachments already in your stash stay there and go back to their vanilla class, caliber and stats.

## Compatibility

The mod replaces these game files:

- `DefaultGameplayTags.ini`
- The Rattler's item definition and preset (`ID_Sig_Sauer_MCX_Rattler`, `DA_Sig_Sauer_MCX_Rattler`)
- The item definitions of the 7.62x39 HP round, the adrenaline injector, Morphine, the MFAK and Painkillers (`ID_762x39_HP`, `ID_Adrenaline_Injector`, `ID_Morphine_Injector`, `ID_MFAK`, `ID_Painkiller`) and the painkiller effect's stat config (`U_PainDebuff`)
- The item definitions (`ID_*` under `Items/Attachments`) of:
  - Every muzzle device except the AUG RAT Worx adapter, the M14 National Match brake and the AS VAL and VSS integral suppressors
  - Buffer tubes, AR, MCX, AK and FAL stocks, the SKS SAGE and M14 Troy SASS chassis and the QBZ-97 cheek rest
  - The Stark SE3 and Troy Modular Combat Grip foregrips
- The item definitions of these weapons (`ID_*` under `Items/Weapons`): AK-74M, AK-12, AK-105, AK-101, AK-102, AKS-74, AK-103, AK-104, M4A1, MCX Virtus, CQ, QBZ-97, AUG A3, SCAR-L, STV-380, MK-47, SKS, FAL, M14, SCAR-H, SR-25, Galil ACE, M305, RFB, SVDS, AKS-74U, PP-19 Vityaz, P90, MPX, Vector, MP5, MP5K, MP5SD, Honey Badger, KAC LAMG, RPK-74, RIA VR80, AS VAL and VSS
- Eleven NPC loadout presets (`DA_Inventory_AI_*`): IGC patrol A, guard and sniper, UICS patrol A, patrol B, guard and sniper, VLF patrol A, patrol B, guard and sniper
- The loot presets of the ammo box and the two med boxes (`DA_LootContainer_AmmoBox`, `DA_LootContainer_MedBox_01`, `DA_LootContainer_MedBox_02`)

It conflicts with any other mod that replaces those files, and it needs an update after every game patch that changes them.

## Known issues

* Vendor/Gunsmith screen shows Rattler as 0/30 ammo. Run the `ResetVendor` console command to fix.
* Some devices are misnamed in the vanilla game. E.g. `P90 flash hider` is actually a muzzle brake / compensator. This mod only changes stats, not names.
* Vanilla does a simple sum of ergonomics and recoil stats when multiple muzzle devices are equipped (e.g. a suppressor over a muzzle brake). The mod works around it for recoil, since a suppressor cancels its mount's recoil bonus, but ergonomics still add up.
