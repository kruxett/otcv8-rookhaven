# Class starter spells — local delivery

This slice adds two spells for each permanent third-Ascension class. The server
owns class entitlement, learned spells, compatible equipment, mana and shared
combat/healing exhaustion. It retains vocation 3 and the existing skill focus.
No new items, DAT/SPR/OTB records or spell animations are required.

All values are provisional. This is a local test delivery; it is not deployed or
pushed. The local passive feature gate protects both permanent classes and their
new spells.

## Spell contract

| Class | Spell | Mana | Shared exhaustion | Behavior |
| --- | --- | ---: | ---: | --- |
| Reaver | Cleaving Arc | 18 | 4 s combat | Reduced hits on up to three monsters immediately in front. |
| Reaver | Rend | 12 | 4 s combat | Smaller focused hit; bonus only against the caster's Bloodletting wound. |
| Blademaster | Focused Thrust | 24 | 4 s combat | Focused hit on one monster. |
| Blademaster | Flurry | 20 | 4 s combat | Two smaller hits, 250 ms apart; armor applies to each. |
| Earthshaker | Crushing Blow | 24 | 4 s combat | Heavy single-target hit, without slow. |
| Earthshaker | Rolling Thunder | 18 | 4 s combat | Impact followed by a smaller ground pulse on the original tile. |
| Marksman | Blitzshot | 14 | 4 s combat | Primary shot and weaker hit on one nearby monster. |
| Marksman | Scattershot | 18 | 5 s combat | Compact target-centered volley, capped at three monsters. |
| Arcanist | Resonant Burst | 18 | 4 s combat | Three pulses using wand element; split one total damage budget. |
| Arcanist | Arcane Surge | 22 | 5 s combat | Wand-element beam through three tiles directly ahead. |
| Lifekeeper | Mending Thread | 22 | 2 s healing | Self heal or named party member, within 7×5 tiles and sight. |
| Lifekeeper | Essence Lash | 12 | 3 s combat | Ranged rod-element attack scaling with magic level. |

Flurry, Rolling Thunder and Scattershot are **new replacement proposals** for the
rejected Keen Edge, Stoneheart and Piercing Shot starters. Their implementation
makes them available for local playtesting, not established final balance.

The same-kind exhaustion blocks both starter spells and interacts with existing
spells. It is not a separate one-second rotation. Healing and combat retain their
existing separate exhaustion conditions. The client displays authoritative
cooldown events; text hotkeys remain usable.

## Central tuning

Server source: `../Rookhaven/data/lib/class_spells/config.lua`.
This contains mana, exhaustion, range, weapon damage ratios, magic-level
coefficients, target caps, pulse timing and Rend's wound bonus. Spell identity,
permanent class entitlement and equipment categories are validated natively.

Weapon ratios use the ordinary weapon raw ceiling; they do not inherit Head
Splitter's forced critical multiplier. A multi-hit spell's listed ratios describe
its individual hits; Resonant Burst's formula describes its **total** three-pulse
budget. AoE spends a smaller per-target budget and has a finite target limit.
Bow spells consume one compatible round per successful cast, including burst
arrows; they do not duplicate the ammunition's ordinary explosion.

The acquisition audit and revised low-and-slow budgets are in
[class-spell-balance-audit.md](class-spell-balance-audit.md). Spell registration
alone is not evidence that ordinary players can obtain a spell. Higher registered
healing spells have no traced ordinary learning route; Mending Thread is therefore
anchored to Light Healing. Bow budgets use obtainable ordinary ammunition and
Sure Shot, rather than assuming access to conjured burst arrows or a usable Volley.

Rend now costs 12 mana / 4 s with a 0.50–0.85 weapon budget. Its own-wound bonus
does not retain the previous large mana-efficiency advantage over Head Splitter.
Rolling Thunder costs 18 mana / 4 s: its single-target raw mean is approximately
0.65 weapon ceilings, versus Ground Slam's 0.71875 at 20 mana. Its three-target
budget is approximately 1.05 ceilings total. Ground Slam currently uses healing
exhaustion in the existing XML; combined rotations require hunting tests.
All new physical hits apply armor, including each separate Flurry hit.

Full weapon wield requirements are checked before a starter can spend mana or
start exhaustion, and again before delayed hits. Required level, magic level,
weapon skill, vocation, premium and disabled weapon metadata cannot be bypassed
by a class spell using the item's full attack value. Ordinary legacy attacks and
their existing partial-power rules are unchanged.

Change central values, refresh the owned local runtime and restart the server.
Rebuild the native server only for code/configuration-contract changes. Rebuild
the local client package and regenerate its matching checksums for client edits.
The client obtains the display values from the server.

### First use after Ascension

