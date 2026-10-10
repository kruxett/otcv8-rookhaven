# Magic Quiver artwork

The user-approved sprite is PixelLab candidate **#60** (provider index 59), generated natively at **32×32** through PixelLab MCP. Its original PNG is `source/pixellab-frame-59.png`; `sprite.png` contains identical file bytes.
SHA-256: `8b72631bffe15acea1358e7918d6ec845429f5e9225763279bbe86ae21eac198`.

It has binary alpha, 439 opaque pixels and 49 colors including transparency. Visible bounds are `[4,1,29,31)` (exclusive maximum). No pixels were resized, redrawn or recentered. `preview.png` is enlarged with nearest-neighbor sampling for review only; the importer always uses the original 32×32 sprite.

PixelLab object: `67f3d67b-cea2-4837-9241-f6a2d52d5312`.
Generation prompt:

> Empty magic quiver in Tibia art style. Diagonally tilted from bottom-left to top-right, long broad tapered indigo leather body, small dark hollow opening, aged gold rim and base, bright cyan enchanted gem and a small cyan rune, thin brown shoulder strap behind the body. Crisp pixel shading and a clear dark outline. No arrows or ammunition.

The DAT/SPR/OTB import maps **SID 12830 → CID 11867 → SPR 36664**. The replacement appends a new sprite and preserves unrelated records. Bag 1987 supplies the static container/pickupable DAT attributes and container/nonstackable OTB flags. `definition.json` retains the 20-place ammunition container, ammo slot and normal ammunition consumption. Shop price remains 150 points. Existing hunter's quiver SID 12425 remains an unrelated, stackable Garrick quest item.

Earlier imagegen concepts and `tools/quiver-tests/draw-native-sprite.py` are historical references. They do not reproduce this approved sprite and must not overwrite it. A source preview is not evidence of its actual game appearance. For native screenshots, release status and test commands, see [Magic Quiver documentation](../../../docs/magic-quiver.md).
