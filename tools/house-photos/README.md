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
requires every floor/frame. It crops the actual 32px tile projection with one
context tile on each side, without redrawing or replacing pixels. It preserves
those native crops and creates 186x210 previews with nearest-neighbour resizing
and black margins to retain proportions in the existing 188x212 image frame.
No new window or layout is required. The existing missing-photo fallback remains.

Assets are in `modules/game_cyclopedia/images/houses/rookhaven/`, with a manifest
of names, IDs, bounds, floors, capture positions and hashes. Current map: 57
houses, each on one floor. Original client stock photos remain separate. The
manifest is provenance data, not a runtime dependency. For a future house with
multiple floors, choose and verify its main view before extending the exporter.
Regenerate the affected photos when the house geometry or its base graphics
change; player furniture and live occupation are intentionally not dynamic.

Current capture: `out/account-management-20261116/house-photos-all-02`, PASS:
57 native house/floor frames, 57 matching crops and 57 proportional previews.
The three review sheets were inspected, including upper floors and Academy
basements. The original fixture database/config/profile were preserved, and all
owned processes were stopped. This is local preparation, not DEV publication.

Current native integration: `house-photos-native-ui-04`, PASS. All 57 photos
were selected via the original paged house list, with no missing-image fallback.
Seven representative screenshots match the shipped preview pixels exactly;
the seven original panels, stale confirmation refusal, native guest editor and
recipient acceptance also pass. The preceding UI probe exposed a test-fixture
attempt to parse an encrypted manifest through the safe/raw resource reader.
The fixture now injects that catalogue into its own test driver; the production
view has no manifest parsing or new decryption API.
