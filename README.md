# OTCv8 Developer Editon (sources)

## DEV 10084: ascension, Sure Shot and guild labels

See [feature changes and test/deploy instructions](docs/ascension-combat-guild.md).
Build with `tools/build-dev.ps1`; verify locally with `tools/test-client-features.ps1`.

## Reusable item skill

Use `$rookhaven-items` for adding an item to both client and server or replacing
its artwork with a supplied image. The versioned skill is
[skills/rookhaven-items/SKILL.md](skills/rookhaven-items/SKILL.md); its references
preserve the exact Duskblade import and the verified build/test/checksum workflow.
The original generated Duskblade artwork was rejected visually. Future artwork
comes from user-supplied repo images or chat attachments.

## Local item proof (2026-10-04)

An original 32x32 sword sprite is installed as **rookhaven duskblade**:
server ID `12829`, client ID `11866`, sprite ID `36659`.
The source artwork and validation manifest are in `assets/items/rookhaven-duskblade`.
`tools/item_assets.py` reads/writes this project's legacy 8.60 DAT, SPR and OTB
formats without an external item editor. It rejects ID collisions and verifies
that existing DAT/OTB records and compressed SPR payloads are unchanged.
This proof has attack 52, defense 32+3 and weight 42 oz; no loot table was changed.
Chase-item balance, rarity and acquisition still need a separate design decision.

The sibling server checkout is `C:\GitRepos\kruxett\Rookhaven`.
Client dependencies use `C:\vcpkg-client` (`x64-windows-static`); server dependencies
use `C:\vcpkg-server` (`x64-windows`, Release). Both are pinned to vcpkg
`62159a45e18f3a9ac0548628dcaf74fcb60c6ff9`. The server needs Boost Asio,
date-time, filesystem, iostreams, system, variant, lockfree and range; Crypto++,
fmt, MariaDB Connector/C, PugiXML and LuaJIT. The Crypto++ overlay in
`tools/server-vcpkg-overlay` replaces two stdext iterator helpers removed by
MSVC 14.51. The server source also now has its missing PCH include guard,
MariaDB header fallbacks and the imported Crypto++ CMake target.

A portable MariaDB 11.4.9 installation and dedicated database are under
`out/local-server`; no Windows service or firewall rule was installed.
The server's ignored local `config.lua` binds to `127.0.0.1`: login `7174`,
game `7175`, database `33307`. Database `rookhaven_item_test` is independent
of live data. Account `itemtest` / password `itemtest` has character `Item Tester`.
Three tables absent from `schema.sql` are provided for this local fixture in
`tools/item-proof/local-custom-tables.sql`; review the complete live schema
before provisioning a new production database.

```powershell
.\tools\build-dev.ps1
.\tools\build-server-local.ps1
.\tools\start-local-item-test.ps1
.\tools\test-item-local.ps1              # automatic native integration test
.\tools\test-item-local.ps1 -Interactive # opens the local client with the test character
.\tools\start-local-item-test.ps1 -Stop
```

`--test` uses a separate `Rookhaven-LocalItemTest` AppData profile with real file IO.
The automatic test verifies actual login and game protocols, a native OpenGL
render of the new sprite, server look text/stats, movement to the ground and
back to equipment, and persistence after logout and relog. It passed with
`enforceClientChecksums = true`. Logs and screenshot are under `out/item-proof`.
It also covers C++ exception recovery through LuaJIT and saving a 297-byte
minimap. The test uncovered and fixed a double unwind inside the Lua C++ catch
handler, a 1 KiB minimap save threshold, the data.zip cwd assumption, and missing
`.lua` to `.luac` fallback in uncached checksums. No combat or loot/drop-rate
test is claimed for this proof.

### Installing on the DEV server

