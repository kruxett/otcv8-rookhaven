# DEV passive and starter-spell balance/access audit

Source review: 6 October 2026. Values are provisional DEV tuning. This review fixes two concrete problems and establishes reproducible source baselines; it does **not** establish equal six-class hunting performance or satisfactory player choices.

## Changes and decision

- Plipus now sells Snakebite Rod **2182 for 50 gold**, alongside Hex Wand 12746 for 50. Only2182's normal attack roll changed **8–18→2–5**; mana 2 and earth element remain. No level, vocation, asset, OTB, item definition or rare Necrotic Rod 2185 change. The ordinary rod source closes Lifekeeper's equipment access gap without handing out chosen-class gear.
- Flurry mana changed **20→18**. Its two hits, damage ratios, four-second cooldown and250ms delay remain. This creates a modest low-armour damage-per-mana choice against Focused Thrust; its damage per second stays lower. The numerical comparison below is the acceptance evidence for this cost change.
- Numeric edits are frozen after those changes. No blanket damage/health buff follows from the comparisons below.

Exact edited server files: [Plipus.xml](../../Rookhaven/data/npc/Plipus.xml), [weapons.xml](../../Rookhaven/data/weapons/weapons.xml), [class_spells/config.lua](../../Rookhaven/data/lib/class_spells/config.lua).

## What counts as available

[balance-access-audit.py](../tools/passives/balance-access-audit.py) reads the configured `rookalmost.otbm`, decodes escaped map nodes and unique IDs, then reads the map's referenced `Untitled-1-spawn.xml`. It links NPC shops to actual spawned NPC filenames/display aliases, drops to registered and spawned monster definitions, and selected chest reward literals to registered actions **and placed map unique IDs**. The current parse finds 66 active NPC names,83 active monster names and no unknown map attributes. A decorative map item is not accepted as a reward.

These links establish authored acquisition sources. They do not prove that a player has completed a dangerous route, has the necessary quest state, can afford the item, receives a random drop, or enjoys the resulting hunt. XML registration alone is insufficient. Price is a gold sink; it is not an income guarantee.

### Fresh third ascension

`data/npc/scripts/The Nameless.lua` resets level 1, HP150 and maximum/current mana 0. Existing skills, magic progress and learned spells are preserved. Possessions are transferred to the player's depot before the reset; they are not destroyed or automatically re-equipped. Third ascension grants the two own-class starters. Ascended vocation 3 supplies15 HP and10 mana per subsequent level, ordinary attack interval2000ms, and fed mana regeneration2 per4seconds.

Consequences: there is no universal retained skill 24/magic 4 guarantee; the audit includes a skill 10/magic 0 sensitivity floor. At level 1, zero mana prevents both starter casts and2-mana wand/rod autos. At level 2,10 maximum mana supports the normal magic auto but no new starter. Unaffixed/undiscounted12–20 mana starters first fit level 3's20 mana;22/24 fit level 4's30. At level 40 the unaffixed baseline is735 HP/390 mana. Progression is3 starting points plus1 every3levels:16 at 40,24 at 64. Existing earned milestones persist through later level loss.

### Ordinary weapon baseline and conditional upgrades

The comparison uses no rolled affixes or admin-only fixture gear. Axes/clubs/swords are one-handed in the ordinary baseline and may keep a shield; bows use ammunition and no shield.

