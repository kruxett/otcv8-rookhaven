# Client correctness follow-up — 2026-10-06

Scope: the audit's Apply draft loss, foreground class-choice feedback, misleading
spell readiness and initial name clipping at the real 800×600 minimum. The client
also renders the server's revised class-specific capstone families. Retro assets,
32px glyphs, tier frames, rank footers and the four-minor-point core-major gate are
preserved. No server main `config.lua` additions are required for these client
changes.

## Apply and authoritative state

An in-flight request records its action, ID, session, revision and saved ranks.
A failed matching Apply retains the current legal draft only when those saved
values and the active authoritative state have not changed. A reduced point
budget or a draft made invalid by the new catalog discards that draft.

An unsolicited unchanged snapshot does not acknowledge/cancel an in-flight
Apply. The existing five-second timeout releases controls and requests a fresh
snapshot; it never restores a captured draft. Consequently, edits made after a
timeout survive an unchanged late rejection, while a higher revision replaces
them with actual saved ranks. An older result cannot cancel a newer pending
request unless its snapshot contains newer authoritative state. Retired sessions
remain unable to regain authority. Invalid snapshots do not finish a request or
replace the visible status with a false success.

## Visible class-choice feedback

The foreground confirmation has its own 36px wrapped status band above its
buttons. Waiting, server rejection, send failure, reconnect and the existing
eight-second request timeout appear there as well as in the main choice window.
After timeout, Confirm stays disabled and Go back becomes Close, which retires
the offer. Closing and late-reply protections retain the server's existing
permanent-choice gates. The consequences remain in their scrollable panel.

## Spell feedback

Cards say **Cooldown ready**, never a promise that the whole spell is usable.
Each card has a permanently visible class-weapon hint. Known zero mana, both
hands empty, missing Marksman ammunition and the latest authoritative wrong-weapon
status are shown beside the cooldown and in its tooltip. Final discounted mana
cost, item type, wield level/skill, targeting and range are still checked by the
server. The client does not block a cast using guessed mana discounts or stale
weapon metadata. The existing authoritative shared-exhaustion disable remains.
Visible cards refresh this feedback at 250ms when no cooldown is running.

## Tree navigation and capstone families

A new empty upward-growing tree opens at the bottom, showing all minor frames
and their 30px nameplates at 800×600. This happens once per new session. Reopening
or receiving combat/runtime updates preserves the player's scroll position.
Explicitly selecting a node reveals the complete frame **and** nameplate on both
axes, after native layout has settled.

Capstone connector routes now come from the actual catalog edges, using separate
side corridors and crossing gaps. All six classes may link their own three
majors without relying on the earlier shared positional family. The existing
`requires.all` rule and single-ID `sum` summary support an anchored major rank;
the compact textual prerequisite explanation now includes that anchor too.

## Targeted verification commands

The root agent coordinates builds and probes serially against the owned local
runtime. These two probes are new; their execution results belong in the final
fix report rather than being assumed from their existence:

```powershell
./tools/run-passives-preview.ps1 -Script passives-client-feedback.lua
./tools/run-passives-probe.ps1 -Script passives-draft-preservation.lua `
  -Success PASSIVES_DRAFT_PRESERVE_OK -TimeoutSeconds 125
```

The feedback preview uses the **real native UI/controllers with a scripted
transport**, offline. It checks five-second timeout recovery, unchanged/changed
late replies, higher revisions, reduced budgets, retired sessions, all six trees
at actual 800×600, all 17 explicit node selections, reopen/runtime scroll
preservation, foreground reject/wait/timeout and shared-cooldown feedback. It
does not prove network combat or a class commit. The separate live draft probe
uses real native combat, the actual Apply button and a calm retry saving exactly
the retained ranks. Existing all-tree geometry, six-tree contract, class-choice
and class-spell shared-exhaustion probes cover the affected adjacent paths.
## Executed verification

- `out/passives-fixes-feedback.log`: **PASS**. Native controller preview checks
  draft rejection/timeout/late authority, all six trees at actual 800×600, all 17
  full-frame/nameplate selections per tree, ordinary reopen/runtime and the real
  same-session catalog/snapshot replay path with existing saved ranks. Foreground
  rejection, timeout Close, retired offer and shared-exhaustion wording also pass.
  A subsequent weapon-hand review corrected the hint and missing-weapon check to
  support the native engine's valid left-hand equipment as well; the focused
  preview adds an explicit left-only case and is rerun for this correction.
- `out/passives-fixes-draft.log`: **PASS**. Actual native combat rejects UI Apply
  with revision1/saved0 unchanged while retaining both drafted points; calm retry
  saves exactly the retained ranks. Later client edits only change routing/focus;
  this Apply controller remains identical to the tested source.
- `out/passives-fixes-geometry.log`: **PASS**. Six actual catalogs at 1280×800 and
  800×640, all 21 connections, genuine centered lettering, 17 nameplate clicks,
  no frame/nameplate intersections or ambiguous shared horizontal capstone tracks.

The root agent ran these serially. Two modal screenshots were independently
inspected: rejection and timeout both render in the foreground retro dialog at
800×600, with readable text and visible recovery buttons. They use scripted
controller fixture descriptions; they do not claim a real NPC class commit.

Adapter failures were corrected without relaxing assertions: oversized catalog
injection now uses real chunk reassembly; portraits load the actual 8.60 DAT/SPR;
the spell player's test double includes the position read by the ordinary battle
panel timer; screenshots wait for a rendered frame; and geometry waits for the
actual requested native root size. The successful logs contain no corresponding
runtime errors. Full affected-system gates and final artifact identities are
reported by the root agent separately.
