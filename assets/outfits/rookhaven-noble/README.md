# Rookhaven Noble outfit proposal

Artwork exploration only. No outfit IDs, DAT/SPR imports, outfit permissions,
shop offers or gameplay changes have been implemented.

The user requested the next shop content and explicitly asked to use existing
outfits as references. The actual native Nobleman (looktype 132), Noblewoman
(140), male Citizen (128) and female Citizen (136) sprites were extracted from
the current client files. Source IDs, input hashes, layouts and per-view hashes
are recorded in `source/reference/native-outfit-references.json`.

Those outfits use 2×2 32-pixel tiles, two layers, four directions, three addon
patterns and three animation frames. The reference images show addon 0,
idle frame 0, base layer with neutral white tint. Tile order matches the actual
client `ThingType::getSpriteIndex` and rendering order. The comparison sheet is
enlarged only for inspection. The source outfit images are not rescaled.

Nobleman and Noblewoman are already Premium-unlocked in the current server's
`data/XML/outfits.xml`. The new proposal is a distinct costume using their
native proportions, pixel density and oblique camera: navy coat, ivory shirt,
short burgundy shoulder mantle, restrained copper trim and brown boots.

The male south reference has a 33×33 visible body on its native 64×64 frame.
For PixelLab it is translated, without scaling, into a 48×48 reference canvas.
The generated male south pose is a first design proposal. Approval of this
pose does not establish the remaining direction, walk-frame, outfit-mask or
client integration requirements. The female version will use the corresponding
existing female references and matching costume direction after the male style
is settled. Both shop purchases remain separate, as requested.
