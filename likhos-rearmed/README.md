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

## Muzzle device rebalance

Each type of muzzle device now has its own role instead of suppressors being the do-all choice.

* Nerfed suppressor recoil reduction by about 60% across the board. Their real benefit is sound suppression.
* Buffed brake / compensator recoil reduction at a small ergonomics cost. Now they're a clear alternative to using a suppressor.
* Flash hiders improve ergonomics and slightly reduce recoil. Default middle ground between the two above.
* Thread protectors and adapters no longer reduce recoil. These serve only a cosmetic purpose.

## Stocks rebalance

Most stocks are rescaled by build. Lightweight and skeletonized stocks give the most ergonomics and the least recoil reduction. Heavy, well-padded stocks give the least ergonomics and the most recoil reduction.

* Rescaled AR, MCX/MPX and AK stocks along that scale. MCX and MPX stocks follow the AR scale, since the MCX mounts AR stocks through an adapter.
* Removed recoil bonuses from buffer tubes and lowered their ergonomics. Their stats stacked with the stock mounted on them, which made buffer tube + Viper the best pick on every AR.
* Removed bonuses from the SKS SAGE chassis. Like the M700 chassis, its grip and stock are added separately, so the stats stacked.

## AK and 5.56 rifle recoil

AK brakes pushed a fully built AK below zero recoil, while 5.56 rifles have no brake that fits them. The two are rebalanced so each platform has its edge.

* An AK with a brake recoils somewhat less than an AR with a flash hider. With suppressors on both, the AR comes out ahead.
* AK brakes reduce recoil less, so a fully built AK no longer goes below zero.
* 7.62x39 AKs recoil more than 5.45 ones. A brake brings them to about AR level.
* 5.56 rifles that fit no brake (M4A1, MCX Virtus, CQ, QBZ-97) recoil less.

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

## Med boxes

In-raid med boxes now hold only medical items. Nylon and polyester fabric no longer take up loot slots, so more medical items spawn.

## Adrenaline injector

Stamina boost raised from 10% to 50%: stamina recovers 50% faster and drains 50% slower for the 3 minutes the effect lasts. Food and drinks keep their vanilla stamina boosts.

## Painkillers

Fixed a vanilla inconsistency: Morphine and the MFAK's Inject now hide the fracture screen distortion, the same as Painkillers do.

## Installation

Extract the zip into `PROJECT QUARANTINE\Test_C\Content\Paks`. It places `likhos_rearmed_P.pak` in `Paks\~mods`.

The mod doesn't need UE4SS.

## Uninstall

Delete `Paks\~mods\likhos_rearmed_P.pak`. Weapons, ammo and attachments already in your stash stay there and go back to their vanilla class, caliber and stats.

## Compatibility

The mod replaces these game files:

- `DefaultGameplayTags.ini`
- The Rattler's item definition (`ID_Sig_Sauer_MCX_Rattler`)
- The Rattler's preset (`DA_Sig_Sauer_MCX_Rattler`)
- The 7.62x39 HP round's item definition (`ID_762x39_HP`)
- The adrenaline injector's item definition (`ID_Adrenaline_Injector`)
- The painkiller effect's stat config (`U_PainDebuff`)
- The item definitions of every muzzle device except the AUG RAT Worx adapter, the M14 National Match brake and the AS VAL and VSS integral suppressors (`ID_*` under `Items/Attachments/Muzzle`)
- The item definitions of these stocks (`ID_*` under `Items/Attachments/Stock`):
  - Buffer tubes: AR-15 PWS Enhanced, AK SAG, AR-15 Colt A2, FAL Folding and AR-15 Strike SI AR Advanced
  - AR stocks: AR-15 ACE Ultra Lite, AR-15 CMMG Ripstock, AR-15 Odin Works Zulu 2, AR-15 Strike Industries Viper Mod 1, AR-15 Magpul UBR, AR-15 Daniel Defense, AR-15 BCM Gunfighter Mod 0 and AR-15 VLTOR IMOD
  - MCX stocks: MCX Collapsible, Folding Mini Skeleton, Folding Visor, Folding Skeleton and Folding Collapsible Tube
  - AK stocks: AK SAG ACR, PP-19, AKS-74U, KPYK CRC-5002-9033, RPK-74 Folding and AK-12 Collapsible
  - SKS chassis: SAGE International SKSALCV
- The item definitions of these weapons (`ID_*` under `Items/Weapons`): AK-12, AK-103, AK-104, M4A1, MCX Virtus, CQ and QBZ-97
- Eleven NPC loadout presets:
  - `DA_Inventory_AI_Patrol_IGC_A`
  - `DA_Inventory_AI_Guard_IGC`
  - `DA_Inventory_AI_Sniper_IGC`
  - `DA_Inventory_AI_Patrol_UICS_A`
  - `DA_Inventory_AI_Patrol_UICS_B`
  - `DA_Inventory_AI_Guard_UICS`
  - `DA_Inventory_AI_Sniper_UICS`
  - `DA_Inventory_AI_Patrol_VLF_A`
  - `DA_Inventory_AI_Patrol_VLF_B`
  - `DA_Inventory_AI_Guard_VLF`
  - `DA_Inventory_AI_Sniper_VLF`
- The loot presets of the ammo box (`DA_LootContainer_AmmoBox`) and the two med boxes (`DA_LootContainer_MedBox_01`, `DA_LootContainer_MedBox_02`)

It conflicts with any other mod that replaces those files, and it needs an update after every game patch that changes them.

## Known issues

* Vendor/Gunsmith screen shows Rattler as 0/30 ammo. Run the `ResetVendor` console command to fix.
* Some devices are misnamed in the vanilla game. E.g. `P90 flash hider` is actually a muzzle brake / compensator. This mod only changes stats, not names.
* Vanilla does a simple sum of ergonomics and recoil stats when multiple muzzle devices are equipped (e.g. a suppressor over a muzzle brake). This is unrealistic, but it is hardcoded and I can't easily fix it.
