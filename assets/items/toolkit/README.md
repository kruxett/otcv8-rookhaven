# Toolkit

Implemented and verified locally on 2026-10-25. Not published or deployed.
The user approved the PixelLab v1 sprite with “Jag godkänner, kör.” The imported
PNG is byte-identical to that native 32×32 source, with binary transparency.

| Server ID | Client ID | Sprite ID | Prototype |
| --- | --- | --- | --- |
| 12865 | 11902 | 36699 | Native use-with tool SID 10511 |

Use the existing Admin/God command `/i 12865` for local inspection. Shop offer
4004 costs a provisional 50 points and grants one Toolkit without map overflow.
It weighs 10 oz. It is a reusable tool with no charges or random jamming.
Its bag appearance does not make it a storage container.

## Behavior and affected existing systems

Use Toolkit on a target to apply rope, shovel, pick or machete behavior.
Existing tool handlers retain the same source content and their original quest,
skill, achievement, reward, transform and decay rules. The native action still
checks source item identity, proximity and floor restrictions.

The clicked object takes precedence over the ground: grass on sand is cut, and
crystals on sand are mined through the existing mining gates. Generic terrain
falls through rope, shovel, pick and machete. Every attempted helper receives
its own position copy because some helpers mutate that value before returning.

The two special non-adjacent silo rope routes were moved unchanged into
`onUseRookhavenRope` in the shared action library. Both ordinary rope and Toolkit
call that helper. Regular pick, shovel, machete and legacy multi-tool wrappers
are byte-unchanged. The legacy tools retain their own behavior and jamming rule.

Modified behavior → affected existing path → verification:

- Shared silo helper → ordinary rope climbing/pulling and both silo routes →
  native use-with packets for Toolkit and ordinary rope; actual PZ refusal handler
  exercised separately by the source contract.
- Tool selection → diggable floors, vegetation and mining/quest nodes → native
  comparisons with ordinary shovel/pick/machete, sand priority, mining refusal,
  training success and learned-mining XP/fragments.
- New shop item → existing grant/debit/icon/history contract → real native purchase,
  insufficient-points and capacity refusal; actual shop source contract.
- New DAT/SPR/OTB item → existing definitions and inventory UI → record preservation,
  native flags, live bag movement/use-with and screenshot.

## Verification actually run

- **106 native checks / 23 real use-with packets**, including use after reconnect,
  instance data and no item loss/duplication/jamming. Evidence:
  `out/toolkit-20261025/native-06/result.json` and its server log.
- **106 shop/admin source checks** and **92 Toolkit routing/PZ source checks**.
  These execute the actual scripts with isolated API doubles. They are not native
  gameplay checks. Log: `out/toolkit-20261025/tool-contracts.log`.
- Existing Cyclopedia equipment 15 and food-time response 29 source checks also
  passed after the shop addition; see `out/toolkit-20261025/source-contracts.log`.
- Asset verification preserved all 12,287 previous DAT records, 12,765 previous
  OTB records and 36,698 previous SPR payloads. Approved pixels, use-with flag,
  non-container/non-stack behavior and SID/CID/sprite mapping passed.
- Real client moved Toolkit into an opened backpack, parsed its native multi-use
  flags, used it from that bag on grass and received the resulting terrain change.
  `ingame-inventory.png` is the complete screenshot; `ingame-backpack.png` is an
  unscaled crop. Rendering uses the existing matched older QA client/server pair
  with current tool scripts. Current-server gameplay was tested separately above.
- No native code changed. All 178 current native source files matched the previously
  tested ordinary Release binary, SHA256 in `verification.json`.
- Owned processes stopped; source cold DB/config and original client profile hashes
  unchanged. Both repositories passed whitespace checks.

Early failed runs identified test-fixture issues: an already delivered inventory
item required a trip through the bag before auto-placement; the wire protocol
needs an inventory-slot address rather than `Item:getPosition()`; the ordinary
tool collection exceeded the fixture's initial capacity; and moving a stackable
coin can replace its native object, so verification must read the destination
rather than retain the old handle. The corrected fixture keeps ordinary player
permissions and real native packet/range checks. No gameplay rule was weakened.
An accidental encoding change to one pre-existing comment was also restored;
all existing shared tool handler bodies match their original content.

## Limits and release state

Player-to-player rope pulling, PvP and blocked silo destinations were not separately
playtested. Ordinary rope's PZ refusal was checked through the actual Lua handler
contract, not through a native PvP scenario. No full passive suite was selected:
the changed tool paths do not alter combat/passive calculations.

The protected client executable/archive pair, RH2 release pin, updater and live
DEV installation have not been rebuilt or published. No commit/push was made.
See `verification.json`, `import-manifest.json`, and
[test sources](../../../tools/toolkit-tests/).