| Class | Ordinary available reference | Authored source | Conditional stronger reference |
|---|---|---|---|
| Reaver | Hatchet2388, attack15 | Spawned Blind Orc,85 gold/orc words; Skeleton/Dwarf loot | Double Axe 2387, attack35, two-handed; single spawned Fire Devil's base 1.36% loot |
| Blademaster | Sword 2376, attack14 | Blind Orc85; Minotaur/Rotworm loot | Crystal Sword 7449, attack35, two-handed; spawned Barbarian Skullhunter base 0.06% loot. Katana2412 attack16 is a smaller Rotworm/UID 30005 upgrade |
| Earthshaker | Mace 2398, attack16 | Spawned Skeleton/Minotaur/Rotworm/Bandit loot | Brutetamer's Staff 7379, attack35, two-handed; spawned Barbarian Brutetamer base 0.31% loot |
| Marksman | Bow 2456 +Arrow 2544, attack25 | Garrick quest progress≥1: bow 200, arrow 3; Blind Orc bow 400 | Same ammo baseline in the high-skill comparison; no stronger ammunition is assumed free or renewable |
| Arcanist | Hex Wand 12746, death2–5, mana 2, range 3 | Plipus50 | Dusk Wand 12753 quest reward: native8–15 plus fixed+6 death, mana 4; UID 30157 chest at 32646,32196,14. Deep quest prerequisites/navigation remain conditional |
| Lifekeeper | Snakebite Rod 2182, earth2–5, mana 2, range 3 | **Plipus50 after this change** | Necrotic Rod 2185 death27–33/mana 5; single Fire Devil at 32053,32230,15, base 0.49% loot; unchanged |

Obi's nearer cheap alternatives are Axe 2386 attack12/20 gold and Short Sword 2406 attack11/30 gold. Admin fixtures' Orcish Axe 2428 and Clerical Mace 2423 are not substituted for ordinary starter purchases. `data/npc/scripts/Garrick.lua` has ranger sell-price rows that are **not** purchases. Among linked unrolled sources,35 is the highest plain axe/sword/club attack. Arcanist's highest plain wand mean is Jade Wand 12758, earth12–24/mana 6 from spawned Dwarf Geomancer base 1.06% loot. Its9 raw HP/s auto costs3 mana/s and suffers earth resistance; Dusk's fixed-affix reward has8.75 raw HP/s at 2 mana/s and a different element. Neither is a universal best encounter choice. Wand candidates are sorted by actual native rolls, not absent item-XML attack attributes.

Both2182 and12746 have native `weaponType=wand`, range 3 and no XML level/magic/vocation restrictions. Native passive eligibility distinguishes rod IDs from custom wands. The Snakebite's19oz/earth projectile and Hex's20oz/death projectile remain in the existing item definitions.

### Armour, shields and gold

- Dixi at 32105,32207,6 sells Chain Helmet 2458 armor 2/52 gold, Leather Armor 2467 armor 4/25, Leather Legs 2649 armor 1/10 and Studded Shield 2526 defense 15/50:137 gold buys armor 7 plus the shield. Leather Boots2643 armor 1 have common spawned Troll/Swamp Troll loot; the model's completed mundane set is **armor 8**.
- Samwell at 31898,32073,7 offers Chain Armor 2464 armor 6/400, Chain Legs 2648 armor 3/300 and Steel Shield 2509 defense 21/600. Brass Helmet 2460 armor 3 is Minotaur loot and a registered UID 30019 reward. With boots this is a conditional armor 13 set, not fresh town gear. Chain Armor also has Minotaur loot/UID 30020. Dragon Shield 2516 defense 31 and Guardian Shield 2515 defense 30 are rare spawned Dragon/Fire Devil loot.
- At shield skill 24, offensive fighting, defense 15 and no weapon extra defense, native shield defense is9 and a successful shield check reduces4–9 physical damage (mean6.5); armor 8 then reduces4–7 (mean5.5). Bow has no shield. Block opportunities refill with a limited counter; three attackers cannot be modeled as three permanent full shield blocks. Spell-only enemy-damage tables below do not include these player defenses.
- Configured source omits `rateLoot`; native default is2. The audit enumerates the actual correlated gold chance/count roll for ordinary unstarred monsters: Rat≈1.75, Orc≈4.28, Rotworm≈4.27, Minotaur≈5.07 **gross** coins perkill. A50-gold purchase is about29 Rat or12 Orc gross expected kills, not a guarantee or time estimate. NPC sales, bags, travel danger and consumable costs are excluded. Base XML percentages in the gear table are not effective drop probabilities after loot/star modifiers.
- Regular arrows cost3 gold. Native ammunition removal defaults enabled, while a starter volley spends one round percast rather than one perrecipient. Renewably conjured crude arrows require Garrick/Oracle progression and have a different damage/mana budget. No unlimited full-strength arrows or routine mana potions are assumed.

