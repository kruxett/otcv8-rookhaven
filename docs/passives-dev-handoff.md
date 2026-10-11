# Passive classes: DEV handoff, 2026-10-06

## Git delivery completed

Both feature commits were pushed and their exact remote branch heads verified:

| Repository | Branch | Feature commit |
| --- | --- | --- |
| Client: `kruxett/otcv8-rookhaven` | `master` | `2ec38dd21b28e19b32f6400cb78e67feb0651802` |
| Server: `Windsmoore/Rookhaven` | `main` | `484575d0872ac2ba136fadbea5a540f262026886` |

On October 7 the Windows deployment project was found to omit the new
`passives.cpp` compilation unit. Follow-up server commit
**`0739977bf2c84bfe8e2187063fc79755c394402e`** adds `passives.cpp` and
`passives.h` to `vc17/theforgottenserver.vcxproj`. MSBuild evaluated the
actual `Debug|x64` project locally and included the passive source exactly
once. The commit was pushed and the remote head verified. A full local
MSBuild compile was not performed because this workstation has no deployed
`C:\vcpkg` dependency tree; the earlier native tests used CMake.

### Client staging after the user's server deployment, October 7

The user explicitly set aside backup/QEMU repairs, forbade a VM restart and
then reported completion of the Discord server deployment. Explorer shows
the runtime EXE updated at 09:16 on October 7. That timestamp and the user's
report do not independently verify the deployed commit, passive hooks or DB
migration.

The complete client ZIP and publication helper have been downloaded through
VNC and extracted into **`C:\rookhavenpassives10085`** on OMBSRV020. The
final helper is `Publish-DEV10085.ps1`, 10,601 bytes, with SHA256
`918f13deafe189c36288fbe29e46dc6e7f48adbcfd9518df58d46ea95a7ec1e0`.
The final transfer ZIP SHA256 is
`8d5a6264cd7a5573319b88e9b0dde821b8a673de902fa8ee62ac6c062d3b3032`;
the Linux worker copy was hash-verified before download. The temporary
download endpoint served only the verified DEV guest and was stopped after
the transfer. It did not expose private configuration or credentials.

The helper has passed PowerShell syntax parsing but has **not been executed
on the guest**. It validates the ZIP and all seven release files, changes
only the two main-config flags with byte-preservation/readback guards,
verifies server Git/native hooks/CRC manifest, and waits for TFS to start
after the updated main config. The user handles that TFS restart through
Discord. The helper then publishes only DEV10085, preserves PROD metadata
and artifact hashes, restarts the identified Node updater, checks its health
and API, and retains the original updater files for rollback.

It never invokes a server deployment, reboots Windows, changes SSH access,
runs a database backup or attempts QEMU repairs. `-VerifyOnly` performs
preflight without writes; `-Prepare` stages/sets the two flags and returns
without publication. Default mode waits for the user's TFS restart if needed
and then publishes. Its recorded result explicitly leaves authenticated
gameplay testing unverified.

The Computer Use skill prohibits running terminal commands through VNC.
The existing bot SSH identity was also rejected using its configured
Administrator mapping. Therefore the user was asked to run the already
staged helper in PowerShell on OMBSRV020. Live health at 09:28 still reports
**DEV10083 / PROD1006**: publication, flag editing and updater restart remain
pending rather than completed.

The server commit includes native hooks, production Lua/data, database
migration30/31 and both central tuning files. The private main `config.lua`
is still excluded from Git. This handoff document is a subsequent client
documentation change; the normal DEV client artifacts remain unchanged.

## Confirmed infrastructure and remaining access issue

The authenticated Proxmox host is **`ombsrv03`, `192.168.1.9`**.
Live QEMU guest-agent replies identified the existing DEV target as:

- **VM109**, Proxmox display name `ombsrv21`.
- Windows hostname **`OMBSRV020`**, Windows Server2022 Standard.
- IPv4 **`192.168.1.44`**, matching the existing DEV deployment target.

After a read-only guest inspection was launched, guest-execution status timed
out. Subsequent guest-agent requests report `QEMU guest agent is not running`.
The VM remains running; the DEV public login TCP port remains reachable. These
checks do not establish the Windows service's exact failure cause.

