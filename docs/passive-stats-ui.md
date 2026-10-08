# Passive statistics in Cyclopedia

Combat Stats keeps the original compact two-column retro layout and adds relevant
passive totals. Talent balance and allocation rules remain unchanged.

## Player navigation

Open Cyclopedia → Character → General Stats → Combat Stats. The original
equipment values, elemental icons, resistance list and damage estimates appear
directly. Relevant passive totals use the same 20-pixel rows. Recovery follows
offensive values; actual armor, defense and an active ward sit in the right column.
Both columns share one scroll area when needed. Unlearned zero bonuses are omitted;
learned bonuses remain visible when their weapon requirement disables them.

Hover a sourced value for its practical effect or click its row or small information
button to open a separate closable Stat sources window with components and conditions. Maximum-health sources
are available on Character Stats alongside the existing current/maximum health
row. Source details take no space in the default combat view. Current totals come
from the native server snapshot; estimates retain their explicit labels and
tooltips. Element Attack is an attack amount, not a percentage.

The character portrait shows level, chosen class and a separate
`Ascension: Ascended` line. The progression name comes from `character.identity`,
and is also retained in the character profile. An ascended character with no class
shows Class not chosen; the client never infers progression from a class or role.
Older servers keep the existing combat values without inventing source amounts.
The client-version 1410+ equipment pages retain their existing behavior.

Passive Talents groups applied ranks into Stat bonuses, Conditional effects and
Special effects. The class, required weapon and applied points appear above the
list. A mixed talent can have two entries: Steady Nerves, for example, separates
its received-healing bonus from its protection below the health threshold.
Unselected talents do not fill this overview. The full tree still contains the
available choices. No Apply preview was added.

## Source and transport contract

`Passives::characterStats()` retains the existing fields and adds read-only
native source components, rank baselines, condition rates and readiness facts.
It does not prune wards, advance combat state, apply talents or change resources.
`data/lib/passives/presentation.lua` turns that snapshot and the existing catalog
into version 1 presentation rows. Equipment critical probability and the
subsequent passive roll are shown separately; their probabilities are not added.
Maximum health separates base health, actually applied talents and other effects.
Finite healing budgets are not presented as continuous regeneration.

Successful `character.passives` responses larger than 8192 bytes are split into
`cp|1|chunk|id|index|total|segment` messages. Segments are at most 7900 bytes, with
a maximum of eight parts, 32768 assembled bytes and a fixed ten-second deadline.
The receiver accepts only the current connection, ordered matching parts and the
expected response action. It clears incomplete transfers on connection changes,
logout and termination. Small replies and the existing 18-field legacy CSV stay
unchanged. This avoids the native server's 8192-byte string limit without
changing the general packet parser.

Rows are reconciled by stable widget IDs. Source selection and scrolling survive
refreshes. Combat source windows close when switching away from stats; explicitly
closed windows stay closed. Source selection survives closing and reopening
Cyclopedia in the same game session. Session state resets on logout.

## Verification for DEV10088

The final local native regression run passed all five existing groups:
normal-client guard, lifecycle, baseline passives enabled, baseline disabled and
the six-tree contract. It covers native combat/healing/conditions, HP composition,
save/reconnect/death, ordinary spells/payment/cooldowns, allocation, weapons and
the existing eighteen presets. Evidence:
`out/passive-stats-ui-20261008/regressions-final.log`.

The rendered presentation test passed with actual native UI widgets at 1280×800
and 800×600. It checked source selection, refresh, legacy navigation, fractional
rates, shaped critical probability, mixed Steady Nerves entries, incompatible
weapons and old-server fallback. Only disposable QA copies lower the minimum
window size; the product retains its 800×640 minimum. Evidence:
`out/passive-stats-ui-20261008/presentation-fifth.log`.

