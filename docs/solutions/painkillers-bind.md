# Use Morphine/Painkillers bind

## Intent

A new keybind in Likho's Point and Shoot that takes a painkiller in one press, to keep the player alive right now. A painkiller here is anything that applies the game's Painkiller buff: the Morphine Injector, the MFAK's Inject and the Painkiller item. The game names the buff after painkillers, and so do the bind's code names. The name the player reads, Use Morphine/Painkillers, names morphine as well, since that is what the key uses most of the time. It uses the fastest painkiller anywhere on the player: the Morphine Injector most of the time, then the MFAK's Inject, then the Painkiller item. Bleeding, fractures and real healing stay with the player, done from the inventory or the vanilla Quick Heal, which stays as it is.

## Constraints and assumptions

- Health has two parts: real health and temporary health. The Painkiller buff adds temporary health on top of real health, even past max health (seen in game by the user). The bind only ever applies this buff.
- The health attribute of the pawn's `HealthComponent` gives real health as `GetBaseValue`, real plus temporary health as `GetCurrentValue` and max health as `GetCurrentMaxValue`. An active dose is an entry tagged `Character.Buffs.Medic.Painkiller` in its `Buffs` (seen in game 2026-11-09: base 39, current 82, max 100, one buff, after a morphine).
- Painkiller doses don't stack, and a new dose doesn't replace an active one: morphine taken over an active Painkiller item dose leaves the weaker dose in place (seen in game 2026-11-09). A painkiller is therefore never used while a dose is active.
- A press uses a painkiller only when more than 5 real health is missing, so a light bleed's first ticks don't burn a dose.
- An item is a painkiller by its use contexts: a context whose `ToTriggerActions` include an action with `Inventory.Stats.Pain Debuff` in its `EffectStatTags`. The tag decides, not the item's name, so a new item with the same tag is picked up without a code change.
- The MFAK lists Inject as its own context in `ItemContexts`, next to Stop Bleeding and Splint Limb. Executing that context injects only. The vanilla Quick Heal on an MFAK removes a condition instead (seen in game by the user).
- Painkillers are searched anywhere on the player: every main container of the player's inventory component, nested storage included. This matches the vanilla Quick Heal, which as the user understands it searches the whole inventory. `MainContainers` is a flat list that already holds every container item's storage as a main container of its own (see Recon), so walking it covers nested items.
- Ruled out: searching only the Rig and Belt, as the game's quick grenade does (see Recon).
- The item is read from the inventory component's `MainContainers` property and passed straight to UFunctions, never a `ContainerItem` returned by one UFunction (`docs/solutions/eat-food-bind.md`, Constraints).
- A use context's `IsValidContext(pawn, nil, item)` and `Execute(pawn, nil, item)` work without an item widget: seen in game for food (`docs/solutions/eat-food-bind.md`) and for the Morphine Injector (2026-11-09). Assumed, unverified, for the MFAK's Inject and the Painkiller item.
- Ruled out: bleeding, fracture and real healing (Health Injector, IVs). Ranking them against each other and against painkillers made the selection too complex for one key.
- Ruled out: steering the vanilla Quick Heal ability (`SGA_QuickHeal_C`, its native `TriageOrder` and tag containers), for the reasons in `docs/solutions/eat-food-bind.md`: native tag container writes from Lua and an item choice no asset describes.

## Scope

Owned, all in `likhos-point-and-shoot/`:

- `Scripts/painkillers.lua`
- `Scripts/actions.lua`: the `UsePainkillers` entry in `ACTIONS`
- `Scripts/keymap.lua` and `Scripts/menu.lua`: the `LikhosUsePainkillers` mapping and its controls row
- `Scripts/config.lua`: the `painkillers` bind
- `README.md` and `CHANGELOG.md`

Context only: `consume.lua` (the food bind whose inventory walk and use path this one follows), `input.lua` and `triggers.lua` (key polling and press dispatch on the game thread), `context.lua` (`block_in_ui`), `lib/util.lua`, `lib/log.lua`, the vanilla inventory component, item contexts and health component. The vanilla Quick Heal is untouched.

## Solution

### `painkillers.lua`

Owns the bind's whole behavior. Exposes `press()`, run on the game thread by the action. Holds no state and no UObject between presses.

On press it:

