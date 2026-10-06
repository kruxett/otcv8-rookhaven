# Six local passive test trees

This document records the temporary-overlay phase. The subsequent local
permanent class and starter-spell increments are described in
[passives-permanent.md](passives-permanent.md) and
[class-starter-spells.md](class-starter-spells.md); the deferred items below refer
to the scope of this earlier phase.

## Scope and approval

This extends the reviewed Reaver prototype with Blademaster, Earthshaker,
Marksman, Arcanist and Lifekeeper. These names identify disposable test overlays.
They do **not** change vocation, class, ascension, learned spells, quest storage,
bank balance or permanent passive progression. Implementation and testing are
local only. No commit or push is authorized by this work.

The capstone mechanics follow the accepted discussion. All numerical values
remain test tuning. The 40 minor and 30 major nodes in the five new trees are
new provisional proposals based on the tested Reaver template; they are not
being presented as a previously approved detailed specification.

## Authoritative files and contract

Server repository: `../Rookhaven`.

* `data/lib/passives/config.lua`: shared numeric defaults and overrides per tree.
* `data/lib/passives/definitions.lua`: names, descriptions, spell metadata and
  capstone descriptions, with text derived from the numeric configuration.
* `data/lib/passives/test.lua`: template, graph, local GOD commands and opcode 103.
* `src/passives.cpp`, `src/passives.h`: native weapon checks, validation and effects.
* `src/luascript.cpp`: native Lua bindings.

`PassiveTest.trees` contains six catalogs; `PassiveTest.tree` remains an alias of
the Reaver catalog for the original preview fixture. `PassiveTest.config(treeId)`
returns a fresh, flat numeric merge of common values and that tree's overrides.
The native server keeps configuration separate per tree and rejects a changed
configuration while that tree has an active overlay. Opcode 103 accepts no
configuration from the client.

Native Lua contracts:

```lua
actor:passiveTest('configure', numericValues, treeId)
actor:passiveTest('start', targetPlayer, treeId)
actor:passiveTest('nodeIds', treeId) -- ordered array of 17 IDs
actor:passiveTest('preset', targetPlayer, 'capname')
```

Starting validates native IDs against catalog IDs. A tree switch must pass the
native combat/queued-action gate before ending the old session. The new session
invalidates old requests, delayed effects, ranks and runtime meters. Logout and
ending the test clear the overlay. No database migration is part of this phase.

The catalog includes `id`, `name`, `weaponName`, `nodes`, `edges`, `branches`,
`spellNames` and optional `healSpellNames`. Branch labels use the client's physical
display order: Precision, Pressure, Sustain, Guard. The native snapshot selects
the catalog by `treeId`; class names are display metadata, not vocation IDs.

## Commands

Use the isolated local server and the retro local client launchers described in
`local-passives-test.md`. Commands require local GOD access; normal players do
not start overlays through the protocol.

```text
/passivetest list
/passivetest help
/passivetest start reaver, Passive Tester
/passivetest start blademaster, Passive Tester
/passivetest start earthshaker, Passive Tester
/passivetest start marksman, Passive Tester
/passivetest start arcanist, Passive Tester
/passivetest start lifekeeper, Passive Tester
/passivetest preset Passive Tester, duelist
/passivetest open Passive Tester
/passivetest status Passive Tester
/passivetest reset Passive Tester
/passivetest trace Passive Tester,on
/passivetest stop Passive Tester
```

Player name may be omitted to target the administrator. Presets accept the short
capstone name or its full `cap_` ID, and must belong to the active tree. Reset is
free. Stop is administrative cleanup; allocating, resetting and switching remain
subject to the native combat rules. Client draft allocation changes no effects
until the server accepts Apply.

## Shared graph and provisional basic nodes

Each tree has 24 test points, eight minors with five ranks, six majors with three
ranks and three capstones with one rank. At most one capstone is allocated.
Core majors require four minor ranks in their own pair; bridge majors require
two minor ranks in each connected pair and one of the connected core majors.

Each capstone requires **15 other spent points** plus any two of its three
relevant major nodes at rank two. Families by zero-based native index are
`{8,9,12}`, `{9,12,11}` and `{10,11,13}`. The graph has 21 edges. It is shared
across trees so the reviewed retro layout and alternate prerequisite paths remain
consistent. The catalog still supplies all prerequisites; client code does not
decide combat eligibility.

The first fourteen stable IDs are identical across trees:

| Minor ID | Per-rank effect |
| --- | --- |
| `minor_precision` | +0.5 percentage points ordinary-attack critical chance |
| `minor_critical` | +5 percentage points critical bonus damage |
| `minor_power` | +0.5% direct weapon/eligible offensive spell damage |
| `minor_efficiency` | -1% eligible spell mana cost; fractional savings carried |
| `minor_vitality` | +1% derived max HP while wielding the correct weapon; no heal |
| `minor_resilience` | -0.5% direct physical monster damage |
| `minor_recovery` | 0.2% life leech from actual primary monster HP damage |
| `minor_focus` | +0.1 mana/second while wielding the correct weapon |

