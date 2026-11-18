# DEV10106: complete house images and Keyring graphic

House previews now show the entire native screenshot, with the camera centred
on each house's tile bounds. The image frame follows the screenshot proportions
within the existing retro side panel (234x182 outer, 232x180 image). No part of
the screenshot is cropped and no padding is added. Surrounding map is retained.
All 57 houses were recaptured in an isolated loopback world; the catalogue and
assets retain authoritative house IDs, names, floors and town mapping.

Keyring offer 1001 uses `/game_shop/images/keyring.png`, exported unchanged from
the existing native keyring sprite (server item 12608, client ID 11652, sprite
35651). This is an offer illustration; buying it still unlocks the three
Keychain spells for 250 points. No item, sprite archive or grant code changed.

Verification: 605 shop contracts include the existing purchase, spell grants,
debit/history and duplicate refusal. Native UI selected all 57 photos, verified
all four town filters and exercised existing house forms, stale confirmation,
guest editor, recipient acceptance and reopen. Seven native screenshots exactly
match preview pixels. Keyring's actual server catalogue loaded its 32x32 texture,
remained visible after category switching and reopening, and was photographed.
Native capture and UI fixtures restored profiles/source DB/config and stopped
all owned processes. No live house purchases or ordinary player changes.

Evidence: `out/housing-keyring-fix-20261118/`, particularly
`image-verification.json`, `full-frames-centered/result.json` and
`native-ui-02/result.json`. The preceding UI attempt failed because the test
used an unavailable image getter; the probe now uses the existing native
texture dimensions. This required no client API change.

Release: prepared locally; publication and updater verification pending.