1. Resolves the PlayerController, its pawn, the pawn's health attribute and the inventory component, as `consume.lua` resolves the component. Any of them missing: logs at debug and does nothing.
2. With a dose already active, or 5 real health or less missing: logs at debug and does nothing.
3. Walks every main container in the game's container order, as `consume.lua` does, and collects the candidates: a medical item (`ItemIdentifier` under `Inventory.Items.Medical`) with uses left (`Inventory.Stats.Durability` above 0) and a Pain Debuff context that reports itself valid.
4. Executes the context of the candidate with the shortest `Inventory.Stats.Usage Time` from its `CurrentStats`, the first found on a tie. The game's own ability plays the animation, applies the buff and spends the use.
5. Finds none: logs at debug and does nothing.

With the current items the order is Morphine Injector (2 s), MFAK Inject (5 s), Painkiller (7 s).

The inventory walk, uses left and context lookup are local to `painkillers.lua`, as in `consume.lua`. The two modules share no code.

### `actions.lua`

`ACTIONS.UsePainkillers` has a `press` only, pointing at `painkillers.press`, the same shape as `ConsumeFoodDrink`.

### `keymap.lua` and `menu.lua`

`LikhosUsePainkillers` is a mapping with display name `Use Morphine/Painkillers`, unbound by default. `menu.lua` lists it after `LikhosConsumeFoodDrink`, so the row shows last in the Likho's Actions section.

### `config.lua`

A fifth bind, `id = "painkillers"`, `mapping = "LikhosUsePainkillers"`, `action = "UsePainkillers"`, `block_in_ui = true`, enabled.

### `README.md` and `CHANGELOG.md`

