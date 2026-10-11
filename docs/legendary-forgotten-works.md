# Legendary: Forgotten Works

Published to the ordinary DEV server on 2026-10-11 as **DEV10096**, with server
commit `44ca5901`, client code commit `5e6c062` and login checksum
`CS1:14287d12`. Restart the DEV client and let its updater finish before testing.
The native binaries and protocol are unchanged from DEV10095.

Bolgrim opens the Forgotten Works for an Ascended character who retrieves his
personal old mould from an eligible dwarven world spawn. Four scattered recipe
pages unlock dwarven, barbarian, dragon and lava designs separately. The original
Smelting tab and its tempering flow remain available.

The DEV10096 UI revision separates the discovered design list from the
selected weapon. Only the active row is tinted and marked **Selected**; clicking
it again keeps the donor. The full signature effect is visible in the detail
pane. **Weapon details**, **Signature details** and **Forge activity** open
read-only explanations. Costs and activity share one scroll area, while status,
Forge, Refresh and Close stay visible. **Unlock designs** also explains the
ordinary quest and page sources in the client.

The DEV10096 Look/Trade revision shortens all ten signature descriptions,
retaining lore, proc chance, the main effect, caps and cooldown. Shared cooldown
and damage-calculation rules are available through **Signature details** instead
of repeating them in every item description. Existing generated items show the
current catalog copy through a presentation-only adapter; their stored affix
text, structured rolls and stats are not rewritten. Custom descriptions are
left intact. Iron Echo, Warbrand, Scale Ash and Cinder Glass also gain a brief
in-world hint about their value to smiths; established crystal/shard copy remains.

Validation: XML changes are limited to ten weapon and four material descriptions.
The focused Lua contract runs the real Look/Trade callers with native API mocks
and the independent previous catalog: 1,084 parameterized cases passed,
including affix preservation, old/current/custom descriptions, distances,
callback composition and admin metadata. No live gameplay or combat/passive
suite was run for this presentation change. Evidence is in
`out/legendary-look-copy-20261011/`.

Release verification: encrypted archive/source equality, server startup and
listeners, preserved config/DLLs/PROD, and the real native DEV10095-to-10096 HTTP
update/restart passed. The successful updater probe verified profile bytes and
recursive DACL restoration against independent fresh safety copies. An initial
probe stopped before any native launch on conflicting profile fingerprints;
its copies and journal were retained without overwriting the current profile.
An atomic-file replacement error during publication was reconciled while the
supervisor held the server stopped, corrected with an explicit backup filename,
and verified before completing publication. The earlier 18 native UI test groups
were reused after checking their source hashes; the focused Look/Trade contract
was rerun. No live character crafting/Look test or passive suite was run for this
release. Evidence: `out/forgotten-dev-release-20261011/release-result.json`.

To unlock designs through ordinary play:

1. Complete The Ascent. Say `hi`, then `forgotten works` to Bolgrim at
   `32124,32023,14`.
2. Participate in a genuine world-spawn Dwarf Guard or Dwarf Geomancer kill
   with more than 14 hours of stamina remaining. While this quest step is
   active, an eligible kill places your own **Old Forging Mould** in the corpse
   if you are not already carrying it. Loot it, return to Bolgrim and say `forgotten works` or
   `mould`. Another character's mould does not count.
3. **Use** a Forging Page to learn that family's designs permanently. Each page
   has a 2% chance per eligible kill in its authored hunting region:

| Page | Eligible monsters | Designs learned |
| --- | --- | --- |
| Dwarf | Dwarf Guard, Dwarf Geomancer | Deepwarden, Oath of the Deep, Ashcleaver, Elder's Reckoning |
| Barbarian | Barbarian Bloodwalker, Brutetamer, Headsplitter, Skullhunter | Forgeheart, Mountain's Verdict |
| Dragon | Dragon, Dragon Hatchling | Wayfarer, Deepforge Arbalest |
| Lava | Fire Devil, Fire Elemental | Stonewake, Ashen Requiem |

