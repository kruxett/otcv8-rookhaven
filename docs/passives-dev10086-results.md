# DEV10086 passive follow-up

Server source: `db44422140454ecdd475d0cf71cad7fccf8af7ad`.
DEV deployment and publication are pending the remaining native balance checks.

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

## Prepared release and access

Ordinary DEV client executable:
`out/install/x64-DevRelease/RookhavenClient.exe`.
Archive: `out/passives-dev-release10086-final/Rookhaven-DEV10086-client.zip`.
EXE SHA256: `4d448961c0a8dd5a5b44acbe85ce9279e39a82344900fecd3279de4a6b8b69d7`.
Data SHA256: `3aac14386c4c09682e5864689f513458c333f6046676a5f069c6cba9eab68de4`.
Client ZIP SHA256: `8dfc48d5cc5d4c48dad9bc5ba7ee28b5bcc2745301148f734432f211c0379c60`.
All133 monitored resources, the native critical-eight order/CS1:d08bec84,
117 passive resources and decoded Cyclopedia/source equality passed. Server
checksum source and final artifact are byte-identical; the earlier export's
LF/CRLF-only difference was reconciled before committing and staging.

The authorized workstation key was added with backup and previous-key
preservation on OMBSRV020. Strict authenticated SSH now succeeds from
192.168.1.253 to192.168.1.44. Passwords, SSH configuration, firewall and service
restart settings were not changed. No private key/QA credentials are in these
artifacts. Reviewed deployment/publication helpers and their receipts live in
`out/dev-access-20261007/`.

## Limits

These are targeted correctness/integration checks and acquisition/formula
analysis. They do not measure sustainable human hunts, full quest navigation,
all rarity distributions, optimized builds, every PvP/death-loss combination,
party uptime or production load. No blanket no-regressions/all-classes-equal
claim follows. Actual DEV updater promotion/restart and two ordinary live QA
logins remain pending publication.