The existing direct SSH fallback was tested with the previously trusted guest
host key. The guest rejected the tested Administrator identity. There is no
verified alternative guest account/key mapping.

**No main-config write was attempted.** Live VNC inspection on October 7
confirmed `C:\Rookhaven\config.lua`, the runtime executable and watchdog
working directory. The config's byte hash and current passive flags still
require inspection through a working guest command/file channel. The earlier
guest inspection was read-only; it must not be represented as a successful
config change or a completed live DEV test.

### Machine inventory and recovery, October 7

The user requested a machine inventory before any Rookhaven changes. Chrome
VNC now works. The following was read directly from Explorer, Notepad++,
Services, Task Manager and Task Scheduler:

| Component | Actual location / lifecycle |
| --- | --- |
| Game server | `C:\Rookhaven\theforgottenserver-x64.exe`, observed PID 6180 |
| Watchdog | `C:\Rookhaven\tfs-supervisor.ps1`, observed PowerShell PID 4708 |
| Active startup task | `StartTFSafterSS`, running, starts `C:\Rookhaven\startafterss.bat` at boot |
| Older startup tasks | `RookhavenSupervisor` and `StartTFS` disabled |
| Discord deployment target script | `C:\Rookhaven\deploy.ps1`, `update` / `recompile` modes |
| Compile helper | `C:\Rookhaven\recompile.ps1` |
| Compiler | Visual Studio 18 Community MSBuild, native `vc17` project, `Debug\|x64` |
| Updater | `C:\Rookhaven\updater\updater-api.js`, Node PID 1508, Administrator |
| Updater metadata | `C:\Rookhaven\updater\manifest.json` |
| Updater artifacts | `C:\Rookhaven\updater\releases\dev` and `releases\prod` |
| Database | Automatic, running MariaDB 12.1 service, observed PID 3284, port 3306 |
| Database files | `C:\Program Files\MariaDB 12.1\data`, configuration `my.ini` |
| Database backup | Task `DEV SQL Backup`, script `C:\scripts\dev_db_backup.ps1` |
| Log rotation | Task `Rookhaven Log Rotation`, script `C:\scripts\logSorting.ps1`, archives under `C:\RookhavenLogs` |
| Log shipping | Automatic, running `PromtailService`, NSSM wrapper; `C:\promtail\config.yml` |

The boot batch script launches the PowerShell watchdog and retries it after
five seconds if it exits. The watchdog runs TFS in `C:\Rookhaven`, waits for
it to exit, waits three seconds, then waits while a process command line
matches `deploy.ps1` before launching TFS again. Deployment creates
`deploy.lock`, requests graceful shutdown through `data\update.flag`, then
fetches and resets to `origin/main`. Its recompile mode builds and copies the
native EXE/PDB. The user retains ownership of this deployment/restart.

**Two operational blockers were found:**

1. QEMU-GA was started, its dedicated VirtIO serial device was disabled and
   re-enabled, and the service was restarted. It now runs as PID 6460, and
   Windows reports the driver healthy. Proxmox guest commands still fail;
   a direct bounded synchronization request through the QGA socket also
   timed out. Service status is not proof of agent communication. No VM
   reboot or TFS restart was performed.
2. `DEV SQL Backup` last returned **`0x1`** on October 7. Its NAS destination
   `\\192.168.1.61\Backup\Rookhaven backups\Database_backup` is inaccessible
   from guest Explorer, which returned **`0x80070043`, network name not
   found**. The script explicitly exits 1 on inaccessible destination.
   NAS port 445 is reachable from the workstation, which does not establish
   guest/task-account share access. A valid backup and restore remain
   unverified. The database credentials file was not read or copied.

The deployed script does not explicitly reject nonzero Git/MSBuild exit
codes before continuing; its failure behavior needs verification before
relying on a successful Discord deployment message as native-build proof.
No deployment-script changes or failure tests were performed during inventory.

The system drive has approximately 70.1 GB free of 126 GB. Other observed
application directories include `C:\RookhavenWeb`, `C:\inetpub`, `C:\vcpkg`,
`C:\Tools` and `C:\promtail`. Full startup registration, IIS bindings,
installed package versions, actual Git HEAD and live database state remain
unmeasured while the guest command/file channel is unavailable. This is an
operational map, not a claim of complete OS/database inventory.

