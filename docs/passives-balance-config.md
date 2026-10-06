# Central passive balance configuration

Edit the server repository's `data/lib/passives/config.lua`.
This is the source for numeric tuning in the six local passive test trees.
It also supplies the permanent classes' effects and the `progression` section
for point milestones and bank-paid respec costs. See [the permanent flow](passives-permanent.md)
for the provisional curve, fees, persistence and player entry points.
The server sends the resulting descriptions and runtime meters to the client.
Do not edit the copied file under `out/local-server/passives-runtime` for normal
balancing: a refresh overwrites that disposable copy.

## Shared values and per-tree overrides

`common` contains shared defaults. `trees.reaver`, `trees.blademaster`,
`trees.earthshaker`, `trees.marksman`, `trees.arcanist` and `trees.lifekeeper`
override those defaults and contain their own capstone values. A shared key
can also be set in one tree to change only that tree. Merges create fresh tables;
changing one tree does not mutate another.

Example changes inside the existing table:

```lua
common = {
  minorPower = .5,             -- +0.5% damage per rank
  majorPressureHits = 5,       -- successful normal attacks per secondary-hit attempt
  majorPressureCooldownMs = 8000,
  manaDiscountCapPercent = 50, -- combined passive mana-discount limit
  -- retain the other existing common keys
},
trees = {
  reaver = {
    minorPower = .75,          -- Reaver only; overrides the shared 0.5%
    rageThreshold = 100,
    ragePerHit = 10,
    berserkPercent = 20,
    berserkMs = 8000,
    -- retain the other existing Reaver keys
  },
  -- retain the other five tree tables
}
```

## Units

| Value kind | Meaning | Example |
| --- | --- | --- |
| `Bps` | Integer basis points of critical chance; 100 = one percentage point | `minorPrecisionBps = 25` gives +0.25 percentage points per rank |
| `Ms` | Integer milliseconds | `berserkMs = 8000` means eight seconds |
| Minor/major percentages | Usually per allocated rank; capstone percentages are the stated whole-effect amount | `minorVitality = 2`, rank5 gives +10% max HP |
| `minorFocus` | Mana per second per rank, with fractional accumulation | `.025`, rank5 gives 0.125 mana per second: one mana every eight seconds |
| Hits/casts/ticks/charges/rage | Positive integer counts | `bloodguardHits = 3` requires three successful ordinary hits |
| Range | Integer tile distance; Concord uses separate x/y extents | `stonebondRange = 2` |

Descriptions identify whether damage is based on actual HP damage, pre-critical
cast damage, recipient max HP or another budget. Increasing a rank value is not
the same as increasing a capstone budget. Native validation rejects unknown
keys, invalid units and values outside the prototype's bounds. Durations are
currently bounded to 50..60000 ms. Bloodletting requires `bleedMs >= bleedTicks * 1000`, so each damage tick respects the engine interval. The native
validator in `src/passives.cpp` defines the other limits.

The low-and-slow audit reduced Focus from `.1` to `.025` per rank. At five ranks
the former value added as much mana as vocation 3's entire normal food regeneration
(2 mana per 4 seconds). Focus also runs without food and in protection zones;
the revised full-rank bonus is 25% of that food baseline, rather than 100%.
It still cannot exceed current maximum mana. See
[the acquisition and balance audit](class-spell-balance-audit.md) for limitations.

## Connected route values

All six trees now contain 29 separate nodes. Their new numeric tuning is in the
same tracked `common` table, with per-class overrides in `trees`:

| Keys | Default and scope |
| --- | --- |
| `midBroadPercent`, `midPrimaryPercent` | 0.5% per rank; eligible secondary/primary spell damage respectively. Sword uses primary damage for Broad; Lifekeeper uses actual direct healing for both. |
| `midPrecisionBps`, `midHealingPercent` | 20 basis points of offensive critical chance per rank; Lifekeeper uses 0.2% direct healing instead. |
| `midManaPercent`, `midHpPercent`, `midReductionPercent` | 1% spell mana discount, 0.5% maximum HP, 0.5% direct physical monster damage reduction per rank. |
| `routeBroadPercent` | 4% per rank; Sword primary spell damage, other offensive classes eligible secondary spell damage. Lifekeeper overrides this to 1% direct healing. |
| `routePreparedPercent`, `routeSetupHits` | 3% per rank after two successful same-target ordinary hits; Lifekeeper prepares an effective direct heal instead. |
| `routeRhythmPercent` | 4% per rank on every third eligible same-target ordinary hit; Lifekeeper uses every third effective friendly direct heal. |
| `routeReturnPercent`, `routeReturnCapPercent` | Recover 3% per rank of actual direct monster damage taken, capped at 1% max HP per rank; the next successful ordinary attack spends the stored recovery. |
| `routeSustainPercent` | Eligible casting prepares 2% actual normal-attack damage healing per rank. |
| `routeBracePercent` | Eligible offensive casting prepares 2% reduction per rank for the next direct physical monster hit, before ward absorption. |
| `routeReadyMs`, `routeCooldownMs` | Stored readiness lasts 12 seconds; grants have an eight-second cooldown where applicable. |

These percentages are conservative starting values, not a completed hunt-balance
result. Do not force a minimum one-point bonus: native fractional ledgers retain
sub-unit amounts. The shared mana-discount cap still applies. The client receives
the configured descriptions from the server.

Named prerequisites and route layout are defined separately in tracked
`data/lib/passives/routes.lua`. Ship that file with the matching server library.
Changing topology requires validation of saved builds; it is not a numeric balance
change. No additional rows in the server's main `config.lua` are needed for these
new route values.

## Apply a numeric change locally

1. Edit `../Rookhaven/data/lib/passives/config.lua`.
2. From the client repository run:

   ```powershell
   ./tools/start-local-passives.ps1 -Refresh
   ```

   This restarts only the owned local test server and recopies its source data.
   Active test sessions end during the restart.
3. Log in again and start/open the desired tree, for example:

   ```text
   /passiveqa equip reaver
   /passivetest start reaver
   /passivetest preset Passive Tester,berserker
   ```

4. Inspect the node text and test its actual effect.

After this configuration support is built, changing supported numeric values
requires **no client rebuild, server C++ rebuild or new client checksums**.
The Lua configuration and catalog are loaded at server startup. Merely opening
a running tree does not reread the edited source file. The native server also
rejects changing a tree's effective configuration while it has active overlays.

## Scope

This configuration tunes implemented effects and the numerical permanent point
curve and respec fees in `progression`. Tree topology, new progression/respec rules,
5/3/1 rank limits, the three-wound Bloodletting mechanic, two-bounce mechanic,
class integration and the base formulas of existing active spells
are separate systems. Changing those requires implementation work. Native
safety bounds, callback lifetimes and percentage arithmetic are not balance knobs.
The basic-node values and all capstone values remain provisional local tuning.

See `local-passives-results.md` for actual gameplay evidence and the targeted
configuration test. Nothing is pushed or deployed by the refresh command.
