# Magic Quiver artwork

`sprite.png` is a provisional sprite drawn directly on a 32×32 RGBA canvas with
16 colors including transparency. Alpha is binary 0/255. The reproducible source
is `tools/quiver-tests/draw-native-sprite.py`; `preview.png` uses nearest-neighbour
enlargement for review only. The imported tile is always the original 32×32 PNG.

One built-in imagegen attempt requested a native 32×32 Tibia8.60 leather quiver,
gold rim, arrows and a small turquoise clasp on transparent background,
with crisp pixel clusters and no antialiasing, blur or downsampling. The tool
returned a large concept instead (the saved PNG is 1254×1254). It is retained at
`source/imagegen-concept.png` as a reference; its pixels were not resized or used
in the SPR. One bounded imagegen edit returned a clearer pixel-style reference,
retained at `source/imagegen-native-reference.png`. The earlier DEV10091 tile
used brown leather and visible arrows. The DEV10092 tile has an empty
dark opening, indigo leather, aged gold rim and heel, two leather cross-bindings,
a cyan gem and connected cyan rune, and a loop strap on the right. Its upper/left
details leave the lower-right area available for the inventory ammunition count.

The current DEV10093 tile moves these same pixels one pixel left and three
pixels up. Its alpha bounds are `[4,4,28,28)` (exclusive maximum), with four
transparent pixels on every side. All 359 opaque pixels and the 16-color palette
are preserved; the sprite is not resized or redrawn.

The new `source/imagegen-empty-magic-reference.png` is a 1254×1254 generated
reference for color and form only. The current tile is drawn directly with
native integer geometry; none of the generated images is downsampled into the
game sprite. This remains a provisional 32×32 interpretation. The native PNG
SHA-256 is `7639464fd8f6ca61ca2f01b7e5f22254e8c64274ae1a7fce27f975d0fc5bd78b`.

The drawing script writes only `sprite.png` and `preview.png`; it does not rewrite
the item definition or any imported DAT/SPR/OTB files.

`definition.json` is the input for the existing rookhaven-items staging script.
The current DEV10093 mapping is SID 12830 → CID 11867 → sprite 36662. DEV10092
used sprite 36661; DEV10091 used 36660. The
[centering stage manifest](C:/GitRepos/kruxett/otcv8-rookhaven/out/item-work/magic-quiver-centred-20261010/staged/manifest.json)
records this artwork replacement. Bag 1987 supplies static container/pickupable DAT
attributes and container/nonstackable OTB flags. The existing hunter's quiver
SID 12425 remains an unrelated, stackable Garrick quest item.

For runtime, shop, release evidence and test commands, see
`docs/magic-quiver.md`. DEV10091's verification history is retained there;
DEV10092 is published. Focused local native verification, the real DEV updater
and the read-only live probe passed. Equipped-counter gameplay was verified in
the disposable loopback runtime; the live probe checked the ordinary character's
unequipped counter state, inventory and actual shop icon.
DEV10093 centering is published and verified in the actual native inventory,
container and shop at both window sizes. The real DEV10092→10093 updater and
two read-only live logins passed; equipped count images remain loopback evidence.
See the [actual before/after crops](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-centering-20261010/visual-analysis/centering-before-after.png)
and [final evidence index](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-centering-20261010/final-dev10093-verification.json).
