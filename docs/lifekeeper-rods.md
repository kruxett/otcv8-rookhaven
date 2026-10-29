# Lifekeeper rods

Eight rods fill the Lifekeeper's weapon ladder the way the spell wands fill the
Arcanist's: three tiers in each of the class's elements (earth, ice, death), with
the existing Snakebite Rod as the first earth tier. Values sit inside the spell
wand ranges of the same tier. Server repository paths are relative to
`../Rookhaven`.

| SID | CID | Rod | Element | Mana | Damage | Level | Source (base chance) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2182 | 3066 | Snakebite Rod (existing) | earth | 2 | 2–5 | 7 | Plipus, 50 gold |
| 12850 | 11887 | Bramble Rod | earth | 3 | 6–12 | 13 | swamp troll, 0.9% |
| 12851 | 11888 | Mossheart Rod | earth | 6 | 13–25 | 20 | tarantula, 2% |
| 12852 | 11889 | Rime Rod | ice | 2 | 4–9 | 7 | barbarian skullhunter, 1.2% |
| 12853 | 11890 | Sleet Rod | ice | 4 | 8–16 | 13 | barbarian brutetamer, 4% |
| 12854 | 11891 | Winterbough Rod | ice | 6 | 15–27 | 20 | barbarian bloodwalker, 3% |
| 12855 | 11892 | Bone Rod | death | 2 | 3–7 | 7 | skeleton warrior, 1.5% |
| 12856 | 11893 | Gravebloom Rod | death | 4 | 8–15 | 13 | ghoul, 0.8%; Forgotten Ancients choice |
| 12857 | 11894 | Wither Rod | death | 5 | 11–19 | 20 | beholder, 4% |

Every source monster spawns on the current map. The classic high rods
(Moonlight, Northwind, Terra, Hailstorm, Springsprout, Underworld) remain
recognised as rods but have no ordinary authored source on the configured map.
Necrotic Rod is an exception: the single Fire Devil at 32053,32230,15 still
drops it at a base chance of 0.49%, with damage 27–33 and mana 5.

Rods and spell wands now use the same level tiers, enforced in both
`data/weapons/weapons.xml` and `data/movements/movements.xml` for either hand.
Spell wands with mana cost 2 require level 7, cost 3–4 level 13, and cost 5–6
level 20. This changes 19 spell wands plus Snakebite's weapon-level entry.
The unrestricted right-hand registrations for those items were removed.
Both legendary magic weapons still require level 35. Classic high rod/wand
registrations outside this ladder retain their legacy rules.

Ashen Requiem's Forgotten Works donor is now the Wither Rod instead of the
Necrotic Rod, whose only source is one fire devil spawn at 0.49%.

## Acquisition audit before implementation, 2026-10-29

The October 12 acquisition work is still present. The shop/drop mix already
matches: **one 50-gold starter and nine monster-drop weapons per family** when
the legacy Necrotic Rod is included. The intended new rod ladder accounts for
eight of those drops. Each family also has one Forgotten Works legendary
recipe. Before this change, wands additionally had one guaranteed Epic quest reward;
rods did not. Both are now choices in that same chest, as documented below.
These source counts do not establish equal farming times or full progression
parity.

`tools/rod-wand-access-audit.py` reuses the existing read-only OTBM parser and
source-link audit, without running its passive balance model. It follows
`config.lua` → `rookalmost.otbm` → `Untitled-1-spawn.xml`, checks monster
registration and loot, spawned NPC shops, mapped/registered quest rewards,
native rod/wand classification, ordered equip registrations and the two magic
forge recipes. The map parsed without unknown attributes. All 45 native magic
weapon definitions were classified: 17 rods and 28 wands, of which 11 and 12
respectively have an authored source including the forge recipes.

Rerun from the client repository:

```powershell
python tools/rod-wand-access-audit.py --output out/rod-wand-audit-20261029/rod-wand-access.json
```

The JSON receipt records source hashes, checkout commits, sources, spawn counts,
sample coordinates and definitions without ordinary sources. The larger initial
source inventory is `out/rod-wand-audit-20261029/source-access.json`. These files
are local evidence under ignored `out/`.

The nine rod drop sources above have these active spawn counts:

| Rod | Monster | Spawns | Monster HP | Base chance |
| --- | --- | --- | --- | --- |
| Bramble | Swamp Troll | 59 | 55 | 0.9% |
| Mossheart | Tarantula | 14 | 225 | 2% |
| Rime | Barbarian Skullhunter | 17 | 235 | 1.2% |
| Sleet | Barbarian Brutetamer | 5 | 245 | 4% |
| Winterbough | Barbarian Bloodwalker | 5 | 305 | 3% |
| Bone | Skeleton Warrior | 18 | 65 | 1.5% |
| Gravebloom | Ghoul | 46 | 100 | 0.8% |
| Wither | Beholder | 4 | 260 | 4% |
| Necrotic (legacy) | Fire Devil | 1 | 200 | 0.49% |