For the current DEV 10084 package, follow the [feature deployment instructions](docs/ascension-combat-guild.md).
The following records the original DEV 10083 item proof and its
`out/Rookhaven-Duskblade-server-files.zip`. That historical server archive contains
`data/items/items.otb`, `data/items/items.xml`, `data/checksum_expected.txt`
and a validation manifest. Back up the corresponding live files and compare
the live items.xml/OTB with this checkout before replacing the complete files.
They must be installed as a matched set with the new client resources.
Restart the DEV server and publish the matching client/data.zip on its updater;
these files have only been tested locally and have not been deployed remotely.
The updater reported DEV `10080` during the local test; the prepared build is `10083`.
The upload must include the new version and existing updater manifest fields
(URLs, hashes, sizes) for that package. No new server executable is needed just
to load the new item. Use `/i 12829` or `/i rookhaven duskblade` as an access
character to create it. Adding a production loot entry is intentionally pending.

### Classic inventory (DEV 10083)

Retro inventory slots use the existing classic stone texture with transparent
slot icons, including the adventurer blessing state. Occupied slots clear the
empty-slot icon and retain the existing rarity frames. This was verified in the
native client against the local server through item movement and relogin.
The screenshot is `out/classic-inventory.png`; the test log is
`out/classic-inventory-test.log`.

LuaJIT compilation now uses deterministic bytecode (`-b -d`) so unchanged Lua
files retain their checksums between builds. When installing this DEV package,
also install `out/RookhavenClient-DEV-checksum_expected.txt` as
`data/checksum_expected.txt` on the DEV server. No server code change is required
for the inventory appearance. The item proof still requires its matched OTB/XML
files as described above.

Ready to use binaries are available in [OTCv8/otclientv8](https://github.com/OTCv8/otclientv8) repository.

OTCv8 sources. You can add whatever you want and create pull request with your changes.
Accepted pull requests will be added to official OTCv8 version, so if you want a new feature in OTCv8, just add it here and wait for approval.
If you add custom feature, make sure it's optional and can be enabled via g_game.enableFeature function, otherwise your pull request will be rejected.

This repository uses Github Actions to build and test OTCv8 automaticlly whenever you push changes to repository.

Check Actions tab to see test results or to download latest binaries. ![Workflow status](https://github.com/OTCv8/otcv8-dev/actions/workflows/ci-cd.yml/badge.svg)

## Compilation

### Automatic

You can clone repoistory and use github action build-on-request workload.

### Windows

You need visual studio 2019 and vcpkg with commit `3b3bd424827a1f7f4813216f6b32b6c61e386b2e` ([download](https://github.com/microsoft/vcpkg/archive/3b3bd424827a1f7f4813216f6b32b6c61e386b2e.zip)).

Then you install vcpkg dependencies:
```bash
vcpkg install boost-iostreams:x86-windows-static boost-asio:x86-windows-static boost-beast:x86-windows-static boost-system:x86-windows-static boost-variant:x86-windows-static boost-lockfree:x86-windows-static boost-process:x86-windows-static boost-program-options:x86-windows-static luajit:x86-windows-static glew:x86-windows-static boost-filesystem:x86-windows-static boost-uuid:x86-windows-static physfs:x86-windows-static openal-soft:x86-windows-static libogg:x86-windows-static libvorbis:x86-windows-static zlib:x86-windows-static libzip:x86-windows-static openssl:x86-windows-static
```

and then you can compile static otcv8 version.

### Linux

on linux you need:
- vcpkg from commit `761c81d43335a5d5ccc2ec8ad90bd7e2cbba734e`
- boost >=1.67 and libzip-dev, physfs >= 3
- gcc >=9

Then just run mkdir build && cd build && cmake .. && make -j8

### Android

To compile on android you need to create C:\android with
- android-ndk-r21b https://dl.google.com/android/repository/android-ndk-r21d-windows-x86_64.zip
- libs from android_libs.7z

Also install android extension for visual studio
In visual studio go to options -> cross platform -> c++ and set Android NDK to C:\android\android-ndk-r21b
Right click on otclientv8 -> proporties -> general and change target api level to android-25

Put data.zip in android/otclientv8/assets
You can use powershell script create_android_assets.ps1 to create them automaticly (won't be encrypted)

## Useful tips

- To run tests manually, unpack tests.7z and use command `otclient_debug.exe --test`
- To test mobile UI use command `otclient_debug.exe --mobile`

## Links

- Discord: https://discord.gg/feySup6
- Forum: http://otclient.net
- Email: otclient@otclient.ovh
