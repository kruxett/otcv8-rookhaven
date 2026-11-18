# Native housing integration

Player account, character, guild and house management belongs in the native
client. The website provides public information and downloads. Future Coins
payments are a separate website feature; house transactions use gold.

## Implementation, 2026-11-17

Local, unpublished work across the client, native server and public web API.
Playable DEV and its updater remain on the earlier release.

- The existing Cyclopedia Houses tab now uses opcode 118 for paginated search,
  town/account/availability filters and real house details. It reuses the complete
  existing houses_on/houses_off button artwork and its pressed state. The
  character button follows the house button instead of covering its icon.
- Native actions support manual/proxy bids, disabling automatic bidding, direct
  sales, owner auctions, named transfers/gifts, private buy offers and
  acceptance/decline/withdrawal, abandonment/cancellation, native guest/subowner/
  door editors and removing visitors. Actor identity comes from the connection.
- Premium, one house per account, pending purchases and other leading/reserved
  auctions are rechecked on the server. Mutations compare a house revision and
  fresh state inside the bank transaction. Client values never become SQL.
- The winning manual price or full proxy maximum is reserved immediately.
  Outbid players receive their hold back; immediate proxy losers reserve nothing.
  Private buy offers reserve nothing until accepted. Buyers are charged once,
  and sellers are paid with the actual ownership handover at server restart.
- Migration 36 to 37 creates compatible web_house_* tables, market revisions and
  explicit native escrow provenance. Legacy pending website sales already paid
  their seller and must never pay again. Ambiguous legacy reservations are
  retained for operator review rather than guessed/refunded twice.
- clientHouseMarketEnabled defaults false. Startup still processes existing
  obligations while new client actions are disabled. Auction timings and the
  bid increment are native configuration values (48 hours, 100 gold and an
  owner-auction maximum of seven days by default).

## Existing client module

The live view is the existing `tab/house/house.otui`, not a parallel browser.
Its original House cards, preview frame, town/state/sort controls and seven
panels are retained: list, bid, move out, transfer, cancellation, acceptance
and rejection. `house.lua` adapts native responses into those cards and binds
the original form controls. `market.lua` is only the bounded opcode transport.
The unused replacement `market.otui` was removed.

Rookhaven completes handovers at restart; the original official-client date
pickers and inbox/belongings wording therefore become the actual restart/depot
terms. Proxy bidding and sale offers reuse the amount form; owner auctions reuse
the transfer form. Additional actions use the existing PopupMenu, visitor input
uses UIInputBox, and guests/subowners/doors use the native access-list editor.
The guildhall selector is visible but disabled because this world's native
house definitions contain no guildhall type. House photos now use real native map captures for all 57 current houses,
with proportional previews in the original image frame. Original stock assets
remain separate, and a missing resource still uses the existing fallback.

A form pins its house revision when opened. Refresh cannot replace that quote
inside a pending confirmation. Incoming private transfers are included under
Own Houses; the named recipient can accept or decline using the original
panels. Private pending terms remain limited to the owner and recipient.
Server list filters/sorts are bounded and whitelisted.

## Town mapping, 2026-11-18

The map defines Rookhaven (1), Gravefall (2), Stillshore (3) and Riverside Hamlet
(4). The 22 Riverside houses (36-57) previously had townid=1 in the authoritative
house XML despite being located in Riverside Hamlet. They now use townid=4.
There are 26 Rookhaven, 9 Stillshore and 22 Riverside Hamlet houses; Gravefall
has none. Native startup already synchronizes this metadata into houses.town_id,
so the client uses the same authoritative town ID for filtering and names.
Images remain selected by the stable house ID; no picture positions changed.

This also affects native belongings delivery, which uses the house town's
locker. `riverside-depot-town4-20261118` passes 26 native checks, including a real
Riverside transfer depositing the old owner's loose items and nested bag in
town 4, and an ordinary restart preserving a single transfer/payment.
`house-town-native-ui-20261118` passes all four town filters and their pagination,
covering all 57 houses, matching city names/IDs and photographs. Empty Gravefall
clears the preceding house and image. The original seven panels and all 57 image
checks also pass. Both owned fixtures stopped; source copies and client profile
were preserved. These are local checks; DEV/updater remain unpublished.

## Persistence and affected existing paths

Game.commitHouseBalances saves complete live participants before changing bank
balances. This preserves consumed deposit coins and earlier deposits. Balances
and market records share one SQL transaction; live balances update only after a
confirmed commit. An unknown commit blocks old live saves and disconnects every
participant so reconnect loads the authoritative database outcome.

Game.completeHouseTransfer is startup-only. The old owner and sleeping guests
are loaded before preparation; native depot movement, bed wake/regeneration,
access clearing, all affected player snapshots, house tiles, ownership and
settlement records share one commit. Prepared failure stops the process before
another startup callback can save uncommitted world objects. Ordinary savePlayer
callers retain their own transaction; only the explicitly owned transfer joins
one. Targeted checks cover owner base HP/mana/class ledger and guest regeneration.