## Combat comparison

Weapon ceiling on offensive fighting is `M=L/5+(skill/4+1)*(attack/3)*1.03`. The bounded model rounds starter endpoints, enumerates spell rolls and enemy armour rolls, and applies native element rounding. Normal auto raw midpoints precede hit chance, shielding and armour and must not be added to spell DPS as delivered damage. For bow, ammo attack is included but distance accuracy remains unmodeled. Resonant Burst has **one total split over three pulses**; Rolling Thunder has an impact plus a separate pulse, including the primary. Delayed target survival, overkill, line of sight, party positioning and fraction carries remain material.

### Level 40, retained skill 24/magic 4, ordinary gear, no passives

Numbers are average spell budget persecond at uninterrupted cooldown, not measured hunt DPS. The3-target column assumes every legal recipient is positioned correctly and survives. Mending is effective-healing capacity before overheal, not damage.

| Starter | Raw1 target | Raw3 targets total | Orc1 /3 after armour or element | Mana/s including magic auto |
|---|---:|---:|---:|---:|
| Cleaving Arc |4.38|13.13|3.75 /11.25|4.50|
| Rend, no own wound |7.38|7.38|6.75 /6.75|3.00|
| Focused Thrust |9.13|9.13|8.50 /8.50|6.00|
| Flurry |7.75|7.75|6.50 /6.50|4.50|
| Crushing Blow |9.88|9.88|9.25 /9.25|6.00|
| Rolling Thunder |7.63|12.38|6.38 /9.88|4.50|
| Blitzshot, maximum2 recipients |11.88|15.25|11.25 /14.00|3.50|
| Scattershot |5.10|15.30|4.60 /13.80|3.60|
| Resonant Burst, death |10.25|10.25|≈10.75 /10.75|5.50|
| Arcane Surge, death |4.90|14.70|5.10 /15.30|5.40|
| Mending Thread |12.50 HPS|12.50 HPS, one recipient|Not enemy damage|12.00|
| Essence Lash, earth |10.33|10.33|12.39 /12.39|5.00|

Ordinary raw auto budgets persecond are Reaver11.01, Sword 10.41, Club11.61, Bow 19.02 before accuracy and defense, and either new50-gold magic weapon1.75. Fed mana regeneration is0.5/s; full-cooldown rows spend far more. Mending25 mean healing for 22 mana has1.14 raw HP/mana before passive benefits/overhealing. A390-mana pool cannot support indefinite cooldown spam. Existing passive mana discounts and earned focus regeneration improve particular builds; no maximum-uptime claim follows from their presence.

### Encounter sensitivity from actual spawns

| Monster | Actual spawns | HP /armor /defense | Relevant element response |
|---|---:|---|---|
| Rat |193|20 /1 /2|Earth12% resistance, death10% weakness|
| Orc |142|70 /4 /8|Earth20% weakness, death5% weakness|
| Rotworm |114|65 /8 /11|No listed element modifier|
| Minotaur |153|100 /11 /11|Fire20% resistance, death5% weakness|
| Skeleton |145|50 /2 /9|Death100% resistance|
| Cyclops |15|260 /15 /20|Energy25% resistance, earth/death10% weakness|
| Fire Devil |1|200 /13 /13|Fire immunity; earth/death20%, energy30%, physical10% resistance|
| Dragon |11|1000 /25 /18|Fire immunity, earth80% resistance; healing/control immunity further affect a hunt|

For example, modest Flurry falls to5.0 spell DPS versus Rotworm and≈0.44 versus Dragon while Focused Thrust is7.75 and4.75. Death Hex/Burst/Surge fail against Skeleton; earth Lash works there but falls to≈2.06 spell DPS against Dragon. These are reachable authored encounters with very different counters, not interchangeable armour dummies. Burst's per-pulse resistance rounding is approximated by total-budget rounding in the table.

### Approved Flurry mana tradeoff

