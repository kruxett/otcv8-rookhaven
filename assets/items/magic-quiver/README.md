# Magic Quiver artwork

`sprite.png` is a provisional sprite drawn directly on a 32×32 RGBA canvas with
15 colors including transparency. Alpha is binary 0/255. The reproducible source
is `tools/quiver-tests/draw-native-sprite.py`; `preview.png` uses nearest-neighbour
enlargement for review only. The imported tile is always the original 32×32 PNG.

One built-in imagegen attempt requested a native 32×32 Tibia8.60 leather quiver,
gold rim, arrows and a small turquoise clasp on transparent background,
with crisp pixel clusters and no antialiasing, blur or downsampling. The tool
returned a large concept instead (the saved PNG is 1254×1254). It is retained at
`source/imagegen-concept.png` as a reference; its pixels were not resized or used
in the SPR. One bounded imagegen edit returned a clearer pixel-style reference,
retained at `source/imagegen-native-reference.png`. The final provisional tile
is reproduced directly with native integer geometry: brown diagonal tube, bold
gold mouth and bottom cap, two leather cross-bindings, four white-fletched arrows,
turquoise clasp in gold and a loop strap on the right. Neither generated image
is downsampled into the game sprite. This remains a provisional 32×32
interpretation, rather than the high-resolution concept itself.

The drawing script writes only `sprite.png` and `preview.png`; it does not rewrite
the item definition or any imported DAT/SPR/OTB files.

`definition.json` is the input for the existing rookhaven-items staging script.
SID 12830 → CID 11867 → sprite 36660. Bag 1987 supplies static container/pickupable DAT
attributes and container/nonstackable OTB flags. The existing hunter's quiver
SID 12425 remains an unrelated, stackable Garrick quest item.

For runtime, shop, release evidence and test commands, see
`docs/magic-quiver.md` once the integration run is recorded there.
