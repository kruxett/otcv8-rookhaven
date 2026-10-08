# Passive statistics in Cyclopedia

The approved presentation combines the current combat statistics with a compact
overview of applied talents. The retro layout, talent balance and allocation
rules remain unchanged.

## Player navigation

Open Cyclopedia → Character → General Stats → Combat Stats. The current view
groups values into Offence, Defence and Recovery. Selecting a row explains its
sources and the conditions that apply. Totals come from the server's native
character statistics; the client does not reconstruct combat formulas.

Detailed stats opens the existing equipment, resistance, blessing, concoction
and damage-estimate view. Current stats returns to the new view. The existing
view also remains the fallback when an older server does not supply the new
presentation. The client-version 1410+ equipment pages retain their existing
behavior.

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
refreshes; source selection also survives closing and reopening Cyclopedia in
the same game session. They reset on logout.

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