Before armour, Focused Thrust averages`.875M`; Flurry's two hits total`.75M`. Ignoring rounding/clipping, Flurry20 is less damage-efficient than Thrust24 once mean per-hit armour reduction exceeds`M/56`. With the ordinary Sword at 40/skill 24, `M=41.6467`, this threshold is only0.744. At 18 mana the equality becomes`A=.075M=3.1235`. This produces a low-armour economy option while preserving Thrust's higher burst and armoured-target efficiency.

| Rounded source expectation | Thrust24 | Flurry20 before | Flurry18 after |
|---|---:|---:|---:|
| Orc damage percast |34|26|26|
| Orc damage permana |1.4167|1.3000|**1.4444**|
| Rotworm damage percast |31|20|20|
| Rotworm damage permana |**1.2917**|1.0000|1.1111|

The script asserts both after-change inequalities. This is a provisional DEV cost tradeoff established analytically; it is not a player-tested preference threshold or overall sword-class balance claim.

## Legal16-point capstones and passive sensitivity

The audit constructs one literal-valid witness for **each of 18 capstones**, checking288 individual purchase prefixes. Each closure spends8 foundation points, own core2+secondary core1, route minor2, advanced major1, one elective point, cap1:16. This is a budget/access proof, not an exhaustive optimiser. Alternative routes can choose different foundations and effects. The capstone requires15 points in other talents; it cannot be bought at 15 total. The authoritative catalog stores29 nodes in native order; display order is separate.

Typical offensive witness scaling is+4.5% base direct damage; some add+1% primary or+5% secondary damage. Prepared routes add+3% after two actual same-target normal hits; paid misses consume offensive readiness. The third-hit route adds4% to its eligible ordinary hit; Life's corresponding route instead improves a third effective heal. These conditional percentages do not imply permanent uptime. Whole-damage rounding occurs before route fractional carry; small bonuses do not force1 HP.

| Class | Three capstone contracts relevant to the budget |
|---|---|
| Reaver | Berserker:10 rage/ordinaryhit,100 threshold,+20% for 8s, no rage during benefit. Bloodletting: every3 hits, wound30% actual triggering damage, max3 wounds/18s; Rend+20% only on your active wound. Bloodguard:30% of 3 actual ordinary-hit HP budgets, ward cap6% maxHP/12s. |
| Blademaster | Duelist:3same-target ordinaryhits prepare35% pre-critical spell echo. Riposte: actual shield block readies40% next-normal counter,6s cooldown. Blade Storm: ordinary critical strikes up to2 adjacent monsters at 40% pre-critical damage each; no recursion. |
| Earthshaker | Aftershock:4ordinaryhits prepare25% spell wave, up to3 recipients. Stoneguard: actual shield blocks build up to3 charges,2% physical reduction/10% spell damage percharge. Stonebond: actual shield block grants3% recipient-maxHP party ward,2 tile range/6s cooldown. |
| Marksman | Deadeye:3same-target stationary hits prepare+30% nextprimary. Skirmisher: movement between3 successful shots enables30%/20% bounces. Quarry:3 hits mark+5% party ordinary damage,10s/20s cooldown. |
| Arcanist | Conduit:3offensive casts ready30%/20% next-auto chains. Resonance:3same-target offensive casts prepare30% next-cast echo. Spellweaver:A-B-A prepares+15% nextspell damage/25% mana discount. |
| Lifekeeper | Renewal:20% effective healing over6s; strongest remaining renewal, no stacking. Aegis:15% effective healing ward, cap8% recipientHP. Concord:40% actual primary rod damage to lowest-percent eligible party member, cap2% recipientHP/action. |

Combat ward and Aegis pools coexist under the10% recipient-maxHP combined ceiling. Bow and the conditional two-handed weapons lose shield-driven benefits. Blade Storm's plain16-point witness has3 percentage points crit, not100%; some alternative/elective choices give more. An isolated100% temporary-configuration integration test can prove its callback but cannot establish shipped proc rate or damage balance.

