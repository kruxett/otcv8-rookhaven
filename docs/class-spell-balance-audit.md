# Class starter spell balance audit

**Audit context:** this document retains the original access and provisional
balance analysis. Subsequent bug corrections and their executed tests are in
[the fixes verification report](passives-fixes-verification.md). In particular,
the contradictory Volley weapon checks described below were an earlier audit
finding; the later local correction does not change the balance values or
establish ordinary hunting balance.

## Scope and evidence

This audit records the conservative local revision made after the user's
low-and-slow correction. The intended comparison is with spells an ordinary
player can actually learn and use in Rookhaven. A spell's XML registration or
existing Lua script does not establish that access.

**Source verified** below means its registration, ordinary acquisition checks
and relevant runtime code were traced. **Conditional** means a required item,
quest or world route still needs confirmation. **Playtest pending** means the
complete acquisition or ordinary hunt has not been exercised by this audit.
The user has not approved numerical balance thresholds. The revision is
provisional and local, and does not change existing spells.

## Ordinary acquisition

### Oracle Stone route

The configured map is `rookalmost` ([config.lua:11](../../Rookhaven/config.lua#L11)).
A read-only parse of its OTBM nodes found default Oracle Stones (item 1354) at
`32104,32190,6` and `32337,32203,4`; its map-data node references
`Untitled-1-spawn.xml`. This confirms actual map content, not just an NPC XML file.
The ordinary talkaction is registered at
[talkactions.xml:72](../../Rookhaven/data/talkactions/talkactions.xml#L72).

The player must stand beside a stone, satisfy the initial Book of Arcanis quest
gate where applicable, and offer a full, positive mana pool. The donation updates
the player's cumulative Oracle total and invokes the event manager. The totals
below are **donated mana**, not ordinary spell mana spent. Sources:
[oracle_stone.lua:90](../../Rookhaven/data/talkactions/scripts/oracle_stone.lua#L90),
[:142](../../Rookhaven/data/talkactions/scripts/oracle_stone.lua#L142),
[:183](../../Rookhaven/data/talkactions/scripts/oracle_stone.lua#L183),
[:225](../../Rookhaven/data/talkactions/scripts/oracle_stone.lua#L225).

Active repeat events cross another interval when a donation is made; failed
learning requirements do not automatically grant the spell later. The player
must qualify when a subsequent interval is crossed. Sources:
[oracle_stone_event_manager.lua:358](../../Rookhaven/data/lib/oracle_stone_event_manager.lua#L358),
[:673](../../Rookhaven/data/lib/oracle_stone_event_manager.lua#L673),
[:742](../../Rookhaven/data/lib/oracle_stone_event_manager.lua#L742).

### Melee and distance

All eight spells below have active Oracle learning events and `needlearn=1`.
Awakened is vocation 1; Ascendant is 2; Ascended is 3. In the first-tier melee
events, vocation 2 or higher bypasses the level-15 learning requirement; it does
not bypass ML or weapon skill. Sure Shot has the corresponding level-10 bypass.

| Spell | Donation interval | Ordinary learning conditions | Status/source |
| --- | ---: | --- | --- |
| Head Splitter | 1,200 | Awakened+, ML 2, axe 17; Awakened requires level 15 | Grant traced: [head_splitter.lua:33](../../Rookhaven/data/OracleStoneEvents/head_splitter.lua#L33) |
| Swipe | 1,100 | Awakened+, ML 2, sword 17; Awakened requires level 15 | Grant traced: [swipe.lua:33](../../Rookhaven/data/OracleStoneEvents/swipe.lua#L33) |
| Ground Slam | 1,000 | Awakened+, ML 2, club 17; Awakened requires level 15 | Grant traced: [ground_slam.lua:33](../../Rookhaven/data/OracleStoneEvents/ground_slam.lua#L33) |
| Axe Throw | 2,000 | Ascendant+, Head Splitter learned, ML 4, axe 24 | Grant traced: [axe_throw.lua:28](../../Rookhaven/data/OracleStoneEvents/axe_throw.lua#L28) |
| Pommel Strike | 2,500 | Ascendant+, Swipe learned, ML 4, sword 24 | Grant traced: [pommel_strike.lua:36](../../Rookhaven/data/OracleStoneEvents/pommel_strike.lua#L36) |
| Seismic Shockwave | 2,500 | Ascendant+, Ground Slam learned, ML 4, club 24 | Grant traced: [seismic_shockwave.lua:28](../../Rookhaven/data/OracleStoneEvents/seismic_shockwave.lua#L28) |
| Sure Shot | 800 | Awakened+, ML 1, distance 13; Awakened requires level 10 | Grant traced: [sure_shot.lua:34](../../Rookhaven/data/OracleStoneEvents/sure_shot.lua#L34) |
| Volley | 2,500 | Ascendant+, Sure Shot learned, ML 4, distance 24 | Grant traced; normal cast was blocked at audit time (corrected later): [volley.lua:33](../../Rookhaven/data/OracleStoneEvents/volley.lua#L33) |

Learning and casting have separate requirements. Runtime XML gives Head
Splitter/Swipe/Ground Slam level 2, Axe Throw/Pommel/Seismic/Volley level 4,
and Sure Shot level 1 plus ML 1. Mana capacity, equipped weapon and ammunition
still apply. See [spells.xml:30](../../Rookhaven/data/spells/spells.xml#L30).
The third Ascension's donation total does not prove ML 4, skill 24, or that the
player crossed a learning interval after reaching those requirements.

**Historical Volley finding:** at audit time its XML set `needweapon=1`, whose
native check permitted only axe/sword/club, while its Lua cast required
bow/crossbow. Normal equipment could not satisfy these disjoint checks;
ordinary bow/crossbow items are two-handed. Sources reviewed at that time:
[spells.cpp:592](../../Rookhaven/src/spells.cpp#L592),
[attack/volley.lua:63](../../Rookhaven/data/spells/scripts/attack/volley.lua#L63),
[items.xml:3737](../../Rookhaven/data/items/items.xml#L3737).
The later local fix sets `needweapon=0` and explicitly validates a compatible
launcher in either hand, together with its ammunition. Executed verification
and any remaining cases are recorded in
[the fixes report](passives-fixes-verification.md). This balance audit did not
use Volley's advertised five-target damage to justify stronger new starters;
ordinary acquisition and hunting comparisons remain separate checks.

**Burst Arrow access remains conditional.** Sure Shot's actual burst branch uses
item 2546, a 3×3 area and one round per successful cast
([sure_shot.lua:34](../../Rookhaven/data/spells/scripts/attack/sure_shot.lua#L34),
[:83](../../Rookhaven/data/spells/scripts/attack/sure_shot.lua#L83)).
Dragon loot includes burst arrows, and Dragon has actual entries in the map's
referenced spawn file
([dragon.xml:58](../../Rookhaven/data/monster/monsters/dragon.xml#L58),
[spawn.xml:225](../../Rookhaven/data/world/Untitled-1-spawn.xml#L225)).
Navigation and ordinary access to those hunt areas were not verified. No
ordinary NPC/shop/quest grant of burst arrows was found. Conjure Explosive Arrow
is registered with `needlearn=1`, but no ordinary learning grant was found
([spells.xml:163](../../Rookhaven/data/spells/spells.xml#L163)). It is not an
established renewable ammunition supply.

Ordinary arrows and a bow have a much clearer path: Garrick sells them, gives
crude training arrows in his quest, and is actually present in the spawn file.
Conjure Crude Arrow is learned after his completed training quest and a
400-mana Oracle interval. Sources:
[Garrick.lua:395](../../Rookhaven/data/npc/scripts/Garrick.lua#L395),
[:987](../../Rookhaven/data/npc/scripts/Garrick.lua#L987),
[spawn.xml:1950](../../Rookhaven/data/world/Untitled-1-spawn.xml#L1950),
[player_400_conjure_crude_arrow.lua:23](../../Rookhaven/data/OracleStoneEvents/player_400_conjure_crude_arrow.lua#L23).

### Elemental magic

All fifteen old elemental spells have active Oracle repeat events and
`needlearn=1`. Each learning script requires an item from its specific family
list **in inventory**; XML weapon compatibility alone is insufficient. First
tier generally requires ML 1 and level 10 (waived for vocation 2+), second tier
ML 2 and level 15 (same waiver) plus its first spell, and third tier ML 3,
vocation 2+ and its second spell. Sources:
[event_manager.lua:243](../../Rookhaven/data/lib/oracle_stone_event_manager.lua#L243),
[wand_lightning_bolt.lua:14](../../Rookhaven/data/OracleStoneEvents/wand_lightning_bolt.lua#L14),
[spells.xml:51](../../Rookhaven/data/spells/spells.xml#L51).

| Family | Donation intervals, tiers 1/2/3 | Highest active grant | Additional restrictions |
| --- | --- | --- | --- |
| Fire | 800 / 1,200 / 1,600 | Wand Inferno, 50 mana / 6 s | Kill It With Fire progress 2+ for early tiers, 3+ for Inferno |
| Energy | 750 / 1,150 / 1,550 | Wand Chain Lightning, 75 mana / 4 s | Listed energy item required |
| Earth | 850 / 1,250 / 1,650 | Wand Deadly Vines, 48 mana / 4 s | Green Widow progress 2+ for Toxic Root, 5+ for Deadly Vines |
| Ice | 900 / 1,300 / 1,700 | Wand Glacial Spike, 46 mana / 3.5 s | Listed ice item required |
| Death | 950 / 1,350 / 1,750 | Wand Soul Drain, 50 mana / 5 s | Listed death item required |

Quest checks and inventory lists are explicit in
[wand_fire_burst.lua:16](../../Rookhaven/data/OracleStoneEvents/wand_fire_burst.lua#L16),
[wand_inferno.lua:15](../../Rookhaven/data/OracleStoneEvents/wand_inferno.lua#L15),
[wand_deadly_vines.lua:15](../../Rookhaven/data/OracleStoneEvents/wand_deadly_vines.lua#L15).
Earth, ice and death teacher lists include rods; old magic access therefore does
not divide neatly into the new wand-damage and rod-healing roles. Teacher and
cast lists also differ: death item 8910 and fire item 12741 do not themselves
satisfy the corresponding Oracle teacher list despite some spell cast support.

These are **conditional highest-tier candidates**, not proof that all five are
normally available to every player. Item acquisition and every quest/world route
have not been played through in this audit. Use the actual player's learned
spell list and obtainable equipment when selecting the hunt comparison. Do not
inflate a starter to compete with a conditional top-tier spell merely because
its formula is large.

### Healing

**Light Healing is the only direct-healing spell with a traced ordinary learning
chain.** Hyacinth teaches it after the letter quest's progress 3, on the `chest`
dialogue, and advances the quest to 4. The action is registered on unique item
30025. Hyacinth has an actual spawn. Sources:
[Hyacinth.lua:402](../../Rookhaven/data/npc/scripts/Hyacinth.lua#L402),
[actions.xml:63](../../Rookhaven/data/actions/actions.xml#L63),
[hyacinths_letter.lua:66](../../Rookhaven/data/actions/scripts/quests/hyacinths_letter.lua#L66),
[spawn.xml:210](../../Rookhaven/data/world/Untitled-1-spawn.xml#L210).

The relevant Hyacinth branch is vocation 1 specifically; the dialogue engine
matches the current vocation exactly. An Ascendant/Ascended who skipped this
quest is not guaranteed to acquire it later. See
[Hyacinth.lua:107](../../Rookhaven/data/npc/scripts/Hyacinth.lua#L107) and
[npc_dialog_engine.lua:1207](../../Rookhaven/data/npc/lib/npc_dialog_engine.lua#L1207).
Previously learned spells remain the ordinary player's saved entitlement.

Heal Friend, Intense Healing, Mass Healing, Ultimate Healing and Divine Healing
are registered with `needlearn=1`, but no ordinary learning grant was found in
the reviewed game data/native acquisition paths. They must not be used as
available progression benchmarks just because their scripts exist. See
[spells.xml:77](../../Rookhaven/data/spells/spells.xml#L77). Administrative fixture
learning is a technical test capability, not ordinary content access.

## What the damage units mean

`M` is the ordinary **raw weapon maximum**, before armor, shielding, resistances,
critical bonuses and passive effects. It is not an average autoattack:

`M ≈ level/5 + ((skill/4 + 1) * (effectiveAttack/3) * 1.03) / attackFactor`.

Distance uses launcher plus compatible ammunition attack. Ordinary melee rolls
approximately between zero and `M`, around `0.5M` on average, using
`normal_random`. Distance additionally has its own minimum, accuracy and miss
behavior. Sources:
[weapons.cpp:158](../../Rookhaven/src/weapons.cpp#L158),
[:659](../../Rookhaven/src/weapons.cpp#L659),
[:913](../../Rookhaven/src/weapons.cpp#L913),
[tools.cpp:298](../../Rookhaven/src/tools.cpp#L298).

The following means are **unrounded source-formula midpoints**, not measured
damage. Integer conversions and different random distributions affect exact
means and variation. New spells round their endpoints before rolling; see
[class_spells.lua:105](../../Rookhaven/data/lib/class_spells/class_spells.lua#L105).
An AoE total assumes all listed recipients are valid and all delayed hits land.

## Conservative local revision

“Before” is the previous local provisional configuration, after Rend had already
been set to 12 mana / 3 s and Rolling Thunder to 8 mana / 4 s. “Revised” is the
current conservative configuration in
[class_spells/config.lua:9](../../Rookhaven/data/lib/class_spells/config.lua#L9).
These are not deployed values or user-approved balance guarantees.

| Starter | Before mana / shared cooldown | Revised mana / shared cooldown | Before raw mean | Revised raw mean |
| --- | --- | --- | --- | --- |
| Cleaving Arc | 14 / 4 s | 18 / 4 s | `0.50M` per target; `1.50M` at 3 | `0.40M` per target; `1.20M` at 3 |
| Rend | 12 / 3 s | 12 / 4 s | `0.825M`; own wound `0.99M` | `0.675M`; own wound `0.81M` |
| Focused Thrust | 18 / 4 s | 24 / 4 s | `1.125M` | `0.875M` |
| Flurry | 12 / 3 s | 20 / 4 s | `0.85M` across 2 hits | `0.75M` across 2 hits |
| Crushing Blow | 18 / 4 s | 24 / 4 s | `1.05M` | `0.85M` |
| Rolling Thunder | 8 / 4 s | 18 / 4 s | `0.65M` on one; `1.05M` at 3 | Same raw budget; higher cost |
| Blitzshot | 14 / 4 s | 14 / 4 s | `0.85M` primary + `0.35M` secondary | `0.70M` primary + `0.20M` secondary |
| Scattershot | 18 / 5 s | 18 / 5 s | `0.45M` per target; `1.35M` at 3 | `0.375M` per target; `1.125M` at 3 |
| Resonant Burst | 18 / 4 s | Unchanged | `L/5 + 4.25*ML + 16`, total 3 pulses | Same |
| Arcane Surge | 22 / 5 s | Unchanged | `L/5 + 1.85*ML + 9` per target | Same |
| Mending Thread | 24 / 2 s healing | 22 / 2 s healing | `L/5 + 2.7*ML + 16` | `L/5 + 1.8*ML + 10` |
| Essence Lash | 12 / 3 s | Unchanged | `L/5 + 2.5*ML + 13` | Same |

Rolling Thunder's one-target total includes its impact and one pulse hit. Its
three-target total is one impact plus three smaller pulse hits, not three full
impacts. Resonant Burst splits one rolled total between three pulses; it does
not multiply that total by three. Flurry applies armor separately to both hits.
See [class_spells.lua:211](../../Rookhaven/data/lib/class_spells/class_spells.lua#L211).

### Existing usable comparison anchors

| Existing spell | Mana / actual shared cooldown | Source-formula raw budget and role |
| --- | --- | --- |
| Head Splitter | 20 / 4 s combat | `0.5M .. (2 + critAmount/100)M`; midpoint `1.25M` at zero bonus. Stronger focused burst. |
| Axe Throw | 25 / 2 s combat | Separate `L/5 + skill*attack*0.008 + 1 .. L/5 + skill*attack*0.025 + 5` formula; range 5 and slow. Higher learning tier does not imply greater damage. |
| Swipe | 20 / 2 s combat | About `0.2875M .. 1.15M` per hit, midpoint `0.71875M`; primary and up to two flank recipients. |
| Pommel Strike | 25 / 4 s combat | About `0.375M .. 1.25M`, midpoint `0.8125M`; adds paralysis. |
| Ground Slam | 20 / 3 s **healing** | About `0.2875M .. 1.15M` per recipient in its circle; its existing `aggressive=0` selects healing exhaustion. |
| Seismic Shockwave | 40 / 6 s combat | Five-tile widening cone, increasing distance multipliers over a `1.15M` base; final step has its explicit critical-sized formula. |
| Sure Shot, ordinary ammo | 8 / 3 s combat | `L/5 .. M`; midpoint approximately `(L/5 + M)/2`, compatible ammunition and guaranteed spell hit. |

Formula sources:
[head_splitter.lua:25](../../Rookhaven/data/spells/scripts/attack/head_splitter.lua#L25),
[axe_throw.lua:18](../../Rookhaven/data/spells/scripts/attack/axe_throw.lua#L18),
[swipe.lua:33](../../Rookhaven/data/spells/scripts/attack/swipe.lua#L33),
[pommel_strike.lua:33](../../Rookhaven/data/spells/scripts/attack/pommel_strike.lua#L33),
[ground_slam.lua:24](../../Rookhaven/data/spells/scripts/attack/ground_slam.lua#L24),
[seismic_shockwave.lua:20](../../Rookhaven/data/spells/scripts/attack/seismic_shockwave.lua#L20),
[sure_shot.lua:23](../../Rookhaven/data/spells/scripts/attack/sure_shot.lua#L23).
Use XML values rather than stale script-header cooldown/mana comments.

The revision removes several cheap, high-budget new options. It does not prove
that every revised option feels worthwhile: for example, Focused Thrust now
costs more than Swipe, and Flurry loses more to repeated armor. Their focused
roles and interactions still need normal hunting feedback. Preserve the old
spells while checking both viable choices and any new option that crowds out an
existing one.

### Magic and healing examples

At level 40 / ML 6, unchanged Resonant Burst's formula mean is **49.5 total**,
Arcane Surge **28.1 per eligible target**, and Essence Lash **36**. A traced
first-tier energy candidate, Wand Lightning Bolt, has a formula midpoint
**45.22** for 12 mana / 2 s; obtaining its listed family item and learning it
remain prerequisites. Its lower cost and cooldown matter, not just its maximum
damage ([wand_lightning_bolt.lua:20](../../Rookhaven/data/spells/scripts/attack/wand_lightning_bolt.lua#L20)).

Conditional later-tier magic formulas can be much larger: Inferno's level-40 /
ML-6 midpoint is 109.5; Deadly Vines' direct component 105.2 before poison;
Glacial Spike 138.1; Chain Lightning and Soul Drain add bounce or prolonged
pulse behavior. These are not universal starter benchmarks, and their full
duration/target opportunity must not be treated as instant reliable damage.
Sources:
[wand_inferno.lua:18](../../Rookhaven/data/spells/scripts/attack/wand_inferno.lua#L18),
[wand_deadly_vines.lua:21](../../Rookhaven/data/spells/scripts/attack/wand_deadly_vines.lua#L21),
[wand_glacial_spike.lua:20](../../Rookhaven/data/spells/scripts/attack/wand_glacial_spike.lua#L20),
[wand_chain_lightning.lua:59](../../Rookhaven/data/spells/scripts/attack/wand_chain_lightning.lua#L59),
[wand_soul_drain.lua:18](../../Rookhaven/data/spells/scripts/attack/wand_soul_drain.lua#L18).

Light Healing's formula is `L/5 + 1.4*ML + 8 .. L/5 + 1.8*ML + 11`, giving an
unrounded midpoint **27.1** at level 40 / ML 6 for 20 mana / 1 s. Its native
integer callback uses **24–29**, midpoint **26.5**. Revised Mending Thread is
**28.8** on the unrounded formula basis for 22 mana / 2 s; its Lua rounding
produces a pre-modifier roll of **27–31**, midpoint **29**. At this specific
level/ML, that is approximately 9.43% more raw healing for 10% more mana, or
about 0.52% less healing per mana. This is an example, not an approved percentage
gate or a general result for every level/build.

Mending adds named party healing and paralysis removal while avoiding its
previous 40.2 formula midpoint. Light Healing also removes paralysis. Neither
formula midpoint nor converted midpoint is an empirical healing average;
missing health, passive modifiers and the separate cooldowns still matter.
Sources:
[light_healing.lua:7](../../Rookhaven/data/spells/scripts/healing/light_healing.lua#L7),
[class_spells.lua:105](../../Rookhaven/data/lib/class_spells/class_spells.lua#L105).

### Passive mana sustainability: Focus

The common Focus value was reduced from **0.1 to 0.025 mana per second per
rank**, with the native fallback adjusted to match. At five ranks, the former
bonus supplied 0.5 mana/s (30 mana/min), as much as vocation 3's normal food
regeneration. The revised bonus supplies 0.125 mana/s (7.5 mana/min), equivalent
to one mana every eight seconds while the profile and weapon category remain
active. One rank supplies one mana every forty seconds. These are accumulator
rates while mana can be restored, not guarantees that every tick is useful at
the mana cap. Source:
[passives/config.lua:31](../../Rookhaven/data/lib/passives/config.lua#L31),
[passives.cpp:859](../../Rookhaven/src/passives.cpp#L859).

Normal vocation-3 food regeneration is 2 mana every 4 seconds (0.5 mana/s) when
the regeneration condition is active and the player is outside protection zone.
The old full-rank Focus therefore doubled that baseline; the revised full-rank
bonus adds one quarter of it. These proportions explain the conservative change
and are not user-approved balance thresholds. Sources:
[vocations.xml:44](../../Rookhaven/data/XML/vocations.xml#L44),
[condition.cpp:877](../../Rookhaven/src/condition.cpp#L877).

Focus uses its own passive tick, with no food, regeneration-condition, combat
or protection-zone requirement. It continues without food and inside protection
zone, where ordinary food regeneration does not restore mana. Its weapon check
is the selected class's weapon category, rather than the new starter spells'
complete wield-requirement validation. Thus even the smaller bonus provides
independent sustain and safe recovery; it should not be described as merely
increasing food effectiveness. The old 30-mana/min independent supply was large
beside five Power ranks' 2.5% raw damage bonus. Sources:
[passives.cpp:80](../../Rookhaven/src/passives.cpp#L80),
[:85](../../Rookhaven/src/passives.cpp#L85),
[:859](../../Rookhaven/src/passives.cpp#L859).

Focus cannot increase maximum mana. Level 1 after the existing Ascension reset
still has zero mana capacity, and starter mana/equipment requirements remain.
Check actual sustain alongside mana discounts, food, consumables, healing and
offensive casts in a normal hunt; the smaller rate alone does not verify the
whole passive balance.

## What still needs ordinary playtesting

1. **Actual loadout and learning.** Compare spells the same normal player really
   knows, with obtainable weapons and ammunition at legitimate wield/equip
   requirements. An admin learning fixture or level-40 stat fixture does not
   establish content access or early progression.
2. **Whole rotation.** Include autos, existing spells and new spells under the
   existing shared combat/healing exhaustion. Autoattacks remain a separate
   swing schedule ([player.cpp:3365](../../Rookhaven/src/player.cpp#L3365)); a
   new cast adds to that rotation. Ground Slam's separate existing healing
   group is especially relevant for club rotation and mana use.
3. **Mitigation and real targets.** Test low/high armor, one/multiple monsters,
   elemental resistances, line of sight and movement that loses delayed hits.
   Armor on multiple small hits can change rankings. Capture actual HP loss,
   mana consumed, ammunition used and fight duration.
4. **Criticals and passives.** Test baseline first, then legal relevant builds.
   Legacy crits, explicit Head Splitter multipliers, Bloodletting synergy,
   Resonance echoes, Renewal healing and mana discounts cannot be inferred
   from the starter's base mean alone. Three pulses are one cast for passive
   accounting, while individual hits can still have critical variation.
5. **Sustain and onboarding.** Ascension retains the old level-1 / zero-maxmana
   reset and vocation 3 gains 10 mana per level. Normal regeneration is 2 mana
   per 4 seconds while applicable; consumables and equipment change sustain.
   Check ordinary level 1–7 experience, and the additional level/equipment
   access needed for each role. See
   [The Nameless.lua:27](<../../Rookhaven/data/npc/scripts/The Nameless.lua#L27>),
   [vocations.xml:44](../../Rookhaven/data/XML/vocations.xml#L44), and
   [the starter delivery document](class-starter-spells.md).

No DPM, TTK, hunt-profit or sustainable-rotation conclusion is established by
these theoretical means alone. Functional probes and successful compilation
are different evidence from human balancing hunts. Record the actual revised
binary/runtime checks separately in [local-passives-results.md](local-passives-results.md)
and retain the existing-system regressions in
[passives-regressions.md](passives-regressions.md).

This audit itself performed source/map reading and formula comparison only. It
ran no build, game process, runtime probe or SQL statement.
