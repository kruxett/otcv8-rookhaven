# Premium scrolls

The user approved these PixelLab sprites on 2026-10-25. Only the scroll pixels
are imported; labels and frames in the first review board are presentation only.
The original 32x32 PNGs are retained under `source/`; each duration's `sprite.png`
is an unchanged copy. Rendering uses fully transparent or fully opaque pixels.

| Days | SID | CID | Sprite | Provisional shop points |
| --- | --- | --- | --- | --- |
| 30 | 12858 | 11895 | 36692 | 250 |
| 60 | 12859 | 11896 | 36693 | 450 |
| 90 | 12860 | 11897 | 36694 | 600 |

All three are movable, pickupable, non-stackable, non-readable, single-tile items
weighing 1 oz. Native DAT/OTB prototype SID5943 supplies those properties.
Each import manifest records its input/output identities and preservation checks;
`verification.json` records the final combined state.

## Use and acquisition

Buy a physical scroll in the Premium shop category. Buying does not activate it.
Carry the scroll, including inside a backpack, and use it to add exactly its
duration to the account. Existing active premium is extended without rounding;
expired premium starts from the time of use. One use consumes the exact scroll.
The server selects the duration from its real SID. There is no client duration,
price or reward authority. Admin item commands remain `/i 12858`, `/i 12859` and
`/i 12860`; no additional grant command was introduced.

`data/scripts/actions/others/premium_scroll.lua` calls the native
`Player.redeemPremiumScroll(item)` binding. It prepares the existing inventory
mutation plan, saves the character (including any preceding shop debit), locks
the account row and commits the projected inventory plus account expiry in one
SQL transaction. Live consumption follows the successful commit in the same
dispatcher turn. Online characters on that account receive the committed expiry.
Rejection leaves the scroll and premium unchanged. An ambiguous commit disconnects
the session and blocks its stale inventory save; reconnect loads the authoritative
account and inventory. Fault injection is compiled only with
`ROOKHAVEN_TRANSACTION_TESTING` and additionally requires loopback-only QA config.

The catalog now contains these three scrolls, the existing Magic Quiver (150)
and the existing Keyring (250). Keyring preserves the three Keychain spell
unlocks from the old bundle. Removed consumable/material/Light-spell offers are
not listed. The catalog has one config source and stays empty if that config
cannot be loaded. Prices are provisional as authorized by the user.

## Verification, 2026-10-25

- Staging and the final asset verifier preserve all 12,280 pre-existing DAT
  records, 12,758 OTB records and 36,691 SPR payloads. All three approved images
  decode losslessly with correct SID/CID/sprite/image hashes and binary alpha.
- The shop/admin source contract passes 79 checks: real config, icon CIDs,
  authoritative grants/prices, successful and rejected purchases, no inventory
  overflow onto the map, history, retained Quiver/Keyring, admin permissions and
  an unavailable-config refusal.
- A native server was built from the current source in isolated staging on the
  Windows build host. The instrumented binary SHA256 is recorded in verification.
  The normal loopback RH2 login uses a protocol driver; this is not an official
  protected-client package certification.
- The native gameplay run passes 59 checks, including ordinary player capacity,
  native ItemType/creation, shop delivery/debit, expired and active premium for
  all durations, exact durable consumption, ordinary item saving, ground/invalid
  item refusal, rollback after a forced premium UPDATE failure, Quiver/Keyring
  regressions, existing premium add/remove, actual registered action via Use
  packet, duplicate Use refusal and reconnect persistence.
- Three additional native fault runs pass: connection loss before COMMIT, loss
  after COMMIT and process exit86 immediately after COMMIT before live application.
  Each verifies the account and inventory together and then reconnects/saves.
  Each run uses a separate cold copy; the original DB/config hashes are unchanged
  and every owned DB/server process is stopped afterward.
- `native-client-review.png` is a 1:1 cutout from real offline UIItem rendering
  with an existing older QA renderer and the new DAT/SPR. It certifies sprite
  decoding/rendering only. The probe profile was restored byte-for-byte.
- Two test setup issues were corrected: expected connection-reset handling in
  the crash driver, and encryption/test bootstrap for the older offline renderer.
  The final passing run directories are recorded in verification.

Representative commands from the client repository:

```powershell
python tools/premium-scroll-tests/verify-assets.py --originals out/premium-scroll-20261025/originals
& ../Rookhaven/out/deploy-fix-20261025/luajit/luajit.exe tools/quiver-tests/shop-admin-contract.lua ../Rookhaven
python tools/premium-scroll-tests/run-native.py --engine-package out/premium-scroll-20261025/qa-runtime.zip --output out/premium-scroll-20261025/new-native-run
# Use a fresh output for each --fault-mode:
# commit_unknown_before, commit_unknown_after, crash_after_commit
python tools/premium-scroll-tests/run-visual.py --renderer out/rods-dev-release-20261012/client/install --output out/premium-scroll-20261025/new-visual-run
```

## Delivery status

Implemented and function-tested locally. No commit, push, DEV updater release,
live server installation or live restart was performed. The protected client
still requires a matching executable/archive rebuild, RH2 pin and coordinated
server build before publication. Its native live shop UI and ordinary updater
transition remain release checks. Concurrent online same-account synchronization,
trade refusal and the maximum SQL timestamp boundary were not separately probed.
No combat/ammunition formula changed, so no passive combat suite was selected.

Next: Light Ring artwork only, pending the user's separate approval. Food Ring
must provide an equipped-only fed state and must never fill ordinary food ticks.
Outfits remain deferred until all other requested products are complete.