Final-warning rent evictions use the same native handover and refund any auction
reservation before clearing its listing. Normal rent collection remains native.
The startup character cleanup retains owners, bidders and pending escrow actors.
A checked SQL reader distinguishes an empty result from a persistence failure;
startup cannot open listeners after a failed house-market readiness check.

## Verification and remaining work

Current restored-UI evidence (2026-11-17):
- `house-photos-all-02`: PASS, 57 native map framebuffer captures. The exporter
  validates every house ID/name/floor against native tiles and the loaded XML,
  and creates 57 original crops plus 57 proportional 186x210 previews. All three
  review sheets were inspected. See [house photo workflow](../tools/house-photos/README.md).
- `house-photos-native-ui-04`: PASS, all 57 previews selected through the original
  house list/pagination, with no missing-image fallback. Seven representative
  small-client screenshots match their thumbnail files pixel for pixel, covering
  ground, upper and underground floors. The existing owner, amount/cancellation,
  leave/transfer, guest editor, recipient acceptance and reopen checks also pass.
  Capture/verification were confined to disposable loopback copies; no live
  account, house owner, world data or updater was changed.
- `original-house-full-03`: PASS, 83 native encrypted market checks, including
  stock filters/all five sorts, incoming private offers, recipient rejection,
  private pending-term visibility, and the earlier proxy/refund/restart paths.
  Owner UI and persisted native guest access also pass in this run.
- `original-house-seven-panels-05`: PASS, all seven original panels exercised
  in the native retro client at 800x640 and 1280x800. The recipient logs in to
  their own freshly returned character list, inspects the original bid and
  rejection panels, then accepts a gift through the original acceptance panel.
  Existing selected/unselected tab dimensions, numeric bounds, duration bounds,
  explicit leave confirmation, stale quote rejection, guest editor and reopen
  are checked. Owned processes stopped and the prior client profile restored.
- `client-request-contract.lua`: PASS, 111 checks, including rejected arbitrary
  sort values/statuses and the bounded recipient-decline request.
- Earlier UI evidence below predates the restored view. Its unchanged engine/
  transaction evidence remains useful; the runs above are the current UI proof.
  No DEV/updater publication has been performed for this work. Live DEV and
  long-term gameplay with real users remain outside these isolated checks.


- Native core engine SHA256:
  bc8bf9d249713937c3e448cb41b5141d4fad83b2f79354f41c108d7d9f8daff4.
  All eight house-core scenarios pass under ignored out/account-management-20261116/
  house-core-*-06: 88 checks including real wallet deposits/reconnect, callback
  rollback, unknown commit before/after SQL, crash after commit, exact depot and
  bed outcomes on cold restart, and the existing native account/character/MFA/
  Guildmaster UI paths. Guest soul regeneration now commits or rolls back with
  the bed, avoiding a separate pre-transfer save.
- housing-guild-public-ui-01 passes native house UI, guild rename and invitation
  withdrawal/permission regressions plus eight real public web/native-schema
  tests using SELECT-only credentials. Guest access was persisted through the
  normal native world-save path. Screenshots at 800x640 and 1280x800 were
  inspected; the complete house icon and non-overlapping navigation are visible.
- The full latest-engine market/guild/public/UI run housing-all-02 passes 93
  checks, including proxy competition/refunds, stale/duplicate requests, private
  offers/gifts, abandonment, already-paid legacy jobs, owner auctions, premium
  expiry before handover and failed SQL-read startup. The website's eight public
  database tests also pass inside that run. Fixture membership is seeded while
  the game server is stopped, then loaded through a normal native login.
- Public web model assumptions about old web-auth columns were removed; public
  guild reads avoid retired web permission/invitation tables. Public character
  responses omit bank balance and pending guild invitations. Website writers
  and player authentication routes remain unmapped.
- housing-rent-01 passes 14 checks: final-warning eviction refunds the full
  proxy hold and clears its listing, ordinary funded rent still charges once,
  and a second restart repeats neither charge nor refund. No broad combat or
  all-passive suite is implied by these persistence checks.
- The website Coins page/catalogue is prepared with CatalogEnabled=false, no
  prices and no checkout route. Provider, currency, prices and paid-currency
  delivery/refund policy remain undecided. See the web coins documentation.
- Management-final-01 passes 62 native management/feature-flag/future-mail checks
  against this same engine. Future mail used the isolated outbox, never SMTP.
- final-legacy-native-web-ui passes 31 outer checks plus all nine real
  public API/native-schema tests. It verifies migration of the old single-house
  UNIQUE listing index, current public listings after cancelled history, hidden
  private agreement terms, a refreshed state behind an old confirmation, and
  guild input cleanup on logout. A confirmation sends its original house revision;
  a changed quote is refused rather than silently using a newer price.