Detailed local observations are in
`out/dev-machine-inventory/inventory.json`; screenshot evidence includes
`out/dev-machine-inventory/backup-share-error.jpg`.

## Required live main-config change — still pending

**The DEV server's main `config.lua` must contain these exact rows:**

```lua
passivesEnabled = true
passiveTestEnabled = false
```

**Git pull does not add them.** The first enables permanent classes/talents;
the second disables administrative test overlays. Preserve every other live
setting and the existing checksum enforcement. These flags take effect during
the user's subsequent server restart through the existing deployment workflow.

The user explicitly requires **no other main-config changes**. The prepared
edit checks that reversing only these two flag edits recovers every original
byte, then verifies the written file against the proposed hash. A private
backup retains the original file and access permissions. Neither the edit nor
the backup has been performed on the guest while access remains unavailable.

The central tuning files are already versioned in the server commit:

- `data/lib/passives/config.lua`
- `data/lib/class_spells/config.lua`

## Prepared normal DEV client

Package: `out/passives-dev-release10085-final/Rookhaven-DEV10085-client.zip`.
Native install: `out/install/x64-DevRelease`.

- DEV version **10085**, retro layout.
- Login: **`testserver2.rookhaven-ot.com:7173:860`**.
- Updater: **`http://updater2.rookhaven-ot.com/api/updater`**.
- EXE SHA256:
  `a269ac41adf17dafe2982181df1b5b769149dec6d226f08ab72a2a3073588afc`.
- Encrypted `data.zip` SHA256:
  `243149c39452ffce2ce8e83814d3aa5c4e9de216dad8d8a3466f620721154a3a`.

Use the complete matching EXE, encrypted archive and DLLs, including
`lib/discord-rpc.dll`, through the existing DEV patch upload procedure.
`updater-values.json` supplies the SHA256 values for that existing service.
Do not replace its URLs or schema with these values-only JSON contents.

The server commit contains the matching133-entry
`data/checksum_expected.txt`; its native critical-path checksum is
**`CS1:d08bec84`**. Verify that manifest reaches the actual server working
directory. Server CRC32 entries and updater SHA256 values have different roles.

Use **Git for current server source**. The optional source/binary ZIPs in the
earlier local export are auxiliary artifacts. The source ZIP predates small
server comment/whitespace and local fixture-default housekeeping changes in
the final server commit; it is not an exact archive of that commit.

### Client publication and updater restart are now authorized

The user has also authorized placing the matching client release on DEV and
restarting its updater. The game-server deployment/restart still belongs to
the user's existing Discord workflow.

A new live DEV API probe with version0 returned:

- Current advertised DEV version **10083**.
- Download base **`http://updater2.rookhaven-ot.com/files/dev/`**.
- Exactly one resource entry, **`data.zip`**.
- Separate binary entry, **`RookhavenClient.exe`**.

The existing DEV10083 archive/EXE hashes differ from the prepared10085 release.
The prepared publication plan verifies all seven release-file hashes and
contains an expected10085 API-response preview preserving the live URL/schema.
This preview is **not** a guessed updater service configuration file.

The client updater's `files` map must continue containing **only `data.zip`**.
Adding DLLs to that map disables complete encrypted-archive replacement and
does not install DLLs beside the executable. Publish the complete seven-file
client ZIP for fresh installs, including the nested Discord DLL. The matching
EXE belongs in the API's separate `binary` object.

Historical proxy metadata routes both DEV and PROD updater hostnames to the
guest's Node backend at192.168.1.44:3000. Preserve PROD artifacts and metadata.
Live VNC source inspection confirmed the directories and metadata above. The
observed updater launch is an interactive PowerShell console running
`node updater-api.js` in its updater directory; Task Manager confirms the
matching Node process. No dedicated updater task appeared in the inspected
root task library; a complete autostart search remains pending. The API reads
the manifest on every update/health request. It serves both channels, so a
process restart can briefly interrupt both updater endpoints. Preserve PROD.

