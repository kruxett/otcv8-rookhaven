# Eleven approved shop outfit families

Marcus selected these families from the original-sprite catalogue on 2026-10-27.
Both sexes use original installed Tibia 15.33 sprites and colour masks. No art
was generated, repainted, rescaled or reconstructed.

| Family | Female look / offer | Male look / offer |
| --- | --- | --- |
| Afflicted | 377 / 6005 | 378 / 6006 |
| Arbalester | 379 / 6007 | 380 / 6008 |
| Arena Champion | 381 / 6009 | 382 / 6010 |
| Armoured Archer | 383 / 6011 | 384 / 6012 |
| Discoverer | 385 / 6013 | 386 / 6014 |
| Entrepreneur | 387 / 6015 | 388 / 6016 |
| Formal Dress | 389 / 6017 | 390 / 6018 |
| Golden | 391 / 6019 | 392 / 6020 |
| Nordic Chieftain | 393 / 6021 | 394 / 6022 |
| Poltergeist | 395 / 6023 | 396 / 6024 |
| Veteran Paladin | 397 / 6025 | 398 / 6026 |

Each offer provisionally costs **250 shop points**, matching Rune Master and
Lion of War. It permanently unlocks the base and both independent addons for
the purchasing character, without requiring premium time. Existing sex,
duplicate, funds and grant-rollback validation applies.

The shop now has 36 offers: 26 gender-specific outfits and the ten existing
non-outfit offers. The four Rune Master / Lion of War offers are unchanged.
Animated native shop previews and the existing read-only Try on window are
reused, retaining the retro client layout.

## Source and import

`import-manifest.json` records original appearance IDs, exact input/output hashes,
source sprite-sheet hashes, displacement, light and animation metadata.
`source/` retains all 5,760 original unmounted idle/walk art and mask layers.

The legacy DAT uses the first source standing pose followed by all eight source
walking poses, as for the previously imported outfits. Mounted patterns, modern
idle animation and source animation timing are not imported into the legacy
client. Source idle frames remain available for future work.

No selected appearance has reverse-addon flags. Golden's original light flag
(brightness 7, colour 206) is preserved alongside its displacement.

The importer is `tools/modern-outfit-tests/import-approved-batch.py`. It refuses
already-installed families and concurrent destination changes. Original/staged
copies and the full import receipt are under
`out/modern-outfits-20261027/import-01/`.

## Completed asset and rule verification

- 19,008 tile-slot pixel round trips passed.
- All 12,294 pre-existing DAT records remain byte-identical.
- All original SPR payload bytes and sprite pointer targets remain intact.
- 7,298 sprites were appended, producing a total of 46,262.
- All 22 reconstructed south/full-addon composites match the approved catalogue
  PNGs byte-for-byte. See `qa/composition-check.json`.
- Source shop/admin contracts: 604 checks passed across all 26 outfit offers,
  covering identity, grant privacy, sex, ownership, funds and rollback, plus
  existing item, spell and admin behavior. The unchanged converter contracts
  also passed 15,217 checks.
- Existing source Try on contracts: 42 checks passed for preview behavior and
  preservation of appearance preferences.

The implementation is complete. Native runtime checks and private package
verification are detailed below. The subsequent coordinated DEV10100 deployment
is recorded in [the release report](../../../docs/shop-dev10100-release.md).

## Expanded catalogue transport

The first connected client check exposed a real size limit: the expanded shop
catalogue exceeds the native server's 8,192-byte string limit. Sending it as one
extended-opcode string produced an incomplete packet and the list never loaded.
Failure evidence is retained under
`out/modern-outfits-20261027/shop-batch-01/`.

`GameShop` now sends larger JSON responses using the client's existing S/P/E
fragment protocol, with 8,000-byte bodies. Small responses keep the original
single-packet format. Fragmentation is local to the shop; the generic opcode,
network, purchase, grant and client reassembly implementations are unchanged.

Changed behaviour → affected existing path → selected checks:

- More outfit records → DAT/SPR and native rendering → byte/pixel preservation,
  native walking previews, all direction/addon/colour selections.
- More shop rows → catalogue transport and existing scroll area → real-codec
  boundaries/reassembly and connected first/middle/bottom-row checks.
- More offers → existing grant and ownership rules → real buy/equip packets,
  refusal/rollback cases, both-sex save/relogin and existing Quiver/Keyring buys.

The native grant run completed 326 assertions and 212 buy/equip wire requests
across the 22 new variants and four existing variants. Its source database and
configuration were unchanged and all owned processes stopped. The transport
correction does not change the tested grant code. Receipt:
`out/modern-outfits-20261027/native-batch-01/result.json`.

## Final connected client and package verification

- Real-codec transport regression: 176 checks passed, including the actual
  8,572-byte catalogue, exact 8,191/8,192/8,193 boundaries, multiple S/P/E chunks,
  Unicode, partial-send failure/recovery, and unchanged small purchase, balance,
  history and error messages. Actual client reassembly code is exercised.
- Connected native client: 929 checks passed across all 26 outfit offers,
  all 26 Try on windows, independent addons, colour changes, movement controls,
  four directions, category reopening and purchase history. Trials never sent
  an equip request, charged points or changed appearance preferences.
- Actual scrolling reaches the last Veteran Paladin offer with visible,
  functional BUY and Try On buttons. Quiver, Keyring and that final outfit were
  purchased; wrong-sex and duplicate purchases preserved points.
- Screenshot analysis confirmed 26 changing, nonblank native previews and all
  104 Try on direction captures. No temporary renderer board was used. The
  malformed-opcode error from the first run is absent from the passing run.
- Owned database/configuration and profile snapshots were preserved/restored;
  all owned processes were stopped. Passing runtime and screenshot evidence:
  `out/modern-outfits-20261027/shop-batch-02/`.

`implemented-native/` contains exact crops and a lossless APNG recording of the
real connected shop. These are screenshots, not painted UI or imported icons.
`capture-manifest.json` identifies their source and crop rectangle.

A fresh private protected executable and archive were built together with
MSVC VS18 and matching LuaJIT bytecode. Verification matched 1,666 source files,
60 runtime hashes and 1,269 archive entries. Decoded protected resources exactly
match the QA resources used for native client checks. Native resource validation
accepted the matching archive and rejected both yesterday's archive and a
modified outfit DAT (three cases passed).

- Protected EXE SHA-256:
  `36e80cb35ff43bd3895264e7fa477639cbee4b630343f88a4ce623ca779eaa79`
- Protected data.zip SHA-256:
  `dd0f30c9d561b6bebe1d9b2cc779cd366df0008fc0550bc455e7e58513074831`
- Private portable package:
  `out/client-shop-native-20261027/protected-client-verified.zip`
- Package receipt and native verification:
  `out/client-shop-native-20261027/protected-verification.json`.

The private protected build keeps a loopback endpoint and existing version; it
was not published. The local validation above did not change live server pins,
updater versions or services. DEV10100 uses a separate static build with the
normal DEV endpoint and matching final server pins, as recorded in the release
report. Historical import receipts are immutable; their original pending-QA
status records the import stage rather than the later release state.