The source model exports each witness's named benefits, exact allocations and static modifiers. For example, its Life Renewal witness multiplies direct healing by approximately`1.06×1.02=1.0812`; its damage-triggered Concord witness instead has+4.5% direct damage and no healing-core multiplier. Defensive witnesses commonly have2% persistent physical reduction,2–5% maxHP, a separately readied1–2% guard reduction and1–1.4% actual ordinary-damage leech. Fractions, readiness, shields, target switching and actual received damage determine their delivered utility; these values are not added as equivalent DPS.

## Existing learned spells and conditional strength

These authored learning paths are active, but third ascension preserves a player's actual learning; it does not award every registered spell. Donation intervals must be crossed after meeting the stated Oracle requirements. Costs below are the incremental Oracle donation intervals, not a promise of total journey cost.

| Existing family | Actual learning/source gate | Material comparison |
|---|---|---|
| Head Splitter /Swipe /Ground Slam | Active Oracle:1200/1100/1000; Awakened+,ML2, matching weapon skill 17; level requirement waived at vocation 2+ | Ratios/cooldowns differ. Swipe's existing script lacks the physical armour flag used by the new sword starters; Ground Slam uses the healing cooldown group. They are not independent always-available free additions. |
| Axe Throw /Pommel Strike /Seismic Surge | Oracle:2000/2500/2500; Ascendant+,ML4,matching skill 24 and prior familyspell | Conditional stronger learned actions/control; not new chosen-class grants. |
| Sure Shot /Volley | Oracle800/2500; first ML1/dist13, later Ascendant+/ML4/dist24/prior Sure Shot | Ammo, geometry, shared group and learned entitlement matter; guaranteed spell hit is not normal bow accuracy. |
| Death wand family through Soul Drain | Spawned active Oracle accepts obtainable Hex12746; later Raise Dead and Soul Drain require prior familyspell/ML3/vocation 2+,1350/1750 intervals | Soul Drain schedules10decaying pulses over36s for 50 mana; repeated long-lived-target schedules can overlap. This existing magnitude invalidates any claim that new-starter-only tables prove whole Arcanist hunt balance. |
| Earth wand/rod family | New2182 satisfies existing Ensnare850/ML1 weapon gate; later Toxic Root1250/Deadly Vines1650 require Green Widow questprogress2/5 | Rod availability does not grant spells or skip quest progress. |
| Light Healing | Active Hyacinth letter quest and registered UID 30025 chest grant; must have completed ordinary learning |20 mana/1s existing selfheal; not automatically assumed learned by an ascended player who skipped its quest. Other registered strong healing spells lack a confirmed ordinary grant in this bounded review. |

At 40/ML4, Soul Drain's real script rolls84–128 then schedules100%,90%,…10% pulses: about5.5 times the rolled budget, minus per-pulse truncation, across36s. Its healing uses the script's computed pulse, not a new starter's effective-HP accounting. This inherited conditional content warrants a separate bounded audit before making a full-class balance claim; no new starter is inflated to match it here.

### Skill 60, rare gear and affixes

The script separately computes skill 60/ML10 with ordinary gear and the conditional upgrades above. For example, Cleaving Arc raw1/3 DPS grows from4.38/13.13 at 24 to9.13/27.38 at 60 with Hatchet, or20/60 with attack35. Focused Thrust becomes18.63 ordinary or43.75 with Crystal Sword. Essence Lash becomes15.33 atML10; Necrotic's raw auto rises to15 HP/s but costs2.5 mana/s and changes earth to death. This is a conditional source ceiling comparison, not an expected level 40 equipment state.

Actual `rarityrolls.xml` slot defaults permit rolls beyond an old fixed-item whitelist. General legendary chance is5/10000; wand-slot legendary is50/10000, each limited to3 selected stats. Sword may roll+3–5attack,+2–5skill,+4–8 crit points or+30–200critical bonus; wand may roll+1–3ML,+4–10matching element or+1 mana regeneration. Armour/shield pieces can roll10–13% physical resistance; a shield can add2–3defense. These are separate sensitivities, not all combined into a guaranteed maximum loadout. A single+10 wand element stat adds5 raw HP/s at 2s autos—larger than the entire mundane1.75 HP/s wand/rod auto budget. Equipment critical chance can therefore change Blade Storm much more than its new0.2-point middle rank. Upgrade/rarity costs, combined attainable distributions, star monsters and human use have not been measured here.

