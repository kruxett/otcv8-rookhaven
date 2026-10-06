# Capstone routes: reviewed implementation proposal

Status: accepted design from the critical review, implemented locally on 2026-10-06
in native validation, catalog metadata, client connections and saved-build migration.
The rules and migration passed their connected tests. Current results and test
scope are recorded in [the fixes and verification](passives-fixes-verification.md).

## Invariants

- Saved node IDs and the 17-entry rank order stay unchanged.
- Core majors still require four combined points across their two minors.
- Bridges still require two minor points in each linked area and one linked
  core major rank.
- A capstone still costs one point, requires fifteen other points and two
  relevant majors at rank two. A build can choose only one capstone.
- The same physical capstone slot must not determine its requirements. The
  displayed name, routes and server validation must describe the same stable ID.

Indices below are **one-based saved indices**, not displayed column indices:
9 Precision/Healing, 10 Pressure, 11 Guard, 12 Sustain, 13 offensive/healing
rhythm bridge, 14 defensive/healing bridge. Guard precedes Sustain in saved data;
the UI displays Sustain before Guard.

## Proposed class-specific families

| Class | Capstone | Relevant major indices | Why |
| --- | --- | --- | --- |
| Reaver | Berserker | 9, 10, 13 | Ordinary offensive attacks and attack/spell rhythm |
| Reaver | Bloodletting | 10, 12, 13 | Actual attack damage, sustain and Rend rhythm |
| Reaver | Bloodguard | 11, 12, 14 | Surviving contact combat and recovery |
| Blademaster | Duelist | 10, 12, 13 | Sustained same-target attacks followed by a finisher |
| Blademaster | Riposte | 11, 12, 14 | Actual shield blocks and defensive contact combat |
| Blademaster | Blade Storm | 9, 10, 13 | Ordinary critical attacks and multiple monsters |
| Earthshaker | Aftershock | 9, 10, 13 | Ordinary attacks preparing an offensive club spell |
| Earthshaker | Stoneguard | 10, 11, 14 | Both a guarded offensive path and a defensive path |
| Earthshaker | Stonebond | 11, 12, 14 | Party protection and recovery |
| Marksman | Deadeye | 9, 10, 13 | Stationary same-target offence |
| Marksman | Skirmisher | 10, 12, 13 | Moving offence, sustain, attack/spell rhythm |
| Marksman | Quarry | 10, 12, 13 | Sustained ordinary attacks supporting party damage |
| Arcanist | Conduit | 9, 10, 13 | Offensive casts preparing an ordinary wand attack |
| Arcanist | Resonance | 10, 12, 13 | Sustained same-target spell expenditure |
| Arcanist | Spellweaver | 10, 12, 13 | Alternating spells and mana sustain |
| Lifekeeper | Renewal | 9, 12, 14 | Direct healing, recovery and received healing |
| Lifekeeper | Aegis | 9, 11, 14 | Direct healing and protection |
| Lifekeeper | Concord | 10, 12, 13 | Damage converted into party healing |

**Blade Storm needs an additional explicit relevant-major anchor:**
`major_precision >= 2`. Merely adding Precision to its family still allows
Pressure + Tactical without any critical chance. The anchor keeps the approved
two-major rule, with the second major chosen from Pressure or Tactical. An
ordinary sword with no critical gear can then activate the talent. Four combined
minor points remains the general core gate; no hidden five-point gate is proposed.

Other caps have no proposed mandatory major anchor. Their triggers already work
without a particular minor statistic, subject to the ordinary weapon/shield,
mana, actual-damage/healing and target conditions.

## Concrete first-capstone builds: exactly sixteen points

Rank vectors preserve this order:

```text
precision, critical, power, efficiency, vitality, resilience, recovery, focus,
major_precision, major_pressure, major_guard, major_recovery,
major_tactical, major_steady, cap_1, cap_2, cap_3
```

The following reusable fifteen-point foundations are legal before adding the
named capstone. Their zero entries are intentional; these are level-40 paths,
not full-budget administrative presets.

| Foundation | First fourteen ranks | Purpose |
| --- | --- | --- |
| O | 4,0,3,1,0,0,0,0,2,2,0,0,3,0 | Offensive attack/spell rhythm |
| H | 0,0,3,1,0,0,5,2,0,2,0,2,0,0 | Offensive sustain |
| G | 0,0,0,0,3,1,3,1,0,0,2,2,0,3 | Guard and recovery |
| C | 5,1,3,1,0,0,0,0,3,2,0,0,0,0 | Maximum intrinsic critical chance on this path |
| SG | 0,0,3,1,5,2,0,0,0,2,2,0,0,0 | Guarded pressure, shield charges into a spell |
| RH | 5,1,0,0,0,0,3,1,3,0,0,2,0,0 | Direct healing with recovery |
| AH | 5,1,0,0,3,1,0,0,3,0,2,0,0,0 | Direct healing with protection |

