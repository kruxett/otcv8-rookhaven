# DEV10086 passive follow-up and DEV10087 updater

Feature source: `db44422140454ecdd475d0cf71cad7fccf8af7ad`; final fixture
baseline: `2cbaedf6d3e419d0ce206d68bae5540d4d69d4e0`.
DEV10086 was rebuilt and published. The later server-only shutdown fix
`53b7386972a5dff5eca3ea08320b2a5178f0972a` is also rebuilt/deployed on DEV;
the published10086 client bytes remained unchanged by that server fix.
Client commit `b512dc99c031fd9dcfe1d10feb8be83e004fd0b7` then corrected Windows
updater cleanup and was built/published as DEV10087. Both ordinary live DEV
logins and the real10086-to10087 updater path passed on the final artifacts.
The later already-Ascended login choice is a separate server Lua increment;
its source, deployment and live evidence are recorded at the end of this report.

## Product scope

Login and automatic refresh now synchronize catalogs/state without opening the
passive window. Explicit toolbar/command opens still work; class selection may
open the newly chosen tree. Draft/Saved labels explain when Apply activates
bonuses and when saved points require Respec.

The first-time free-removal report could not be reproduced as a saved-rank
bypass. The ordinary native first-choice test rejects both a current-revision
saved decrease and a forged stale revision0 while respecCount is0. Unsaved draft
undo remains free and has no native HP or database effect.

Self/other look show the actual permanent class. Cyclopedia presents Class and
Ascension separately, native combat totals, all applied talent descriptions,
conditional readiness and ward/recovery values. Gear's critical threshold is
converted from its actual shaped roll, then combined with passive critical
probability. Rough DPS remains an estimate before hit chance/target reductions.

The five numerical cuts and all174-node acquisition/formula review are in
[passives-low-and-slow-audit.md](passives-low-and-slow-audit.md). No gear, quest,
spawn, gold, tree topology, rank limit or ordinary point milestone was changed.
[passive-admin.md](passive-admin.md) describes the default-off native Admin/God
commands; ordinary players, tutors and GM4 cannot use them.

## Executed local checks

- Final server, local client and ordinary DEV10086 client builds passed.
- All five existing passive regression gates passed: normal module guard,
  lifecycle, baseline enabled/disabled and all-six-tree contract. Evidence:
  `out/passives-regressions10086.log` and `out/passives-regressions/`.
- Real third Ascension/class dialogue, first Apply/decrease lock, free/paid
  respec, save/relogin, death, store-mode and TCP detach passed:
  `out/passives-first-apply10086.log` and the fresh permanent-main log.
- Native draft/result/pending/scroll/spell feedback passed:
  `out/passives-feedback10086-final.log`.
- Nine native Admin/God cases passed, including role revocation, all stages and
  classes, bounds/stale/combat/death guards, actual SQL failure rollback,
  save/relogin and flag-off behavior:
  `out/passives-admin-tests/20261007-181916/`. The initial fixture's IP throttle
  timing was corrected; the complete fresh suite then passed.
- Connected readonly Cyclopedia packet/parser test passed against actual GUID9003
  Reaver state:16 applied points, maxHP826, bonus46. It verified native formulas,
  self/other look, Ascension separation, rank descriptions, mana and combat data:
  `out/cyclopedia-passives-native-run.log`. It changed no character state.
- Actual normal-roll Monte Carlo/native formula check and native retro layouts at
  1280x800 and800x640 passed. See `out/cyclopedia-passives-presentation/` and
  `out/cyclopedia-passives-presentation-review.log`.
- Actual current catalog validation passed6978 cases,2880 legal prefixes and564
  expected rejections. Balance source/model checks covered72 starter profiles,
  eighteen build witnesses and432 cumulative purchase prefixes.

- Fresh ordinary NPC choices for all six classes passed spell learning/relogin,
  both real casts per class and wrong-class/weapon, no-mana and unlearned gates:
  `out/class-spells-tests/`, fresh2026-10-07 logs.
- Bloodguard, Stonebond and Stoneguard actual native budgets passed:
  `out/passives-guard-balance-tests/20261007-185514/`. Bloodguard's64 real damage
  generated9 ward and absorbed9 of11 incoming damage. Stonebond's105 configured
  maxHP generated1 ward and absorbed1 of3. Natural Stoneguard charges1/2/3
  produced18/21/19 damage from unchanged17/19/16 RNG rolls, then reset charges
  exactly once. The first fixture counted an intervening normal autoattack;
  its baseline now isolates the actual spell entry, with unchanged product code.
