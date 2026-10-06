# Passive-tree UI review

## Scope

This is the earlier layout review. The subsequent [historical audit](passives-final-audit.md)
recorded Apply draft loss and initial minor-name clipping at 800×600.
Those findings are addressed in [the current fixes and verification](passives-fixes-verification.md).
The layout review alone is not an overall release-readiness verdict.

This local retro UI increment clarifies the six existing trees. It changes node
shapes, branch identity, connection drawing and requirement/status presentation.
It does not change talent effects, spell balance, point progression or saved ranks.
The user confirmed retaining the **four-minor-rank** core-major threshold.

## Rules shown to the player

- Each core major requires four ranks **combined across its two minor nodes**.
  Guard counts Vitality and Resilience/Resist only: **3 + 1 is accepted**; ranks
  in Iron Resolve or another branch do not count. Any legal split is allowed.
- Precision, Pressure, Sustain and Guard remain the four areas. Lifekeeper's
  first area is labelled **Healing**, because its minor effects heal rather than
  increase critical chance. This is a display alias, not a new rule or tree.
- A bridge needs two minor ranks in each connected area and **either** linked
  core major at rank one. Both areas are required; both majors are not.
- A capstone needs **any two of its three linked majors at rank two**, plus
  **15 total points before the capstone**. Major ranks count toward those 15;
  the capstone itself does not. At most one capstone may be selected.
- Requirement progress is calculated from the current draft. Alternative
  candidates must read as alternatives, including when the overall rule is met.

