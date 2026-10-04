# Ascension, Sure Shot and guild labels — DEV 10084

## In game

- The Nameless broadcasts `[Ascension] <name> has ascended from <old stage> to <new stage>!`
  after a successful database update. Position, progression reset and converted
  skill progress are written in one atomic UPDATE.
- Sure Shot with burst arrows (server item 2546) explodes in a 3x3 area. Ordinary
  arrows remain single-target. One successful cast consumes one round. Either
  weapon hand works.
- **Options -> Interface -> Display guild names below player names** is a saved
  switch, off by default. Guild text uses the existing name font and fits between
  the player name and health bar. Hiding creature names also hides guild labels.

## Test announcements without ascending

Use a GOD account with an access group:

```text
/testascensionannouncement 1
/testascensionannouncement 2
/testascensionannouncement 3
```

These broadcast the real Awakened, Ascendant and Ascended messages with a `[TEST]`
prefix. No vocation, level, storage, equipment or position changes. Omitting the
argument tests stage 3. The existing `/testascension` ritual command is unchanged.

Server settings: `data/lib/ascension_announcements.lua`:

- `enabled = true` enables announcements.
- `firstAscensionMaxOnline = 0` announces all stages at any population. A positive
  threshold suppresses only Unawakened -> Awakened above that online count.
  The count is taken after the ascending player disconnects, at broadcast time.

## Guild metadata

While enabled and online, the client requests `world_names` on existing extended
opcode 101 every two seconds. The server returns nearby player IDs and guild names
from online guild objects, without database queries. Membership changes refresh
while players stand still. Responses do not open the guild manager. Disabling the
switch, logout and module unload cancel the timer.

## Build and verify

```powershell
./tools/build-dev.ps1
./tools/test-client-features.ps1
```

The test runner requires the isolated local configuration: loopback, database port
33307 and server name `Rookhaven Local Item Test`. It temporarily creates a guild
and registers a combat probe, restores the registration and removes the guild in
`finally`. It checks three announcement stages, native burst AoE versus ordinary
arrows, ammo counts, guild membership refresh and the saved switch. Logs are in
`out/feature-integration-test`.

Run the failure-path/engine-I/O checks from the server checkout:

```powershell
C:/vcpkg-server/installed/x64-windows/tools/luajit/luajit.exe ../otcv8-rookhaven/tools/tests/server-features.lua
```

The DEV builder refreshes resources and bytecode even without a C++ relink, so
Lua-only edits do not package older staged scripts.

## Deploy together

Use the complete DEV 10084 client package, including **both** `RookhavenClient.exe`
and `data.zip`; the rendering requires the new native bindings. Updater SHA256
values are in `out/checksum_expected-DEV10084.json`. Preserve the existing updater
manifest's URLs and schema.

Server files:

The prepared archive is `out/Rookhaven-DEV10084-server-files.zip`, with these paths
and a validation manifest. It contains complete files from the checked-out server
revision; use the matching Git update if the live checkout has additional changes.

```text
data/lib/ascension_announcements.lua
data/lib/lib.lua
data/npc/scripts/The Nameless.lua
data/talkactions/scripts/testascensionannouncement.lua
data/talkactions/talkactions.xml
data/spells/scripts/attack/sure_shot.lua
data/lib/guild_system.lua
data/creaturescripts/scripts/extendedopcode.lua
data/checksum_expected.txt
```

Restart the server to load these together. No server executable rebuild, database
migration or DAT/SPR/OTB change is needed. The checksum file comes from the final
packaged client resources. Local verification does not deploy the external server
or publish the updater.