- Kill/Concord native fractional checks passed:0.48-HP kill budgets yielded
  [0,0,1], and twelve real baseline rod hits caused45 damage/6 healing. Full HP
  did not bank fractions; wrong weapons cleared them. Evidence:
  `out/passives-balance-pass-20261007/native-balance-evidence.json`.

- Real-party Renewal, Aegis and Concord suite passed all three cases, including
  exact direct/HoT/actual-damage healing, receiver wards, caps and independent
  mana costs: fresh `out/class-spells-synergy-tests/` logs.

- Connected readonly Cyclopedia checks passed for all six ordinary classes,
  including actual Class/Ascension and native packet/parser values. Five subjects
  had empty ranks/maxHP735; post-Concord Lifekeeper had16 applied ranks/maxHP742,
  matching native HP. Evidence: `out/cyclopedia-passives-native-six-classes/`.

Native fixture tools are
registered only in the owned loopback runtime, never in source game data/DEV.

The deployment exposed a passive timer cleanup crash during orderly shutdown
of the old server. Matching EXE/PDB symbolization placed the access violation
in `Passives::releaseDeferredAction`, called by global Lua timer cleanup. Source
lifetime review identified that this cleanup can run after the action map's
destruction. A small storage owner now retires the map
before destroying its entries and late releases check retirement first.

The rebuilt fix passed all five existing gates again, real Earthshaker/Arcanist
delayed casts and weapon cancellation, and actual `stopEvent` reference release.
An ordinary pending-timer shutdown passed native/client ExitCode0 with no new
dump. Evidence: `out/passives-regressions10086-shutdown-fixed.log`,
`out/passives-shutdown10086-fixed.log` and
`out/passives-shutdown-tests/20261007-193444/result.json`.

## Published release and access

Final ordinary DEV10087 client executable:
`out/install/x64-DevRelease10087/RookhavenClient.exe`.
Archive: `out/passives-dev-release10087-final/Rookhaven-DEV10087-client.zip`.
EXE SHA256: `8598ebf96cfd1b6e7fee42ee8319a872e302860e739c5b8e20a5a2bb4c8cdb08`.
Data SHA256: `2ff3a4c90235fe43f177eea9455e62f7746d98d9d9c65a96fd205dbffeef3cb9`.
Client ZIP SHA256: `030d3271c6ce9f7857befd920b69320d2c6fedd2a6e9069c3c35f2939c5bb5e6`.
All133 monitored resources, the native critical-eight order/CS1:d08bec84,
117 passive resources and decoded Cyclopedia/source equality passed. The ordered
resource CRCs are unchanged from10086, so that client publication needed no
additional server deploy. Generated checksum comments name10087 while the
then-deployed source header names10086; their resource rows match. At that
publication, the source archive included the deployed server source/checksum
file. The later Lua increment is recorded below. The immutable export report retains its
prepared-only flags; publication and live execution are attested separately.

The authorized workstation key was added with backup and previous-key
preservation on OMBSRV020. Strict authenticated SSH now succeeds from
192.168.1.253 to192.168.1.44. Passwords, SSH configuration, firewall and service
restart settings were not changed. No private key/QA credentials are in these
artifacts. Reviewed deployment/publication helpers and their receipts live in
`out/dev-access-20261007/`.

The existing DEV supervisor performed both server rebuilds. Publications changed
DEV10085 to10086 and then10087; PROD1006 metadata/files and the existing updater
process4556 were preserved.
Final server EXE SHA256:
`f86204f06e0ac557b305125504b9d729f12e2c02011d5d318cc94558b3924a6c`.
A real subsequent shutdown of that patched DEV binary returned ExitCode0,
created no new dump, preserved config/HEAD/updater files and restarted through
the existing supervisor. Evidence:
`out/dev-access-20261007/dev10086-patched-orderly-restart.log`.
The10086 source ZIP predates the shutdown fix; its separate Git patch and
binary/client binding receipt are in `out/passives-dev10086-shutdown-fix/`.
The10087 source archive includes that fix. That publication's SSH inspection confirmed server
HEAD53b738, the above server binary, process1628, updater4556, no deployment lock,
`passiveTestEnabled=false` and `passiveAdminEnabled=true`. It found no new crash
dump after the patched orderly restart. Evidence:
`out/dev-access-20261007/dev10087-final-state.json` and
`out/dev-access-20261007/publish10087-run.log`.

## Executed live client and updater checks