The corresponding wand inventory is:

| Wand | Source | Spawns | Base chance / price |
| --- | --- | --- | --- |
| Hex | Plipus The Mage | 1 NPC | 50 gold |
| Ember | Witch | 2 | 5.4% |
| Spark | Orc Shaman | 17 | 1.2% |
| Vine | Orc Shaman | 17 | 2.2% |
| Ruby | Kindling | 12 | 1.1% |
| Flare | Fire Bat | 34 | 0.9% |
| Surge | Elf Arcanist | 3 | 3.9% |
| Ash | Sulfur Imp | 16 | 0.85% |
| Voltaic | Minotaur Mage | 15 | 2.7% |
| Jade | Dwarf Geomancer | 3 | 1.06% |
| Dusk / wand of the Ssythari | Forgotten Ancients chest UID 30157 | 1 chest | Choose wand or Gravebloom Rod, fixed Epic affixes |

Percentages are the XML chance divided by 100,000. Actual chance also depends
on `getLootRandom()`/`RATE_LOOT`, star multipliers, the stamina gate and available
corpse space. They are not live drop measurements. The checked-in config omits
`rateLoot`; the native fallback is 2. No live config value was read.

Progression findings and their disposition:

- **Resolved:** the 19 spell wands and the nine-item rod ladder now share
  tiers 7/13/20. Snakebite's right-hand bypass is removed, and Dusk/Gravebloom
  both require 13. Damage, mana costs, elements, shop prices and loot are unchanged.
- All three ice rods are barbarian drops in Stillshore. The normal boat requires
  Floki's boat repair progress 2 and 50 gold. This is a regional/quest gate on
  the ice path, not an empty rod tier. No ice wand currently has an ordinary
  authored source at all: Shiver, Icicle, Glint, Glacier and Frost are defined
  but unavailable through the checked ordinary paths.
- Blaze, Gloom and Serpent Wands also lack ordinary authored sources. No classic
  wand 2187–2191/8920–8922 has one. Decorative Hex/Ember map placements in
  Plipus's shop are excluded from the acquisition count.
- The legacy Necrotic Rod is substantially stronger than the new death ladder.
  Its single deep spawn makes it a rare outlier, not a dependable replacement
  for Bone → Gravebloom → Wither. Its drop and combat values were not changed.
- Forgotten Works supplies Stonewake from an Epic Jade Wand and Ashen Requiem
  from an Epic Wither Rod. Both recipes use the lava material group and the same
  shared quest/activity/payment framework; they are crafted rewards, not a
  choice of free quest loot. Donor hunts differ (3 Geomancers versus 4 Beholders).

### Implemented quest choice and legacy exchange

The same mapped Forgotten Ancients chest (UID 30157 at 32646,32196,14) now
opens `game_questreward`, a compact 420×336 retro window. The player selects
Dusk Wand or Gravebloom Rod and presses **Choose**, or closes/cancels without
consuming the reward. Neither choice is restricted to the current class.
Both are level 13, base 8–15 death damage / 4 mana, with fixed Epic +1 Mana Regen
and +6 damage matching the weapon's actual element. **Dusk Wand and Gravebloom
Rod are both death weapons**; wand/rod determines the class role, not the element.
Their names are `wand of the Ssythari` / `rod of the Ssythari`.
The UI displays real client item IDs supplied by the server.

The quest's ritual, staircase and final-door bindings do not require third
Ascension or a permanent class. Arcanist/Lifekeeper are third-Ascension choices,
so the reward UI labels the options **Wand** and **Rod**, without implying a
current class or a class restriction. Both weapons require level 13 to equip/use;
their weapon/equip entries have no vocation requirement. Full dungeon navigation
has not been playtested as part of this change.

Each option shows its name, weapon type, element, level, base damage, mana cost
and fixed Epic bonuses directly beside its item icon. Only **Choose** and
**Cancel** appear below the choices; no inspection window or hover text is needed.

The existing rarity loader retains `wandStats` alongside `wandTypes` from the
same `weapons.xml` entries. The inline information reads those base values and
native item level; the damage affix is selected by the loaded combat
element instead of assuming attribute 14 (death). Missing preview/bonus data
refuses preparation without consuming the claim. No item elements, damage
ranges, mana costs or rarity weights were changed in this presentation update.