| Class | Capstone | Foundation | Final cap ranks |
| --- | --- | --- | --- |
| Reaver | Berserker | O | 1,0,0 |
| Reaver | Bloodletting | H | 0,1,0 |
| Reaver | Bloodguard | G | 0,0,1 |
| Blademaster | Duelist | H | 1,0,0 |
| Blademaster | Riposte | G | 0,1,0 |
| Blademaster | Blade Storm | C | 0,0,1 |
| Earthshaker | Aftershock | O | 1,0,0 |
| Earthshaker | Stoneguard | SG | 0,1,0 |
| Earthshaker | Stonebond | G | 0,0,1 |
| Marksman | Deadeye | O | 1,0,0 |
| Marksman | Skirmisher | H | 0,1,0 |
| Marksman | Quarry | H | 0,0,1 |
| Arcanist | Conduit | O | 1,0,0 |
| Arcanist | Resonance | H | 0,1,0 |
| Arcanist | Spellweaver | H | 0,0,1 |
| Lifekeeper | Renewal | RH | 1,0,0 |
| Lifekeeper | Aegis | AH | 0,1,0 |
| Lifekeeper | Concord | H | 0,0,1 |

### Payoff conditions to verify

Blade Storm C supplies **5.5% intrinsic passive critical chance** with the current
config (five minor ranks at 0.5 percentage points plus three major ranks at one
percentage point). At one successful attack every two seconds, the illustrative
mean wait is about 36 seconds before an ordinary critical hit, plus the adjacent
monster requirement. The previous route's maximum at sixteen points was 3%.
This is an accessibility correction, not a claim of measured hunt balance.
The minimal anchor supplies at least 2% regardless of how the four precision-area
minor points are split. That can still be slow. Display its dependency honestly
and retain the bounded natural-trigger test; do not increase damage to mask it.

Riposte, Stoneguard and Stonebond need a legitimate shield and actual shield
blocks, not a shield-looking icon or forced administrative proc. Renewal and
Aegis need effective direct healing; overhealing is correctly excluded. Concord
needs actual primary damage and its Heal Friend eligibility rules. Arcanist
capstones need a legal wand and actually castable distinct spells; two starters
already allow A-B-A for Spellweaver. All first-capstone tests should use ordinary
level-40 gear and actual learned spells, with no critical gear or fabricated proc
unless it is a separate deterministic engine test.

## One authoritative rule source

Preferred: native per-tree capstone metadata owns family indices and optional
anchor indices. Expose it through the existing trusted server-side passive Lua
API. `buildTree`, `annotateCatalog`, `requires`, `requirementSummary` and `edges`
all consume that metadata. The client renders the supplied graph; it does not
reconstruct a universal left/middle/right family. Native validation must take
the tree on both apply and permanent restore. Unknown/missing metadata fails
startup or refuses that tree, rather than silently falling back to the old routes.

An integration test should compare all eighteen catalog family/anchor contracts
to accepted and forged rejected native allocations at sixteen points. Pure
source equivalence or a screenshot is insufficient. Keep exactly twenty-one
unique edges (eight core, four bridge, nine capstone links), even where two caps
share a family. Render actual endpoints with crossing gaps and readable routes;
do not draw unrelated substitute links just to keep the old picture.

## Compatibility for existing local saved builds

Some old capstone allocations cease to satisfy their class-specific routes.
Stable IDs alone does not preserve validity. The main agent selected a free full
rank refund for an old-valid/new-invalid build. This gives every user the same
new graph and prevents an old route silently bypassing Blade Storm's new anchor.

1. Keep a saved build that satisfies the new rules unchanged.
2. If it fails the new rules but satisfies every old rule, reset only its ranks
   in a locked DB transaction. Preserve class, earned points, respec counter,
   bank and starter entitlements. All earned points become available again.
3. If it fails both old and new rules, reject the corrupt ledger. Do not turn an
   arbitrary invalid allocation into a free successful login.
4. Notify affected local users that routes changed and all their talent points
   were refunded without a fee or a counted respec.

The transaction must re-read and validate the locked row's actual class, ranks,
point budget and respec count. Failure must leave the original row and in-memory
profile unchanged and inactive. An already active profile cannot retain its old
ranks after the row is reset; either refuse that restore while active or update
combat state, HP and revision as one coherent profile transition. The next login
is idempotent: no extra refund, fee or respec increment.

Required cases include Blade Storm old G-only build -> refund; a new valid C
build -> retained; Riposte old H-only build -> refund; old and new common G/O
paths -> retained; too many caps, bad ranks or below-gate corruption -> rejected;
DB write/commit failure -> unchanged; logout/relogin -> unchanged refunded row;
class/bank/earned/count/spells -> identical before/after.

**Downgrading only the binary is not safe:** the new rules can produce a saved
build that the old universal families reject. Keep a pre-change passive-ledger
backup and document restoring compatible ranks before any downgrade. No
production migration is proposed or authorized in this review; release migration
still needs its own backup and rollback rehearsal.

## Enumeration evidence

`out/capstone-routes/proposed-families-and-16point-builds.json` contains all eighteen
concrete builds above and fifty-four legal sixteen-point witnesses: all three
possible relevant-major pairs for each capstone, counting the Blade Storm anchor
where it adds a third major. The independent planning calculation checks rank
limits, exact point count, core/bridge gates, relevant major pairs and the anchor.
This is static reachability evidence. The main agent must still submit accepted
and forged rejected vectors through the live native server and compare catalog
families, requirements and actual displayed endpoints.