Learning a new family consumes one page. An already learned page or a page used
before the quest unlock is retained. Spawn location and combat participation
matter; an artificially spawned monster of the same name is insufficient.
Pages can be traded. Materials, tempering and forge activity are separate
crafting requirements and do not unlock designs.

Each recipe consumes its exact Epic donor and preserves its two enchantment
instances/totals. The resulting Legendary has a fixed signature. Ordinary
upgrading and natural/forced loot stop at Epic; only explicit recipes produce
new Legendary equipment. Existing older Legendary items retain their profiles.

| Recipe key | Weapon | Signature | SID / CID |
| --- | --- | --- | --- |
| deepwarden | One-handed sword | Swordguard | 12831 / 11868 |
| oath | Two-handed sword | Sweeping Edge | 12832 / 11869 |
| ashcleaver | One-handed axe | Ground Ember | 12833 / 11870 |
| elders_reckoning | Two-handed axe | Frontal Sweep | 12834 / 11871 |
| forgeheart | One-handed club | Stone Mend | 12835 / 11872 |
| mountains_verdict | Two-handed club | Stormcall | 12836 / 11873 |
| wayfarer | Bow | Windstride | 12837 / 11874 |
| deepforge_arbalest | Crossbow | Ricochet | 12838 / 11875 |
| stonewake | Earth wand | Living Bark | 12839 / 11876 |
| ashen_requiem | Death rod | Soul Draw | 12840 / 11877 |

Only successful paid ordinary weapon attacks enter the 12% signature lottery.
All ten share a character cooldown, retained through weapon swaps, logout and
death. Additional damage cannot crit, leech, skill or trigger another proc;
ordinary PvP legality, armor, resistance and mana shields still apply. Protection
and healing have explicit low caps. Delayed effects and charges are invalidated
when their weapon instance/session changes. Canonical values are in server
`src/legendaryitems.cpp`, item XML and `forgotten_works_config.lua`.

Native 32×32 PixelLab sprites are stored in `assets/items/legendary/`. Four-frame
cosmetics animate only equipped hand widgets, retaining their rarity border and
input behavior. They do not modify Item shaders or add a character aura.

## Corrections after the independent review

The original findings below are retained as historical evidence. The fixes add
authoritative resulting weapon stats, inherited totals, level, hands and ammo
requirements to the compact retro forge. Detailed hovers explain signatures,
the shared cooldown and effective activity. The Epic donor has a framed slot
and permanent name/drop hint. Refresh preserves it, successful crafting leaves
a persistent notification, and a rejected quote refreshes changed requirements.
Only a deliberate station-open reply opens the window. Session/request matching
rejects stale responses and a matching Close invalidates the server quote.

Native preflight and commit now plan the final inventory together. The result
replaces the exact donor in its carried bag, including full nested bags. Material
stacks retain their attributes, gold change must fit normally, and final capacity
uses each holding bag's native weight reduction. Failure mutates no live inputs.

Delayed damage rechecks current source combat permission and protection zone,
then native target legality, secure mode, sight and range. An ordinary source
entering PZ no longer damages an outside target. IgnoreProtectionZone remains
an explicit native exception; CannotUseCombat still refuses damage.

Living Bark now reserves up to 12 HP for two direct hits, at most 6 PvE or 3 PvP
per hit, expires after eight seconds and respects the shared ward ceiling. Full
mana shields and DoT leave it untouched; a partial shield resolves before ward
absorption. Soul Draw heals 20% of actual primary-plus-signature HP damage,
capped at 8; mana-shield damage contributes no healing. Hand-slot badges and
tooltips show active charges, ward/hit budget, movement duration and cooldown.
No character effect was added. Frontal Sweep now states its primary-position
requirement explicitly.

Acquisition and party corrections are documented in the tuning section below.
The revised chase duration and natural proc frequency still require ordinary
hunting telemetry; forced diagnostic attacks do not establish final balance.

## Acquisition tuning

Costs follow the recipe family:

| Family | Iron Echo | Warbrand | Scale Ash | Cinder Glass |
| --- | ---: | ---: | ---: | ---: |
| Dwarven swords/axes | 400 | 80 | 50 | 20 |
| Barbarian clubs | 120 | 800 | 50 | 20 |
| Dragon bow/crossbow | 120 | 80 | 200 | 20 |
| Lava wand/rod | 120 | 80 | 50 | 120 |

