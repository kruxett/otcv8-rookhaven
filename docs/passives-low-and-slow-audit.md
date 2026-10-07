# Passive low-and-slow pass, 7 October 2026

This pass reviews all **174 talents (29 × six classes)** against the configured
Rookhaven map, source-linked acquisition and native formulas. It makes five
focused numerical reductions and preserves existing gear, old spells, tree
topology, point milestones, class eligibility and the one-capstone rule.
Source calculations are balance evidence, not measured hunt performance or a
claim that every class is equally strong. Native test results must be recorded
separately after rebuilding.

## Actual acquisition and comparison scope

The read-only `tools/passives/balance-access-audit.py` was rerun on the current
configured `rookalmost.otbm` and its referenced `Untitled-1-spawn.xml` before
editing. It found **66 active NPC names, 83 active monster names, no unknown map
attributes**, 12 starter spells, 72 formula profiles and 18 legal first-capstone
builds. Shops require a spawned NPC; drops require registered spawned monsters;
selected literal chest rewards require an action registration and placed map
unique ID. Decorative items and unspawned monster definitions do not count as
acquisition. Scripted quest/forge rewards are additionally source-reviewed.

These are conditional authored sources. The review did not navigate every map
route, complete every quest, observe live drop distributions or prove normal
players can farm every referenced spawn. Stronger conditional sources are
sensitivity cases, not the baseline or justification to inflate talents.

| Role | Ordinary source baseline | Conditional authored upgrade |
| --- | --- | --- |
| Axe | Hatchet2388 attack15, spawned Blind Orc85 gold; Obi Axe2386 attack12/20 | Great Waraxe12732 attack27, mapped Hatchling chest UID30217; Double Axe2387 attack35, single deep Fire Devil loot |
| Sword | Sword2376 attack14, Blind Orc85 and ordinary monster loot; Katana2412 attack16 chest/Rotworm | Crystal Sword7449 attack35, Barbarian Skullhunter loot; Jagged Sword8602 attack21, mapped Mini Annihilator chest/Wyvern loot |
| Club | Mace2398 attack16, Skeleton/Minotaur/Rotworm/Bandit drops | Clerical Mace2423 attack28, Dwarf Geomancer loot; Brutetamer's Staff7379 attack35, Barbarian Brutetamer loot |
| Bow | Bow2456 and Arrow2544 attack25; Garrick quest progress≥1,200/3 gold; Blind Orc bow400 | Forge after Rite of Precision, materials/gold; no free unlimited arrows assumed |
| Wand | Hex12746 death2–5, mana2, spawned Plipus50 | Dusk12753 mapped Ancient Depths chest UID30157: native8–15 plus fixed6 death and food-dependent1 mana regen; Jade12758 earth12–24/mana6, Dwarf Geomancer loot |
| Rod | Snakebite2182 earth2–5, mana2, Plipus50 | Necrotic2185 death27–33/mana5, same single deep Fire Devil loot; unchanged |
| Armour | Dixi leather body4, helm2, legs1; common Troll boots1 → complete mundane armour8 | Samwell Chain body6/legs3 plus Brass helm3/boots1 →13 total; body Brass8/Scale9/Plate10; conditional Warrior helm8 and Plate legs7 |

The remembered attack21 and armour8–9 are therefore not current hard source
ceilings. Body-piece armour is distinct from the native **sum** of worn armour.
The35-attack weapons cited are two-handed and lose shield-driven talents.
Barbarian spawns are in the northern Stillshore area; the normal Stillshore boat
requires Floki repair progress2 and50 gold. The Fire Devil is a single spawn at
32053,32230,15. Mini Annihilator requires four eligible level30 players and
permits one reward; the reward chest alone is not fresh gear access.

Rarity slot defaults and forging remain material conditional sensitivities:
legendary sword rolls can add3–5 attack,2–5 skill,4–8 crit points or30–200 crit
bonus; a wand elemental roll can add4–10 damage per auto; armour can roll10–13%
physical resistance. Forge tiers have material gates and500/5000/20000 gold
costs. No combined perfect-affix loadout is assumed. These stronger existing
systems are recorded, not changed or treated as required ordinary progression.

Existing eligible learned spells are included in the comparison: Oracle
Head Splitter/Swipe/Ground Slam and later own-weapon spells require their
donation, skill, ML and Ascension conditions; third Ascension retains actual
learning, not every spell. Soul Drain has its inherited ten decaying pulses over
36s and overlaps on durable targets. Light Healing requires its actual learning
quest. Passive power does not justify raising new spells to match these old
conditional schedules, and this pass does not silently retune them.

## Focused changes and why

