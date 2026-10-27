# Light Ring

Implemented locally from the user's approved PixelLab artwork. The requested
final behavior is two static sprites: an unlit jewel while unequipped and a
bright, steadily lit jewel while equipped. The earlier pulse draft is rejected
and retained only as source history. There is no animation or overlay.

| State | Server ID | Client ID | Sprite | World light |
| --- | --- | --- | --- | --- |
| Unequipped | 12861 | 11898 | 36695 | 0 |
| Equipped | 12862 | 11899 | 36696 | Level7, colour206 |

The ring costs **10 shop points**, weighs1 oz and supplies **two hours of
equipped use**. Remaining time pauses when removed, resumes without refilling,
survives save/relog and consumes the ring at expiry. Duration and price are
provisional; the user explicitly requested a cheap ring. Its world light matches
the existing normal lit torch SID2051, without mana/health/stat bonuses.

## Implementation

The existing `transformEquipTo` / `transformDeEquipTo`, `stopduration`, `duration`
and `decayTo` paths handle the two states. Three normal ring movement registrations
are added to the server's `data/movements/movements.xml`. The Utility offer4002
grants the unlit item through the existing no-map-overflow shop delivery path.
The active SID is never sold directly. Existing ring hand-holding rules remain;
the jewel and world light activate in the finger slot.

Both states use the static, movable/pickupable, non-stackable DAT/OTB prototype
SID2165. `tools/light-ring-tests/stage-items.py` runs the standard static importer,
then adds the native light attribute only to the newly staged active DAT/OTB
record. It verifies unrelated records before applying source-hash-checked files.
No shared C++, protocol or client inventory UI change is required.

## Verification, 2026-10-25

- Final asset check passes: both approved PNGs decode exactly, all identifiers,
  static flags, ring XML and native light attributes match. Every pre-existing
  12,283 DAT record, 12,761 OTB record and 36,694 SPR payload is preserved,
  including the previously implemented premium scrolls and Magic Quiver.
- The shop/admin source contract passes88 checks. It covers cheap price10,
  unlit grant, correct icon CID, private grant isolation, purchase/debit/history,
  insufficient points and delivery failure, plus retained premium/Quiver/Keyring.
- The current native server gameplay run passes with terminal counter43:
  ordinary-player capacity/slot rules, actual purchase, light0/7, correct static
  equip transform, instance-attribute preservation, native charge depletion,
  pause/resume without a refill, normal torch coexistence and fallback, stronger
  independent light preservation, existing time-ring transform/speed regression,
  active-state save/relog and accelerated expiry/removal. Polling assertions mean
  the terminal counter can vary with decay-bucket timing.
- Real ingame screenshots use an existing matched pre-integrity QA client/server
  pair and the new item definitions/graphics in a cold-copy local fixture. The
  client logs in normally, receives the real inventory/map, moves the ring from
  finger to backpack and back using ordinary game packets, and checks the real
  slot CIDs. The visual server confirms equipped SID12862 and light7/colour206.
  This complements the current-server gameplay test and does not certify a new
  protected executable/archive or a published release.
- The cold source DB/config and the existing probe profile are restored/unchanged
  by hash; all owned client/server/DB processes are stopped. Final evidence paths
  and asset identities are recorded in `verification.json`.

Test setup repairs: Windows' desktop file mapping blocked the initial Python
truncate/resize copy; source assets were restored from verified originals and
the final import used the native PowerShell copy path. The native helper needed
ordinary move flags, explicit bag placement and occupied hands because legacy
auto-destination can hold a ring in a hand/ammo slot. A historical unrelated
Quiver startup assertion was disabled only in the private older visual runtime.
The final gameplay and visual runs are clean.

```powershell
python tools/light-ring-tests/verify-assets.py --originals out/light-ring-20261025-import-04/originals
& ../Rookhaven/out/deploy-fix-20261025/luajit/luajit.exe tools/quiver-tests/shop-admin-contract.lua ../Rookhaven
python tools/light-ring-tests/run-native.py --engine-package out/premium-scroll-20261025/qa-runtime.zip --output out/light-ring-20261025/new-native-run
python tools/light-ring-tests/run-ingame-visual.py --debug-dependencies out/light-ring-20261025/visual-debug-deps.zip --output out/light-ring-20261025/new-ingame-run
```

## Review and release status

The user approved both static sprites and the final ingame appearance on 2026-10-25.
See `ingame-equipped.png`, `ingame-unequipped.png` and the native inventory crops.
These are screenshots from actual local gameplay, not composited mockups.

No commit, push, DEV deployment or updater publication was performed. A matching
protected client executable/archive, RH2 pin and ordinary release smoke are still
required before release. No two-hour wall-clock soak was run: native metadata,
real elapsed charge depletion and shortened remaining-charge expiry were tested.
No shared combat/ammunition/passive rule changed, so no full passive suite was
selected. Next product: Food Ring artwork, which requires its own approval before implementation.