Every craft also consumes 100 Light Blue Fragments, 100 Red Fragments, one
Pristine Forging Shard and 20,000 carried gold. Each of four personal activity
counters consumes 225 effective minutes. Same-region/current-login continuity
allows at most five minutes between genuine eligible kills, earning at most
60 seconds per receipt. A first kill establishes a baseline. A solo hunter must
have a positive native damage receipt no older than 60 seconds; shared-XP
members use native recent damage/healing eligibility. Only unlocked, online,
alive ordinary participants within range and above 14 hours stamina divide
personal activity. Offline time, long idle gaps, region changes, artificial
spawns and excluded quest areas do not accrue it. **Forge activity** explains these rules;
Bolgrim explains tempering in-world. Eligible accepted party members receive
their own named mould, including healers whose damage dealer owns the corpse.

The four origin pools match the active map's authored spawn XML: 7 dwarven,
36 barbarian, 18 dragon and 8 lava spawn positions. Material/page RNG uses
ordinary eligible kills without star loot multipliers. Materials and pages are
tradeable; mould ownership and personal activity are character-bound.

The common lava catalyst falls from 200 to 20 for non-lava recipes. Authored
timer/RNG-only source bounds make this roughly 1.39 optimistic global lava hours,
compared with 13.89 previously. Across one of each ten weapons, 400 Cinder Glass
replaces 2,000. These are world production bounds, not measured hunting times:
native respawn checks, fighting, travel and competition add time. Family-specific
primary materials distribute demand without bypassing the four personal cores.

Material amounts and drop chances are provisional. Fifteen effective hours is
the configured personal gate, not a measured total farm time or a guaranteed
100–200 hour chase. Tune from ordinary hunt telemetry before launch.

## Admin testing

Only character groups 5/6 with access may use these commands. Targets must be
online; arguments use spaces, not command separators.

```
/legendaryadmin help
/legendaryadmin status Krux
/legendaryadmin unlock Krux
/legendaryadmin prepare deepwarden Krux
/legendaryadmin grant deepwarden
/legendaryadmin force
/legendaryadmin reset
```

`prepare` supplies one craft's Epic donor, materials, gold and personal counters,
sets quest stage 2 and teaches all recipes. The recipient needs capacity and a
free backpack slot, and still completes the actual forge dialog. Omitting the
target prepares the issuer. `grant` gives the issuer a complete testing item.
`force` queues the next eligible signature lottery on the issuer; ordinary
payment, cooldown and combat rules still apply. `reset` clears only the issuer's
signature cooldown, pending force, temporary effects and diagnostic counters.
It does not restore quest progress, pages, cores, materials, gold or items.
Generic `/i` cannot create an incomplete catalog weapon.

For a quick crafting/UI test on DEV10096:

First restart/update the ordinary DEV client to 10095. The resulting weapons
require level 35 to equip/use; admin preparation does not raise character level.

1. Use an access character in group 5/6. Run `/legendaryadmin status`, then
   `/legendaryadmin prepare deepwarden` with capacity and a free bag slot.
2. Run `/goto Bolgrim`. The NPC is at `32124,32023,14`; walk to the lava forge
   at `32118,32024,14` and stand within one tile on the same floor. The forge
   uses item 7504/action ID 50053. Direct access-character teleport is also
   supported: `/goto {x = 32117, y = 32024, z = 14}`.
3. Use the forge, open **Forgotten Works**, choose **Deepwarden**, and drag the
   Epic weapon from the supplied backpack into the donor slot. Check its two
   inherited rolls, resulting stats, visible signature effect and listed costs.
   Open the three detail buttons, change designs, then click the active design
   again: only one row should remain selected and the donor should be retained.
4. Try Refresh, clearing the donor, Close/reopen and Forge/Cancel. Cancel must
   retain the donor and all costs. Confirming Forge replaces the exact donor in
   its bag, retains both rolls and consumes the listed materials, gold and
   225 minutes from each of the four personal cores. Resize the client and
   verify that text and controls remain reachable.