`data/lib/core/ancients_reward.lua` owns the chest-issued 60-second offer. Opcode
106 accepts only a bounded token and `wand`/`rod` selection or cancellation.
Confirmation repeats the current login generation, player, chest identity and
position, proximity, lifetime and one-time claim. The item is prepared with its
fixed rarity before the native inventory transaction grants it. CAP, bag space
or preparation refusal keeps the claim available; it never drops a reward on the
floor. Duplicates and stale offers cannot grant another item. Logout clears the
offer. The client disables duplicate confirms while waiting and keeps a failed
choice open for a retry until its offer expires.

Storage 70078 remains the completion/exit-door flag. New storage 70176 records
1 for wand or 2 for rod. The completion flag is set only after successful delivery;
the loot-room exit's binding is unchanged. The action comment and quest journal
now describe the choice correctly.

**Existing recipients:** ask Plipus about `ssythari`, `ancients`, `reshape` or
`exchange`, then answer `yes`. A player with completed 70078 and unset 70176 may
exchange one carried Epic `wand of the Ssythari` for its rod counterpart. The
exact item is replaced in its backpack container through the native transaction.
Current enchantment totals and roll history are reapplied through the existing
upgrade library, including changed legitimate affixes; no fresh roll is made.
The old completion/exit flag stays set, and recording the new rod choice prevents
another exchange. New claims are already recorded and cannot use this migration.

The exchange rejects an ordinary Dusk Wand, a marked item belonging to another
player, an equipped/ground item, an ambiguous pair of eligible wands, missing
quest completion, the wrong NPC or distance, missing affix data and native CAP/
transaction refusal. Historical quest items have no owner marker, so their
existing server-authored name, Epic tier and the recipient's completion storage
are the available legacy provenance; new rewards carry an owner GUID marker.

The mapped Hatchling choice is Runed Warclub 12728, Tempered Broadsword 12725,
Great Waraxe 12732 or Ranger Hood 12703. Its fifth reward script offers Spellweave
Hood 12779, but registered UID 30226 has no placed map item; that option is not
counted as available. UID 30217 appears at two map positions, both referring to
the same Great Waraxe reward. Mini Annihilator offers Royal Mace 12708, Jagged
Sword 8602, Gilded Axe 12720 or Ranger Gambeson 12704. Neither quest currently
offers a wand or rod. Their shared completion storages already enforce one
choice; adding magic options there would be a separate content proposal.

### Verification of the implementation

Changed acquisition → prepared item grant/native inventory transaction → both
choices, cancel, duplicate confirmation, CAP refusal/retry and legacy replacement.
Changed level policy → ordinary equip in either hand → level boundaries 6/7,
12/13 and 19/20 for all 28 ladder weapons, with an ordinary knife regression.
New UI → actual retro widgets → 1280×800 and 800×640 screenshots.

Focused contracts run through `../Rookhaven/tools/tests/run-ancients-reward.py`
with Lupa LuaJIT 2.1: actual reward, rarity and affix libraries (304 checks),
client UI module (29 checks), existing client-request contracts (91 checks),
NPC dialog regression (20 cases / 53 checks), and forge regression (33 groups).
The inventory boundaries in those Lua contracts are modeled; the native runner
below exercises the real engine and client separately.

The read-only inventory now also follows the registered/mapped chest delegation
to both service choices and verifies equal native/equip tiers in each hand.
Its post-change receipt is `out/ancients-reward-20261029/access-inline.json`.
Native run receipts and screenshots are under `out/ancients-reward-20261029/`.
The final **native-06 run passed** using the server engine matching all 178
recorded native source files, with the current server data and the real QA
client loading the new UI module. It exercised the actual mapped chest and
opcode, both reward branches, cancellation, duplicate confirms, native CAP
refusal/retry, Plipus's real `ssythari` → `yes` dialog and exact replacement,
and logout/reconnect with the rod, claim flags and changed affixes intact.
The six level boundaries produced **336 actual equip checks** (28 weapons ×
two hands × six levels), plus six ordinary-knife regression checks.
Both native screenshots were reviewed; text, icons and controls fit at 1280×800
and 800×640. The source database/config and the user's client profile were
verified unchanged, and every process started by the runner was stopped.

The focused contracts additionally simulate an earth rod alongside the death
wand: the inline information and actual granted +6 affix both follow earth,
with no death affix granted to that rod.

The **native-inline-01 run passed** with item information directly beside the
icons at 1280×800 and 800×640. Both choices, cancellation, duplicate denial,
CAP refusal/retry, Plipus exchange and reconnect persistence were rechecked.
`--details-only` reused native-06's tier evidence for the unchanged weapon/equip
XML instead of repeating the 336 equip checks. Its receipt is
`native-inline-01/result.json` under the same evidence directory.

