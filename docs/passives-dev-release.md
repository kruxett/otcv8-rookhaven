# Passive classes: prepare the existing DEV release

Status: **local preparation only**. No Git push, DEV deployment, updater upload,
restart or database change is performed by the exporter. The existing Windows
DEV workflow remains the deployment path; this document adds the feature's
required files and checks.

Final local export completed: `out/passives-dev-release10085-final`.
Its `release-manifest.json` identifies the exact artifacts and source hashes;
`final-check.json` records successful archive, DLL, exclusion and checksum
checks. The [DEV verification record](passives-dev-verification.json) records
16 newly executed gates, their evidence scope and remaining live checks.

DEV target: **192.168.1.44**, existing script **`C:\Rookhaven\deploy.ps1`**.
The script's switches and live working-directory layout have not been inspected
in this checkout. Use its established **recompile** procedure; do not substitute
an invented deployment command or script-only reload.

## Required change on the DEV server: main `config.lua`

**You must add or set these exact two rows in the DEV server's main
`config.lua`. This private file is ignored by Git, so a Git update alone will
not add them. Restart the server after changing them.**

```lua
passivesEnabled = true
passiveTestEnabled = false
```

The first enables ordinary passive/class gameplay. The second keeps the
administrative test overlay disabled. The central talent and spell tuning
files are included in the source bundle and explicitly unignored for Git.
Include these and all new feature files in the eventual server/client commits;
`git commit -am` alone does not include new, currently untracked files.

## What must accompany Git update and client upload

| Requirement | Why it is required |
| --- | --- |
| Server Git update includes new native sources and production data | New native Lua bindings, combat hooks, 29-node rules, class selection and spell entitlement are a matched feature. Copying only Lua is insufficient. |
| Existing server deployment recompiles and restarts | `src/passives.cpp/.h`, native call sites and config bindings must enter the executable. |
| Live **main** `config.lua`: `passivesEnabled = true`, `passiveTestEnabled = false` | `src/configmanager.cpp` defaults permanent support to false. Local fixture configuration does not enable normal DEV. |
| Final normal DEV client, version **10085** | Native DEV defaults, EXE, resources and server capability handshake must match. Use the regular DEV endpoint/updater and retro layout. |
| Complete matching `RookhavenClient.exe`, encrypted `data.zip` and DLLs | The native/resource changes must ship together. The `--local-passives` profile disables the updater and is not the release package. |
| Matching `data/checksum_expected.txt` in the server **working directory** | CRC32 values come from final encrypted archive entries; retain existing monitored regular modules as well as passive resources. |
| Existing DEV updater metadata updated for these exact artifacts | Its full `data.zip` and EXE download checks use SHA256, separately from server CRC32. Preserve existing URLs and service schema. |

Client activation is retro DEV or the isolated local test profile. Normal PROD
remains inactive. DEV registers protocol103 but displays no passive/class/spell
UI until the server acknowledges `enabled=true`, `capable=true`,
`schemaVersion=2`, `catalogVersion=2`, `nodeCount=29`. Disabled/unsupported servers
must not open these windows. No local flag is required for supported normal DEV.

## Optional local export

The existing Git/deploy/upload pipeline can be used directly. The helper below
is an optional artifact check/export step, not a replacement pipeline.

Use the final normal DEV install directory and the matching final server EXE.
The root build/test report supplies their identities and executed native gates;
the exporter does not infer a successful build or test from file existence.

```powershell
$python = 'C:\Users\marcu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$luajit = 'C:\vcpkg-client\installed\x64-windows-static\tools\luajit\luajit.exe'
& $python tools/passives/package-dev-release.py `
  --install out/install/x64-DevRelease `
  --server-exe ../Rookhaven/build/local-passives/tfs.exe `
  --version 10085 --luajit $luajit `
  --output out/passives-dev-release10085-final
if ($LASTEXITCODE -ne 0) { throw 'DEV release export failed.' }
```

Add `--dry-run` to validate inputs without writing release artifacts. Output must
be a new directory. The helper compiles source Lua with the supplied build
LuaJIT's deterministic `-b -d` into a temporary directory for equality checks;
it does not launch the client/server or recompile either executable.

Optional inputs:

- `--checksums <file>`: the **existing regular DEV server manifest**, if it is
  newer/different from the sibling checkout's `data/checksum_expected.txt`.
  Every listed path is preserved and refreshed; a missing resource fails export.
- `--server-dll <file>`: repeat for server runtime DLLs that must accompany the
  EXE. Existing server deployment still manages its normal dependencies.
- `--source-allowlist <json>`: reviewed `{ "client": ["relative/file"],
  "server": ["relative/file"] }` lists. The default lists production source
  and complete feature files; the archive is a review/transfer aid, not a
  complete Git checkout or an instruction to overwrite extra live changes.
- `--evidence <json>`: embed root-supplied final build/test evidence.
- `--updater-template <json>`: only an **existing successful full-archive API
  response** (`files`, `url`, `binary`). URLs and other fields remain unchanged.
  Do not pass a differently shaped internal service manifest.

