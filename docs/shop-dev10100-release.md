# Shop release: DEV10100, 2026-10-27

Marcus authorized pushing the approved shop work and deploying its matching
client update. The server and client sources were pushed to their existing
`codex/durable-dev-deploy` and `codex/server-validation` branches. This release
targets DEV; PROD remains version 1006 with its original manifest and bytes.

## Published release

Durable deployment job `21e2ace5-12d5-4552-8eff-0e733b5d320a` completed
`SUCCEEDED` at 08:38:58 UTC. It used the short 60-second warning, a matching
successful native shutdown receipt and exit 0, a database/client backup, a fresh
Debug server build, and manifest-last client publication before starting the new
runtime. Its hold was cleared after the new process passed stability checks.

- Server source: `d4cd097a59f61562fd20a66e7015887aef6ca537`.
- Client runtime source: `455df3b16c80e78e9c214a4239b49899aa8f28b0`
  (subsequent release-smoke tooling/documentation do not change packaged resources).
- DEV login: `testserver2.rookhaven-ot.com:7173:860`.
- DEV updater: `http://updater2.rookhaven-ot.com/api/updater`.
- [Full DEV10100 client ZIP](http://updater2.rookhaven-ot.com/files/dev/Rookhaven-DEV10100-client.zip).

| Artifact | SHA256 |
| --- | --- |
| Running server EXE | `8a0e3fa249706f52800c3738691d9bb26cbaa4c3d47d159875007f2e045365b0` |
| Client EXE | `63995c7deb7b3f109de50623d5d17c61ffa396d6d876107b4bcfb6127528ccec` |
| Encrypted data.zip | `45174ada2976e07012f384bf7772c6d7e8f63eadc14e000c14e2123062f0983c` |
| Full client ZIP | `8c467be0398be570def84afd72da50d41a76897ac98dc9748130b9ee1e750e3f` |

The RH2 resource fingerprint is
`a5ed2b78a1f6d79981f827fd1850e412e877dd6dd0a017a132673c35b67a449e`.
The matching CRC and RH2 pin files were installed with the release. The package
is the static Windows build with the ordinary DEV endpoint, not the earlier
private loopback client.

The shop contains 10 non-outfit offers and 26 gender-specific outfit offers:
Rune Master, Lion of War and the 11 subsequently approved families. Both sexes,
colour masks and both addons are included. Outfit offers cost 250 shop points
each. Native animated previews and Try on retain the retro shop layout.

## Verification

Pre-release checks covered asset preservation, shop transport, purchases,
save/relogin and native UI behavior. Their dependency-based regression selection
and evidence are recorded in
[the outfit implementation report](../assets/outfits/modern-shop-20261027/README.md).
These include 604 shop contracts, 176 real-codec transport checks, 326 native
grant assertions with 212 buy/equip requests, 929 connected client checks, and
three protected-resource acceptance/refusal cases. Existing Quiver/Keyring
purchases and small shop responses were covered as regressions.

The final normal exporter bound the exact deployed Debug EXE and frozen client
package: 1,666 client source hashes, 164 source/bytecode comparisons and 157 CRC
entries passed. Exported client ZIP and both pin files exactly match the staged
and published artifacts. Its manifest SHA256 is
`486c3dbe4c6305e9917822e63a5d1ebe92fdc89fd9aa069868f25e158e1488ea`.
The exporter's `preparedOnly` flag describes that export operation; actual
publication is proven separately by the durable job and public HTTP readback.

Public HTTP readback downloaded and hashed the DEV EXE, data.zip and full ZIP;
all three matched the table. Both public PROD files also retained their original
hashes. The updater offers 10100 to 10099 and reports 10100 up to date.

The real published 10099 client downloaded the new EXE/archive over HTTP,
promoted them and restarted into the verified 10100 native client. Its blank
login window visibly showed version 10100. The native asynchronous bridge and
self-deletion helper exited naturally. All four existing client profile trees
were restored with identical bytes, paths, owners and DACLs, and all owned test
clients were closed. No GUI authentication was performed.

An owned ordinary QA account then authenticated through the normal DEV login
and world route. The four wire cases passed: old 10099 RH2 refused, absent
second RSA block disconnected, QA mode 1 refused, and retail 10100 accepted.
The actual 8,572-byte catalogue arrived through S/E fragments and contained all
36 expected offers, exact IDs/titles/costs, all 26 outfit variants with addons 3,
and the ten existing products. Init/history/init preserved points and status
after normal first-init initialization; history was empty. Normal logout was
sent. This live smoke made no purchases, equip requests or gameplay commands;
purchase/equip behavior was tested on the isolated runtime described above.

Private evidence is retained under `out/release-smoke-20261027/`:
`native-updater-02/` and `live-wire-02.json`. Earlier harness failures are also
retained: the first updater check assumed synchronous deletion, and the first
wire check expected an error packet for a missing RSA block. The checks were
corrected to the native source contracts and rerun successfully; no product
changes or manual deletion were used to make them pass.

The final read-only runtime audit at 08:52:41 UTC confirmed source/EXE identity,
clean tracked source, schema 34, matching pins and all six published artifacts,
unchanged config hash, and the actual checksum enforcement enabled with the
test overlay disabled. The same PID owned both listeners, native readiness was
fresh and stable, the supervisor was healthy, and no hold remained. Current
stdout contained zero errors/warnings and stderr was empty. Independent SQL
confirmed the owned ordinary QA fixture was offline and preserved. The database
backup's completion marker and recorded SHA256 matched. Exit 0 is proven by the
successful pinned worker gate; its raw process exit code was not separately
persisted for this final audit. A pre-deploy server-DLL byte baseline was not
available, and the release changed no DLL paths.

Final smoke-tool regressions passed 5/5, plus Python compilation and the
PowerShell parser. The log reader was subsequently bounded and opened with
shared read/write/delete access; its output matched both retained native logs
exactly, and the parser and five offline regressions passed again. No further
live sessions were needed. Sanitized runtime/publication receipts are retained
under `out/shop-dev-release-10100-20261027/`.

## Operational repairs and limits

The existing updater API had no running process or startup task. Its unchanged
script was restored under the SYSTEM startup task `RookhavenUpdaterAPI`, then
verified through both public API hosts.

The first prepare attempt stopped before admitting a job because the old
maintenance controller had latched `STATE_WRITE_FAILED`. With zero online
players and a verified private database backup, one isolated ordinary
CTRL_BREAK followed the existing save/flush shutdown path. The old process
exited 0, its stderr was empty, and the supervisor restarted the unchanged
release. Genuine readiness remained stable for 60 seconds before the successful
prepare/submit. No readiness state was forged, no live process was force-killed,
and no database was restored. The transient write's exact Win32 cause was not
logged; this recovery is separate from the subsequent deployment receipt.

Private operator receipts and backups remain outside Git. Credentials, database
contents and private configuration contents are not included in this report.