The README has a `Use Morphine/Painkillers` section: one key takes the fastest painkiller anywhere in the inventory (Morphine Injector, then the MFAK's Inject, then the Painkiller item), only with more than 5 health missing and no dose still active. The changelog has the entry under the version of the build, with the minor version bumped for the new feature.

### Result

The player binds Use Morphine/Painkillers under Settings > Controls > Likho's Actions. In a raid, hurt by more than 5 health, pressing it injects morphine from anywhere in the inventory if there is a Morphine Injector, otherwise uses the MFAK's Inject, otherwise takes a Painkiller, with the vanilla animation and effect. With a dose still active, 5 health or less missing, no painkiller carried, a menu open or another use running, nothing happens. The vanilla Quick Heal key is unaffected.

## Recon

Sources: cooked assets read with repak and UAssetGUI (usmap `Test_C-5.6.1-0+UE5-4fb9b615`, 2026-11-08) and `CXXHeaderDump` of 2026-11-06.

### Items

`/Game/Blueprints/InventorySystem/Items/Medical/<Name>/ID_<Name>`. Use time is the `U_UsageTime_C` stat, uses the `U_Content_C` stat. Every context is a `U_UseInventoryItem_C`, every action an `IA_UseInventoryItem_C`.

| Item | `ItemIdentifier` | Uses | Use time | Contexts (`ContextName`: action `EffectStatTags`) | Buff |
|---|---|---|---|---|---|
| `Morphine_Injector` | `Inventory.Items.Medical.Morphine Injector` | 1 | 2 s | Inject: Pain Debuff | 50 for 180 s |
| `Painkiller` | `Inventory.Items.Medical.Painkiller` | 4 | 7 s | Use Painkiller: Pain Debuff | 20 for 100 s, grants `Character.Effects.Painkiller` |
| `MFAK` | `Inventory.Items.Medical.MFAK` | 6 | 5 s | Stop Bleeding: Stop Heavy Wound, Stop Wound. Splint Limb: Stop Fracture. Inject: Pain Debuff | 50 for 380 s |

- The Pain Debuff actions of the Morphine Injector and the MFAK's Inject have `Action = Painkiller`.
- Montages: Morphine Injector `AM_FP_Morphine_Injector_Use`, MFAK Inject `AM_FP_MFAK_Inject`, Painkiller `AM_FP_Painkiller_Use`.
- MFAK `ItemProperties.DefaultContext` and `ActionContext` are two more contexts named Treat, with actions tagged Stop Heavy Wound, Stop Fracture and `Inventory.Stats.Chance To Wound`. They are not in `ItemContexts`.
- No other medical item carries Pain Debuff. `Health_Injector` carries `Inventory.Stats.Heal Instant`, the IVs `Inventory.Stats.Heal Over Time`.

### Buff

- `/Game/Blueprints/SimpleGameplayAbilitySystem/Effects/SGE_Attribute_Buff.SGE_Attribute_Buff_C`: `Attribute`, `Buff` (`FGameplayTag`), `Data` (`FSimpleAttributeData`: `BaseValue`, `MinValue`, `MaxValue`), `StackingBehaviour = ReInit`.
- The `U_PainDebuff_C` stat config (`StatTag = Inventory.Stats.Pain Debuff`) has a default effect with `Attribute = Character.Attributes.Health`, `Buff = Character.Buffs.Medic.Painkiller`, `BaseValue = 50`, duration 120 s. Items override only duration and, for the Painkiller item, `BaseValue`.
- `SGE_Fractured_C` has `MaskingTags` `Character.Effects.Painkiller`: the Painkiller item's dose hides the fracture's screen distortion, while the effect and its icon stay (seen in game by the user).
- `U_UsageTime_C`: `StatTag = Inventory.Stats.Usage Time`.

### Inventory

- `FMainContainer`: `MainContainerUID` (`FGuid`), `ContainerElements`, `ContainerItems`. A container item's storage is the main container whose `MainContainerUID` is that item's `ItemUID`.
- `MainContainers` in a raid, 2026-11-09, by position (0 based): 0 Primary slot (AK-12), 1 to 4 the AK's attachment and magazine storage, 5 to 7 empty Secondary, Pistol and Plate Carrier slots, 8 Rig slot (AVS armored rig), 9 the rig's pockets (morphine, keys, ammo), 10 a magazine's storage, 11 to 13 key storage, 14 Belt slot (four RGO grenades), 15 Backpack slot, 16 the backpack's contents (cases, morphine), 17 to 20 the cases' contents (MFAK, IVs) and an injector, 21 Helmet slot, 22 the helmet's NVG mount, 23 GCPS slot, 24 empty Melee slot, 25 Special Equipment slot (binoculars).
- `/Game/Blueprints/InventorySystem/Objects/DefaultContainerSettings/DA_PlayerContainerSettings` (`IRRDefaultContainerSettings`) lists the equipment slots in order: 0 `U_Primary_C`, 1 `U_Secondary_C`, 2 `U_Pistol_C`, 3 `U_PlateCarrier_C`, 4 `U_Rig_C`, 5 `U_Belt_C`, 6 `U_Backpack_C`, 7 `U_Helmet_C`, 8 `U_GCPS_C`, 9 `U_Melee_C`, 10 `U_SpecialEquipment_C`. The slot containers in `MainContainers` are the ones no item holds, in this order.
- `/Game/Blueprints/SimpleGameplayAbilitySystem/Abilities/SGA_QuickGrenade.SGA_QuickGrenade_C` searches with `InventoryComponent:GetContainerItemsByTags` on slots `[4, 5]` (Rig and Belt), `bAllContainers = false`, `bDeepSearch = true`.
- `SGA_QuickHeal_C` derives from native `SimpleGameplayAbility_QuickHeal` and adds nothing; its search is native and no asset describes it.

### Native classes

From `CXXHeaderDump/Test_C.hpp`:

- `UItemAction`: `Action` (`FName`), `EffectStatTags` (`FGameplayTagContainer`), `Execute`, `CanStart`, `CanApplyAnyEffect`.
- `UItemContext`: `ContextName`, `ToTriggerActions`, `IsValidContext`, `Execute` (`docs/solutions/eat-food-bind.md`, Recon).
- `UHealthComponent`: `Health` (`USimpleGameplayAttribute_Health*`). Reached through the pawn's `GetHealthComponent()`.
- `USimpleGameplayAttribute`: `BaseData`, `CurrentData`, `Buffs` (`TArray<FSimpleAttributeBuff>`: `Tag`, `Data`), `GetBaseValue()`, `GetCurrentValue()`, `GetCurrentMaxValue()`.
- `USimpleGameplayAbility_QuickHeal`: `TriageOrder`, `MedicalItemTags`, `HealingStatTags`, `PainReliefStatTags`, values set in native code.

## Tradeoffs

- Painkillers only over a full triage: one rule the player can predict, at the cost of opening the inventory for bleeding, fractures and real healing.
- Fastest first: the MFAK's Inject (5 s) goes before the Painkiller item (7 s), at the cost of spending an MFAK use that could have stopped a bleed later.
- Doing nothing while a dose is active: a new dose would neither stack nor replace it, so nothing is wasted on a double press, at the cost of not topping up a buff about to run out.
- More than 5 health missing: no dose spent on a scratch, at the cost of a press that does nothing at 96 of 100.
- The whole inventory, as the vanilla Quick Heal, over the Rig and Belt only, as the quick grenade: every painkiller carried counts, at the cost of using up ones the player keeps in the backpack as a reserve.
- Pain Debuff stat tag over a hard-coded item list: a new item with the same tag is picked up without a code change, at the cost of relying on the developers tagging it.
