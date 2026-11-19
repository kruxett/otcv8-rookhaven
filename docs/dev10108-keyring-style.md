# DEV10108: approved Keyring spell illustration

Replace the shop illustration with the exact enlarged proposal Marcus approved
on 2026-11-19. Three collected-key symbols use Rookhaven's shaded metal palette,
dark contours and restrained rendering. Native 32x32, binary transparency;
the approved generator PNG is copied unchanged to the existing resource path.

Source PNG SHA256:
`957040e553255a46d3938986f3ea407f6bf117bf4337fa6608170a2ea9b29978`.
PixelLab Pro Flash job `abffb93e-c310-4ac7-8908-676459d85442`.
Source/provenance: `assets/items/keyring/`. The Magic Quiver reference guides
style only. This is the illustration for the existing three-spell Keyring
offer, not a new inventory item or changed ability. Purchase/price/grants,
item archives, house images and retro layout are unchanged.

Published and live verified on DEV as **10108**. Client runtime source
`390a7f1f`, server source `262676b85a237ca2896be9660a09632e4c562a5b`.
Persistent deployment `a45ba809-d059-4797-8b67-2d7b34c00c32` completed
`SUCCEEDED` with the normal warning, clean shutdown, backup and restart.
Only matching client integrity/checksum pins changed on the server. The server
EXE and private runtime config are unchanged. Live tracked source is clean,
both native listeners belong to the intended process, checksum enforcement
is enabled, and the QA overlay remains disabled. PROD artifacts and non-DEV
updater fields are unchanged.

Verification: 605 shop contracts passed. Native UI loaded the actual catalogue,
displayed the approved texture, and passed category switching/reopen. The
shared native housing fixture also passed with its original forms, all 57
photos and all town filters, restoring the source DB/config/profile and
stopping all owned processes. No new gameplay behavior was introduced.

The protected retail client approves 1,569 resources. 715 relevant resources
pass source/bytecode equality; an additional direct decode of the final
encrypted shop PNG proves its bytes match the exact user-approved image.
The full public client ZIP matches the prepared artifact. Actual DEV10107
downloaded the new EXE/archive and restarted normally into DEV10108, whose
blank login/version were visually observed. All original profile bytes and
owner/DACL fingerprints were restored and test processes stopped.

Eighteen native live checks passed, including old proof refusal, new retail
world login, town filters and the shop catalogue. The temporary dedicated QA
character was removed through native account management afterward. No live
shop purchase, house transaction or gameplay command was sent.

Evidence: `out/keyring-style-20261119/`, aggregate `release-result.json` and
native screenshot `native-ui/accounts-shop-keyring-800.png`. Real updater:
`out/release-smoke-20261027/native-updater-10107-to-10108-20261119/`.

Client EXE SHA256:
`f417d241cb0b829498791387ac39b29fcf6f6595510467a2bc614df68f3ee6ef`.
Client data.zip SHA256:
`d6411a6739ecbcc3f9194301c3dd4e5f739b690be1e42f5cabaabe1b3fe89340`.

[Full DEV10108 client](https://updater2.rookhaven-ot.com/files/dev/Rookhaven-DEV10108-client.zip).
