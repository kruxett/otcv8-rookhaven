# DEV10107: original Keyring artwork

The Keyring shop illustration is now original Rookhaven artwork, generated
directly at 32x32 in PixelLab Pixen. It shows an intact steel ring with brass
keys, with hard pixel edges and binary transparency. The image is copied
unchanged to the existing shop resource path; no UI dimensions, item records,
price, purchase/grant code or house images change.

Artwork and provenance: `assets/items/keyring/`. Release evidence:
`out/keyring-original-20261118/`. PixelLab job
`5105b74a-1cc9-4646-ba8b-bf53c7fbfcee`, one native-size generation. The
generator result, selected source sprite and installed shop PNG are identical:
SHA256 `3a73b55c0444961b9ec01a47aebb5fdeb4f5b2e1dc9de9f1d314e58a27a5b1e4`.

Published and live verified on DEV as **10107**. Client runtime source
`742bba15`; server source `dd392438af3fbd53daa662ffe7c564bb73b560f6`.
Persistent deployment `53003e06-285d-49bb-a929-f1df11c0aea6` completed
`SUCCEEDED` with the normal warning, clean shutdown, backup and restart.
Server changes are matching client integrity/checksum pins only. The native
server binary, runtime config, PROD artifacts and non-DEV manifest fields are
unchanged; both native listeners and clean live source were verified.

605 shop contracts passed. The native client displayed the new texture in the
actual server catalogue, including category switching and reopen. Its shop
screenshot is `native-ui/accounts-shop-keyring-800.png`. The existing housing
fixture also passed with its original forms, all 57 images and all town filters;
source DB/config/profile restoration and owned process cleanup passed.

The protected retail build approves 1,569 resources; 715 relevant resources
passed source/bytecode equality. The full public client ZIP matches the prepared
archive. Actual DEV10106 downloaded the new EXE/archive and restarted into
DEV10107, whose blank login/version were visually observed. The first automated
run completed the real update but exceeded its GUI acknowledgement timeout;
all profiles were restored. The isolated retry with a longer GUI observation
window passed, with identical profile bytes and owner/DACL fingerprints restored.
Evidence: `out/release-smoke-20261027/native-updater-10106-to-10107-20261118-retry1/`.

Eighteen native live checks passed, including old proof refusal, new retail
world login and the actual shop catalogue. The temporary dedicated QA character
was removed through the native account service. No live shop purchase, house
transaction or gameplay command was sent. Aggregate: `release-result.json`.

Client EXE SHA256:
`3903a577d8c0eb8a7f0867e8792ff860b48da2c1cd5bbc9a9e7d13901252bdcb`.
Client data.zip SHA256:
`13de2ca9f2e6efcccbd296171b08ca2bce16765017275ce9ee8f8303e938ceff`.

[Full DEV10107 client](https://updater2.rookhaven-ot.com/files/dev/Rookhaven-DEV10107-client.zip).