Lifekeeper replaces the first two effects with +0.5% and +1% direct healing per
rank. No critical healing mechanic is implied. Rod damage still uses Power.

| Major ID | Per-rank effect and trigger |
| --- | --- |
| `major_precision` | +1 percentage point critical chance; ordinary critical prepares -2% mana for the next eligible cast, ready 8 s |
| `major_pressure` | +1% direct damage; every fifth successful ordinary attack can hit one adjacent extra monster for 10% pre-critical damage, 8 s internal cooldown |
| `major_guard` | +2% max HP; actual direct monster damage prepares -1% damage on the next direct physical monster hit, ready 8 s |
| `major_recovery` | +0.2% leech; qualifying primary monster kill heals 1% max HP, 12 s internal cooldown |
| `major_tactical` | -1% eligible spell mana; alternating ordinary attacks and eligible offense prepares +2% next spell damage, ready 8 s |
| `major_steady` | +2% received direct healing; below half HP, -1% direct physical monster damage |

Lifekeeper's `major_precision` instead gives +1% direct healing and prepares the
mana discount from effective direct healing. Its `major_tactical` alternates
ordinary rod attacks and effective direct healing, preparing +2% next direct
healing per rank. Passive heals and healing over time do not advance that sequence.

Provisional display names, in ID order:

| Tree | Eight minor names | Six major names |
| --- | --- | --- |
| Reaver | Precision, Critical Force, Power, Efficiency, Vitality, Resilience, Recovery, Focus | Measured Edge, Overwhelming Force, Iron Resolve, Battle Recovery, Tactical Focus, Steady Nerves |
| Blademaster | Accuracy, Keen Force, Sword Power, Efficiency, Vitality, Poise, Recovery, Focus | Measured Blade, Relentless Edge, Iron Poise, Second Wind, Blade Rhythm, Steady Hand |
| Earthshaker | Accuracy, Heavy Force, Club Power, Efficiency, Vitality, Resilience, Recovery, Focus | Measured Impact, Heavy Pressure, Iron Foundation, Battle Recovery, Heavy Rhythm, Steadfast |
| Marksman | Accuracy, Deadly Force, Bow Power, Efficiency, Vitality, Resilience, Recovery, Focus | Measured Shot, Pressure Volley, Iron Resolve, Field Recovery, Shot Rhythm, Steady Aim |
| Arcanist | Accuracy, Critical Force, Arcane Power, Efficiency, Vitality, Resilience, Recovery, Focus | Measured Spark, Arcane Pressure, Iron Will, Arcane Recovery, Spell Rhythm, Steady Mind |
| Lifekeeper | Mending, Healing Force, Rod Power, Efficiency, Vitality, Resilience, Recovery, Focus | Measured Remedy, Vital Pressure, Iron Resolve, Life Recovery, Healing Rhythm, Steady Care |

## Capstone contracts and initial tuning

All secondary damage, bleeding, shields, passive heals and delayed echoes must
avoid recursive passive procs. Actual monster HP damage and effective direct
healing are measured after relevant mitigation; overkill/overheal cannot create
extra resources. Area spells and burst-arrow secondary effects remain one action.

| Tree | Capstone | Mechanic and initial test values |
| --- | --- | --- |
| Reaver | `cap_berserker` | Ordinary axe hit gives 10 Rage; at 100, +20% direct damage for 8 s; no Rage during Berserk |
| Reaver | `cap_bloodletting` | Every third ordinary hit applies a wound: 30% actual damage over 18 s; at most three player-owned wounds per target, only with this choice; legacy bleeding elsewhere |
| Reaver | `cap_bloodguard` | Three ordinary hits grant 30% of their actual damage as ward, cap 6% own max HP, 12 s |
| Blademaster | `cap_duelist` | Three ordinary hits on one monster prepare next sword spell echo: 35% pre-critical cast budget after 250 ms; target change breaks setup; ready 12 s |
| Blademaster | `cap_riposte` | Actual shield block prepares one next ordinary hit at +40% base damage; 6 s internal cooldown, ready 12 s |
| Blademaster | `cap_bladestorm` | Ordinary critical strikes at most two extra adjacent monsters, each 40% pre-critical base damage |
| Earthshaker | `cap_aftershock` | Four ordinary hits prepare next club spell's delayed wave: 25% pre-critical cast budget after 500 ms, at most three targets |
| Earthshaker | `cap_stoneguard` | Actual shield blocks build up to three charges: -2% direct physical monster damage/charge; next club offense consumes for +10% damage/charge; expire 12 s out of combat |
| Earthshaker | `cap_stonebond` | Actual shield block wards eligible party within two tiles for 3% recipient max HP, 12 s, 6 s cooldown; self fallback; no damage redirection |
| Marksman | `cap_deadeye` | Three ordinary hits on one target without moving prepare +30% next ordinary primary shot; movement/target change breaks setup |
| Marksman | `cap_skirmisher` | Moving between successful hits builds three Momentum; next ordinary shot bounces to two distinct monsters at 30%/20% pre-critical damage, two-tile links with line of sight; no piercing alignment or repeat burst explosion |
| Marksman | `cap_quarry` | Three same-target ordinary hits mark one monster for 10 s: +5% party ordinary-attack damage, 20 s cooldown; Marksman marks do not stack |
| Arcanist | `cap_conduit` | Three successful offensive casts prepare next ordinary wand hit to chain to two distinct targets at 30%/20% pre-critical damage, two-tile links with line of sight |
| Arcanist | `cap_resonance` | Three casts on one primary target prepare next wand spell echo: 30% full-cast pre-critical budget after 500 ms; target change breaks setup |
| Arcanist | `cap_spellweaver` | Three successful offensive casts differing from the previous spell prepare next offense at +15% damage/-25% mana; A-B-A qualifies; ready 12 s |
| Lifekeeper | `cap_renewal` | Effective direct healing adds 20% healing over three ticks/six seconds; stronger remaining renewal replaces weaker; no stacking or overheal |
| Lifekeeper | `cap_aegis` | Effective direct healing wards receiver for 15% healed, cap 8% receiver max HP, 12 s; stronger replaces weaker, no stacking |
| Lifekeeper | `cap_concord` | Actual primary rod attack/eligible rod spell damage heals lowest-HP% eligible party member including self for 40%, capped at 2% receiver max HP; one proc/action, solo self, Heal Friend range 7x5, same floor and line of sight |

