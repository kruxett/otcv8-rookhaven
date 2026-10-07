# DEV passive QA commands

The startup flag `passiveAdminEnabled` defaults to `false`. Enable it explicitly
only in DEV's server config and restart/recompile for the native addition.
Keep `passiveTestEnabled = false` on DEV: the existing loopback overlays and
runtime-only test fixtures are separate. PROD retains the default-off admin flag.

The issuer must have group access, group ID >=5, and account type >=5
(Community Manager/Admin or God6). Players, tutors and GM4 are rejected. The
native API repeats these checks for every write; opcode103 exposes no admin API.
Targets must be online, alive and out of combat, including queued effects.

| Command | Result |
| --- | --- |
| `/passiveadmin help` | Usage and six class IDs |
| `/passiveadmin status PlayerName` | Current stage/class/points/ordinary respec quote |
| `/passiveadmin ascension 2, PlayerName` | Prepare the ordinary third-Ascension dialogue |
| `/passiveadmin ascension 3, PlayerName` | Prepare legacy class selection without a chosen class |
| `/passiveadmin class reaver, PlayerName` | Choose/switch the third-stage QA class; clear talent ranks |
| `/passiveadmin respec, PlayerName` | Clear ranks freely; retain normal paid respec count/price |
| `/passiveadmin points 16, PlayerName` | Set a validated QA budget0..24; reject budgets below saved ranks |

Omit the target to use yourself. Classes are `reaver`, `blademaster`,
`earthshaker`, `marksman`, `arcanist`, `lifekeeper`. Stage values0..3 set the
appropriate Oracle and The Ascent prerequisites. These preparation commands
preserve level, XP, mastery/progress, current/base resources, possessions and
bank; they do not perform an ordinary story Ascension. Choosing an ordinary
third Ascension afterward still performs its normal reset/depot/reconnect flow.

`ascension` deliberately clears the chosen-class ledger and its old respec
counter so The Nameless can offer a fresh choice. `class` switches preserve the
existing respec counter/price and bank, replace only the twelve new starter
entitlements, and keep learned legacy spells. Both clear the QA point override.

`points` stores a DEV-only QA override in reserved storage70175, so a low budget
stays low after reconnect even on a high-level test character. Admin respec
keeps this override. A server with the admin flag disabled ignores the storage
override and resumes ordinary milestone increases. It does not revoke a higher
point budget already saved in the earned-points ledger or remove saved ranks;
use `class`, `ascension` or a validated `points` command to clean up QA state.
Normal players still cannot remove saved ranks
without their normal Respec confirmation/payment; class choice remains permanent.

Each write verifies a current target/session quote and locks the durable ledger.
Vocation/storage/ledger/new-starter writes share one transaction. Runtime changes
follow a successful commit; no full-player save overwrites unrelated live state.

The owned local audit is `tools/run-passives-admin-tests.ps1`. It opts into admin
QA only for that suite, checks default-off and native roles, each class, exact
point bounds, stale/combat/death gates, real DB rollback and reconnect, verifies
both low and high saved budgets when the flag is disabled, cleans GUID9001's
chosen ledger, and restores the default-off runtime. Source game data never
register the runtime-only audit fixture.
