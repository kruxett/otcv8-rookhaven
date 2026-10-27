# Rune Master and Lion of War

Selected by the user after rejecting the OTSP Acolyte trial. Imported locally
from the existing installed official Tibia client; artwork was not generated,
painted, rescaled, or reconstructed. These are CipSoft assets, not CC BY assets
from the OpenTibia Sprite Pack. The appearance schema reference is
https://github.com/opentibiabr/otclient/blob/main/src/protobuf/appearances.proto.

| Family | Sex | Source appearance | Rookhaven looktype | Shop offer |
| --- | --- | ---: | ---: | ---: |
| Rune Master | Female | 1385 | 373 | 6001 |
| Rune Master | Male | 1384 | 374 | 6002 |
| Lion of War | Female | 1207 | 375 | 6003 |
| Lion of War | Male | 1206 | 376 | 6004 |

Each offer costs a provisional 250 points and permanently unlocks the base and
both independent addons for that character, without requiring premium time.
There are now fourteen offers: the ten existing shop products plus these four.
Server-side sex, ownership, duplicate and insufficient-points checks remain in
the existing shop grant path. Failed grants restore prior addon ownership.

Current shop presentation uses animated, rotating native 64x64 UICreature views
inside 88px retro rows. Item rows retain their existing styles. Try On opens the
existing outfit window with local colour, addon, direction and movement controls;
it never equips, charges, or saves appearance preferences. The test-store banner
was removed. The current real shop recording is
`implemented-native/shop-native-recording.gif`; the real trial window is
`implemented-native/shop-native-tryon.png`. Earlier all-angle boards are historical
QA art-review panels, not shop UI. Renderer regression panels exist only in the
injected QA driver and are destroyed before the test client exits.

The 8.60 conversion uses source idle group phase zero as its standing pose,
then all eight original walking frames. Original four-direction art, addon
layers, tint masks, per-outfit displacement and bounding size are preserved.
Modern animated idle effects, source timing and mounted patterns are not part
of this legacy import. Raw appearance records and imported art/mask PNGs are
retained in `source/`. Input/output hashes are in `import-manifest.json`.

Verification actually completed:

- All 3,456 imported tile slots compared against source pixels. All 12,290
  existing DAT records remained byte-identical; original SPR payloads retained.
- Source shop/admin contracts: 193 checks passed, including real catalog
  identity, price/grant privacy, all four outfit grants, wrong sex, duplicates,
  failed-grant rollback and existing item/spell purchases. The reused runner
  also passed the unchanged 15,217 converter contract checks.
- Current source-matched native server: 57 assertions and 34 actual buy/equip
  wire requests passed, covering all four variants and addon masks 0/1/2/3,
  colours, restrictions, Quiver purchase and save/relogin. Engine match covers
  all 178 current native server source files. Report:
  `out/modern-outfits-20261026/native-02/result.json` in the repository.
- Connected local client: bought/equipped both male variants; rendered four
  variants in every direction and addon state; walked and returned; displayed
  all four actual shop rows. Screenshots are in `implemented-native/`. Report:
  `out/modern-outfits-20261026/ingame-02/result.json`.
- Owned database copies/processes stopped and original profile/database restored.

The earlier graphics-only `run-ingame-visual.py` used a matched older QA executable
pair for rendering; current server behavior was checked separately. Its boards are
temporary panels using the native UICreature renderer, with animation disabled.
World/shop screenshots use the normal retro interface. These checks do not
certify a newly built protected executable/archive or a DEV deployment.

The import exposed an existing UI animation boundary bug: a legacy nine-phase
outfit (standing + eight walking phases) tried to draw UI phase nine, outside
0..8. `src/client/outfit.cpp` now excludes the standing phase from the UI loop
and retains phase zero for single-frame appearances. World drawing and classic
three-phase player animation retain their previous behavior. This small C++
change has now been compiled and verified in a fresh current QA client. Longer
legacy UI walks are capped to a one-second cycle while classic two-phase timing
and world gait remain unchanged. A private build on the verified Windows build
host used VS18, matching LuaJIT 2.1 and dynamic dependencies. Provenance:
`out/client-shop-native-20261026/qa-client/package/build-receipt.json`.

Current shop acceptance, after the user requested the proper native presentation:

- `run-ui-contracts.py`: 42 actual-source preview checks, including no profile or
  equip writes, normal outfit acceptance, and stopped/replaced floor timers.
- `run-shop-visual.py`: 124 native UI assertions passed with the fresh QA client
  and current source-matched server. Covered the actual shop rows, layout,
  category switching/reopen, both trial windows, addon/colour/direction/movement
  controls, no trial charge/equip/save, buy cancel/confirm, Quiver and Keyring,
  wrong-sex and duplicate refusal, and purchase history.
- `check-shop-animation.py`: each of four outfits displayed all eight distinct
  native walking images with no blank frames. Static looktype126 remained one
  image, Citizen128 retained two walk images, and decorative10/17/26 animated
  correctly. Report: `out/shop-outfit-preview-20261026/native-03/animation-result.json`.
- All owned processes stopped; source database/config and original profile
  restored. No protected retail build, publication or live restart occurred.

The first capture run exited before its asynchronous PNG encoders finished;
the driver now checks PNG completion before exiting. A renderer probe initially
used one-direction looktype1 while facing south; the static test now uses a
valid four-direction appearance126. These were probe issues, not outfit defects.

Initial fixture failures were repaired before the passing runs: the two-client
wire driver had a response-check timeout shorter than its combined socket wait;
the visual fixture used an unavailable namespaced world-light function. A
transient SPR copy failure during the first import was recovered by restoring
all pre-import assets before the successful fresh import-02 run.