5. Equip the result and test normal attacks outside PZ. For a separate effect
   test, use `/legendaryadmin grant stonewake`, equip it, then run
   `/legendaryadmin reset` and `/legendaryadmin force` before a successful paid
   attack. Watch `/legendaryadmin status` and the equipped item's feedback.
   Swapping weapons must retain the shared cooldown.

To test natural acquisition, use a separate Ascended character before running
`prepare` or `unlock`. Speak to Bolgrim with `hi` and `forgotten works`, retrieve
the personal mould from an eligible authored dwarven world spawn, return it,
use a recipe page and follow the tempering dialogue. The admin preparation
commands skip this quest flow; no command resets the quest to stage 0.

## Verification and release

Fresh release evidence is in `out/chase-dev-release-20261011/`:

- `coordinated-deployment-result.json` and `post-runtime-final.json` verify the
  published DEV10095 updater manifest/API, matching client resources, rebuilt
  Windows server and enforced `CS1:14287d12`. The final runtime check observed
  448 seconds of uptime with no new startup errors or crash dumps. PROD remained
  1006. These checks did not log in or exercise gameplay on live DEV.
- `server/native-verification.json` records 14 passing native client gates in
  owned loopback runtimes, including the old 10094 rejection, 38 item/combat
  fix assertions, enabled/disabled combat baselines, delayed effects, lifecycle
  and all six passive trees. Connected Legendary checks covered seven inventory
  transaction cases, all ten paid signatures, four primary PvP cases, the actual
  production forge and inherited rolls, quote replay, shared cooldown and ward
  behavior, plus Bolgrim's ordinary-character quest path. Failed harness attempts
  and their corrected reruns remain recorded; production rules were unchanged.
  Original databases/configs and dedicated probe-profile bytes were preserved,
  and owned processes were stopped.
- `client/final-client-evidence.json` records the corrected client build,
  159 source/package equality checks and 16 actual-catalog compatibility
  assertions. Native rendering produced 17 screenshots at 1280×800 and 800×640,
  using supplied rendering snapshots. The real DEV HTTP updater then downloaded
  and promoted the new EXE, restarted from 10094 to 10095 and verified the actual
  DAT guard and loaded UI modules. This updater test covered unauthenticated
  startup, not live gameplay. Its ordinary and LocalItemTest profiles, and the
  render probe profile, were restored with file bytes and recursive permissions
  verified; the immutable release install was unchanged.

Still unmeasured: natural proc/drop/page frequency, full material/core farming,
ordinary chase duration, long sessions, spawn competition and secondary-player
PvP/secure-mode combinations. The five-fix NPC test did not establish private
callbacks or the full 300-second lifetime; Bolgrim dialogue was tested separately.
The unchanged Stonebond gate was not rerun by the shared-ward fixture. Local
native gameplay results and rendering snapshots do not establish live DEV
gameplay or final balance.

The first 2026-10-11 client build unexpectedly ran the legacy native checksum
generator and wrote the ordinary profile's derived `checksum_expected.txt`.
Metadata showed no other profile writes. Its original bytes were unavailable,
so the resulting file was preserved rather than replaced with a guessed copy.
`client/profile-reconciliation.json` records this incident. The legacy generator
is now disabled by default; the corrected build preserved the reconciled profile.
Later rendering/updater probes restored their captured profiles as described
above. This does not claim restoration of the checksum file's pre-build bytes.

### Historical local evidence, 2026-10-10

Original implementation evidence is collected in `out/legendary-assets-20261010/`.
Review fixes and connected retests are in `out/legendary-fixes-20261010/`, with
isolated UI evidence in `out/legendary-review-20261010/client-fixes/`. Server
fixtures under `tools/legendary-fixture/` and the named native QA scripts belong
only in an owned loopback runtime. Never copy them into DEV/PROD data.

The change requires a recompiled server, matching DAT/SPR/OTB/XML, final encrypted
client resources and freshly exported login checksums. The following local
package 10094 and `CS1:5e69735b` results are historical evidence, superseded by
the original DEV10095 publication. Preserve checksum enforcement.

