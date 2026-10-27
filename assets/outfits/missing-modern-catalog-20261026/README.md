# Missing player outfit catalogue — 2026-10-26

This catalogue is for choosing additional shop outfits. It changes no game,
DAT/SPR, server configuration, shop offer, account or player state.

## Scope and comparison

The installed official Tibia package is **15.33.c9e45e**. A combined named-player
registry contains 136 male/female outfit families. Its unordered sex ID pairs
match an independently read complete current Outfit IDs table exactly.

Rookhaven already has 26 enabled, registered families with nonempty local art,
including Rune Master and Lion of War under their Rookhaven look IDs. Therefore
the catalogue contains **110 missing families / 220 sex variants**. Of these,
102 have two independent addon rows; Jersey and seven Retro families have none.

NPCs, monsters, staff looks and temporary disguises are outside this catalogue.
This is an inventory of this installed source version, not a claim about assets
released after it. See `audit/inventory-audit.md` for source conflicts and checks.

## Original sprites

Every preview uses original installed sprite pixels and exact color masks.
There is no generated art, repainting, mirroring, inferred pose or resizing in
the extracted source media. The browser uses integer nearest-neighbour scaling.
All four directions, separate addon selections and all original walking phases
are available for both sexes. The still mode shows the first original idle pose.
Lossless APNG timing is illustrative, not a promise about in-game movement speed.

Color indices are the same for every variant: head 58, body 49, legs 2, feet 58.
Actual in-game color selection remains a separate feature of the existing client.

Modern reverse-addon flags are mapped from the primary protobuf (49 east,
50 west, 51 south, 52 north). Their documented semantics put addons under the
base. The catalogue reverses selected rows including the base accordingly.
Exact relative order between addon 1 and 2 is a documented inference; it has not
been proven against the official renderer. This affects 27 looks in at least
one direction, and only male Captain and male Illuminator in the default south
view. See `audit/reverse-addons/` for evidence and affected IDs. Importing a
selected outfit requires a separate client verification.

## Files and reproduction

- `index.html` and `catalog.js`: complete interactive catalogue, usable together
  locally or via a local HTTP server. Search by name, number or look ID; compare
  both sexes, directions, addon modes and walk animation. Selections are local.
- `catalog.json`: full named catalogue, source IDs and media paths.
- `media/`: 3,520 PNG stills and 3,520 lossless APNG walking previews.
- `render-manifest.json`: source hashes, sprite-sheet hashes, geometry and phases.
- `qa/`: targeted data and presentation checks.
- `audit/`: original source snapshots and the presence comparison.

Build read-only catalogue assets with:

```powershell
python tools/modern-outfit-tests/build-missing-catalog.py
```

Primary registry: https://github.com/opentibiabr/canary/blob/main/data/XML/outfits.xml

Independent complete ID table: https://exetares.wiki/Outfit_IDs

## Verification actually run

- All 7,040 final media references exist; no empty exported source frames.
- South/full stills match the earlier independent atlas byte-for-byte for
  218 variants. The two differences are the documented male Captain and
  Illuminator reverse-addon corrections.
- 48 final APNG animations / 384 decoded frames match source-composited RGBA
  exactly. Initial GIF color quantization was detected and fixed by APNG.
- Browser checks covered all 110 families through pagination, name/number/ID
  search, male/female previews, all addon modes, all four directions, animation
  switching, saved selection, and the eight families without addons.
- Responsive checks passed at 736 and 320 pixels with integer sprite scaling;
  zero observed console errors or broken image elements. See `qa/browser-qa.json`.

No in-game import was performed or tested for these catalogue candidates.