## Verification and practical limits

Run the read-only analytical audit from the client checkout:

```powershell
python tools/passives/balance-access-audit.py --server C:/GitRepos/kruxett/Rookhaven --summary
```

Completed here: active-source/map decoding;12 starter rows;72 formula profiles;18 legal16-point allocations/288 purchase prefixes; current central config/export equality; armor 8; spawned Plipus50-gold2182 registration;2182/12746 exact2–5/mana 2 parity; unchanged2185; both Flurry economy inequalities; four exact gross-gold distributions. These are source/model assertions. No native client, server restart, database mutation or actual purchase/combat was run by this audit agent.

[passives-dev-access.lua](../tools/tests/passives-dev-access.lua) supplies separate root-runner `shop_insufficient`/`shop_purchase` phases for ordinary GUID 9004. Root seeds49 or50 cash, bank 0, empty hands and normal backpack within3 tiles of spawned Plipus. It asserts actual shop2182/12746prices, UI affordability,49-gold buy-packet rejection, then50-gold authoritative item/cash changes and real bought-item equip. NPC shops use **cash+bank**; bank 0 is essential for the negative boundary. Handler invocation is not OS mouse/keyboard automation. Marker: `PASSIVES_DEV_ACCESS_OK`. The initial native probe iterations failed on server/client item-ID and untrimmed XML shop-name assumptions. The corrected probe requires authoritative `rodClientId`, `hexClientId` and server `rodCount`, locates rows by mapped client ID, checks normalized exact names and a fresh shop-open event, and uses mapped client IDs for trade/inventory. Root subsequently completed the corrected native phases; the results are recorded below.

### Root-executed native access and combat results

Both corrected shop phases passed against the actual local server using the
final DEV10085 EXE/resources in its isolated local profile. Ordinary GUID9004
had bank0:49 cash stayed49 with no rod after a real buy-packet rejection;
50 cash became0 and server item count0 became1 after purchase. The purchased
rod was equipped in hand slot5; its authoritative server/client IDs are
2182/3066. Logs: `out/passives-dev-shop-insufficient.log` and
`out/passives-dev-shop-purchase.log`.

The same saved, purchased rod was then used against an actual zero-armour,
non-resistant local monster fixture with zero talent ranks. One observed
ordinary hit removed2 HP and spent exactly2 mana. With1 mana, no shot damage
or payment occurred. The legitimately learned Essence Lash then damaged that
monster and charged its separate12 mana. No rod was granted by an admin helper.
Logs: `out/passives-dev-rod-combat.log`; `PASSIVES_DEV_ROD_OK`. The log's
`zeroManaDenied` label means insufficient mana (1<2), not a zero-mana fixture.
The measured hit proves the native path and payment; it does not sample the
whole random2–5 distribution.

The final Blademaster regression also passed actual Focused Thrust24-mana and
Flurry18-mana casts, learned-state persistence and wrong-class/weapon/mana/
unlearned/cooldown rejections (`out/class-spells-tests/blademaster.log`).

These probes use real server combat and NPC handlers with runtime-only fixture
setup/observations. They are not human hunting, live DEV tests or OS input
automation. Review normal hunts with attainable armour, food/ammo,1/3 enemies
and both low/high retained skills before describing all six classes as balanced.

Audited central source SHA256: passives config `0da5a55139518af22ec9dd9dc2fe5b2b4e04f8c36088f4f2092858fa466d8a3d`; starter config `84aa028923b2276fe18ab8a8661c403eceaa0544bc8208bd20494cde3383f7b7`; Plipus `ae6dd9bc80fb726312e6868c3d286afbf499fa4f0ffc7b4c538cd8a2383023b5`; weapons `3c0dba127d8ff6524b31a37d3b9ef8686ccc6bbf8fba61759aff614737c0c66a`. The script returns current hashes for these and the map, spawn and item data. Re-run after any source change.