Historically verified locally on 2026-10-10:

- Final client and server builds, 19-item binary import with old records and
  pixels preserved, encrypted archive SHA256
  `28a15f187d719174a6438e0cfae6443e52614afdbc3a72ec004dbfa04e76f868`
  and login checksum `CS1:5e69735b`.
- 28 actual-Lua forge/rarity/reforge/loot/context contracts, nine activity
  contracts, five fixture-cleanup contracts, exact 69-origin availability,
  and the six existing Corrupted startup lifetime regressions.
- Original five native gates: module guard, lifecycle, ordinary combat with
  passives enabled/disabled and six-tree allocation/weapon contracts.
- After these fixes, ordinary combat was rerun with passives enabled and
  disabled (both exit 0): exact native damage/healing/area, full mana shield,
  existing condition coexistence/cures, live/cancelled Lua scheduler callbacks,
  right-hand Head Splitter payment/recast rejection and Light Healing payment.
  The first disabled attempt inherited depleted HP from the enabled run and
  died; its failed log is retained. The passing disabled rerun restored the
  same fixture start state first. No production rule was changed for that test.
- Seven connected native transaction cases: full/nested bags with final net
  capacity, exact partial stacks, capacity failure, changed costs, exact coin
  change, no change room and nested holding-bag rounding. All failures retain
  exact inputs; nothing is delivered to the ground.
- All ten paid signatures and the final bolt. Character group 5 with a normal
  account is allowed; group 4 and ordinary characters are refused. Evidence is
  `attempt4/controller.log`; a later unrelated fixture assertion failed, so its
  whole-run marker is not used as evidence of completion.
- Completed connected follow-up (`attempt7/`, both clients exit 0): ordinary
  source entering PZ and revoked combat permission cause zero delayed damage;
  explicit IgnoreProtectionZone remains allowed. Living Bark preserves its
  budget against DoT/full mana shield, resolves partial shields before ward,
  consumes tiny-hit charges and expires correctly. Four primary PvP/mana-shield
  cases and secondary crit/leech suppression pass.
- Real shared-party Aegis/Living Bark regression (`ward2/`, both clients exit
  0): paid Heal Friend and Stonewake attacks grant 12+3 and 3+12 in both orders,
  respecting the recipient's 15-HP shared ceiling. Actual character stats
  include both sources. Incoming 20 damage loses 5 HP, and stopping the Aegis
  caster removes only its ward; Living Bark keeps its native 6-per-hit limit.
- Actual production forge dialog/confirmation, server-native output stats,
  exact family material/gold/four-core consumption, two unchanged inherited
  enchantment rolls, manual equip and replay rejection. Logout and genuine
  native death retain the shared cooldown and clear active charges.
- Native UI response-order, Refresh, Close, pending results and rejected-quote
  rendering checks at 1280×800 and 800×640. Real connected inventory feedback
  and input checks pass at both sizes. The actual server preview image is in
  `out/legendary-fixes-20261010/screenshots/`.
- Ordinary-character Bolgrim quest path (`quest4/`, both clients exit 0):
  unascended refusal, ascended acceptance, foreign mould refusal, genuine paid
  kill of an authored world Dwarf Guard, personal mould collection/return,
  actual native page Use unlocking exactly four dwarven recipes and tempering
  dialogue. Ascension and the page are explicit test setup; page drop frequency
  and the complete material/core hunt are not established by this test.

An existing startup queue used deleted Monster userdata; its narrow repair is
included and the previously crashing native gate now passes. Test-only healing
headroom and post-forge arena positioning were corrected without changing
signature rules. Review test repairs were restricted to QA harness assumptions:
virtual-item ownership, guaranteed hit on the one-final-bolt case, arena/role
restoration, real NPC channel/dialogue delays, seeded page placement and the
real passive-client hello acknowledgement. They do not bypass ordinary weapon
payment, native damage, NPC handling or world-spawn provenance during evidence
collection. Owned clients/server/database are stopped, the temporary runtime
config is restored byte-for-byte, and QA roles, gear, storage and passive ledgers
are restored. Quest/ward/baseline numeric progression is restored from the
pre-quest snapshot; earlier combat-test skill gains remain in the disposable QA
characters. See `final-restoration.log` and `progression-restored.log` under the
fix evidence directory. Ordinary client profiles were not opened or moved by
these review retests.

