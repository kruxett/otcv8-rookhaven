# Server validation branch: test and release notes

The paired client/server branch is `codex/server-validation`. It starts from
client `c9f56307fe4e8ae2430c3b577e05a7766502b547` and server
`87a904aab5e21e664103b4b3a8817fbb8b27eb3a`. Neither default branch nor DEV is
changed by running this local suite.

The server validates packet structure before dispatch, binds queued requests to
the current connection, bounds incoming work, and validates custom messages
against explicit schemas. Inventory mutations prepare their entire result
before applying costs or rewards. Personal Store uses durable SQL transactions,
revision checks and receipts, including recovery after an uncertain commit.
Smelting confirmations bind to the server's station and exact item selection.
Monster-only spells cannot be invoked as player spells.

These checks make the server authoritative for the covered rules. A client
build hash is compatibility information, not proof that a player runs an
unmodified process. Valid-looking automated play and multiplayer saturation
need separate detection and capacity work.

## Run the owned native fixtures

Build a loopback QA client with `tools/build-dev.ps1 -QaClient` and a server
with the `ROOKHAVEN_INGRESS_CONTRACT` and `ROOKHAVEN_TRANSACTION_TESTING` CMake
options enabled. Both server options default to **OFF**. The local runner uses
the existing stopped fixture DB, MariaDB binary and loopback config documented
by the development workflow; it copies them before testing.

```powershell
./tools/run-server-validation-native.ps1 -Suite inventory
./tools/run-server-validation-native.ps1 -Suite store
./tools/run-server-validation-native.ps1 -Suite flow
./tools/run-server-validation-native.ps1 -Suite wire
./tools/run-server-validation-native.ps1 -Suite lifecycle
```

Run these serially. They share loopback ports 33308, 7174, 7175 and optionally
7176. Each run owns a timestamped directory beneath
`out/server-validation-native-qa`, preserves the original DB/config and test
profiles, and records process cleanup, artifact hashes and test receipts in
`report.json`. Never point the fixtures at DEV or a live database. Store
competition additionally requires unused player/account ID 90103 in the copied
database and uses a second real client with a separate preserved profile.

| Suite | Changed dependency and checks |
| --- | --- |
| inventory | Exact costs/change, refusals, stack attributes, capacity, holding bags/quivers, equipped upgrades, durations, tradepack delivery, 600 separate material stacks, one-use station confirmations |
| store | Native item/SQL/UI round trips; every reached deposit/buy statement failure; two real buyers for last stock; lost commit acknowledgement before/after commit; process exit immediately after commit and recovery from the same DB; offline mailbox load failure/success |
| flow | Real 8.60 movement, autowalk, bags, attack/follow, NPC/chat, outfit, shared XP, custom windows, spells and reconnects; 0/150/500 ms RTT with jitter; per-opcode/action rolling peaks and reject counters |
| wire | Real RSA/XTEA login positives and malformed framing/checksum/padding/truncated game requests against the owned listener |
| lifecycle | Existing save, reconnect, disconnect, offline-vendor and death/HP cleanup consumers of the changed session/persistence paths |

The lifecycle probe is selected because sessions and saving changed. This is
not a full passive allocation, combat or class regression suite.

The server repository documents native contracts and offline commands in
`docs/server-validation-protocol.md`, `docs/server-validation-inventory.md`
and `docs/personal-store-transactions.md`. Detailed final execution evidence is
recorded in `docs/server-validation-results.md` alongside those contracts.

## Publication and rollback

Publish matching client and server artifacts together, with normal protected
client integrity pins and both server test options OFF. The new smelting and
Personal Store mutations intentionally require the new confirmation envelopes;
an older client cannot perform those operations. Build and local QA are not
deployment or live DEV verification.

Before publishing, back up the current DB and inspect the store migration's
preflight. A branch revert is straightforward while this remains undeployed.
After new store transactions have occurred, restoring only legacy store tables
would diverge from current inventory and payments. Follow the server's recovery
notes and use a forward fix or coordinated whole-database recovery instead.