The ordinary native suite passed for all six saved class characters, comparing
actual server replies and native character values with the displayed widgets,
source clicks, refresh and reopen at both sizes. Reaver's allocated reply used
the new chunk transport; the other five ordinary characters had no applied ranks.
Evidence: `out/passive-stats-ui-20261008/native-all-six-final.log` and
`out/cyclopedia-passives-native-suite/`.

The separate allocated suite passed using the owned loopback admin fixture:
six classes at both sizes, 16 applied points per class, 108 talent-row selections
and 89 actual chunked reports. It verified visible selected rows and stable source
selection and scrolling after actual network refresh, then stopped the overlay,
logged out and exited with code 0. Evidence:
`out/cyclopedia-passives-allocated-20261008-100721/result.json` and `native.log`.
It does not reset ordinary test characters or live players. Prepared combat procs
were not activated in this UI suite; their native behavior is covered by the
existing regression presets, while mixed Steady presentation is checked in the
rendered fixture test.

Twenty source-extracted receiver checks and eleven actual sender checks passed,
including malformed/interleaved parts, bounds, timeout, UTF-8, pipes and the real
10902-byte Reaver reply. These are isolated transport tests, in addition to the
actual native login and presentation suites.

The normal Release DEV10088 package passed source-to-encrypted-archive equality,
including Cyclopedia, passive resources and the ordinary inventory module. All
133 monitored checksum rows, the critical eight and their order are unchanged.
The checksum preview uses a local fixture server executable only to calculate
the resource contract; it is not the published server artifact.

No new tuning or gameplay behavior is claimed by this presentation change.
Screenshots and compilation alone are not counted as runtime regression checks.

## DEV deployment and publication

Server commit `8e5936a261b591d0288ccbc944e6a67c3e6c9e34` was deployed with
the reviewed controlled native-build helper. The old process exited with code 0,
MSBuild succeeded, and the existing supervisor started the new server. Independent
readback verified process 4932, parent 4708, login/game ports 7173/7174 and the
new executable SHA256
`69ea9cfe8539aeaa8f16a727bd789158b8f3aa5f84965acd34d4e00eb94a3373`.
The exact three reviewed server files were the complete source diff. Config,
controls, DLL membership and previous dump files were preserved; no new dump or
pending maintenance request remained.

The authoritative release export uses that actual guest-built executable.
Client implementation commit: `29d299b8d4aa56f35c97c5b7ed12ecad70ccd4c4`.
Normal client executable SHA256:
`cb4fcbdd104ef92562e9880e9e8be3f1e426d7526946e0f55d933b4b5b9cc8c2`.
Encrypted data.zip SHA256:
`a495ef67c9c9bb5745028c6c0a647694bd1456d5a9453c74db2b9ba7475c0745`.
The release verifies equality for 141 resources and includes the new server
presentation file in its reviewed source export. Private root configuration and
local test fixtures are excluded.

DEV10088 was published and independently read back through the public updater.
Version 10087 receives the exact new hashes, while 10088 reports up to date.
The separate PROD endpoint still reports its unchanged version 1006 and hashes.
Evidence is under `out/passive-stats-ui-20261008/`: the actual guest deployment
receipt, `postdeploy-readonly.json`, `publish-actual.json`,
`postpublish-readonly.json` and `public-updater-readback.json`.

The real updater then passed from an isolated complete DEV10087 installation:
actual DEV HTTP download, archive replacement, binary promotion, original exit 0
and automatic restart into a real no-arguments DEV10088 child. The child retained
the correct executable/archive identity for the eight-second stability check.
Both normal and LocalItemTest profiles were restored with their original bytes
and recursive access rules; original installs were preserved. This verifies the
normal updater using an owned copy, rather than changing a separate user install.
Evidence:
`out/passive-stats-ui-20261008/native-updater-6d1dcddfe3b140599d31c861ec46b473/result.json`.

