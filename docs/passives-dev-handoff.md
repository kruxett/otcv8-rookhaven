# Passive classes: DEV handoff, 2026-10-06

## Git delivery completed

Both feature commits were pushed and their exact remote branch heads verified:

| Repository | Branch | Feature commit |
| --- | --- | --- |
| Client: `kruxett/otcv8-rookhaven` | `master` | `2ec38dd21b28e19b32f6400cb78e67feb0651802` |
| Server: `Windsmoore/Rookhaven` | `main` | `484575d0872ac2ba136fadbea5a540f262026886` |

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

**No main-config write was attempted.** The expected
`C:\Rookhaven\config.lua` and actual server working directory still require
live inspection after guest-agent access is restored. The pending guest
inspection was read-only; it must not be represented as a successful config
change or a completed live DEV test.

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

## Existing workflow and outstanding live checks

1. Restore guest-agent access, inspect the actual config/runtime layout, then
   back up and update the two main-config flags with readback verification.
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

**No Discord deployment, TFS restart, live database migration or client patch
upload was performed by this handoff.** Full preparation evidence, database
procedure and measured balance limits remain in
[the release guide](passives-dev-release.md),
[the verification record](passives-dev-verification.json) and
[the balance review](passives-dev-balance.md).
