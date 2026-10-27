# Food Ring

Implemented and verified locally on 2026-10-25. Not published or deployed.
The user approved the apple-v2 PixelLab graphic with “Vi kör på den.”
Both equipment states use that exact native 32×32 PNG without alterations.

| State | Server ID | Client ID | Sprite ID |
| --- | --- | --- | --- |
| Unequipped | 12863 | 11900 | 36697 |
| Equipped | 12864 | 11901 | 36698 |

Provisional shop offer 4003 costs 10 points and delivers one inactive ring.
The ring weighs 1 oz and lasts two hours of equipped use. Its remaining time pauses
when removed. Existing native ring transformations and decay handle the charge.
Admin/God can use the existing `/i 12863` command.

## Food reserve and exploit prevention

The ring never calls `Player.feed`, sets ordinary food ticks, or grants a full
food reserve. It owns a separate infinite regeneration condition in the ring
slot, with `FOOD_RING_REGEN_SUBID`; infinite here means the condition lives with
the equipment, while the item itself has a finite two-hour charge.

Ordinary eaten food counts down as before and takes precedence over the ring.
When that food expires, the ring supplies the same vocation-specific HP/mana
regeneration. Combat/resting HP rates, equipment mana bonuses and protection-zone
pauses follow the existing food rules. A shared predicate excludes the suppressed
ring from both actual regeneration and displayed regeneration rates.

Unequipping, removing or expiring the ring removes its equipment condition.
The runtime predicate also verifies the actual equipped item and enabled ability.
The condition is not persisted as eaten food. Ring time and instance attributes
persist through the native item path. Equipping hungry for one second and removing
the ring leaves the player hungry; repeating this or saving/relogging gives no
extra food. Eating actual food while wearing it still grants only that food's
normal reserve. No 1% floor is written into the ordinary reserve.

Cyclopedia's food-time response can show the equipped ring's remaining time;
reading it never changes the reserve. The retro client layout is unchanged.

## Verification actually run

- New ordinary Release server build; all 178 native source files matched the
  isolated build snapshot. Binary SHA256 is in `verification.json`.
- Native gameplay: 157 checks in `out/food-ring-20261025/native-06` using ordinary
  character permissions, real shop purchase, actual food action, real inventory
  moves and three fresh logins. Covered one-second and 20-cycle equip exploits,
  hungry/bag/equipped reconnects, no double food regeneration, reserve preservation,
  taking over at food expiry, HP/mana gains, combat/resting rates, vocation changes,
  equipment mana bonus, protection-zone pause, native duration/pause/resume/expiry,
  instance data, failed delivery and insufficient points.
- Existing-system regressions: ordinary food consumption/full refusal, life-ring
  regeneration stacked with ordinary food, Light Ring transformation/torchlight,
  current regeneration presentation and existing shop offers.
- Actual source contracts: shop/admin 97 checks; existing Cyclopedia equipment 15
  checks; food-time response 29 checks. Log: `out/food-ring-20261025/source-contracts.log`.
- Asset import: both mappings and unchanged approved pixels; all 12,285 prior DAT
  records, 12,763 prior OTB records and 36,696 prior SPR payloads preserved.
- Native client rendering: real local connection and ordinary move packets,
  equipped/unequipped screenshots in `out/food-ring-20261025/ingame-01`.
  The existing matched older QA client/server pair is used only for rendering;
  its private XML omits the new food ability. The food behavior above was tested
  separately on the new current-source server. This is not a new protected release.
- Owned processes stopped; cold source DB/config and original client profile
  hashes unchanged after the runs. Both repository diffs passed whitespace checks.

The earlier failed native runs exposed fixture issues: an expiry assertion ran
before the next creature bucket; zero-valued mana setup entered combat and changed
resting HP regeneration; and the long wire session needed ping responses to avoid
a timeout/reconnect bypassing login. Pool setup now uses direct fixture clamps,
combat has its own explicit test, and the wire runner sends keepalives. No gameplay
rule was weakened. A mapped-file import copy also failed without changing that
source state; the verified staged files were installed by atomic file replacement.

## Limits and evidence

The two-hour value is checked in native definitions and remaining-time/accelerated
expiry tests; a two-hour wall-clock soak was not run. Death/PvP were not separately
playtested. No full passive suite was selected: only the affected regeneration
presentation and equipment/food paths were exercised.

The protected client executable/archive, RH2 release pin, updater and live DEV
installation have not been rebuilt or published. The server build logged an
unavailable `pwsh.exe` post-build hook; MSBuild returned 0 and the resulting binary
and explicitly packaged dependencies passed the native checks.

See `verification.json`, the two `import-manifest.json` files, and:

- `ingame-equipped.png` / `ingame-equipped-inventory.png`
- `ingame-unequipped.png` / `ingame-unequipped-inventory.png`
- `source/apple-v2/generation.json` / `source/apple-v2/validation.json`
- [Test sources](../../../tools/food-ring-tests/)