The released normal DEV10088 client passed two ordinary live logins on the
separate Dev Login Qa hecafa character, previously mapped to GUID48. Each cycle
checked the real updater, server hello/catalog, actual class in self-look and
Cyclopedia, separate Ascended identity, a quiet login with manual tree opening,
ordinary-player rejection of admin commands, current A/B rows and sources,
legacy details, network refresh and close/reopen. The actual product viewports
were 1280×800 and its 800×640 minimum. Both logins ended with a safe logout and
native exit code 0. Sixteen actual framebuffer captures were retained.

Class, ranks, points/respec values, ordered inventory slots, position, level,
experience and maximum resources matched the observed baseline. Current health
1288 and mana 760 also stayed unchanged in both cycles. Both private profiles
were restored with byte and recursive-access-rule verification, and original
10087/10088 installs remained intact. Evidence:
`out/passive-stats-ui-20261008/live-stats10088-e9ef0f53/result.json` and
`cyclopedia-stdout.log`.

This live character has no applied talents or class weapon, so its 3226-byte
response exercises the raw transport and inactive/empty views. Applied builds,
long chunked replies and all six classes are verified by the separate local
native suites. No live allocation, respec, class change or combat was performed.
The client has no bank-balance binding, and its protocol does not expose database
GUIDs; neither a live bank measurement nor a direct GUID/SQL-state proof is
claimed. The live character was selected by its previously verified exact name.

## Original layout extension — DEV10089

Three independent history, information and retro-design reviews compared
`29d299b8` with parent `d9c6f6ddc5bb33636d5825414acf77d4c8663b8e`. The user
selected Originalet utbyggt: restore the compact two columns, separator and
elemental icons; extend the same rows with relevant passive totals and optional
sources. CurrentOverview and its navigation buttons are removed. The native
statistics, passive effects and transport remain unchanged.

Actual checks for this increment:

- Fresh-source native UI: six class/progression headers, unchosen class, separate
  Ascension, legacy critical/DPS/reduction values, elemental attack units,
  fractional regeneration, HP sources on Character Stats, source close/page
  changes, refresh selection, learned inactive effects and older-server fallback.
  Actual viewports1280×800/800×600.
- Six ordinary saved local classes: actual identity/self/other look, native source
  composition, ranks, critical semantics, CSV fields, bank/read-only invariants,
  source refresh and reopen.
- Six allocated local overlays in both sizes:12 cases,108 talent-detail clicks,
  90 chunked reports and24 captures. Row visibility and refresh/scroll stability
  passed. Stop restored baseHP735; logout cleared the overlay; config unchanged.
- Unchanged Cyclopedia transport contract:20 checks, including connection,
  ordering, budgets and lifecycle cleanup.
- Final normal DEV package: source equality for141 resources, unchanged native
  critical-eight checksum `CS1:d08bec84`, and a connected ordinary Reaver probe
  using the exact final executable/archive pair.
- Actual HTTP updater10088→10089: archive replacement, original exit0, native
  restart into10089 and eight-second stable identity. Existing executable/DLLs
  reused. Both profiles and original installations restored.
- Published10089: two ordinary live logins on Dev Login Qa hecafa, previously
  mapped toGUID48. Quiet login/manual tree, admin rejection, default Combat Stats,
  separate Ascension, actual HP/stat sources, refresh/reopen, Passive Talents and
  viewports1280×800/800×640 passed. Inventory, position, ranks, points/respec,
  level, XP and maximum resources stayed unchanged. Health1288 and mana760
  matched both initial readings. Safe logout/native exit0;16 captures retained.
  Private profiles restored with byte and recursive-DACL verification.

The initial updater probe stopped before native startup because its backup
fingerprint differed. Both trees were preserved. Reconciliation identified one
missing session minimap file; recovering its exact preserved bytes restored
**both initial profile fingerprints exactly**. A move diagnostic preserved all29
entries. A fresh updater run and subsequent live test passed full restoration.
This was a failed harness/profile attempt, not a passed product test. The cause
of that initial file movement remains unmeasured.

