# Client resources and removal of the built-in bot

The distributed Rookhaven client loads executable resources only from its
matching `data.zip`. The entire `game_bot` tree, bundled CaveBot/vBot scripts,
terminal module and their icons are removed. There is no build option that
re-enables the bot. The legacy bot feature and item-ID context-menu branch are
also removed. Normal hotkeys, inventory actions and map click walking remain.

## Native enforcement

`tools/client_resource_manifest.py` builds a deterministic list of every packaged
resource. Lua scripts are measured as the exact LuaJIT bytecode shipped by the
build. Paths, decoded sizes and SHA-256 hashes are compiled into the executable.
Adding, removing or changing a resource therefore requires rebuilding it.

Before mounting an archive, C++ verifies its complete file set and decoded
contents. Extra/renamed modules, missing or changed files, duplicate paths and
path aliases are rejected. ENC3 header and decompressed sizes are bounded before
decryption. Encrypted bytes are not treated as proof of authenticity.

Normal startup uses the archive beside the executable, without searching the
current directory, ancestors or writable profile for code. Module/script loading
also requires a manifest entry from the verified in-memory archive. Profile
settings and minimap files remain writable. Loose files cannot override approved
bytecode, and `/mods` is no longer a discovery root.

The distributed build rejects `--test`, `--run-script` and `--local-passives`.
The chat `/lua` evaluator, terminal and filesystem/native Lua module loaders are
removed. Optional `progdn32.dll` and `lua51.dll` preloading is removed.

`--verify-resources` performs the same native archive check without opening the
game or executing Lua; success is exit code 0. A QA build cannot certify a
distribution. `--isolated-profile` starts the ordinary protected client with a
separate diagnostic profile, no updater and the local fixture endpoint; it does
not authorize additional scripts or bypass verification.

## Server compatibility and its limit

Game login now requires RH2 and two 128-byte RSA blocks. Credentials retain their
original block capacity. The second block carries a build mode and SHA-256 of
`RH2|resourceFingerprint|executableSha256|challengeTimestamp|challengeRandom`.
The server measures that claim against its own two-line
`data/client_integrity_expected.txt`. Missing/malformed pins, missing blocks,
wrong markers, wrong challenges and incompatible builds are rejected.

This is a compatibility gate, **not remote attestation**. Hashes are public and a
modified client or a custom protocol implementation can reproduce the claim.
An unchanged official executable rejects injected module files; that does not
prove that an arbitrary process on a player's computer is bot-free. External
automation, modified binaries and process injection are outside this guarantee.
Gameplay permissions and limits must continue to be enforced by the server.

The old `enforceClientChecksums` setting does not disable RH2. The old eight-file
CRC manifest remains an artifact inventory only; it no longer authorizes login.

## Builds, tests and publication

Use `tools/build-dev.ps1` for the distributed client. It refreshes staging to
remove deleted resources and emits `client_integrity_expected.txt` beside the
final executable/archive. Rebuilding the executable can change its hash even
when resource contents stay identical: always take the pin from the final build.

`tools/build-local-passives.ps1` explicitly builds with `ROOKHAVEN_QA_CLIENT=ON`.
That executable supports instrumented Lua probes, but native game/login
connections accept only literal loopback addresses without proxies. Server QA
mode also requires `passiveTestEnabled`, a loopback-only bind and a loopback peer.
Never distribute this QA executable. The historical helper names do not require
running the passive suite.

For a coordinated release:

1. Build and verify the final distributed executable and full archive together.
2. Export the release with `tools/passives/package-dev-release.py`; it now runs
   native verification and includes the matching RH2 pin as a separate artifact.
3. Publish the executable and complete archive through the existing updater.
   Resource-only updates with changed contents require the new executable too.
4. Deploy the RH2 server and that release's `client_integrity_expected.txt`
   together under the normal maintenance workflow. Older clients cannot log in.
5. Verify the public updater, normal login and live version after publication.
   Roll back the client pair, server binary and compatibility pin together.

No DEV or PROD deployment is part of the local implementation verification below.
The planned client version is DEV10098. Do not deploy a server pin copied from a
QA build or from an earlier build of the executable.

## Repeatable checks

From the client repository, with the configured Python/LuaJIT tools:

```powershell
python tools/tests/client-manifest-generator.py --luajit <luajit.exe>
python tools/tests/client-resource-integrity.py --package <distributed-package> --output <new-results-directory>
python tools/tests/client-login-integrity.py --runtime out/local-server/passives-runtime --output <results.json>
./tools/run-passives-probe.ps1 -Script client-no-bot-native.lua -Success CLIENT_NO_BOT_NATIVE_OK
```

The resource test uses the pre-removal bot from commit `27a8b5d`, or an explicit
`--bot-source` directory. It never executes that code. The wire test accepts only
127.0.0.1:7175 and the disposable fixture credentials; its positive case also
demonstrates why a reported build hash is not remote attestation. Run it again
with `--qa-disabled` after restarting the fixture with its test flag disabled.
Do not run competing probes on the same fixture character. Preserve and restore
the stopped disposable database and probe profile.

## Verification, 2026-10-14

- Distributed Windows client, QA client and native server build successfully.
- Manifest generator: six checks pass for deterministic bytecode, stable outputs,
  added/removed files, forbidden bot source and duplicate source/bytecode paths.
- Native resource validator: 20 cases pass, including the full restored bot,
  renamed modules, altered bytecode, duplicate/traversal paths, malformed ENC3,
  missing/corrupt packages and forbidden command-line execution modes.
- Normal protected-client startup with injected loose files and profile files
  continues using approved resources; the injected marker never executes.
- Server wire regression: 13 cases pass with the QA exception disabled and 13
  with it enabled. Missing, malformed and ambiguous server pins are covered.
  Old/stock packets and wrong markers, sizes, modes, hashes and challenges are
  rejected; matching proofs are accepted. Disabling the old checksum setting
  does not disable RH2 enforcement.
- An unmodified upstream OTCv8 executable from commit
  `aacfe3f1fe4bcadb5a34ff1f36263e1c96b3dd32`, with its bot module present,
  is refused by the loopback server. Only its local test startup script and item
  data are configured; its executable and protocol implementation are unchanged.
- Native QA integration passes character-list/game login, normal chat, disabled
  `/lua` evaluation, inventory look, hotkeys/options, retro layout, map autowalk,
  return movement and logout. The protected retail startup is tested separately.
- The final protected client also logs in through its real account and character
  dialogs while the server's QA exception is disabled. Native mouse/keyboard
  input opens a bag, opens/closes hotkeys, moves the character by clicking the map,
  and logs out successfully. No injected Lua driver is used for that session.
- The existing NPC native regression passes multiline greetings, thread answers,
  trade window, emotes, walk-away/re-entry and Torvind's seven-line response.
- A separate updater test using a local HTTP server was blocked by automatic tool
  approval with only `blocked by policy` supplied. It was abandoned. A real
  updater transition and live-server smoke remain release checks; local package
  verification is not a substitute for those checks.
- Local test processes are stopped. The disposable database (539 files) and the
  pre-existing probe profile (315 files) are restored with matching SHA-256 hashes.

This change does not alter combat or passive formulas; no full passive suite was
selected. Compilation retains existing compiler/dependency warnings. Initial
upstream-client test setup lacked fonts/things modules; the clean rerun loads
those dependencies and confirms refusal without those setup errors.
