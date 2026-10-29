# Passive-tree pixel art

The six current talent catalogs contain 29 nodes each. Their 174 approved
PixelLab icons have separate runtime paths, so each talent has its own image
without changing saved node IDs, ranks, prerequisites or gameplay formulas.

## Approved talent artwork

- The 174 PNGs live at
  `data/images/game/passives/talent_<tree>_<node-id>.png`.
- `assets/passives/talents-manifest.json` records every catalog key, runtime
  path, SHA-256, visible-pixel hash, color count and PixelLab provenance.
- Each tracked runtime PNG is also its canonical authoring source. No second
  copy or hand-authored palette grid is required to preserve this artwork.
- Most glyphs were generated at native 28×28 and padded unchanged to 32×32.
  The approved Aftershock refinement was edited at native 32×32; its original
  pixels and transparent margin were preserved without resampling.
- Every PNG is 32×32, uses binary alpha, and keeps a transparent two-pixel safe
  border. Most use at most 24 opaque colors; the approved Aftershock uses 50.
  Fourteen colors was a constraint of the older drawing tool, not the engine.
- OTUI renders glyphs at 32×32 with `image-smooth: false`. Frames, rank text,
  locks, selection borders, connectors and disabled opacity remain separate UI
  elements. Do not bake them into the art or shrink the glyph to make room.
- The style uses compact readable forms, dark contours, shaped material
  shadows and selective highlights. These PNGs do not change DAT, SPR, OTB or
  the default spell atlas.

The server catalog builder in `data/lib/passives/test.lua` selects
`/images/game/passives/talent_<treeId>_<nodeId>` for every node. The existing
client reads that image path directly; no extra client mapping is involved.
Only the icon field changes. Node IDs and their saved-rank order remain stable.

## Legacy artwork and spell consumers

The original 108 PNGs remain byte-identical under
`data/images/game/passives/`: 102 older node icons and six tree emblems.
Their `assets/passives/manifest.json` and
`assets/passives/pixel-sources/<icon-id>.json` files still describe the
original native pixel grids.

Twelve class spells use eleven of those older image paths. For example,
`major_pressure` supplies both Cleaving Arc and Scattershot,
`minor_power` supplies Essence Lash, and `cap_bloodletting` supplies Rend.
The new talent filenames keep those spell cards unchanged. Replacing a legacy
PNG would also replace every spell illustration that references it.

`tools/render-passive-icons.py` remains the renderer for those legacy 108
palette-grid sources only:

```powershell
python tools/render-passive-icons.py
```

Its 14-color validation and original contact sheets apply to the legacy art,
not the new PixelLab talent set. The renderer does not regenerate the approved
talent PNGs. Avoid `--author` unless intentionally replacing the legacy grids.

## Import and verification

`tools/passives/import-talent-icons.py` verifies the current tracked talent
PNGs, their catalog paths and preservation of the legacy spell art. Supply an
existing standalone Lua51 DLL to evaluate the pure catalog tables; it starts
no game server, client or database:

```powershell
python tools/passives/import-talent-icons.py --lua-dll "C:/path/to/lua51.dll"
```

The explicit `--write` mode imports the approved study selections, writes the
manifest and changes only the catalog icon expression. Its initial import
compares the full pre/post six-tree catalog, permitting only the 174
`node.icon` changes, and checks all 108 legacy PNGs and the class-spell config
for byte preservation. It copies the selected 32×32 PNG bytes exactly.

PNG/hash checks establish asset integrity. Real-client inspection separately
checks native-size legibility, rank overlays, disabled/selected states,
scrolling and the compact retro layout. An offline contact sheet is not an
in-game screenshot, and artwork validation does not establish combat balance.

Adding packaged PNGs requires a matching rebuilt client executable/archive.
Follow `docs/client-resource-integrity.md` for package verification and a
coordinated release; a source import alone does not publish an update.

## Local native verification, 2026-10-28

All six trees were inspected in a real connected loopback client using server
catalogs and legal test presets. All 174 catalog image paths resolved to the
approved PNGs; glyphs and loaded images remained 32×32 without smoothing.
Rank text, lock markers, selection frames, scrolling and catalog refresh on
reopening passed at the existing retro layout, including 800×600.

The run saved 30 original framebuffer screenshots. The private archive was
checked against all 174 source PNG hashes and current passive-module files.
The test overlay stopped and the client logged out normally; the source
database/config and existing test profile were preserved, and owned processes
were stopped. This checks artwork and UI presentation, not combat balance or
a published client update.

The approved 174 icons and matching server catalog paths were subsequently
published in [DEV10101](dev10101-release.md), 2026-10-29. Current PNG preservation,
catalog metadata and package equality were rechecked for that release. The
October 28 screenshots remain the six-tree native art/UI inspection evidence.

Local evidence is under
`out/passive-icon-study-20261028/native-01/`: `native-examples.html`,
`result.json`, `passive-icons-native-receipt.json` and
`final-native-verification.json`.