The rule source is [server catalog metadata](../../Rookhaven/data/lib/passives/test.lua).
[Native validation](../../Rookhaven/src/passives.cpp#L113) remains authoritative.

## Visual contract

- Minor: **44×44**, up to five ranks.
- Major: **104×52** rectangular form, up to three ranks.
- Capstone: **64×64** ornate form, one rank.
- Talent names sit in attached **30px-high** nameplates directly below their
  frames. Widths are **58px minor**, **104px major**, and **108px capstone**.
  Text is centered horizontally and vertically; authored two-word names use a
  consistent two-line break. Clicking a nameplate selects the same node as its icon.
- Icons remain the native **32×32** pixel assets with smoothing disabled. The
  surrounding widgets provide the tier distinction; icons are not enlarged.
- Redundant `M`, `C` and unexplained `x` markers are removed. A pixel lock marks
  an unmet prerequisite or another selected capstone; a blue square marks a
  changed, unsaved draft. Rank labels and the detail panel explain the state.
- Saved/applied ranks use the owned color; draft changes use blue. Selected-node focus
  and related incoming sources must remain distinguishable from ownership.
  Maximum rank, exhausted point budget and waiting for the server are separate
  reasons, rather than generic prerequisite locks. Locked nodes remain inspectable.
- Four branch panels group the minor pairs and show progress toward the major.
  Their labels sit above the minor nodes without crossing the connector track.

The client draws the catalog's **21 edges**, with independent tracks, gaps at
crossings and destination arrows. Selecting a node highlights its incoming
connections; it must not imply that every incoming alternative is mandatory.
Applied-route coloring uses saved ranks, while requirement progress uses draft
ranks. Undoing a draft must restore the saved presentation.

Sources: [controller](../modules/game_passives/passives.lua),
[layout](../modules/game_passives/passives.otui).

## Configuration boundary

Server `catalogRules` centralizes the readable catalog description of existing
fixed prerequisites. It is **not** an independent gameplay configuration switch.
The client accepts compact requirement summaries only when their expanded AND/OR
conditions match the catalog's actual `requires` alternatives.

A future gate change must update native validation and the catalog together,
review saved-build compatibility, and migrate or refund affected builds before
stricter validation is enabled. Editing `catalogRules` alone cannot safely change
the native rule. In particular, tightening four to five could invalidate existing
saved builds during restore/login; cosmetic improvements must not do that.

## QA evidence and remaining review

The coordinating offline metadata check reports **28,992 comparisons passed**.
This supports catalog/requirement consistency; it is not a live-game or visual
PASS. Its source is [passives-catalog-metadata.lua](../tools/tests/passives-catalog-metadata.lua).
This document's author performed source inspection only and did not run builds,
clients, servers or database operations for this documentation task.

Targeted review methods for the coordinating run:

- Render all six trees at **1280×800** and **800×640**. Inspect long labels,
  branch grouping, capstone tier distinction, requirement wrapping, scrolling,
  readable native pixel icons and reachable action buttons.
- Check the user's Guard example at 3/4, then 4/4 using 3+1. Compare a split
  across the pair with four ranks in one minor; unrelated ranks must not unlock it.
- Check bridge AND-area/OR-major rules and each capstone's two-of-three choices.
  An unused optional source must not look like an outstanding mandatory condition.
- Inspect locked, open, owned, changed draft, maximum rank, no points, other
  capstone selected and pending-response states. Apply/Undo must distinguish
  draft effects from active saved effects.
- Reopen and reconnect an unchanged permanent build. Class, saved ranks, earned
  points, respec quote and existing prerequisite behavior must remain unchanged.
  Existing-system checks follow [passives-regressions.md](passives-regressions.md).

Actual live probe results and screenshots are appended by the coordinating agent
once executed. Compilation and offline metadata checks do not replace those checks.

## Executed local checks — 2026-10-06

The final client package passed:

| Check | Result and evidence |
| --- | --- |
| Native retro layout | All six trees at both 1280×800 and 800×640: 17 centered captions, native 32px glyphs separate from rank footers, no frame/caption/branch-label crossings, 21 unique connections touching their actual endpoints, scroll endpoints and reachable controls. `out/passives-ui-preview.log`. |
| Live branch progress | Every tree: Guard 0/4 → 3/4 locked → 4/4 unlocked → Undo 0/4. Visible padlock, disabled/enabled Add button and explanatory requirement row checked in the real connected client. |
| Authoritative prerequisites | Every tree: forged allocations with points in Sustain instead of Guard, only three Guard minor points, and removal of a required minor from an applied build were rejected by native validation without changing revision or ranks. All four areas accepted 3+1 minor ranks and their major in a complete applied build. `out/passives-regressions/six-trees-contract.log`. |
| Existing passive contracts | Six catalogs, all 18 capstone presets, correct/wrong weapon activation, health restoration, reset, Stop and logout passed. Same live contract log. |
| Existing-system regressions | Normal-profile module guard, lifecycle, baseline combat/conditions with passives enabled but no overlay, and baseline with the feature flag disabled passed. `out/passives-ui-regressions.log`; detailed logs under `out/passives-regressions/`. |
| Permanent Reaver profile | Real third Ascension choice, retained legacy learning/two starters, capstone save/relogin, forged protocol gates, free/paid/unfunded respec, death, personal-store reconnect, TCP detach, level-loss milestone and ordinary top-menu reopen passed. `out/passives-ui-permanent.log` and `out/passives-permanent-tests/third-ascension.log`. |

The native renders found two concrete layout problems and were rerun after fixes:
the branch-label rectangle touched a gutter connector, and Lifekeeper's Measured
Remedy caption exceeded its width. Branch labels now leave both gutter tracks
clear; all major/capstone captions use a centered 108px width. A separate visual
review inspected the final Reaver desktop and Lifekeeper small-window images.

Screenshots are under `out/passives-ui-review/`: each class has an offline native
render in both sizes, a live Guard 3/4 lock example, and an applied live preset.
The offline images explicitly identify their preview status. Live screenshots
use the disposable administrator's temporary overlay; they do not alter a class.

Permanent save/reconnect evidence above is for Reaver. Other five permanent class
profiles, every element/resistance combination, hunting balance, PvP, production
load and an installed DEV/PROD updater were not retested in this UI increment.
No talent powers, point milestones, spell costs or native prerequisite rules
changed. Everything remains local; no commit, push or production upload occurred.

### Previous first UI increment artifact identity

- Local package `out/install/x64-LocalPassives/data.zip` SHA256:
  `582095037d09e254a1e89c426d9e3c71bb487850e9867ebec017d11fd62cd33f`.
- Package and owned runtime `checksum_expected.txt` both SHA256:
  `2cc7980dcfc8f66ecc5ff68efbd349fd3db723c624e20c8b96b7bce847246574`.
  Login CS1 remains `d08bec84`; the manifest lists eight legacy resources and
  116 passive resources. The archive SHA covers the complete package.
- Native server binary is unchanged for this increment, SHA256:
  `7bdb50b29e8d048cf4a7bd8d4589ac25be3649963264626192e4d6cc071f7da5`.
- Server catalog source and runtime copy both SHA256:
  `478d920791f27fb79c8e77f2766f7dd4491ea70b193a004f3401a54d60707d35`.
- Server definitions source and runtime copy both SHA256:
  `7c990179ea167ff07bb48adac93b74f8d6a3144694e9bb6c2dd649464f7aa90d`.

### Manual local review

Start `out/install/x64-LocalPassives/Start Local Passives.cmd`, then log in as
`passivetest` / `passivetest` (Passive Tester). The owned loopback server uses
login7174/game7175 and isolated DB33308. For the Reaver overlay:

```text
/passiveqa equip reaver
/passivetest start reaver
```

The same pair of commands supports `blademaster`, `earthshaker`, `marksman`,
`arcanist` and `lifekeeper`. `/passivetest stop` ends the temporary overlay.
The fixture-only equip command is restricted to the allowlisted loopback test
administrator. Ordinary players retain the permanent class/weapon rules.

## Talent-name harmonization follow-up — 2026-10-06

The earlier caption check centered the label rectangle, but did not check the
actual text alignment. `PassiveCaption` used unsupported `topcenter`; the native
translator fell back to `AlignNone`, so the letters remained left-aligned.
The valid branch-caption setting is now `top` (top-center), and the dedicated
talent-name style uses `center`. All names use the attached nameplates described
in the current visual contract above. Their borders reflect selection and rank
state, and their tooltips and clicks match the corresponding node.

The final local client was rebuilt and checked in the native client:

- All six trees at both **1280×800** and **800×640** passed. Checks now assert
  actual `AlignCenter`, complete name text, width and height fit, the same 30px
  band height, attachment to the frame, and all 17 nameplate clicks. Existing
  32px icon, rank-footer, 21-connection, collision and control checks remain.
  Evidence: `out/passives-names-build.log`, `out/passives-names-preview.log`.
- The normal-profile guard, lifecycle and connected six-tree contract passed
  again. The latter includes Guard 0/4 → locked 3/4 → unlocked 4/4 → Undo 0/4,
  forged native prerequisite rejection, legal 3+1 splits in every branch,
  all 18 capstone presets, weapon activation, reset, Stop and logout.
  Evidence: `out/passives-names-guard.log`, `out/passives-names-lifecycle.log`,
  `out/passives-names-contract.log`.
- Visual inspection covered Reaver desktop, Blademaster small-window and the
  live Reaver Guard 3/4 state. An independent reviewer also inspected the first
  two native renders and found no blocking name-placement issues.

New screenshots are in **`out/passives-nameplates/`**. For each class this contains
desktop and small-window native previews, a connected Guard 3/4 screenshot and
an applied live preset. The previous `out/passives-ui-review/` images are retained
as earlier evidence and do not show this correction.

This follow-up changes client presentation only. Native server code, balance and
prerequisite thresholds are unchanged. The enabled/disabled baseline suites and
permanent Reaver scenario were not rerun for this label correction; their earlier
results remain recorded above. No commit, push or deployment occurred.

### Current final artifact identity (supersedes the first UI increment)

- Local `out/install/x64-LocalPassives/data.zip` SHA256:
  `9e9393aac30b200694c13b4fcb35a1b62e150cf7d6582221dc50148a3c092149`.
- Package and owned runtime `checksum_expected.txt` both SHA256:
  `8e9479c8f3fbd2b2aed5d560b98b617268088544b791876cbf201371bb4cd822`.
  Login CS1 remains `d08bec84`; eight legacy and 116 passive resources are listed.
- Server binary and catalog/definitions source/runtime identities are unchanged
  from the first UI increment recorded above.