Outputs:

- `Rookhaven-DEV10085-client.zip`: final EXE, complete encrypted `data.zip`, all
  installed DLLs (including `lib/discord-rpc.dll`, preserving their paths) and
  LICENSE when present.
- `Rookhaven-DEV10085-server-binary.zip`: supplied server EXE and explicit DLLs.
- `Rookhaven-DEV10085-source-files.zip` and `source-allowlist.json`: allowlisted
  complete client/server source files, with hashes in the release manifest.
  The default server list includes the matching `data/checksum_expected.txt`;
  prepare that source file from the final export before the final source ZIP.
  No main local config, fixtures, DB runtime, `.git` or test output is included.
- `checksum_expected.txt`: native critical eight in their actual C++ order,
  existing monitored paths, and all packaged `game_passives` modules/art.
- `updater-values.json`: SHA256 values for the existing upload process.
  With an existing API response template, `updater-response.json` is produced
  instead. Neither output publishes anything.
- `release-manifest.json`: artifact hashes, native `CS1` login checksum,
  source/package equality, monitored paths/counts and stated limits.

The helper validates native client/server critical-path order, ZIP integrity,
ENC3 decoding, exact source/bytecode equality for init, critical/monitored
resources, passive UI/art and actionbar, and exact passive resource membership.
It rejects stale packaged files and non-release overlay files. A validation
pass is not an end-to-end updater download, live login or gameplay test.

Copy the generated checksum file into the Git/deployment input and into the
**actual server working directory's** `data/checksum_expected.txt` as the
existing workflow requires. `ProtocolGame::validateClientChecksums` reads that
relative path. The checkout's file and a different runtime directory's file are
not interchangeable. Do not disable checksum enforcement to work around a
mismatch. Do not use the pre-encryption post-build checksum output.

## Database preparation: existing database30 to31

Before the authorized deployment, identify the DEV database and its actual
MariaDB tools/options file through the existing Windows procedure. Do not use
local fixture credentials or include a credential/options file in release ZIPs.

Read-only baseline queries:

```sql
SELECT value FROM server_config WHERE config = 'db_version';
SHOW TABLES LIKE 'player_passives';
```

**No manual schema import is required for database version30.**
`src/otserv.cpp` calls `DatabaseManager::updateDatabase()` during startup.
`src/databasemanager.cpp` loads `data/migrations/30.lua`, whose idempotent
`CREATE TABLE IF NOT EXISTS player_passives` succeeds before it returns true;
only then does the migration runner record version31. `data/migrations/31.lua`
currently terminates the migration chain. Retain both migration files in the
server Git update. On failure, investigate the startup error and table definition;
do not manually advance `db_version` to hide a failure.

The table stores player ID/foreign key, class ID, earned points, respec count and
rank vector. The supplied canonical `schema.sql` also defines it, for a **new**
database. Do not import that whole schema into an existing DEV database. If the
observed version is not30, reconcile its normal migration history first.

After startup, verify:

```sql
SELECT value FROM server_config WHERE config = 'db_version'; -- expected31
SHOW CREATE TABLE player_passives;
SELECT COUNT(*) AS passive_classes FROM player_passives;
```

### Separate legacy17 to29 ledger migration

This is not the database-version migration. `src/passives.cpp::restorePermanent`
recognizes a strictly valid old17-rank ledger when that character's permanent
class is restored. Under a transaction and locked row, it writes29 ranks.
Compatible ranks are retained; an old route that no longer satisfies the new
prerequisites gets a free full talent refund with a player-facing message.
Class, earned points and respec count/price remain unchanged. Invalid current29
ledgers are rejected, not silently refunded as legacy data. Do not mass-rewrite
rank strings or delete the table as a deployment shortcut.

## Existing Windows deployment checklist — for later authorization

1. Preserve current server/client/updater artifacts, their manifests/checksums,
   and the live main config. Finish the normal server save/stop procedure and
   take a **full DEV database backup** before starting the new executable.
2. Use the existing `C:\Rookhaven\deploy.ps1` Git-update and **recompile**
   workflow. Ensure production data and migration30/31 accompany native source.
3. Set `passivesEnabled=true` and `passiveTestEnabled=false` in the live **main**
   config, preserving its host, DB credentials and all other current settings.
   Keep ordinary checksum enforcement enabled.
4. Place the generated checksum manifest in the actual server working directory.
   Start/restart through the existing workflow; verify DB31/table definition and
   that class/spell startup validation reports no error.
5. Use the existing DEV client patch upload process for the complete matching
   EXE/resources. Apply the generated SHA256 values to its existing metadata;
   incremented DEV version10085, URLs and schema must match that service.
6. Check an ordinary normal-DEV client login, The Nameless class offer,
   all six trees, learned spells, Apply/Undo, respec and reconnect. Verify no
   local-test label/control, no unsupported-server UI, and no fixture exposure.
   Check actual updater download/restart separately; local module tests do not
   measure that network path.

### Full backup and rollback

Use the existing secured DB option file and database name; these variables are
deliberately not filled with guessed installations or credentials. A full dump
can be prepared using the site's actual `mariadb-dump.exe`:

