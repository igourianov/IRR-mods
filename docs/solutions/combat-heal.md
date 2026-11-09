# Combat Heal bind

## Intent

The Use Morphine/Painkillers keybind in Likho's Point and Shoot becomes Combat Heal: one key that treats whatever matters most right now. Hurt below 90% with no painkiller dose active, it takes a painkiller as before. Otherwise it treats the first of heavy bleed, bleed, fracture and missing health that it has an item for. For each it picks the fastest item that treats it, and among equally fast ones the one that wastes least.

## Constraints and assumptions

- Health has two parts: real health and temporary health. The Painkiller buff adds temporary health on top of real health. The health attribute of the pawn's `HealthComponent` gives real health as `GetBaseValue` and max health as `GetCurrentMaxValue`. An active dose is an entry tagged `Character.Buffs.Medic.Painkiller` in its `Buffs` (`docs/solutions/painkillers-bind.md`, Constraints, seen in game 2026-11-09).
- Painkiller doses don't stack and a new dose doesn't replace an active one (seen in game 2026-11-09). The painkiller step never runs while a dose is active.
- A condition is read from the gameplay tags the pawn owns: the `OwnedGameplayTags` of the `GameplayTagsComponent` of the pawn's `GameplayAbilityComponent`. Heavy bleed is `Character.Effects.Heavy Wounded`, bleed `Character.Effects.Wounded`, fracture `Character.Effects.Fractured`. These are the tags the game's stop effects require (see Recon). Assumed, unverified: a heavy bleed, a bleed and a fracture each grant their tag on the player pawn while they last, and the tags are readable from Lua.
- An item treats a condition through a use context in its `ItemDefinition.ItemContexts` whose `ToTriggerActions` include an action with the condition's stat tag in `EffectStatTags`. The tag decides, not the item's name, so a new item with the same tag is picked up without a code change. The MFAK's `ItemProperties` contexts (Treat) are not in `ItemContexts` and are never used.
- Assumed, unverified: executing a context with several actions (the CAT Tourniquet, Compression Bandage, IFAK and MFAK's Stop Bleeding each stop a heavy bleed and a bleed) spends one use and applies each action whose effect's required tag the pawn has.
- Assumed, unverified: the heal amount of a healing item is its `CurrentStats` value under its heal stat tag (40, 65, 85, see Recon). The Saline IV's effect has `Amount = 40` and `EffectMagnitude = 65`, so its real total is unconfirmed.
- Items are searched anywhere on the player, read from the inventory component's `MainContainers` and passed straight to the context, as `docs/solutions/painkillers-bind.md` does (Constraints). A `ContainerItem` returned by one UFunction is never passed to another.
- A use context's `IsValidContext(pawn, nil, item)` and `Execute(pawn, nil, item)` work without an item widget: seen in game for food and the Morphine Injector. Assumed, unverified, for the other medical items.
- A condition the player has but carries no usable item for doesn't stop the press: the next step is tried.
- Ruled out: checking for a heal over time still running. The heal step counts health an IV is still about to give as missing, and a press during it uses another healing item. Wasting it is the player's choice.
- The mapping id is `LikhosCombatHeal`. Use Morphine/Painkillers was never published (Nexus has 1.1.123), so no player has a key set on `LikhosUsePainkillers` and the README and changelog don't mention it.
- Ruled out: steering the vanilla Quick Heal ability (`SGA_QuickHeal_C`, native `TriageOrder`), for the reasons in `docs/solutions/eat-food-bind.md`.
- Ruled out: the Adrenaline Injector (`Inventory.Stats.Stamina Boost`) and the Revive Syringe (no use context). Neither treats a condition here.

## Scope

Owned, all in `likhos-point-and-shoot/`:

- `Scripts/combat_heal.lua`
- `Scripts/actions.lua`: the `CombatHeal` entry in `ACTIONS`
- `Scripts/keymap.lua` and `Scripts/menu.lua`: the `LikhosCombatHeal` mapping and its controls row
- `Scripts/config.lua`: the `combat_heal` bind
- `mod.txt` (minor version), `README.md` and `CHANGELOG.md`

Within this scope, `Scripts/painkillers.lua`, the `UsePainkillers` action, the `LikhosUsePainkillers` mapping and the `painkillers` bind are not part of the solution.

Context only: `consume.lua` (the food bind whose inventory walk and use path this follows), `input.lua` and `triggers.lua` (key polling and press dispatch on the game thread), `context.lua` (`block_in_ui`), `lib/util.lua`, `lib/log.lua`, the vanilla inventory component, item contexts, health component and gameplay ability component. The vanilla Quick Heal is untouched.

## Solution

### `combat_heal.lua`

Owns the bind's whole behavior. Exposes `press()`, run on the game thread by the action. Holds no state and no UObject between presses.

On press it resolves the PlayerController, its pawn, the pawn's health attribute, its owned gameplay tags and the inventory component. Any of them missing: it logs at debug and does nothing.

It then walks the steps in order and executes the pick of the first step that applies and has a candidate:

| Step | Applies when | Stat tag on the action |
|---|---|---|
| Painkiller | real health below 90% of max, no dose active | `Inventory.Stats.Pain Debuff` |
| Heavy bleed | pawn has `Character.Effects.Heavy Wounded` | `Inventory.Stats.Stop Heavy Wound` |
| Bleed | pawn has `Character.Effects.Wounded` | `Inventory.Stats.Stop Wound` |
| Fracture | pawn has `Character.Effects.Fractured` | `Inventory.Stats.Stop Fracture` |
| Heal | real health below max | `Inventory.Stats.Heal Instant` or `Inventory.Stats.Heal Over Time` |

A candidate is a medical item (`ItemIdentifier` under `Inventory.Items.Medical`) with uses left (`Inventory.Stats.Durability` above 0) and a context carrying the step's stat tag that reports itself valid. Candidates are ranked by:

1. Speed: shortest `Inventory.Stats.Usage Time`.
2. Waste. For the painkiller and condition steps, the number of treatments the item has: the distinct step stat tags across all its `ItemContexts`, the two heal tags counting as one. Fewer is less waste. For the heal step, a heal that covers all the real health missing beats one that falls short. Among covering heals the one with the least overheal is less waste, among short ones the bigger heal.
3. Fewest uses left, so partly used items go first.

The first found wins a full tie. The pick's context is executed; the game's own ability plays the animation, applies the effect and spends the use. No step with a candidate: it logs at debug and does nothing.

One pass over `MainContainers` collects what every step needs, so a press reads the inventory once. Each item's treatments come from its definition's contexts.

With the current items the picks are:

- Painkiller: Morphine Injector (2 s), MFAK Inject (5 s), Painkiller (7 s).
- Heavy bleed: CAT Tourniquet (2 s), IFAK (4 s), MFAK (5 s), Compression Bandage (6 s).
- Bleed: CAT Tourniquet (2 s), IFAK (4 s), Bandage (5 s, 1 treatment), MFAK (5 s, 4 treatments), Compression Bandage (6 s).
- Fracture: Alu Splint (5 s, 1 treatment), MFAK (5 s, 4 treatments), Improv Splint (12 s).
- Heal: Health Injector (3 s), then an IV (14 s): Saline (65) when it covers the missing health, otherwise Blood (85). With 50 missing Saline, with 70 missing Blood.

### `actions.lua`

`ACTIONS.CombatHeal` has a `press` only, pointing at `combat_heal.press`, the same shape as `ConsumeFoodDrink`.

### `keymap.lua` and `menu.lua`

`LikhosCombatHeal` is a mapping with display name `Combat Heal`, unbound by default. `menu.lua` lists it after `LikhosConsumeFoodDrink`, so the row shows last in the Likho's Actions section.

### `config.lua`

The fifth bind is `id = "combat_heal"`, `mapping = "LikhosCombatHeal"`, `action = "CombatHeal"`, `block_in_ui = true`, enabled.

### `mod.txt`, `README.md` and `CHANGELOG.md`

`mod.txt` has the minor version bumped for the new feature. The README has a `Combat Heal` section and no `Use Morphine/Painkillers` one: one key that takes a painkiller when hurt below 90% and no dose is active, otherwise stops a heavy bleed, a bleed, splints a fracture or heals, in that order, using the fastest item and the least wasteful among equally fast ones. The changelog has the entry, an added keybind, under the version of the build, and no entry for Use Morphine/Painkillers.

### Result

The player binds Combat Heal under Settings > Controls > Likho's Actions. In a raid, each press does one thing: below 90% health with no dose active, it injects morphine (or the next fastest painkiller). Otherwise it stops a heavy bleed, then a bleed, then splints a fracture, then heals missing health, each with the fastest item carried that treats it. Pressing again moves on to the next problem. With nothing to treat, no item for anything there is, a menu open or another use running, nothing happens. The vanilla Quick Heal key is unaffected.

## Recon

Sources: cooked assets read with repak and UAssetGUI (usmap `Test_C-recon`, 2026-11-09) and `CXXHeaderDump` of 2026-11-06.

### Items

`/Game/Blueprints/InventorySystem/Items/Medical/<Name>/ID_<Name>`. Uses is the `U_Content_C` stat (`Inventory.Stats.Durability`), use time the `U_UsageTime_C` stat. Every context in `ItemContexts` is a `U_UseInventoryItem_C`, every action an `IA_UseInventoryItem_C`.

| Asset | `ItemIdentifier` | Uses | Use time | `ItemContexts` (action `EffectStatTags`) |
|---|---|---|---|---|
| `Bandage` | `Inventory.Items.Medical.Bandage` | 1 | 5 s | Stop Wound |
| `CAT_Tourniquet` | `Inventory.Items.Medical.CAT Tourniquet` | 1 | 2 s | one context: Stop Heavy Wound, Stop Wound |
| `Compression_Bandage` | `Inventory.Items.Medical.Compression Bandage` | 2 | 6 s | one context: Stop Heavy Wound, Stop Wound |
| `IFAK` | `Inventory.Items.Medical.IFAK` | 4 | 4 s | one context: Stop Heavy Wound, Stop Wound |
| `MFAK` | `Inventory.Items.Medical.MFAK` | 6 | 5 s | Stop Bleeding: Stop Heavy Wound, Stop Wound. Splint Limb: Stop Fracture. Inject: Pain Debuff |
| `Aluminium_Splint` | `Inventory.Items.Medical.Alu Splint` | 3 | 5 s | Stop Fracture |
| `Improv_Splint` | `Inventory.Items.Medical.Improv Splint` | 1 | 12 s | Stop Fracture |
| `Morphine_Injector` | `Inventory.Items.Medical.Morphine Injector` | 1 | 2 s | Pain Debuff |
| `Painkiller` | `Inventory.Items.Medical.Painkiller` | 4 | 7 s | Pain Debuff |
| `Health_Injector` | `Inventory.Items.Medical.Health Injector` | 1 | 3 s | Heal Instant, stat value 40 |
| `Saline_IV` | `Inventory.Items.Medical.Saline IV` | 1 | 14 s | Heal Over Time, stat value 65; effect `Amount = 40`, `EffectMagnitude = 65`, `TickInterval = 5` |
| `Blood_IV` | `Inventory.Items.Medical.Blood IV` | 1 | 14 s | Heal Over Time, stat value 85; effect `Amount = 85`, `EffectMagnitude = 85`, `TickInterval = 5` |
| `Adrenaline_Injector` | `Inventory.Items.Medical.Adrenaline Injector` | 1 | 2 s | Stamina Boost |
| `Revive_Syringe` | `Inventory.Items.Medical.Revive Syringe` | 1 | 8 s | none (`ItemProperties` holds a `U_InspectItem_C`) |

Stat tags are `Inventory.Stats.<name>`. The heal effects: `Health_Injector` `SGE_Attribute_Modifier_Instant_C`, the IVs `SGE_Attribute_Modifier_OverTime_C`.

### Effects

`/Game/Blueprints/SimpleGameplayAbilitySystem/Effects/`, class defaults:

- `SGE_StopHeavyWound_C`: `RequiredGameplayTags = [Character.Effects.Heavy Wounded]`, `DurationMagnitude = 80`.
- `SGE_StopWound_C`: `RequiredGameplayTags = [Character.Effects.Wounded]`, `DurationMagnitude = 80`.
- `SGE_StopFractured_C`: `RequiredGameplayTags = [Character.Effects.Fractured]`, `DurationMagnitude = 80`.
- `SGE_IsWounded_C`: `GrantedGameplayTags = [Character.Effects.Wounded]`, `DurationMagnitude = 1`.
- `SGE_Fractured_C`: `MaskingTags = [Character.Effects.Painkiller]`. It grants no tag in its class default.
- No asset effect for a heavy bleed was found besides `SGE_IsHeavyWounded_Debug_C`, which sets nothing.

### Native classes

From `CXXHeaderDump/Test_C.hpp`:

- `APawn` subclass with `HealthComponent` and `GameplayAbilityComponent` (`UGameplayAbilityComponent*`).
- `UGameplayAbilityComponent`: `GameplayTagsComponent` (`UGameplayTagsComponent*`), `ActiveEffects` (`TArray<USimpleGameplayEffect*>`), `GetActiveGameplayEffects()`.
- `UGameplayTagsComponent`: `OwnedGameplayTags` (`FGameplayTagContainer`), `HasGameplayTags(FGameplayTagContainer, bool ExactMatch)`, `GetOwnedGameplayTags()`.
- `USimpleGameplayEffect_Wounded`: `LightBleedRate`, `HeavyBleedRate`, `bIsHeavy`, `IsHeavy()`, `K2_OnEscalatedToHeavy()`.
- `USimpleGameplayEffect_Fractured`: `FracturedBodyPart`, `GetFracturedBodyPart()`.
- `USimpleGameplayEffect`: `RequiredGameplayTags`, `GrantedGameplayTags`, `CanStartEffect(UGameplayAbilityComponent*)`.

## Tradeoffs

- Speed over waste: the CAT Tourniquet stops a light bleed before the Bandage, and the MFAK splints before the Improv Splint, at the cost of spending items that could treat something worse later. Waste only breaks ties in use time.
- Painkiller first below 90%: temporary health comes before stopping a heavy bleed, at the cost of the bleed running 2 s longer.
- Always healing below max, fastest first: the Health Injector goes before an IV even at 90 missing, at the cost of more presses and of overheal on a scratch.
- Covering the missing health over least overheal: one IV press heals fully when an IV can, at the cost of overheal, e.g. Blood overheals 15 at 70 missing where Saline would leave 5.
- Gameplay tags over walking active effects: one tag lookup per condition, at the cost of relying on the game granting the tags the stop effects require.
- One step per press over treating everything in one press: each press is one use with one animation, at the cost of several presses for several conditions.