The Reaver bleeding duration is the reviewed phase-one value of 18 seconds,
which permits three naturally accumulated wounds at the game's attack cadence.
Rend synergy is deferred because the new ascension spells are outside this phase.

## Existing weapons and spells

Native weapon metadata controls eligibility. Rod item IDs are
2181, 2182, 2183, 2185, 2186, 8910, 8911 and 8912. Wand IDs are 2187–2191,
8920–8922 and 12741–12759. These are server item IDs, not client sprite IDs.
Marksman requires a bow/crossbow with ammunition, rather than thrown weapons.

Existing eligible spells:

* Axe: Head Splitter, Axe Throw.
* Sword: Swipe, Pommel Strike.
* Club: Ground Slam, Seismic Shockwave.
* Bow/crossbow: Sure Shot, Volley.
* Wand: Fire Burst, Flame Nova, Inferno; Lightning Bolt, Shock Blast, Chain
  Lightning; Ensnare, Toxic Root, Deadly Vines; Frost Shard, Ice Lance, Glacial
  Spike; Shadow Bolt, Raise Dead, Soul Drain. These names have the existing
  `Wand ` prefix in the spell registry.
* Rod offense: the nine Earth/Ice/Death entries in the preceding list, subject to
  each existing script's actual element/item checks. Existing spells called
  "Wand" can also accept rods; this prototype does not rewrite them.
* Rod healing: Light Healing, Intense Healing, Ultimate Healing, Divine Healing,
  Heal Friend, Mass Healing.

Spells still require their existing learning, skill, mana and weapon conditions.
The test does not grant spells. A summon-only cast or a cast causing zero actual
monster damage must not count as successful offense. Direct healing counts only
its effective amount. New spells and hotkey/cooldown adapters remain deferred.

## Client and graphics

Only the classic retro layout is in scope. First fourteen icon paths in each
new tree are `/images/game/passives/<tree>_<nodeId>.png`; Reaver retains the
reviewed original paths. Capstone filenames are the full `cap_` IDs. Icons are
native 32x32 with binary transparency and a restrained palette; interpolation
is disabled. No new world sprites, `.dat`, `.spr` or `.otb` entries are needed.

The isolated local profile disables the updater and uses the executable's own
archive. The ordinary DEV/PROD launch profiles remain separate. Packaged resource
checksums must be calculated after the final archive, as in the existing local
build/checksum workflow.

## Verification gates

Completed source/catalog checks:

* LuaJIT loads configuration, definitions and template for all six trees.
* Each has 17 unique nodes, rank limits 5/3/1, 21 valid edges, valid prerequisite
  IDs and three prerequisite alternatives per capstone.
* All 102 tree/node icon references exist; numeric merges do not mutate defaults
  and do not leak another tree's capstone configuration.
* Catalogs encode to about 15–16 KB each and fit four or five 4000-byte chunks,
  under the client's 100 KB/32-part bounds.
* Stub command contract tests exercised six starts, all 18 preset names,
  status/reset/trace/stop, catalog chunks and four rejected inputs.

These checks validate data and Lua dispatch, not native gameplay. Before calling
the expansion playable, the native build, real client tree selection/layout,
combat effects, state cleanup, party targeting and balance need independent live
tests. Include wrong weapon, stale session/revision, combat-time tree switch,
fractional mana, overheal/overkill, shields from multiple sources, delayed target
removal and two players with different active trees. Each capstone requires a
natural trigger test rather than merely forcing its meter through an admin tool.