Stage the release before the user's Discord deployment. Activate the matched
DEV10085 files/metadata and restart the identified updater once the new game
server runtime and matching CRC manifest are ready; publishing the new client
against the old server can cause checksum rejection. Inspect API and download
hashes after the updater restart, then perform the real client update/login
checks. The client release is now staged on the guest as described above.
On October 7 the user explicitly authorized PowerShell through VNC. The
publisher ran on OMBSRV020. Its first attempt stopped at the config helper's
atomic replacement: Windows PowerShell converted its null backup argument to
an invalid path. The original config was not replaced by that attempt. The
helper was corrected to use the already protected backup path, then rerun.

The second run verified the deployed Git head **0739977bf2c84bfe8e2187063fc79755c394402e**,
built/runtime server EXE equality, native passive hooks and the ordered matching
client/server checksum manifest. Config readback verified **passivesEnabled=true**
and **passiveTestEnabled=false**, with all unrelated original config bytes
preserved. It is now waiting for the user's Discord TFS restart to load those
flags before advertising the new client. **Client publication and updater
restart have not yet been confirmed.** Windows remains running.

At 09:55 the live public updater still advertises DEV10083 and PROD1006.
VNC confirms the publisher's ten-minute wait expired because TFS did not
restart with the new config. The publisher stopped before updater publication
or restart. The verified config edits remain in place. After the user's Discord
game-server restart, rerun the publisher and verify the public download hashes.

### Actual DEV test attempt, October 7 at 09:58

The normal, unmodified DEV10085 client was launched without local-test flags
from `out/install/x64-DevRelease/RookhavenClient.exe`. Windows process inspection
confirmed its executable/command line. Native Computer Use observation returned
the workstation's Windows PIN screen, so UI interaction was stopped and the user
was asked to unlock Windows and log an existing DEV test character into the client.
Client rendering, authentication and the passive handshake are **not verified**.

Actual public DEV login TCP at `testserver2.rookhaven-ot.com:7173` accepted a
connection. Both currently served DEV10083 artifacts were downloaded and their
SHA256s matched the actual updater API. This confirms reachability and integrity
of the **old advertised release**, not publication or updating to DEV10085.
Measurements are retained in `out/actual-dev-check/public-check.json`.

After the Discord TFS restart and matched client publication, the remaining
actual client checks are ordinary login, automatic schema2/catalog2/29-node
negotiation, existing class/talent/spell entitlement, retro UI and unchanged
class/ranks across safe logout/relogin. Existing local regression runners must
not be pointed at this server: they mock the updater and mutate disposable
loopback database/player fixtures. Use an existing designated DEV test character.

## Existing workflow and outstanding live checks

1. Actual config/runtime inventory and the two main-config flag edits are
   complete, with readback and unrelated-byte verification. QEMU repair,
   database backup work and VM reboot are explicitly excluded by the user.
2. The **user** triggers the existing Discord DEV deployment with server
   **recompilation** and the normal save/backup/restart procedure. A Lua-only
   update is insufficient for the new native hooks.
3. Existing startup migrations handle supported DB30→31 automatically. Do
   not import the fresh-install schema or manually advance the DB version.
   Check the real migration result after startup; the live DB has not yet
   been inspected or changed during this handoff.
4. Transfer the matching DEV client patch through the existing upload process.
5. Test the real updater download/restart and ordinary login, class choice,
   talents/spells, persistence and respec against the updated actual DEV server.

The updater endpoint returned HTTP200 with `upToDate=true` for a DEV10085 API
probe. That proves an API response, **not** an artifact download/restart or an
authenticated gameplay session. Earlier normal DEV compatibility and database
rehearsals ran against the isolated local server/database.

**The user's compiled Discord deployment passed the publisher's source/native
and checksum checks. Main-config editing is complete; the publisher is waiting
for the user's Discord TFS restart before publishing client/updater 10085.
Actual live DB migration and authenticated gameplay remain unverified.** Full preparation evidence, database
procedure and measured balance limits remain in
[the release guide](passives-dev-release.md),
[the verification record](passives-dev-verification.json) and
[the balance review](passives-dev-balance.md).