Not measured: ordinary total farm time, natural signature frequency,
secondary-player PvP selection and long-term competition for the authored
spawns. The short quest test does not establish natural recipe-page frequency
or human enjoyment. Acquisition costs and signature feel still need ordinary
hunt telemetry before final launch tuning.

The initial build wrapper's ordinary-profile guard aborted before launching a
native client because its backup did not match the expected fingerprint. The
current profile and differing backup were both preserved without overwriting
either; automatic restoration of the expected original was not verified.
Subsequent encryption skipped the ordinary-profile launcher and native tests
used dedicated LocalPassives profiles. The metadata-only reconciliation is in
`out/legendary-assets-20261010/profiles-63f78040efbf45378af6163fd9e1b5a7/profile-reconciliation.json`.

## Original critical follow-up review, 2026-10-10

Two independent critics reviewed combat/economy and UI/quest UX. This initial
read-only review described the pre-fix implementation:
a new native test confirmed a delayed Ground Ember protection-zone bypass.
An ordinary group-1 subject triggered a real paid Ashcleaver attack, then entered
an actual map PZ before the two pulses; the outside monster still lost 14 HP.
Only the activation lottery was forced by the isolated admin fixture. Source
combat permission/zone must be checked again when delayed damage executes.
Evidence: `out/legendary-review-20261010/pz-controller.log` and `pz-peer.log`.
The initial boundary search failed because the test required too many clear
tiles; the revised bounded fixture found a real PZ edge. Both final clients exited
0, owned entities were cleaned, fixture roles/gear/storage restored, and the
local server/database stopped. No ordinary profile was moved or accessed.

Other findings requiring correction or a design decision:

- Craft preview omits output stats, handedness/ammo and level requirements;
  the client also ignores the transmitted shared-signature rule. The empty
  donor target has no visible frame or permanent Epic requirement label.
- A pending Forgotten preview received after Close recreates and focuses the
  forge on Smelting. Reproduced in the native offline rendering probe.
- Refresh clears the donor, and a successful craft's transient message is
  replaced by the next automatic donor-less preview.
- Quotes do not preflight output room/capacity. The result is inserted before
  costs are removed, rejecting some crafts whose final inventory would fit.
  Actual-Lua/stub-native reproduction confirms safe refusal, not item loss.
- Eleven eligible kills spaced 121 seconds apart earn zero personal activity
  over 20m10s. The rule, party splitting and stamina exclusion are not explained
  in the UI. Native respawn scheduling can compound this ordinary-hunt risk.
- A quest-locked shared-XP helper counts in the activity denominator but earns
  no core: a 60-second gap credits the unlocked hunter 30 seconds and helper 0.
  This needs an explicit anti-boosting/party design decision, not an assumed fix.
- All recipes use the same eight lava spawn positions. Authored timers and
  fixed RNG yield an optimistic expected 13.89 global world-hours of lava
  materials per craft; ten crafts need about 139 such hours before additional
  native spawn delays, fighting and travel. This is source-based capacity,
  not observed player farm time. Launch population/competition needs testing.
- Stonewake and Ashen Requiem have particularly small signature budgets and
  may not feel worthy of the chase. Compare ordinary hunts and visible feedback
  before increasing numbers; forced zero-armor budget tests do not prove balance.

The real seven-material/gold UI was rendered and inspected at 800x640 and
1280x800; it fits and scrolls, with no confirmed clipping. Full ordinary-player
quest completion, natural farm/proc rates, secondary-player PvP and partial mana
shields remain unmeasured. Detailed UI evidence is in
`out/legendary-review-20261010/ux-quest-critic.md`; combat/economy reproductions
and source-bound calculations are in `out/legendary-critic-20261010/`.
