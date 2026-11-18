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

Published and live verified on DEV as **10106**. Client runtime source
`180c2482`, server source `484919b1acdd1be2cbfea88b005d0fddd525c9a6`.
Persistent deployment `869aa9bd-c962-4708-bb95-84f7e3e626c6` completed
`SUCCEEDED`, using the normal warning and clean shutdown/backup/restart.
The server binary was reused because its native sources did not change.
Live source is clean, both native listeners belong to the intended process,
checksum enforcement remains enabled and the QA overlay remains disabled.
Runtime config, PROD artifacts and all non-DEV updater fields are unchanged.

The protected static retail client was rebuilt with 1,569 approved resources;
715 relevant resources pass source/bytecode equality, including the complete
shop module and graphic. EXE SHA256:
`ec480c84a67cd2029239f3a9b85eb3a2bf22c83b9f00bdf53f2bf09dd739c15e`;
archive SHA256:
`c1881fca2c35823b41db62134d7ea66c8c2398ece3f4d3932d8128acfb73d519`.
The complete public client ZIP matches the prepared archive. Actual published
DEV10105 downloaded the new EXE/archive and restarted normally into DEV10106;
its blank login/version were visually observed. All original profile bytes and
owner/DACL fingerprints were restored and test processes stopped.

Eighteen native live checks passed: old compatibility proof refused, new retail
proof accepted, native account services, all town filters/pagination and the
actual 36-offer shop catalogue with Keyring's new path and unchanged 250-point
cost. The dedicated temporary QA character was removed through normal account
management afterward. No live purchase, house transaction or gameplay command
was sent. Updater evidence is under
`out/release-smoke-20261027/native-updater-10105-to-10106-20261118/`;
the aggregate release receipt is `out/housing-keyring-fix-20261118/release-result.json`.

[Full DEV10106 client download](https://updater2.rookhaven-ot.com/files/dev/Rookhaven-DEV10106-client.zip).
