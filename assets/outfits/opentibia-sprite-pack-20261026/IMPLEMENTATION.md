# Acolyte: rejected and rolled back

**Current status:** the user rejected both outfits as unsuitable for Rookhaven.
The local DAT, SPR and server outfit XML now match their exact pre-import hashes;
shop offers 6001/6002 and the empty Outfits category have been removed. The ten
other shop offers remain. Source shop/admin contracts passed 165 assertions after
the removal; retained generic outfit tests use private fixtures. Runtime credits
were removed with the unused graphics. No release or live database was changed.
See `out/outfit-otsp-20261026/removal-01/result.json` in the repository.

The following documents the earlier trial only. Its screenshots, sources and
native test evidence are retained as history and are not active game content.

User selected source outfit IDs 20 and 21 for a local import trial. Each source
ID contains one complete outfit: four directions, three animation frames,
base plus two independent addons, and native colour masks. The upstream
DAT/SPR does not name genders. Rookhaven assigns 20 to female (looktype 373)
and 21 to male (looktype 374) based on their visual designs.

The art and masks are unchanged. Female footwear retains its fixed source
colours; the male mask also has the native footwear colour region. Shop offers
6001 and 6002 cost a provisional 250 points each, unlock the corresponding
outfit and both addons permanently for that character, and require no premium
time. Wrong-sex and duplicate purchases are refused without charging points.

Import verification compared all 576 sprite slots against the source, retained
12,290 unrelated DAT records byte-for-byte and preserved all original SPR
compressed payloads. See `import-manifest.json` for hashes and mapping.

Checks actually run, with results under the repository's `out/` directory:

- `tools/magic-gold-converter-tests/run-contracts.py` using its existing native
  Lua runtime: shop/admin contract 159 assertions passed; unchanged converter
  contract 15,217 assertions also passed.
- `tools/outfit-tests/run-native.py`: 24 current source-matched native server
  assertions passed, including real purchase/equip packets, insufficient points,
  wrong-sex and duplicate refusal, failed-grant rollback, an existing Quiver
  purchase, and both characters' save/relogin persistence. Result:
  `out/outfit-otsp-20261026/native-01/result.json`.
- `tools/outfit-tests/run-ingame-visual.py`: a real loopback client connection,
  male outfit purchase/equip, female NPC, all four native rendered directions,
  and two shop offer widgets passed. Original profile and database were restored;
  owned processes stopped. Result: `out/outfit-otsp-20261026/ingame-02/result.json`.

Screenshots in `implemented-native/` come from that connected local client.
The directions image uses a temporary QA panel with the game's UICreature
renderer. The world and shop images use the normal retro UI. The visual runner
uses a matched older QA client/server executable pair; current server behavior
was tested separately against the engine matching all 178 current native source
files. These are local checks, not certification of a protected distributable.
No new client build, DEV upload, live server restart or public release was done.

Runtime credits are included under `data/credits/opentibia-sprite-pack/` with
the upstream AUTHORS and CC BY 4.0 license. Source commit:
`ae88e1828671b349e729dd21177dde15ea41e123` from
<https://github.com/peonso/opentibia_sprite_pack>.
