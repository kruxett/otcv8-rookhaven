# DEV release smoke, 2026-10-27

Owned QA scripts only. Root coordinates publication, ordinary QA account
provisioning, database backup and the greenlight to start. These scripts never
deploy, restart a server, change existing accounts or run the local QA engine
against DEV. Do not run concurrently with another Rookhaven client or QA session.

## Evidence boundaries

1. `Run-NativeUpdater.ps1`: previous published retail DEV client, actual public
   updater HTTP, binary/data promotion, normal restart, normal settings profile,
   native login window and visible version. No credentials entered. All four
   original profile trees are preserved and restored by same-volume opaque
   rename, with relative paths, every file SHA256 and owner/DACL fingerprints.
   Only processes created in the fresh owned client copy with expected hashes,
   exact PID/path/creation identity are stopped. A journal remains recoverable.
2. `live-compatibility.py`: ordinary owned QA account through normal DEV login
   and game ports. Old build RH2, missing block and QA-mode claims are refused;
   the target retail claim succeeds last. Read-only `init/history/init` checks
   real native S/P/E catalog transport, all 26 outfit variants, full addons,
   native look IDs, 250-point outfit prices, all ten existing products and
   unchanged points after the first init. It logs out and sends no purchase or
   outfit commands. Normal login bookkeeping and first-shop default point
   initialization may persist on the owned QA character; this is not a claim of
   a byte-identical live database before/after login.
   This checks protocol/build compatibility, not remote attestation.
3. Native in-game shop and Try On interactions were tested separately by the
   local batch native/UI suites. This release smoke does not claim a native GUI
   account login, live purchase, live Try On interaction, or a cheat-proof client.

## Configuration

Create an owned JSON outside the source tree, with these fields. Fill target
hashes from the final build receipt and independently check the public API after
publication. Never put passwords in this JSON or commands.

```json
{
  "stage": "C:/GitRepos/kruxett/otcv8-rookhaven/out/release-smoke-20261027/native-updater-01",
  "oldClientZip": "C:/GitRepos/kruxett/otcv8-rookhaven/out/release-smoke-20261027/baseline-10099/Rookhaven-DEV10099-client.zip",
  "oldClientZipSha256": "090d5f889c9447ea269f1a773b29ad679f793c2ad003b8e8b96d5348de7f0086",
  "oldVersion": 10099,
  "newVersion": 10100,
  "oldExeSha256": "07e0c8e47ccac44524670d3b010a4eb24ae16342e5b7bbb433a97f1a5785e8db",
  "oldDataSha256": "815cbe343abc08409c72c9c9672957ab92f3c492400b1ba9b68816afea6bc13d",
  "oldResourceFingerprint": "e6b61af84c2b8d03b5eab07ce7c5aaf3393296123e8dd077955df05d2cdb6be2",
  "newExeSha256": "TARGET_EXE_SHA256",
  "newDataSha256": "TARGET_DATA_ZIP_SHA256",
  "newResourceFingerprint": "TARGET_NATIVE_RESOURCE_FINGERPRINT",
  "updaterApiUrl": "http://updater2.rookhaven-ot.com/api/updater",
  "loginHost": "testserver2.rookhaven-ot.com",
  "loginPort": 7173,
  "ownedQaAccountConfirmed": true,
  "uiWaitSeconds": 900
}
```

The updater script refuses an existing stage. It preflights the live public
target before moving any profile, then launches without `--test`,
`--local-passives`, profile environment overrides or injected Lua. Watch
`ready-for-ui.json`; capture the native window and version with the computer-use
tool, leave account/password blank, then create the stage's `finish-ui` marker.
This marker means observation is done and cleanup may proceed; retain a separate
GUI observation receipt/screenshot. A timeout fails the combined run and still
attempts restoration. Do not interrupt the guard process while profiles are moved.
Native promotion's detached self-deletion helper has a thirty-retry asynchronous
contract. The guard observes file/bridge/helper disappearance for up to 45
seconds after initial child stability; it never deletes an executable itself.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/release-smoke-tests/Run-NativeUpdater.ps1 -Config <owned-config.json>
```

After updater cleanup and root's account/route greenlight, run the wire smoke.
The private account JSON supplies `account` (or `accountName`), `password` and
`characterName` (or `character`). Root verifies the QA account is owned and ordinary; the probe
never executes SQL or changes account/character privileges. Do not expose the
private file or raw network packets in output.

```powershell
python tools/release-smoke-tests/live-compatibility.py --config <owned-config.json> --private-account-file <protected-metadata-path> --output <fresh-result.json>
```

`test-probe.py` runs offline mocked socket regressions for valid multi-fragment
UTF-8 responses, corrupt frame checksum rejection and unexpected old-build
acceptance, failed logout sending and a replaced legacy product. Negative cases
verify accepted-session logout, and a failed logout cannot produce PASS.

```powershell
python tools/release-smoke-tests/test-probe.py
```

ExecutionPolicy Bypass above affects this owned test process only; it does not
change machine/user policy. A missing second RSA block deliberately receives a
silent TCP close before XTEA setup; the other compatibility rejections require
the native verification-error response.

## Actual release run

Evidence under `out/release-smoke-20261027/`:

- `baseline-10099/receipt.json`: public previous ZIP and remote release FS hash
  match; inner EXE/data match the published10099 manifest.
- `native-updater-02/result.json`: real HTTP10099→10100, old exit0, verified
  base-child promotion/restart, bounded native file/bridge/helper cleanup, all
  four original byte/path/owner-DACL profile digests restored exactly.
- `native-updater-02/native-10100-blank-login.jpg`: clean native10100 version and
  blank login fields; no GUI authentication performed.
- `live-wire-02.json`: four real compatibility cases PASS; actual8572-byte S/E
  catalog contains all26 native outfit variants and ten expected products;
  read-only init/history/init, unchanged points after first init, logout sent.

Preserved failures explain test assumptions corrected without product edits:
`native-updater-01` checked asynchronous deletion too early; `live-wire-01.json`
expected an error message for a missing RSA block rather than its intended EOF.
The initial shell attempt also stopped before execution under Restricted policy.
