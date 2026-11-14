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
```

For production, build with the normal production `DEFAULT_SERVER_ENDPOINT` and
`UPDATER_CHANNEL=prod`, deploy the matching protected client/server pins, and
enable the same server feature flag. No account-service code changes are needed.
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
DLL directory; `--client` must be a loopback-only QA package. `--ui-only` reruns
just the native UI path after a UI/driver change. Python requires cryptography;
the two isolated Lua checks can run under LuaJIT or Lupa from the client root.
Screenshots/build outputs do not replace these existing-path regressions.