DEV10089 data.zip SHA256:
`4ec35e95dfaad5d15c3c1bf2d828592ffb271fe34d4959124ba87b484e2271d6`.
The executable remains verified10088
`cb4fcbdd104ef92562e9880e9e8be3f1e426d7526946e0f55d933b4b5b9cc8c2`.
Publication retained serverHEAD`7b70fcf45f3e810b079002e6c640eb0de1e37545`,
runtimePID5560, config/checksums, supervisor and updater identities. PROD1006
metadata, public API hashes and full release tree stayed unchanged. No server
restart, native deployment, database change or live allocation occurred.

Evidence under `out/stats-ui-review-20261008/`: `package10089-final.log`,
`publish10089-actual.json`, `public10089-readback.json`, `native-retro.log`,
`allocated-retro.log`, `transport-retro.log`, `final-package-native-reaver.log`,
`native-updater-aa3b3d19434e46bbb66b0bf22112cfe6/result.json`,
`native-updater-236c65a5d73945dfbc77ef0d5d360cb0/root-recovery-final.json`,
and `live-stats10089/result.json` / `cyclopedia-stdout.log`.

Limits: live QA has no applied talents or class weapon. Filled trees, all six
classes and long responses were tested locally. Combat, death, spell payment
and store behavior were not rerun for this UI-only increment; their gameplay
implementations are unchanged. No new balance claim, direct live bank reading
or database-GUID measurement is made.

## Attainable-stat and clarity follow-up (local validation)

The default retro layout is retained. Stats describe present equipment, learned
talents or active effects; unrelated unlearned zero bonuses are omitted. Learned
bonuses disabled by the class weapon remain visible at zero with the activation
warning. Food regeneration paused in a protection zone remains inspectable.
Finite Renewal healing has its own `Healing Remaining` HP total, rather than a
zero continuous-regeneration row. Hover explains the practical effect first;
the optional source window puts that explanation before the calculations.

Source acquisition was traced through the existing class-choice/catalog and
starter-spell paths, food's `player:feed`, and ordinary equipment/rarity paths.
For example Troll loot includes helmet2461 and shield2512; Blind Orc sells axe2388
and armor2467. The active map spawn XML includes Troll and Blind Orc. Supported
equipment slots have enabled rarity pools for elemental damage, critical chance,
critical extra damage, HP/skills and selected resistances; ordinary corpse loot
calls `rollRarity`. This establishes working acquisition paths for these stat
families, not ordinary availability of every item in `items.xml`. Unrolled or
unavailable affixes are not listed as empty future bonuses. The available talent choices stay in the
tree, not the character's applied-stat summary.

The ordinary content has no variable attack interval: all active vocations use
2000ms, with no item/rarity/talent source for another interval. Its fixed row is
hidden, while the actual interval remains in the estimated-DPS explanation.
Empty elemental attack, absent critical/talent protection and zero resistances
are hidden. The duplicated critical-extra row, 100-damage armor-percent reference,
combined theoretical reduction rows and unavailable modern Forge stats are
omitted. Damage ceilings, average-hit and DPS estimates remain explicitly marked
as estimates affected by real weapon/skill/level/stance/bonus values.

Two existing response errors were corrected. Static ItemType values missed
rolled weapon/element attributes. Flat armor reduction was also mislabeled as
physical resistance, and native ability lookup used combat bit flags as array
indices. Read-only native fields now use the actual equipped weapon and the same
enabled equipment/absorption indices as `Player::blockHit`. Native absorptions
multiply; rarity resistance uses the actual health-change slots and parser,
with its own50% cap. The displayed combination excludes flat armor and talent
protection and preserves vulnerabilities and fractional percentages. Per-hit
rounding and the attack's defense/armor/resistance checks still matter.