The first real10085-to10086 updater run downloaded/promoted/restarted correctly,
but failed because its temporary versioned executable remained. This was a
product defect: the Windows deletion helper's explicit application launch failed,
and its ungrouped CMD condition skipped retry delays while the file was locked.
The small10087 correction groups the condition and uses Boost's CMD launch form.
An actual Boost/CMD reproduction verified deletion with unlocked and temporarily
locked files, preserving an unrelated sentinel.

The real10086-to10087 run then passed HTTP download, exact EXE/data identity,
native promotion, old-process ExitCode0, native restart, eight seconds of stable
base-executable identity and deletion of the temporary versioned executable.
Both existing client profiles and the original installed artifacts were restored
unchanged. Evidence: `out/dev-access-20261007/native-updater10087-run.log` and
`out/dev-access-20261007/native-updater-f3aedc5d611e4693ad7b1db8dc282871/result.json`.
The harness's earlier preparation recovery and two Cyclopedia fixture errors
(an unavailable bank API and an incorrect button callback assumption) were
resolved before the successful fresh runs; they did not require gameplay edits.

Two ordinary QA logins passed on10086 and two more passed on the final10087,
using the separate existing `Dev Qa decfffheac` character. The final run used the
actual DEV updater and native login/UI. On both logins the full tree/Cyclopedia
stayed closed, the real toolbar opened the tree, look showed Reaver, ordinary
admin access was denied, and opcode31/parser/native statistics matched:
level80, five of24 points applied, maxHP1335, talent HP bonus0, armor1, defense4,
attack interval2000 and critical chance0. Class Reaver and Ascension Ascended
appeared separately. Saved ranks, class/points/respec quote, items and position
were unchanged; the character logged out safely. No Apply or Respec was issued.
The live client does not expose a bank-balance binding, so bank preservation was
not directly measured in these readonly runs. Bank accounting was exercised in
the local native free/paid/admin respec checks.

Root inspected the final native framebuffer captures of quiet login, character
profile and Passive Talents; the retro1280x800 layout and actual displayed values
matched the assertions. Live evidence and profile/artifact restoration:
`out/dev-access-20261007/live-cyclopedia10087-run.log`. Protected captures remain
in the temporary QA stage and contain no login credentials.

## Limits

These are targeted correctness/integration checks and acquisition/formula
analysis. They do not measure sustainable human hunts, full quest navigation,
all rarity distributions, optimized builds, every PvP/death-loss combination,
party uptime or production load. No blanket no-regressions/all-classes-equal
claim follows. The real updater and ordinary live login/UI checks above passed;
live combat and state-changing Admin commands were not run on the ordinary QA
character. Their native accounting/access regressions ran in the isolated local
fixture. Local Qwen supplied-text reviews did not complete and provide no
corroborating evidence; its VM inventory confirmed only that the DEV VM was running.

## Already Ascended login choice, later follow-up

Server commit `c38a691f83085b3b01a1a6c2b47bedef22c3fa5e` offers class choice
after the supported-client hello only to already Ascended/vocation3 characters
without a permanent class. This login offer works away from The Nameless and
retains existing discipline restrictions. Cancel and background refresh stay
quiet; `!passives` explicitly reopens the offer. Confirm uses the native permanent
transaction, learns the two starters and preserves existing progression,
resources, possessions and position. It performs no new Ascension reset. An
already chosen character receives neither the picker nor an automatic tree.
The existing NPC third-Ascension offer retains its original eligibility and
proximity checks.

Fresh native checks passed on the unchanged DEV10087 client package:

- Four owned loopback cases: ordinary vocation2 stays quiet; unassigned magic,
  sword and unfocused Ascended receive the eligible cards automatically at the
  temple, away from the NPC. Actual UI cancel/back/retry/reconnect, forged and
  stale requests, real combat rejection and duplicate confirm were checked.
  Native class commit and relogin preserve level40/XP988123, mana/mastery progress,
  exact ordered inventory, outfit, capacity and bank10000; two starter rows are
  learned once, chosen login stays quiet and each native client exits0.
- Existing NPC fresh/magic/sword scenarios passed reserved-dispatch rejection,
  legal discipline choices, reconnect, combined walk-away rejection and NPC
  offer expiration. The original proximity/island/quest/focus guards were
  retained and source-reviewed; wrong quest, lost focus and off-island while
  still in range were not separately injected in these scenarios.
- The real third-Ascension permanent scenario passed reset/learning, first Apply
  locking, forged revision0 rejection, free/paid/insufficient-bank respec and
  persistence/detach/death/store behavior.