Both starters are learned immediately when the class is chosen. The existing
third-Ascension reset still returns the player to level 1 with current and maximum
mana both zero. Vocation 3 grants 10 current and maximum mana per level gained,
so capacity without equipment, passive or other bonuses is `10 * (level - 1)`.
Learning immediately does not mean the spells can be cast immediately.

The first levels whose **mana capacity** fits the current provisional costs are
listed below. Actual use also requires current mana and eligible equipment; this
table does not bypass the equipment's own level/skill requirements.

| Class | First starter | Second starter |
| --- | --- | --- |
| Reaver | Cleaving Arc: level 3 | Rend: level 3 |
| Blademaster | Focused Thrust: level 4 | Flurry: level 3 |
| Earthshaker | Crushing Blow: level 4 | Rolling Thunder: level 3 |
| Marksman | Blitzshot: level 3 | Scattershot: level 3 |
| Arcanist | Resonant Burst: level 3 | Arcane Surge: level 4 |
| Lifekeeper | Mending Thread: level 4 | Essence Lash: level 3 |

No starter can be cast at level 1. Mending Thread fits mana capacity at level 4,
but Snakebite Rod and the basic Wand of Vortex require level 7. Thus the magic
starter fixtures' gear is not usable at levels 1–6. Mending uses 22 of the available
60 mana at level 7, leaving 38 after one cast. With normal vocation-3 regeneration
of 2 mana every 4 seconds, replacing 22 mana takes approximately 44 seconds,
provided normal food/regeneration is active and allowed throughout, without
further mana use, consumables or regeneration modifiers. Retained Light Healing
costs 20 mana and first fits at level 3, without a rod requirement.

**Release check:** ordinary human hunting from level 1 through 7 after a real
third Ascension must assess rebuilding the mana pool, access to suitable gear,
spell frequency and healing sustainability across all six classes. This
onboarding limitation is documented rather than changing the existing Ascension
reset or quietly reducing spell costs. Higher-level fixture casts do not verify
this early experience.

Sources: server `data/npc/scripts/The Nameless.lua:27` and `:33` (reset),
`data/XML/vocations.xml:44` (gain and regeneration), `src/player.cpp:1707`
(level gains), `data/lib/class_spells/config.lua:9` (starter costs) and
`data/spells/spells.xml:80` (Light Healing).

## Persistence and delayed actions

The chosen class grants only its two starters. Existing learned spells remain.
Granting is idempotent and is recovered when the permanent class is restored.
Learning uses persisted class entitlement, not the currently displayed test tree.
An admin overlay cannot give ordinary players another class's starter spells.

New delayed spell callbacks share one native action. They freeze their cast
budget and revalidate the caster's class/session, equipment and target before
later hits. They must stop after logout, death, invalidated ranks or equipment
context change. An identical replacement weapon with the same type, stats and
element has the same cast context. Existing legacy delayed spells retain their
established behavior.
Passives count a multi-hit/pulse spell as one cast.

## Local testing

`tools/run-class-spells-tests.ps1` drives six real clients sequentially against
the isolated local server/DB. Fixed disposable player IDs 9006–9011 and a
runtime-only `/classspellqa` command supply normal group-1 characters, equipment,
owned dummies and measurements. Test scaffolding is not registered in source game
data. These dummies do not attack; fixture weapons pause further ordinary swings
after the first target-selection swing, so autos cannot contaminate measured spell damage,
mana or ammunition. Cleanup restores the ordinary weapon speed. The existing
combat regression arena retains its attacking monsters and normal weapon speed.
QA dummies are attackable but non-hostile: even a hostile monster with an empty
attack list puts the player in combat through the normal attack-target callback.
Accounts and passwords are `classreaver`, `classblademaster`,
`classearthshaker`, `classmarksman`, `classarcanist`, `classlifekeeper`.

Required checks: actual Nameless choice and relogged learned spells; each spell's
real damage/healing, costs and shape; one ammunition charge; rejection without
mana/damage for wrong class/equipment, missing learning or mana; shared cooldown;
delayed cancellation and one-cast passive accounting; party healing and range;
retro controls at 800×640. Existing spell/combat/condition and permanent
persistence regressions must also run on the final binary.

Results and screenshots are recorded in `docs/local-passives-results.md` after
execution. A successful build alone does not verify the spell behavior.

## Dialogue and lore

The Nameless presents a permanent path and talents that may be reshaped. Every
choice lists its weapon discipline before confirmation. The existing third
Ascension's fourfold training applies from that point onward; it is not a claim
that earlier training was already fourfold. Class choices retain the existing
quest, confirmation and possession flow.

Wording was checked against The Nameless, Eldric's Third Flame/common-thread
dialogue, Garrick's marksman equipment and Hyacinth's recovery theme. No new
lore event or lineage is asserted. Names and descriptions remain reviewable
content, especially Flurry, Rolling Thunder and Scattershot. NPC failures give
an in-world recovery instruction; diagnostic details stay in the server log.