The **native-preascension-01 run passed** with the final Wand/Rod labels and an
ordinary vocation-0 (Unawakened) character at the mapped chest. Both claims,
cancellation, duplicate denial, native CAP refusal/retry, legacy exchange and
reconnect persistence passed before any Ascension. The runner moves its owned
character to the chest; this proves the reward has no class/Ascension gate,
not that the complete dungeon route was traversed. Its receipt is
`native-preascension-01/result.json` under the same evidence directory.

Intermediate native runs are retained as failed evidence. Their fixture issues
were corrected: a reset excluded the player's own occupied destination tile;
level loss also reduced CAP and confounded equip checks; and logout was attempted
from the quest/shop location while ordinary logout restrictions still applied.
The runner now allows its own tile, restores fixture CAP for the level checks,
and returns to the normal temple/PZ logout position. No gameplay validation was
relaxed to make those tests pass.

Published as [DEV10101](dev10101-release.md) on 2026-10-29 with the rebuilt
protected executable/archive, matching RH2 pin and server Lua/data deployment.
The October 12 results below remain historical.

## Where a rod ID must be listed

- `src/passives.cpp`, the `rods` set in `weapon()`: decides whether Lifekeeper
  passives and class spells treat the item as the class weapon. Native; a new ID
  needs a server rebuild.
- `data/spells/scripts/attack/wand_*.lua` and the copies in
  `data/OracleStoneEvents/`: one ID list per element for the nine earth, ice and
  death rod spells.
- `data/weapons/weapons.xml` (element, mana, damage, level) and
  `data/movements/movements.xml` (equip level).

Essence Lash, the upgrade forge and rarity rolls read the weapon registry or the
weapon type and need no ID list.

## Art and import

Sprites are native 32×32 PixelLab candidates styled on the existing rod sprites,
kept under `assets/items/rods/<slug>/` with the untouched candidate in `source/`.
Seven shafts ran off the bottom edge and were shortened two rows and closed with
an outlined foot; the Bramble Rod was also moved down one row to close its tip.
`tools/rod_assets.py` stages the batch into DAT/SPR/OTB/XML and verifies that no
existing record changes; `assets/items/rods/manifest.json` holds the result.

## Verification on 2026-10-12 (local loopback only)

`tools/tests/rods-native.lua` with the server fixture `tools/rods-fixture/control.lua`
ran in the real client against the local server built from this source:

- all eight definitions load on server and client, and can be created;
- every loot row is present on its monster, and the forge recipe names the Wither Rod;
- as Lifekeeper every rod counts as the class weapon and a wand does not; as
  Arcanist the reverse, with the existing Hex Wand still accepted;
- real attacks on a dummy: damage inside each rod's range, mana spent equal to its cost;
- each rod channels the rod spell of its own element and is refused another element's;
- Essence Lash casts with the Wither Rod;
- equipping is allowed at levels 20/13/7 and refused at 19/12/6 for the matching tier.

`tools/tests/rods-visual.lua` captured the rods in an open bag in the real client.
`tools/tests/spell-security-contract.lua` (52) and `forge-security-contract.lua`
(28 groups) still pass.

Not exercised: an actual monster kill dropping a rod, forging Ashen Requiem from
a real Wither Rod, and rarity rolls or upgrades on the new rods. Drop rates and
damage are starting values, not a measured balance pass.

## DEV10097 release on 2026-10-12

Published to the ordinary DEV server as **DEV10097**: server commit `178aba9a`
(native EXE built on the DEV host from `7503f1f5`, identical native source),
client commit `a4df63d`.

- `modules/game_features/features.lua` now requires client IDs 11887–11894, which
  moves the login checksum from `CS1:14287d12` to `CS1:a87b278f`. Earlier DEV
  clients are refused until they update.
- The client release is archive-only: the already published `RookhavenClient.exe`
  is reused with a new `data.zip`. The prepared package (that EXE plus the new
  archive) started offline with version 10097 and 11895 item types, and the same
  login checksum was enforced in the local login tests.
- On DEV: orderly shutdown with no players online, full database dump, fast-forward,
  new EXE installed, client published while the server was stopped, restart through
  the existing supervisor. Readback showed the new commit and EXE, listeners on
  7173/7174, a clean start-up log, the updater offering 10097 to a 10096 client on
  both the local and public endpoint, and config and PROD unchanged.

Not exercised on DEV: a gameplay login, the native updater download/restart from a
10096 client, and any rod behaviour. Those were tested on the local loopback only.
Receipts are under `out/rods-dev-release-20261012/` (ignored by Git).