- The existing scripted login protocol check passed actual server-library
  status/refresh silence and explicit open. Its fake-player test stubs choice
  eligibility; the new native cases above measure that behavior.

Evidence: `out/ascended-login-native-suite.log`,
`out/class-choice-login-tests-20261007-184005/`,
`out/ascended-login-existing-npc-regressions.log` and
`out/ascended-login-permanent-regressions.log`. The first permanent rerun exposed
a test-fixture reference to unexported slot boundary constants. Replacing them
with the Lua-exported head/ammo boundaries repaired the fixture; the native
rerun passed without changing gameplay for that error.

The first Lua-only DEV deployment safely rolled back when Windows PowerShell5.1
treated normal Git stderr as a terminating error. The helper then used actual
process exit codes; real disposable Git success/error checks and16 guard cases
passed before a fresh deployment. The successful deployment's old native server
exited0, no new dump appeared and the existing supervisor resumed the new source
as process7600 with login/game listeners7173/7174. Config, binary/PDB/DLLs,
updater process4556 and DEV10087/PROD1006 artifacts were preserved. Evidence:
`out/dev-access-20261007/ascended-login-deploy-fixed-run.log` and
`out/dev-access-20261007/ascended-login-runtime-verified.json`.

This changes server Lua only. The10087 client and native server binary remain
the hashes recorded above; its source ZIP predates this later Lua increment.
The separate patch, source pins and deployment binding are in
`out/ascended-login-class-choice-release/`. Unchanged combat formulas and the
updater reuse their preceding evidence; they were not rerun for this increment.
The new global offer's natural expiration callback was reviewed; the native
expiration test above covers the existing NPC offer, not a timed global expiry.

The follow-up live check passed with a separate new ordinary QA character,
`Dev Login Qa hecafa`/GUID48 on the existing QA account17. Initial SQL creation
inserted only this fresh players row: vocation3, no class/quest/spell/item rows,
zero bank/store mode, level80/XP7915807, mana760/790 and position32097,32218,7.
Locked before/after fingerprints preserved the existing `Dev Qa decfffheac`/
GUID47, account17 and their related rows. Readonly preparation initially stopped
on TLS defaults, an overly broad trigger guard and PowerShell5.1's single-result
array handling. Reconciled receipts confirmed no creation or retained temporary
credentials in those attempts. Metadata proved all inspected tables were InnoDB
and the sole players trigger was BEFORE DELETE; the final guard rejects INSERT
side effects while leaving that existing trigger unchanged. The explicitly
authorized temporary127.0.0.1/TCP3306 QA TLS exception changed no permanent setting.

The normal DEV10087 native client used the actual updater/login route and
received six eligible cards automatically before any game action, away from the
NPC. Actual UI cancel stayed classless and quiet; ordinary `!passives` reopened
the offer. Confirm committed Reaver through the native transaction without reset
or reconnect, learning Cleaving Arc and Rend. A second actual login had neither
class picker nor automatic tree/Cyclopedia; the toolbar still opened the tree.
Both cycles passed actual look, separate Class Reaver/Ascension Ascended,
opcode31/parser/native passive stats and ordinary-admin denial. No talent Apply,
Respec, combat, item/bank grant or Admin mutation was issued on this live figure.

Postlive readonly SQL confirmed exactly one Reaver ledger with24 earned points,
zero29 ranks/respec count and exactly the two learned starters. The progression
hash (XP, maxHP, mana/magic progress, base skills/tries, capacity and position)
was unchanged; bank remained0 and inventory/depot/inbox stayed empty. Original
QA47/account17 fingerprints were still identical. The native client exited0,
all installed/profile bytes were restored and no native client was left running.
Root inspected the automatic picker, confirmation, chosen quiet login, character
profile and Passive Talents framebuffer captures at retro1280x800, plus two
local native discipline/quiet captures. Final DEV inspection retained process7600,
matching source pins/config/native binary/updater versions and no new crash dump.

Live evidence: `out/dev-access-20261007/ascended-login-live10087-run.log`,
`ascended-login-qa-create.log`, `ascended-login-qa-postlive.log` and
`ascended-login-final-runtime.json` in the same directory. The11 protected live
captures remain in its `ascended-login107-ef9e55a0/` stage. This positive live
check proves the new ordinary path and chosen-login silence; the broader combat,
discipline, forged/stale/duplicate and old-NPC regressions ran locally as listed
above. The live client has no bank binding; bank0 preservation above is measured
by SQL, with paid bank accounting still covered by the local permanent scenario.
