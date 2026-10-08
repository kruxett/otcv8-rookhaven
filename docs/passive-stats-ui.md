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