The five existing regression gates passed on the rebuilt native server. The
actual response-builder contract passed15 cases, including rolled attributes,
stacking, ignored backpack/ammo rarity, vulnerabilities, no armor-derived percent,
CSV positions and finite healing. An actual native100-damage probe with2/5/3%
equipment absorption and20% rarity resistance delivered72 damage; the continuous
combined percentage is27.7544%. Original QA equipment, native stats and HP were
restored. This deliberately uses test equipment, not an acquisition playtest.
Native UI checks passed1280x800 and800x600, including zero-row removal, preserved
learned/paused bonuses, unsupported Forge rejection, source refresh, fractional
values, finite-healing expiration, class/Ascension and old-server fallback.
The six ordinary saved classes and all six filled16-point test trees passed in
both sizes. Sources, refresh and reopen survived; the allocated suite also
checked108 talent-detail selections and Stop/logout cleanup.

The first connected run caught a CSV regression: omitting the entire resistance
field shifted later fields in the existing splitter. A genuine physical-zero
transport placeholder now preserves all18 positions and stays hidden in the UI.
A stale test assumption that every class has a visible weapon-ATK row was also
updated for empty/wand equipment; the compact damage rows remain20 pixels high.

Evidence: `out/stats-ui-review-20261008/attainable-server-build.log`,
`attainable-regressions.log`, `attainable-equipment-contract-final.log`,
`attainable-equipment-native-final.log`, `attainable-presentation-verified.log`,
`attainable-six-classes-verified.log`, and `attainable-allocated.log`.
The Qwen supplied-text job exhausted its60-second budget without a deliverable;
the audit and implementation were completed here. At this local checkpoint,
DEV10089/PROD were unchanged. The native metadata requires server recompilation;
the subsequent DEV deployment and updater checks are recorded below. Ordinary
hunts and all item acquisition routes remain outside this targeted verification.

## DEV10090 publication and live verification

Published on2026-10-08 after compiling server commit
`463c7efeb31892ba471cfc6dcd8d1d00e19f4c8a` on OMBSRV020. The existing supervisor
performed the orderly shutdown/restart; MSBuild exited0 with independent
success/error checks. The fresh runtime PID6980 owns7173/7174. Its EXE SHA256 is
`84dbe65d190e45fa60a01a0ab7e167727266fdd293bbe9058e78eeeeb4d09135`.
Configuration, control scripts, DLLs, updater process and PROD1006 release tree
were preserved; no new crash dumps appeared. The equipment fixture is present
only as a Git test source and is not registered on live DEV.

Client commit `0431305` provides DEV10090. The package verified141 source/resource
equalities,117 passive resources and the eight critical files (`CS1:d08bec84`).
It retains the verified10089 native client and dependencies. Published data.zip
SHA256: `23baf34dcf06e59657d86d70fd23a52b027989b29d2e6c03bf0f8bd66685352e`.
The genuine native updater downloaded10090 from the public DEV endpoint,
restarted into the ordinary retro client, and passed its stable-child checks.

Two ordinary live DEV logins of `Dev Login Qa hecafa` passed the actual protocol,
equipped CSV/native values, enabled-equipment metadata, practical source details,
irrelevant-row removal, refresh/reopen and1280x800/800x640 layout checks.
Class and `Ascension: Ascended` appeared separately. Login stayed quiet, manual
tree opening worked, talent descriptions were current, and ordinary admin access
was denied. This QA character has zero allocated ranks and no class weapon;
the six filled trees and combat assertions remain the local evidence above.
No live class, allocation, equipment, movement or combat changes were made.
Both profiles were restored, including recursive DACL verification for live QA.

The first live probe failed an added test assertion: unarmed native snapshots
omit weapon fields, while the CSV carries zero. The established local contract
already uses zero for that absent value. Only the task-local probe was corrected;
its failed receipt was retained and both logins passed in a fresh stage.

Evidence under `out/stats-dev10090-20261008/`: `server-preflight.json`,
`server-deploy-stdout.txt`, `server-postdeploy.json`, `publish-preflight.json`,
`publish-actual.json`, `server-final.json`,
`native-updater-7c74e6095bac4a42a7e5f6db70a4f279/result.json`,
and `live-stats10090-retry1/result.json` / `cyclopedia-stdout.log` /16 captures.
