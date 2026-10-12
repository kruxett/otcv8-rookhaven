# Lifekeeper rods

Eight rods fill the Lifekeeper's weapon ladder the way the spell wands fill the
Arcanist's: three tiers in each of the class's elements (earth, ice, death), with
the existing Snakebite Rod as the first earth tier. Values sit inside the spell
wand ranges of the same tier. Server repository paths are relative to
`../Rookhaven`.

| SID | CID | Rod | Element | Mana | Damage | Level | Source (base chance) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2182 | 3066 | Snakebite Rod (existing) | earth | 2 | 2–5 | 7 | Plipus, 50 gold; quest chest |
| 12850 | 11887 | Bramble Rod | earth | 3 | 6–12 | 13 | swamp troll, 0.9% |
| 12851 | 11888 | Mossheart Rod | earth | 6 | 13–25 | 20 | tarantula, 2% |
| 12852 | 11889 | Rime Rod | ice | 2 | 4–9 | 7 | barbarian skullhunter, 1.2% |
| 12853 | 11890 | Sleet Rod | ice | 4 | 8–16 | 13 | barbarian brutetamer, 4% |
| 12854 | 11891 | Winterbough Rod | ice | 6 | 15–27 | 20 | barbarian bloodwalker, 3% |
| 12855 | 11892 | Bone Rod | death | 2 | 3–7 | 7 | skeleton warrior, 1.5% |
| 12856 | 11893 | Gravebloom Rod | death | 4 | 8–15 | 13 | ghoul, 0.8% |
| 12857 | 11894 | Wither Rod | death | 5 | 11–19 | 20 | beholder, 4% |

Every source monster spawns on the current map. The classic high rods
(Moonlight, Necrotic, Northwind, Terra, Hailstorm, Springsprout, Underworld)
remain recognised as rods but are well above this curve and are not distributed.

The level requirement is enforced when equipping (`data/movements/movements.xml`)
and in the weapon registry (`data/weapons/weapons.xml`). The spell wands
12741–12759 have no level requirement today; only these rods, the two legendary
weapons (35) and the left-hand rule on Snakebite Rod/Wand of Vortex (7) do.

Ashen Requiem's Forgotten Works donor is now the Wither Rod instead of the
Necrotic Rod, whose only source is one fire devil spawn at 0.49%.

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
a real Wither Rod, rarity rolls or upgrades on the new rods, and any DEV or live
server. Drop rates and damage are starting values, not a measured balance pass.
