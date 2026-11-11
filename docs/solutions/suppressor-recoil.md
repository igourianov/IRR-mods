# Suppressors without recoil reduction

Follow-up to `docs/solutions/ak-rpm-recoil-balance.md`.

## Intent

The game sums the stats of stacked muzzle devices, so on an AR a suppressor on a flash hider added both reductions and beat the flash hider alone. Per the user:

- A flash hider or brake should recoil less than a suppressor.
- Suppressors mounted on the barrel don't reduce recoil.
- A suppressor that stacks on a flash hider or brake cancels that device's recoil bonus. Brakes included.
- Raise the 5.45 and 5.56 AK bases to keep the AK and AR split even.

## Recon

From the extracted cooked assets (game build 26487830):

- A stacking suppressor is one whose tag appears in another muzzle device's name map (its `U_Muzzle_C` slot). Barrel-mount suppressors come in through the `UISI_Muzzle_*` class lists.
- Stacking pairs, with the mod's mount recoil:
  - Griffin M4SD II on the Gate-LOK (-4) and the Colt A2 (-2, vanilla)
  - AAC 762-SDN-6 on the SCAR-L and SCAR-H AAC SD 51T flash hiders (-2, vanilla)
  - Surefire SOCOM556-MONSTER on the Surefire SD3P-556 (-1, vanilla)
  - DT338 Suppressor on the DT338 brake (-22)
  - Honey Badger Trash PANDA on the Cherry Bomb brake (-17)
  - Surefire SOCOM338-TI Suppressor on the SOCOM338-TI brake (-22.5)
  - SVD Rotor43 on the Rotor43 thread adapter (0), so it counts as barrel mount here
- Item prices live in `FIRRMarketAvailability.DefaultMarketPrice` on `FIRRVendorDefaultItem` rows. `DA_VendorSettings` (`UVendorSettings.VendorDataTable`) still points at `/Game/Blueprints/InventorySystem/Vendor/DT_Vendor_Old`. `DT_Vendor` no longer exists. Prices were looked at for a price-scaled penalty, which the user dropped.

## Solution

In `likhos-rearmed/stats.json`:

- Every suppressor the mod lists has `Recoil` 0, except the stacking ones, which are set to the opposite of their mount: M4SD II +4 (tuned for the Gate-LOK), AAC 762-SDN-6 +2, SOCOM556-MONSTER +1, DT338 +22, Trash PANDA +17, SOCOM338-TI +22.5.
- The VSS and AS VAL integral suppressors stay out of the mod.
- 5.45 and 5.56 AK bases +2.5, then every AK base rounded up to a whole number per the user: AK-74M 58, AK-12 56, AK-105 58, AK-101 57, AK-102 57, AKS-74 58, AK-103 64, AK-104 64.

Full builds from the scratchpad resolver, per second (stat × RPM / 700), before the AK raise:

| | Loud | Suppressed |
|---|---|---|
| M4A1 | 15.4 | 20.0 (was 10.3) |
| AK-74M | 6.5 | 24 (was 19.5) |

After the raise and rounding the 5.45 AKs sit at 9.5 and 27, so the AK leads by about 6 loud and the AR by about 7 suppressed. The AK-12 lands at 9.5 and 25, the AK-101 and AK-102 at 9 and 26, the 7.62x39 AKs at 16 and 33.

Files: `likhos-rearmed/stats.json`, `README.md` (and the gitignored `README.bbcode`), `CHANGELOG.md`.

## Tradeoffs and open

- The stacking values depend on the mount's recoil. A later change to a mount needs the matching suppressor changed too.
- The M4SD II on a Colt A2 ends 2 worse than no muzzle device.
- Brake-mounted suppressors show large positive recoil in the gunsmith screen.
- SMGs and pistols lose 2.5 to 6 when suppressed. This feeds the parked SMG review.
- Ergonomics still stack.
- The KAC QDC eliminator taking a second flash hider is a game bug and is ignored.