| Central value | Before | After | Causal reason |
| --- | --- | --- | --- |
| `common.majorKillHeal` per rank |1% maxHP|0.2% maxHP|Free trivial-monster kill sustain previously dwarfed ordinary food regeneration and actual-damage leech |
| Reaver `bloodguardPercent` |30% of three actual primary hits|15%|Repeatable ward supply previously converted30% of ordinary delivered damage into protection; source, caps and strongest-ward rule preserved |
| Earthshaker `stonebondPercent` |3% recipient maxHP|1.5%|Repeated block-triggered party wards scaled with every recipient's HP independently of incoming damage; range,6s cooldown and shield requirement preserved |
| Earthshaker `stoneguardDamage` per charge |10%|5%|Three cheap repeatable shield charges previously gave30% spell burst on top of prepared-route/power bonuses; cap3 charges and2% reduction/charge preserved |
| Lifekeeper `concordPercent` |40% actual primary damage|15%|Damage-to-effective-healing conversion was far larger than minor/core sustain and grew sharply with the conditional Necrotic rod;2% recipient/action cap preserved |

Kill-heal and Concord now retain **less than one HP** of fractional earned
healing while the selected recipient is missing HP. They do not round each tiny
event up to1HP. Full/dead recipients grant no stored healing; filling HP or a
clipped/rejected whole heal discards the remainder. Combat-profile cleanup,
wrong-class weapon changes, reset, logout and death discard these new ledgers.
Concord carry belongs to the source and current recipient's GUID **and runtime
ID**, so changing recipient/reconnecting cannot transfer it. No source damage,
counter, attack cadence, ward stacking or overheal is amplified by the ledger.

This is necessary for the ordinary2–5-damage rod: truncating15% independently
would make every ordinary Concord shot heal0. Likewise the first legal
rank1 kill-heal at level7/240HP earns0.48HP: three qualifying kills earn one HP,
not three. Full-HP kills still consume the existing12s cooldown and bank nothing.

## Marginal value and cumulative progression

For offensive physical ceiling `M=L/5+(skill/4+1)*(attack/3)*1.03`, one attack
point adds `(skill/4+1)*1.03/3`. Thus a0.5% Power rank at40/skill24/attack15 is
about **0.092 attack points** in raw ceiling; all five Power ranks plus three
Pressure ranks give5.5%, about **1.01 attack**. At64 the same build is1.12;
at40/skill60/attack35 it is2.01. This excludes crits, armour, hit chance and cast
uptime and is not a displayed-item-attack or delivered-DPS claim. No passive
rank directly adds armour or weapon attack.

Ascended fed health regeneration is2HP/5s =0.4HP/s; fed mana is2/4s =0.5mana/s.
Focus5 remains0.125mana/s,25% of that mana baseline, and also works without food
and in PZ. Baseline after third Ascension is150HP and0maxmana; subsequent levels
add15HP/10mana. Preserved skills/learned spells vary by player.

| Milestone | Points | Representative raw passive size / constraint |
| --- | --- | --- |
| Level1 |3|Three Power ranks give1.5%, or three Vitality ranks3% maxHP; zero mana still prevents magic autos/starters |
| Level10 |6|A four-point foundation plus own core2; e.g.Power4+Pressure2 gives4% raw direct damage |
| Level22 |10|Foundation/core investment plus the first middle-route ranks; capstone remains unavailable |
| Level40 |16|First capstone:8 foundation, own core2+secondary1, route minor2, advanced1, one elective, cap1; representative direct power4.5% plus scoped route bonuses |
| Level64+ |24|Eight further ranks extend the same legal class/cap route; no second capstone or all-rank-max assumption |

The source model validates **18 cumulative same-class build witnesses**, one per
capstone, at3/6/10/16/24 points and432 individual legal purchase prefixes. These
are explicit legal examples, not exhaustive optimized best builds. Exact ranks,
static/readied modifiers, derived HP and before/after kill-heal amounts are in
`out/passives-balance-pass-20261007/cumulative-builds-and-sensitivities.json`.

For a rank3 kill-heal build,735HP at40 previously restored22HP/qualifying kill,
up to1.83HP/s at a kill every12s. Now the fractional budget is4.41HP/kill,
averaging0.3675HP/s while HP is missing. At64/1095HP the comparison is
32/12=2.67HP/s versus6.57/12=0.5475HP/s. Higher derived HP increases both; normal
kill rate, current missing HP and leech determine real sustain. These are
conditional rates, not measured hunting outcomes.

Bloodguard's former30% conversion becomes15%: three actual20HP hits previously
supplied18HP ward, now9; incoming damage and strongest-ward refresh determine
actual absorption. Stonebond at40/base735HP is22→11 ward HP per recipient per
eligible block/cooldown, at64 is32→16; it cannot stack its own pool. Concord
from three ordinary actual4HP shots previously healed1+1+1=3HP; now their
1.8HP total budget heals1 with0.8 carry if the same recipient remains injured.
A rare actual30HP rod hit formerly yielded12HP, now4 with0.5 carry, before the
recipient/action cap. The old12HP example requires recipient maxHP at least600
for the2% per-action cap not to bind; the new4.5HP budget needs225. Its5mana auto
still costs far more than food restores.

