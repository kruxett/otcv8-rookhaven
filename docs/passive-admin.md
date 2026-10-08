# DEV passive QA commands

The startup flag `passiveAdminEnabled` defaults to `false`. Enable it explicitly
only in DEV's server config and restart/recompile for the native addition.
Keep `passiveTestEnabled = false` on DEV: the existing loopback overlays and
runtime-only test fixtures are separate. PROD retains the default-off admin flag.

The issuer's character must have group access and the standard Admin group5
(Community Manager) or God group6. These character roles do not require a higher
account type, matching the character-group checks in `/i`, `/addskill`, `/up`,
`/down` and `/tp`. Custom groups above6 retain their previous account-type>=5
requirement, including the isolated loopback QA fixture. Players, tutors and GM4
are rejected. Lua delegates permission to the native API, which repeats these
checks for every status/write; opcode103 exposes no admin API.
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

## Character-role regression, October 8

The former Lua and native checks required account type>=5 even for the standard
God character group6. The original native build reproduced the refusal on group6
with account type1 (`out/passives-admin-tests/20261008-192343/02-exercise.log`).
Self-look says God using the character group, so that extra account requirement
could disagree with both self-look and the existing character-based commands.

Server fix `7b70fcf45f3e810b079002e6c640eb0de1e37545` removes that extra
requirement for the standard character groups5/6. The enabled-DEV, connected
actor, target, combat, current quote and transaction checks stay intact. The
isolated local overlay administrator is a separate API and is unchanged.

All nine native admin audit cases passed on the corrected build:
`out/passives-admin-tests/20261008-193133/` and
`out/passive-admin-god-20261008/after-fix-final.log`. The thirteen-role matrix
includes Admin5/account1 and God6/account1, while players/tutors/GM4 on account6
and custom7/account1 stay denied, including reuse of a formerly valid quote.
The low-account role phases invoke the actual Lua command handler for help/status
and verify their real network replies and unchanged resources/durable state.
The registered talkaction path is checked separately by sending
`/passiveadmin status` from the real client. Native writes, all six class switches,
point bounds, paid respec preservation, combat/death denial, reconnect and actual
database rollback also passed. The owned runtime was restored to admin-disabled
and its GUID9001 ledger cleaned afterward. Live user characters and account roles
were not used or changed by these tests.

The same server commit was deployed to DEV on October 8 at 17:40 UTC. The
previous runtime exited cleanly with code0; the fresh native build succeeded.
Independent readback verified the new runtime PID5560 under the existing
supervisor4708, owning both7173/7174, with native SHA256
`2e14f625148ebf1b8d78a8eeba61d099ab2bd0c8a3c93b6b6c407ab400736804`.
Source pins, config, groups, DLLs, prior dumps, updater processes and published
DEV10088/PROD1006 releases matched the captured baseline. No deploy requests or
new dumps remained. Evidence is in
`out/passive-admin-access-20261008/actual-deployment-result.json`,
`actual-postruntime.json`, and `root-independent-runtime.json` in that directory.
Kruxet's command was not run through the live user session; the command behavior
was verified with the real local native build and low-account Admin/God roles.
