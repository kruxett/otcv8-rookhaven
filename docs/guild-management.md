# Native guild management

The native client and game server own all guild mutations. The public website
continues to read the existing guild, membership, rank and MOTD records. It has
no upload endpoint and this change does not enable website management.

## Membership and views

There is no 100-member cap. Opcode 101 returns one requested view at a time,
with ten database rows per page for members, outgoing invitations, incoming
invitations and activity. Search (name, title and rank), sorting and the online
filter apply to the whole guild before pagination. Ordering includes player id
as a stable tie breaker. Counts describe the whole result, not the current page.

Online presence comes from one pass over the guild's online players. Opening
the manager never loads every offline member or scans all online players once
per member. Disbanding uses one cascading InnoDB deletion, then clears only
online guild members. Database failure preserves their live membership.

Replies are checked against a 7,900-byte budget; the shared 8,192-byte network
and JSON limits remain unchanged. Nearby guild labels also use bounded chunks.
The client keeps the selected tab, debounces search, rejects stale read replies
after newer requests or closing/logout, and clamps pages after list changes.

Ordinary members use a compact read-only view: the selected crest stays in the
header, while the emblem editor, PNG instructions, invitation management and
rank-permission controls are hidden. Descriptions appear as wrapped text rather
than disabled edit fields; empty descriptions leave no placeholder. Hidden
management rows do not reserve space in the member and rank lists. Guild list
panels are real scroll areas; their rail and gutter appear only on overflow,
and scrolling resets when a filter or resize makes the content fit again.

## Emblems

On Windows, the leader chooses a static **32 × 32 PNG, at most 64 KiB** using
the OS file chooser, previews it and presses Save. Choosing/decoding runs off
the game loop with one outstanding import. A bounded PNG preflight verifies
signature, chunks/CRC and dimensions, rejects animation and strips ancillary
metadata before the Windows WIC decoder. Only 4,096 RGBA bytes leave the importer.

The authenticated game connection carries canonical base64 in two bounded
strings, keeping each below the existing JSON string limit. The server checks
the exact size, alphabet and padding, normalizes invisible RGB, derives the guild
from the player and rechecks current database ownership inside the write
transaction. A revision prevents stale overwrites. The current guild's emblem
is fetched separately and cached; changing member pages neither downloads it
again nor creates new textures for an unchanged image.

Recipients render fixed raw pixels directly. They never decode somebody else's
PNG, access upload URLs or write uploaded files into the client archive.
The custom crest appears in Guild Manager. Existing ally/enemy/neutral combat
symbols remain independent. Guild halls and guild wars are unchanged.

Storage is **one current image per guild**, not originals or history. Removal
keeps an empty revision tombstone; disbanding cascades the entire record.
Limits in `Rookhaven/src/guildemblem.cpp` are:

- Three successful changes per guild per UTC day, including removal.
- Ten admitted attempts per account per UTC hour, including invalid or stale
  image attempts. The account and guild counters persist across reconnects,
  leadership changes and server restarts.
- Thirty attempts per IP per UTC hour and sixty globally per minute. The
  dispatcher-side IP map is capped at 4,096 entries and expires hourly.
- At most 16,384 guild records (64 MiB of image payload, plus row/index overhead).
  A locked singleton makes the storage admission check atomic. Account counters
  have one row per existing account and cascade when that account is deleted.

SQL failure leaves the previous emblem and revision intact. An indeterminate
commit is resolved by refreshing authoritative storage; the client does not
assume its preview was saved.

## Configuration and rollout

`clientGuildEmblemsEnabled = true` is the default. Set it to `false` in the
server's private environment configuration and restart to disable reads and
writes without deleting stored images. The same setting works on DEV and PROD.
No database connection or upload destination is embedded in the client.

Migration 37 upgrades the required schema to **38**, creates the bounded image,
quota and guard tables, and widens old 15-character guild titles to 30 without
shrinking wider existing columns. Startup verifies transactional engines, keys,
cascading ownership, image width and the required columns before opening game
services. Do not run the new server against schema 37 or downgrade an upgraded
database with an older executable.

Publish the matching native client, Lua/OTUI resources and server together using
the existing DEV release workflow and matching integrity pins. The old client
does not understand the new refresh/page/emblem contract. Build and deployment
scripts must not patch application behavior. Public web queries remain compatible.

## Focused verification

`tools/account-service-tests/guild-contract.py` runs the production Lua decoder,
text boundary and nearby-label chunking contracts. `run-native.py --house-market
--guild-parity --guild-scale` provisions ordinary accounts/characters in its
disposable loopback database and exercises the real encrypted guild protocol
with 1,000 additional members, 230 invitations and 130 guildless invitations.
It also checks existing roles, rank/title edits, leadership, invitation handling,
leave/rejoin, failed/successful disband, emblem authority, revisions, SQL failure,
quota persistence and the disable flag. The housing flag supplies existing test
actors; it does not run the unrelated housing suite in this mode.

Add `--guild-ui --client <owned-QA-package> --encoder <owned-QA-encoder>` for the
native 800×640 / 1280×800 UI checks. Its `GUILD_IMPORT_WAIT` log entries identify
the owned malformed and valid PNG fixtures to choose in the visible OS dialog.
No player account or live DEV/PROD database is used. The runner records actual
binary hashes, reply sizes, exit codes, screenshots and restoration results.

`--house-market --house-ui-only --guild-parity --guild-ui-polish` runs the focused
member/leader presentation pass: normal member login, every member tab, real
mouse-wheel scrolling, filtering, empty results, resize transitions and role
reconnects, plus the leader's retained image and description controls. It uses
the same disposable fixture and captures both supported window sizes.

The completed 2026-11-19 run passed 65 native checks. It started with 1,002
members, verified every page, then removed one through the real kick action;
the UI therefore displayed 1,001 members. The largest observed reply was 5,543
bytes. The Lua contracts additionally delivered 2,000 nearby labels in fifteen
bounded messages. Transparent PNG import, preview, Save and the reloaded header
and preview were verified in the Windows client at both sizes.

This is large-membership coverage with a few real online sessions, not a load
test with a thousand simultaneous clients. Other operating systems are outside
these implementation checks. DEV deployment and the public updater are checked
separately through the paired release workflow.