## Verdict for every shared talent role

IDs are shared across all six trees; weapon-flavoured displayed names are in the
174-entry source artifact. Lifekeeper exceptions are stated rather than treated
as critical damage. Retained numbers are reviewed provisional tuning, not proof
of equal utility at every damage/armour breakpoint.

| Talent ID / role | Maximum current size | Verdict |
| --- | --- | --- |
| `minor_precision` |2.5 crit points; Life2.5% healing|Retain: rare ordinary crit/low direct healing; no attack-speed increase |
| `minor_critical` |25 crit-bonus points; Life5% healing|Retain: not25% extra every hit; marginal average depends on actual crit probability/gear |
| `minor_power` |2.5% direct damage|Retain: smaller than one ordinary attack point in the baseline; static native rounding can mask very small hits |
| `minor_efficiency` |5% eligible spell discount|Retain: fraction billing, actual mana payment and minimum1 maintained |
| `minor_vitality` |5% maxHP|Retain: no healing or zero-mana bypass; stacks with existing base HP only once |
| `minor_resilience` |2.5% direct physical monster reduction|Retain: excludes conditions/PvP; static rounding and armour affect actual small-hit value |
| `minor_recovery` |1% actual primary-damage leech|Retain: finite delivered damage, not area sum or nominal weapon damage |
| `minor_focus` |0.125mana/s|Retain prior low-and-slow reduction; independent food/PZ benefit explicitly acknowledged |
| `major_precision` |3 crit points/6% readied next-cast discount; Life3% healing|Retain: critical/effective-heal setup and single paid-cast consumption |
| `major_pressure` |3% direct power,30% precrit secondary every5 hits/8s|Retain: normal2s autos need10s for5 successful hits; nearby secondary/armour required |
| `major_guard` |6% maxHP/3% readied physical reduction|Retain: no free healing; next qualifying hit, not another ward pool |
| `major_recovery` |0.6% leech/now0.6% maxHP kill heal per12s|Reduce kill component only; fractional early utility and no full-HP bank required |
| `major_tactical` |3% static mana discount/6% prepared cast benefit|Retain: alternating eligible normal/cast setup; not permanent6% auto damage |
| `major_steady` |6% received direct healing/3% reduction below50%HP|Retain: smaller conditional health/survival benefit and passive heals excluded |
| `mid_sweeping_form` |2.5% secondary spell damage; Sword primary; Life healing|Retain scoped damage/healing only |
| `mid_true_aim` |1 ordinary crit point; Life1% healing|Retain, not universal offensive-spell crit |
| `mid_focused_edge` |2.5% primary spell damage; Life healing|Retain restricted learned direct actions |
| `mid_measured_breath` |5% eligible spell discount|Retain additive billing cap, not wand-auto mana discount |
| `mid_stout_heart` |2.5% maxHP|Retain composed native HP once |
| `mid_braced_guard` |2.5% direct physical reduction|Retain fractional reduction ledger and no condition/PvP benefit |
| `path_broad_stroke` |12% secondary; Sword primary; Life3% healing|Retain: most classes need extra positioned targets; Sword flat spell route pays two foundations; Life uses smaller override |
| `path_deliberate_cut` |9% prepared primary/healing|Retain: two real same-target ordinary hits,12s readiness, paid miss consumption for offense |
| `path_blood_return` |9% one received hit/cap3% maxHP|Retain:8s grant cooldown, actual HP loss and next successful normal hit; no absorbed-damage budget |
| `path_hewing_rhythm` |12% every third normal hit; Life third effective heal|Retain:4% raw sequence average at most, resets/target/expiry rules preserve cadence |
| `path_battle_sustenance` |6% one actual normal primary hit healing|Retain: cast setup,8s cooldown, no summed AoE budget or automatic continuous leech |
| `path_iron_rhythm` |6% one readied physical hit reduction|Retain: cast setup/8s grant cooldown; applied before existing ward consumption |

## Verdict for all eighteen capstones

