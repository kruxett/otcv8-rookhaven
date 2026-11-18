# House images from the actual client

`native-client.lua` captures the client's native map framebuffer. It logs in to
an owned loopback copy, visits each house's authoritative native tile bounds,
shows that exact floor, and hides only the local photographer's outfit and UI
annotations. The source map/sprites render normally; these are not reconstructed
or generated images. Owners, player decoration and live DEV are not used.

The existing isolated account test runner supports this capture mode:

```powershell
python tools/account-service-tests/run-native.py --output <new-owned-output> `
  --engine <current-QA-server.exe> --dll-directory <QA-server-directory> `
  --rsa-key <private-QA-key> --client <loopback-QA-client-directory> `
  --encoder <QA-overlay-encoder> --house-market --house-ui-only --house-photos
python tools/house-photos/export.py <new-owned-output> --install
```

The server helper is copied only into that disposable runtime. It checks the
server name, loopback connection, fixture character and normal group. It provides
temporary guest access there, never changes house ownership, and is never copied
to the game server source data or a release. Profile/source-copy restoration and
process cleanup are handled by the existing runner. `--house-photo-limit 3` is
available for a capture sample; the exporter refuses an incomplete catalogue.

The exporter checks native house IDs/names against the loaded house XML and
requires every floor/frame. It preserves the entire native 576x448 source and
uses the entire screenshot, including surrounding map. The capture centres the
house bounds even when the photographer cannot stand in their middle. Export
checks that all house tiles fit and their centre is within half a native tile
of the frame centre. It creates 232x180 previews with nearest-neighbour resizing,
filling a 234x182 frame in the existing side panel. There is no crop or added
padding; the frame follows the complete screenshot's proportions. Black map void on an
upper floor is part of the actual game rendering. Use `--output <new-folder>`
to re-export an existing capture without overwriting its previous evidence.
No new window or layout is required. The existing missing-photo fallback remains.

Assets are in `modules/game_cyclopedia/images/houses/rookhaven/`, with a manifest
of names, IDs, bounds, floors, capture positions and hashes. Current map: 57
houses, each on one floor. Original client stock photos remain separate. The
manifest is provenance data, not a runtime dependency. For a future house with
multiple floors, choose and verify its main view before extending the exporter.
Regenerate the affected photos when the house geometry or its base graphics
change; player furniture and live occupation are intentionally not dynamic.

Current capture: `out/housing-keyring-fix-20261118/full-frames-centered`, PASS:
57 complete native house/floor frames. All original pixels are retained in the
full-size assets. Every preview is exactly the entire source resized, with no
crop or added padding. All house centres are within half a native tile of the
frame centre. This replaces the earlier cropped/letterboxed DEV10105 assets.

Current native integration: `out/housing-keyring-fix-20261118/native-ui-02`, PASS.
All 57 photos were selected via the original paged house list; all four town
filters match the authoritative IDs (26/0/9/22). Seven representative screenshots
match the shipped preview pixels exactly at 800x640. Original house forms,
stale confirmation refusal, guest editor, recipient acceptance and reopen pass;
the screenshots also cover 1280x800. Original fixture database/config/profile
were preserved and all owned processes stopped. The production view has no
manifest parsing or new decryption API. Release status is recorded separately.