```powershell
# Set $dbDumpExe, $dbClientOptions, $dbName and $backupFile from the DEV procedure.
& $dbDumpExe "--defaults-extra-file=$dbClientOptions" `
  --single-transaction --routines --events --triggers --hex-blob `
  "--result-file=$backupFile" $dbName
if ($LASTEXITCODE -ne 0) { throw 'DEV database backup failed.' }
Get-Item -LiteralPath $backupFile
Get-FileHash -LiteralPath $backupFile -Algorithm SHA256
```

Keep this private database backup outside release archives. Verify the dump can
be restored using the existing DB restore procedure before relying on it.

Rollback uses the previous matched server executable/data/config, prior normal
DEV client/update metadata and checksum manifest **and the full pre-deployment
database backup**. Stop the server first. Merely dropping `player_passives` or
lowering `db_version` does not undo class/spell/bank/player changes; old binaries
cannot safely consume newly stored29-rank builds. Restoring the full backup
also discards player changes made after that backup, so coordinate the rollback
window through the existing DEV procedure.

## Prepared evidence

Exporter checks: seven small-input dry-run/assembly/rejection cases passed;
report: `out/passives-dev-release-smoke.json`. ENC3 decoding also matched actual
final normal DEV OTUI, OTMOD and icon source bytes. Final full package hashes,
normal DEV native tests and server regression results are recorded by the root
release report and the generated `release-manifest.json`; do not reuse earlier
local-profile artifact hashes.

The normal DEV native tests now passed real allocation, orphan rejection,
relogin, free and paid respec (exact1000gp bank debit), and both starter spell
entitlements. Administrative QA commands were rejected even for a GOD account
on a local IP while `passiveTestEnabled=false`. These supersede earlier
local-only limitations for the measured normal DEV paths. The prepared package
includes the supplied server executable and any adjacent runtime DLLs; the
existing server deployment may instead recompile it normally. This does not
deploy anything.
The packaged DEV module/updater-request probe also passed50 offline cases,
including DEV version10085, DEV request flag and a scripted updater response
(`out/passives-dev-client/stdout.txt`).

### What "normal DEV client" verification means here

The tested EXE/resources are the ordinary DEV10085 build with its unchanged
release endpoint and updater URL. The online probe redirects only its
disposable login to the new **local** server on127.0.0.1:7174/game7175 and uses
the isolated DB33308. Its test bootstrap supplies an explicitly scripted
updater response. Other combat/NPC probes use `--local-passives --test` with
the same final EXE/resources, which disables their updater. These are local
compatibility tests, **not a login to the live Development server or a real
updater download**. Test bootstraps are absent from the release archives.

### Automatic database rehearsal completed locally

`out/passives-dev-database-final/report.json` records a successful automatic
version30-to31 startup migration in a disposable clone. All37 ordinary table
checksums remained unchanged. A second startup preserved every resulting table
checksum. A full pre-upgrade dump was restored into another disposable clone:
all38 pre-upgrade tables, version30 and absence of the new ledger matched.
The original fixture remained unchanged during this frozen rehearsal.

### Final focused native regressions

Using the final DEV EXE/resources with the isolated local test profile:

- Actual third ascension through The Nameless, checked native save, class and
  own two-spell learning, legacy Light Healing retention, legal16-point
  capstone allocation, reconnect, paid/free respec, death, saved derived HP,
  TCP detach and earned milestones passed (`out/passives-permanent-tests/third-ascension.log`).
- Actual Flurry18-mana and Focused Thrust24-mana casts, learning persistence
  and class/weapon/mana/learning/cooldown rejections passed
  (`out/class-spells-tests/blademaster.log`).
- Existing fixed native damage/healing, area recipients, mana shield,
  standard bleed/poison and cure isolation, Lua scheduling, right-hand Head
  Splitter and Light Healing passed with permanent gameplay enabled and
  disabled, while admin test overlays were disabled in both
  (`out/passives-dev-baseline-enabled.log`, `out/passives-dev-baseline-disabled.log`).
- Actual ordinary NPC rod purchase and purchased-rod combat/payment passed;
  see [balance evidence](passives-dev-balance.md#root-executed-native-access-and-combat-results).
- The focused29-case/2391-assertion ascension failure probe passed using
  the actual NPC Lua flow with mocked native item/save/SQL callbacks.
  Its injected failure cases are not native database-failure injections.

The preceding connected-tree report is historical local evidence for the
broader UI, routes and18 capstone tests. Those complete suites were not all
rerun on this final DEV executable. The new [DEV verification record](passives-dev-verification.json)
identifies the final binaries, exact newly executed gates and remaining limits.

No separate manual schema import is required for an existing supported server:
the existing startup migration mechanism creates the ledger. The fresh-install
`schema.sql` is not an upgrade script. A full live DEV backup still belongs in
the user's existing deployment procedure; these disposable clones and private
dumps are excluded from the release package.

Remote deployment, the real DEV database migration, upload and updater
end-to-end verification remain unexecuted by this preparation task.
