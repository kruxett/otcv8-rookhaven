# In-client accounts and characters

The retro login window opens **Create account**. Registration requires an account
name, email and confirmed password, then uses ordinary login to open the empty
character list. **Create character** is available from that list. It offers a
name, sex and actual starter-outfit preview; a successful creation refreshes the
ordinary character list without entering the game automatically.

Characters start at level 1, group 1 and vocation 0 (Unawakened), with HP 150,
mana 0 and CAP 400. The configured town supplies the temple position. Existing
first-login scripts grant the normal torch, knife, robe, bag and apple once.
Class/Ascension choices remain part of progression. No player template is cloned.

Email is mandatory and checked for syntax. This feature does not send mail,
verify ownership or implement password recovery. Existing accounts can still
log in and add characters with their existing email/password rules.

## Authentication security upgrade (DEV10103)

All three authentication paths share versioned scrypt hashes (`N=131072, r=8,
p=1`, random 16-byte salt, 32-byte result). Schema migration 34→35 widens the
password column to binary-collated ASCII VARCHAR(255). New registrations never
write SHA1. Existing SHA1 accounts upgrade after successful authentication;
wrong passwords do not change the stored value. Binary compare-and-swap prevents
a concurrent upgrade overwriting a newer password. Existing short passwords and
blank email addresses remain usable. The cost follows the
[OWASP password-storage guidance](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).

Two dedicated workers perform slow hashes outside the game/IO/database workers,
with at most eight queued jobs and 60 admitted operations per IP per minute.
Limits reject overload explicitly. Database transactions never span a hash or a
worker callback. Character creation rechecks the exact authenticated stored hash
under the account lock, then applies existing bans, capacity and creation rules.
Accepted creation requests can finish after a lost connection; ordinary login
or refresh reconciles an unreceived reply without duplicating the account.

The coordinated release uses a private environment-specific RSA-2048 key for
normal login, game login and creation. Invalid, truncated or 1024-bit keys fail
startup. The public modulus is compiled into the matching client; private keys
are runtime secrets and must never enter Git, client archives or release logs.
Old clients require the new release before connecting.

The updater now uses HTTPS, verifies certificate chains and hostnames against
the operating system trust store on Windows, and refuses HTTPS→HTTP redirects.
Artifact downloads always use HTTPS, including historical HTTP base URLs in an
authenticated manifest. There is no cleartext retry on verification failure.
The first migration from an old HTTP updater cannot authenticate its own initial
download retroactively: distribute the new full client over its verified HTTPS
download address. Later updates use the corrected updater.

This is not a claim that the entire legacy RSA/XTEA game transport is a modern
authenticated TLS protocol. Review that transport before public production.
Counters remain process-local and reset on restart, and email syntax does not
verify ownership. Email verification and password recovery remain separate work.

## DEV and production configuration

The native server registers service `0x03` (RHA1 version 1) on the **existing login
port**. The client uses the selected login endpoint; the character view snapshots
the endpoint/account from the successful login. It has no separate DEV URLs,
web server, database credentials or web-login fallback.

Set these in the server's private `config.lua`; they are read at startup and
require a normal server restart:

```lua
clientAccountServicesEnabled = true  -- default false; enable per environment
clientAccountCreationEnabled = true
clientCharacterCreationEnabled = true
clientCharacterLimit = 8            -- clamped to 1..20
clientCharacterTownId = 1           -- Rookhaven; must have a valid temple tile
clientAccountIpLimitPerHour = 3      -- successful registrations per IP per process
rsaKeyFile = "C:/private/rookhaven-rsa.pem" -- private RSA-2048 key, exponent 65537
```

For production, build with the normal production `DEFAULT_SERVER_ENDPOINT` and
`UPDATER_CHANNEL=prod` and `SERVER_RSA_PUBLIC_KEY_FILE=<production modulus file>`,
provision a separate production private key and authenticated updater endpoint,
deploy the matching protected client/server pins, and
enable the same server feature flag. No endpoint changes inside the account-service
module are needed. The DEV public modulus is `tools/keys/dev-rsa.txt`; QA uses
its separate key. The build refuses a missing public-key file. Do not reuse the
DEV or QA private key for production.

For local QA, `tools/build-dev.ps1 -QaClient` and the local-passives builder
prepare a separate RSA-2048 fixture through `tools/prepare-local-rsa.py`
(Python with cryptography). Its protected private key and public modulus live
under ignored `out/local-server/auth/`; existing keys are validated and preserved.
The local server launchers and native probes use that same fixture. An external
key pair can be selected with `-ServerRsaPublicKeyFile` for the client and
`-RsaKeyFile` for the local server. `-BuildOnly` compiles without running the
graphics-dependent installer, for headless build hosts; package verification is
still a separate required release check.
Registration and character creation can also close independently. Missing towns,
database errors and bans fail closed; existing login stays available.

New accounts use 4-20 ASCII letters/digits/underscores and passwords of 10-40
bytes without control characters. Character names use 3-29 ASCII letters and
single spaces, normalize case and reject staff/NPC names. These limits fit the
existing 8.60/RH2 RSA game-login block. Existing longer credentials get an explicit
shorter-name refusal when their combination would exceed that block.

RSA establishes a fresh OpenSSL-generated XTEA key before any credentials are
sent. Requests/replies are checksummed, bounded and versioned. Each connection
accepts one creation request. The server authenticates characters, checks bans
and locks the account before counting/inserting. Database failures roll back;
an uncertain commit asks the player to log in/refresh before retrying. Private
account SQL errors redact input. Password hashes retain existing server login
compatibility. UI cancellation, timeouts and late replies have generation guards;
duplicate submissions are disabled. Remember password uses the existing encrypted
settings behavior; an unchecked box no longer writes plaintext on failed login.

## Guilds

Guild creation already exists in-game: speak to **Crestwick**, **Grimald** or
**Osmund** and say **guild**. The NPC opens founding mode in the existing Guild
Manager, valid for 60 seconds. The top-menu manager remains available for ordinary
management. The server now also refuses a current guild member founding another
guild, including after revisiting a Guildmaster.

## Targeted verification

Changed creation paths affect authentication, database transactions, first login,
character-list refresh and guild membership. Shared key generation also affects
ordinary login/game login. These paths are covered by:

* `tools/account-service-tests/protocol.lua`: actual client protocol lifecycle,
  encrypted credential ordering, malformed replies, closed services, cancel and
  timeout/exactly-once behavior.
* `tools/account-service-tests/login-settings.lua`: existing login writes with
  Remember password on/off, including validation failure.
* `tools/account-service-tests/run-native.py`: real RSA/XTEA and native server,
  fresh MariaDB from the retained SQL seed, successful/rejected creation,
  duplicates, bans, parallel character caps, feature flags, invalid town,
  transaction failure/recovery and private error redaction. With `--client`,
  it runs the actual new native QA client and retro views, both preview sizes,
  first items, normal login, remembered encryption, maximum RSA credentials,
  reconnect, Guildmaster creation and persisted leader permissions.

The runner uses loopback ports 33314/7187/7188, an owned runtime/database copy and
the existing QA-only profile, which it preserves/restores. It never changes live
DEV/PROD or the source fixture. Supply a current native engine and its matching
DLL directory and `--rsa-key <private loopback fixture key>`; `--client` must be
a loopback-only QA package compiled with the matching public modulus. `--ui-only` reruns
just the native UI path after a UI/driver change. Python requires cryptography;
the two isolated Lua checks can run under LuaJIT or Lupa from the client root.
Screenshots/build outputs do not replace these existing-path regressions.
