# Local passive-tree pixel art

This is the original art for six standalone local admin trees. The artwork
uses the existing retro equipment/spell language; final appearance and balance
still require review in the actual client and user feedback.

## Runtime contract

- 108 runtime PNGs at native 32×32: 102 node icons and six tree emblems.
- Reaver keeps its original 17 `<node-id>.png` files and `reaver.png` unchanged.
- Blademaster, Earthshaker, Marksman, Arcanist and Lifekeeper each have 14
  `<tree>_<minor-or-major-node-id>.png` files, three `cap_<capstone>.png` files
  and one `<tree>.png` emblem under `data/images/game/passives/`.
- Render icons at 32×32 with `image-smooth: false` in OTUI.
- Node frames, rank text, lock/selection states and connectors are separate UI
  elements. Do not bake them into or shrink the icon.
- A transparent two-pixel border keeps the glyph inside the 28×28 safe area.
- Every pixel has alpha 0 or 255. Each icon uses at most 14 opaque palette colors.

Original native pixel primitives use dark contours, steel, muted bronze,
blood-red and restrained blue/green. The existing default spell atlas and
classic equipment panels were inspected as style references. No reference
pixels were copied. These icons do not change DAT, SPR, OTB or the spell atlas.

## Sources and regeneration

`assets/passives/pixel-sources/<icon-id>.json` holds an explicit 32-row palette
grid, its palette and semantic purpose. `assets/passives/manifest.json` records
tree membership, runtime/source paths, dimensions, color counts and SHA-256
hashes for both the JSON sources and rendered PNGs.

```powershell
python tools/render-passive-icons.py
```

The default command renders and validates the checked-in grids. With
`--author`, the original native-size primitives in the script regenerate the
grids first. Do not use `--author` after hand-editing a grid unless intentionally
replacing that edit. The renderer uses Pillow and writes only passive assets.

## Inspection artifacts

- `assets/passives/previews/<tree>-native-contact.png`: each tree's 18 glyphs at
  actual 1× size, including its emblem.
- `assets/passives/previews/<tree>-diagnostic-4x.png`: nearest-neighbour
  magnification for inspection only; never a runtime source.
- `assets/passives/previews/all-capstones-native-contact.png`: all 18
  capstones and six weapon-tree emblems at actual 1× size.
- `assets/passives/previews/all-capstones-diagnostic-4x.png`: the same overview
  enlarged for individual-pixel inspection.

The sheets were visually inspected during creation. The production glyphs
are generated directly at 32×32, with no antialiasing or high-resolution
downsampling. Inspect them again in the final client at normal UI scale:
contrast, legibility, borders, rank labels and disabled/selected states depend
on the surrounding window.

## Icon meanings

The shared manifest is the detailed meaning/palette source. The capstones use
especially distinct silhouettes:

- `cap_berserker`: horned battle mask and paired axes.
- `cap_bloodletting`: three bleeding cuts across steel.
- `cap_bloodguard`: steel shield containing a blood-red heart.

Precision and critical damage use distinct target/edge markings. Power uses a
clenched leather gauntlet for Reaver and weapon impact for the other trees;
healing uses a heart; recovery uses blood and living leaves; focus uses a blue
mana crystal. Guard and resilience use different shield geometry and central
details. Shared HP/mana/guard motifs intentionally reuse the same native
pixels; each tree still has independent source and runtime files for future
art changes. Offensive motifs and emblems distinguish sword, club, bow, wand
and rod. Lifekeeper replaces critical-chance/critical-damage motifs with
mending hands and a growing flower for its direct-healing nodes.

The five additional capstone sets have independent silhouettes:

| Tree | Capstones and visual motifs |
| --- | --- |
| Blademaster | Duelist: finishing blade; Riposte: returning blade and shield; Bladestorm: crossed sweeping blades. |
| Earthshaker | Aftershock: club with impact rings; Stoneguard: masonry wall; Stonebond: three linked shields. |
| Marksman | Deadeye: eye and focused arrow; Skirmisher: two arrow bounces between three targets; Quarry: marked beast. |
| Arcanist | Conduit: linked lightning orbs; Resonance: central rune with echo arcs; Spellweaver: three elemental threads. |
| Lifekeeper | Renewal: living leaves around a heart; Aegis: blue shield and healing cross; Concord: three joined mending hands. |

## Validation and limits

The renderer checks every grid and PNG for exact dimensions, palette coverage,
binary alpha, a maximum of 14 opaque colors and the transparent safe border.
All 108 icons pass these checks. Reaver's 18 PNG SHA-256 values were compared
against the original manifest and are identical.

Contact-sheet inspection verifies native silhouettes and enlarged pixel
construction. It does not prove their final in-game layout, rank overlays,
disabled states or gameplay effects; those are checked by the native client
and server integration probes separately.