| Class/capstone | Verdict and quantitative reason |
| --- | --- |
| Reaver/Berserker |Retain20%/8s after10 successful normals, no rage while active: at2s perfect autos about5.7% raw time-average, lower with misses/downtime |
| Reaver/Bloodletting |Retain30% actual wound every3 hits:10% nominal normal-damage budget before wound survival/immunity and the finite3-wound limit; own-wound Rend synergy remains conditional |
| Reaver/Bloodguard |Reduce30→15% actual conversion;6% maxHP ward cap/lifetime and strongest pool unchanged |
| Sword/Duelist |Retain35% precrit echo after3 normals; separate physical armour, delayed target survival, cast timing and mana limit delivery; high-skill sensitivity remains in hunt cases |
| Sword/Riposte |Retain40% counter budget/6s after actual block and ordinary hit; no automatic extra swing; loses shield path with two-handed gear |
| Sword/Blade Storm |Retain two40% precrit adjacent strikes only on ordinary critical: low unrolled crit rates bound expected pack benefit; gear-critical sensitivity explicitly unmeasured |
| Club/Aftershock |Retain25% total successful spell-wave budget after4 normals; split across at most3 targets, not25% full AoE copied onto every recipient |
| Club/Stoneguard |Reduce10→5% spell damage/charge: max15% prepared spell burst; retain2% physical reduction/charge, actual block setup and charge consumption |
| Club/Stonebond |Reduce3→1.5% recipient HP ward; block requirement,6s cooldown,2tile party geometry and nonstacking preserved |
| Bow/Deadeye |Retain30% fourth stationary same-target primary shot:7.5% raw four-shot sequence at perfect setup; moving/target changes reset |
| Bow/Skirmisher |Retain30%+20% two additional bounces on fourth movement-qualified normal: at most12.5% pack budget/sequence, no duplicated arrow explosion |
| Bow/Quarry |Retain5% party normal-damage mark10s/20s, three-hit setup, one source-owned mark; no spell/PvP amplification |
| Wand/Conduit |Retain30%/20% normal chains after3 paid offensive casts: limited by learned casts, mana, target geometry and actual ordinary weapon budget |
| Wand/Resonance |Retain30% next-cast echo after3 same-target casts:7.5% four-cast budget before element, delayed survival and cost |
| Wand/Spellweaver |Retain15% prepared spell/25% prepared-cast discount after alternating3-cast setup:3.75% damage/6.25% mana averages over4 casts before other discounts |
| Rod/Renewal |Retain20% effective healing over6s, strongest remaining replacement; fullHP/passive/HoT excluded, repeated casts do not add independent full schedules |
| Rod/Aegis |Retain15% effective healing/8%HP cap; actual paid effective healing source and combined10% two-pool limit prevent free raw-heal wards |
| Rod/Concord |Reduce40→15%, preserve2% recipient/action ceiling; actual ordinary primary damage and injured self/party selection; fractional baseline rod utility required |

## Verification and remaining limits

Completed source/model checks: map acquisition linking, all174 node descriptions
and prerequisites, native resolution ordering, full before/after values,
72 baseline starter profiles,18 cap witnesses,432 cumulative purchase prefixes,
gear-equivalent sensitivities and native Lua test preparation. Whitespace/source
checks and Lua syntax compilation are recorded with execution evidence.

The current server Lua was exported offline again after the five reductions.
`out/passives-balance-pass-20261007/after-balance-verification.json` records a
passing comparison against the frozen before catalog and access model. Exactly
the five approved central values changed (the shared kill-heal value appears in
all six class configs). All174 node IDs, rank limits, prerequisites and topology
are unchanged. Gear, quests, spawned acquisition sources, modeled gross coin
drops, point progression and all72 baseline starter formula profiles compare
equal. The ordinary2–5 rod/50gold vendor and rare27–33 rod checks passed again.
All18 cumulative build witnesses and432 purchase prefixes were rerun; their
proposed kill-heal numbers were checked against the actual current configs.
The frozen before inputs remain available, and these are source/model results.
The actual Lua/client catalog validator also passed after the export: six trees,
174 nodes,216 logical edges,6978 cases,2880 legal purchase prefixes and564
expected rejection cases. Evidence is in
`out/passives-balance-pass-20261007/catalog-after-proof.json`.

Prepared native regression `tools/tests/passives-balance.lua` uses the separate
server fixture `tools/passives-fixture/passive_balance_qa.lua`, registered only
in the owned loopback runtime. It tests actual ordinary kills at240HP and the
real bought-baseline2–5 rod path, fractional accounting, no forced minimum,
full-HP no banking and wrong-weapon cleanup. It does not inject proc counters,
RNG, native damage or cooldown completion. Configured player/monster HP is
disposable setup, not evidence of normal post-Ascension experience. Root must
run this after rebuilding and record actual markers/logs.

Targeted existing regressions remain necessary: Reaver Bloodguard actual
absorption, Earth Stoneguard real block/consumption and Stonebond party wards,
Life Concord recipient selection/caps, Renewal/Aegis combined pools, all-six
catalog/config equality, resources and cleanup. Human baseline/rare hunts,
all-spawn navigation, affix distributions, exact party uptime, death-loss and
whole learned-spell rotations remain unmeasured by this analytical pass. No
blanket "all classes balanced" or "no regressions" conclusion follows.
