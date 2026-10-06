# Local passive trees: actual test results

## Current review and open issues

The current fixes, package assessment and actually executed verification are in
[the fixes verification report](passives-fixes-verification.md). That report
supersedes status and readiness claims in this document and in
[the original final audit](passives-final-audit.md).

The original audit reproduced draft loss on rejected Apply, incomplete special
bleeding budgets and counted wounds on immune targets. Subsequent corrections
and their verification are recorded in the fixes report; these older findings
must not be read as current unfixed defects. Exact Git exceptions have also been
added for both server tuning files without unignoring the private root
`config.lua`. **No manual root-config additions are required for these fixes.**
The fixes report identifies the versioned game-data configuration that must
accompany a future server deployment.

**Everything below records earlier local test campaigns.** Dated results,
"current" or "final" headings, artifact descriptions and visual dimensions below
are historical, not the status of the latest build. Their original evidence is
retained. Current numeric defaults live in the server's two balance config files.

Tested locally on 2026-10-05 with the built Windows client and server. These
results distinguish native rendering, real connected gameplay and source review.
No commit, push or production deployment was performed.

## Six-tree expansion: historical campaign status

All six standalone administrative test trees are implemented locally. This does
not change the characters' real classes, vocations or ascensions. The following
expansion checks have passed:

| Check | Evidence and scope |
| --- | --- |
| Catalogs and configuration | Six catalogs have 17 stable node IDs, 21 edges and 5/3/1 rank limits. Numeric configuration is isolated by tree; resource paths and catalog fragmentation were checked |
| Native connected contract | `PASSIVES_ALL_TREES_CONTRACT_OK`: all six catalogs, fresh sessions, all 18 legal 24-point presets, equipment activation, no free healing on re-equip, reset, Stop and logout |
| Native retro presentation | `PASSIVES_ALL_TREES_UI_OK` and `PASSIVES_NATIVE_PREVIEW_OK`: all six trees at 1280×800; Lifekeeper also at 800×640. Cards, native 32px icons, caption widths, connectors, controls and detail scrolling were asserted |
| Existing spell hand checks | LuaJIT loaded all 23 allowlisted spell files and tested 140 weapon-predicate cases. The narrow nil-hand iteration fix was checked for left-only, right-only, mixed, wrong and empty hands; this is a predicate test, not a full live cast test for every spell |

All fifteen new capstones have now passed their individual natural live runs.
Each listed log contains both `PASSIVES_CAPSTONE_NATURAL_OK <tree> <cap>` and
`PASSIVES_CAPSTONE_OK <tree> <cap>`, with no failure marker. The first confirms
a natural proc; the second follows Stop, restoration to base maximum HP and
logout/UI cleanup. Party and final regression rows remain for the campaign owner
to complete. Catalog/UI checks alone do not count as a live capstone pass.

### Final live campaign results

| Tree | Capstone | Final status | Retained evidence / observation |
| --- | --- | --- | --- |
| Blademaster | Duelist | PASS | `out/passives-natural-blademaster-duelist.log`; natural finisher proc |
| Blademaster | Riposte | PASS | `out/passives-natural-blademaster-riposte.log`; natural proc and six real shield blocks observed |
| Blademaster | Blade Storm | PASS | `out/passives-natural-blademaster-bladestorm.log`; ordinary critical hit, legal 5.5% crit build |
| Earthshaker | Aftershock | PASS | `out/passives-natural-earthshaker-aftershock.log`; natural proc through ordinary hits and existing spell |
| Earthshaker | Stoneguard | PASS | `out/passives-natural-earthshaker-stoneguard.log`; natural proc, five real shield blocks, three guard charges observed |
| Earthshaker | Stonebond | PASS | `out/passives-natural-earthshaker-stonebond.log`; natural shield-block proc, 23-HP caster ward observed; party case below |
| Marksman | Deadeye | PASS | `out/passives-natural-marksman-deadeye.log`; natural ordinary-arrow proc |
| Marksman | Skirmisher | PASS | `out/passives-natural-marksman-skirmisher.log`; movement between ordinary shots and natural proc |
| Marksman | Quarry | PASS | `out/passives-natural-marksman-quarry.log`; natural proc with 9.72 seconds of mark remaining at observation |
| Arcanist | Conduit | PASS | `out/passives-natural-arcanist-conduit.log`; effective existing wand-spell casts produced a proc |
| Arcanist | Resonance | PASS | `out/passives-natural-arcanist-resonance.log`; effective existing wand-spell casts produced a proc |
| Arcanist | Spellweaver | PASS | `out/passives-natural-arcanist-spellweaver.log`; real Lightning Bolt/Shock Blast alternation at 4.4-second intervals |
| Lifekeeper | Renewal | PASS | `out/passives-natural-lifekeeper-renewal.log`; direct healing proc and two HP of actual follow-up healing observed |
| Lifekeeper | Aegis | PASS | `out/passives-natural-lifekeeper-aegis.log`; 28 effective healing and a four-HP ward observed |
| Lifekeeper | Concord | PASS | `out/passives-natural-lifekeeper-concord.log`; ordinary rod damage produced six effective healing on caster; party case below |
| Earthshaker + ordinary party peer | Stonebond shared ward | PASS | `out/passives-final-party-stonebond.log`; real shield-block creation on both players; peer without overlay absorbed controlled native monster combat: ward22 ->12, HP735 unchanged before expiry |
| Lifekeeper + ordinary party peer | Concord effective healing | PASS | `out/passives-final-party-concord.log`; two real clients in party; six effective healing to the peer without overlay, matching native recipient ID |
| Reaver, final expanded binary | Bloodguard absorption/equipment regression | PASS | `out/passives-final-ward.log`; natural shield, actual absorption, unequip/re-equip and no free healing |

For a pass, record the final binary/package and unique retained log or screenshot.
The capstone runner reuses its output directory between runs, so its last log
alone cannot prove all fifteen cases. Record any skipped or failed case explicitly.

Two initial fixture attempts timed out without demonstrating a native combat
defect. Blade Storm's original 2.5% critical chance was too unreliable for the
bounded run; a legal draft with three Precision major ranks raised it to 5.5%,
and a real ordinary critical hit passed. Spellweaver's first 2.6-second cast
spacing ignored the existing four-second attack-group cooldown; using 4.4 seconds
allowed actual alternating casts and passed. Neither correction forced a proc
counter or changed native combat code for the campaign.

The existing campaign checks natural activation/procs and cleanup. Its party
variant checks a ward on the caster and a real peer with no passive overlay, exactly ten HP of controlled native monster-combat absorption before expiry, or
effective Concord healing on that peer. These checks do not independently
measure every damage/mana coefficient or every additional AoE recipient.
Concord's current runner uses ordinary rod attacks; it does not prove offensive
Ensnare casts. Arcanist runs use Lightning Bolt and Shock Blast; deferred
Soul Drain/Chain Lightning full-cast budgets and delayed kill credit have been
reviewed in source, but are not numerically measured by those smoke runs.

Expansion contract logs: `out/passives-all-trees-contract/stdout.txt` and
`out/passives-all-trees-contract-result.log`. Expansion UI logs:
`out/passives-preview/stdout.txt` and `out/passives-all-trees-ui-result.log`.

## Final six-tree presentation and visual limits

The final shape treatment distinguishes 44×44 minor cards, bronze double-frame
64×64 major cards and wider 104×64 capstone cards with a permanent CAPSTONE label.
Every glyph remains native 32×32 with smoothing disabled. This final major/
capstone shape arrangement supersedes the earlier Reaver frame treatment
described below. Shared prerequisite rails and selected gold routes remain.

The combat HUD now distinguishes accumulating mechanics from reactive triggers.
Blade Storm, Stonebond, Renewal, Aegis and Concord display their trigger text
instead of a misleading empty charging bar. Other trees display the authoritative
charge/Guard/Casts progress, while Reaver retains rage, Berserk, ward and owned
target bleeding feedback. A wrong weapon displays the matching weapon
requirement. Labels use the catalog's player-facing capstone names.

Extra passive damage currently uses the existing `HITAREA` visual for physical
damage and `ENERGYHIT` for other elements. The damage retains its actual combat
element; the generic visual is a prototype limitation and does not establish
an element-specific final animation treatment.

## Reaver phase one: visual correction after review

The client presentation now grows from minor nodes at the bottom to capstones
at the top. Majors have their names inside their cards. Capstones have a larger
64px bronze double frame and a permanent tier label; glyphs remain native 32px.
Shared connections are drawn once as separate forks between tiers, without
crossing cards or labels. All nine major-to-capstone relations remain visible
through shared rails, with upward chevrons below the three capstones. Sustain
and Guard exchange display columns to make room for those paths. Selecting a
capstone highlights its paths and eligible majors, and the details describe the
actual any-two-at-rank-2 requirement. Shared segments are rendered once and
combine their routes' colors. Server prerequisites, point costs and combat
effects are unchanged.

The final package passed the native preview again at 1280×800 and 800×640:
all 17 tier-sized cards are inside the canvas, no cards overlap, tier order is
bottom-up, icons remain 32px, capstone tier text fits, capstone connections remain
visible with a minor node selected, no connector crosses a card, and tree/detail
scroll endpoints work. The real connected contract test then passed draft allocation,
Apply, server rejections, preset, confirmation reset and reopen/logout.
Screenshots after restoring all capstone links:
`out/passives-evidence/passives-capstone-links-live.png`,
`passives-capstone-links-draft.png` and `passives-capstone-links-small.png`.

## Previously passed Reaver checks (phase one)

The following results were obtained before the five-tree native expansion.
They remain historical evidence; they do not by themselves prove that every
expanded-binary combat path has been rerun.

| Check | Evidence |
| --- | --- |
| Client/server native builds | Successful link; local client archive packaged after final UI changes |
| Retro window at 1280×800 and 800×640 | Real OpenGL client; 17 nodes, 32px glyphs, controls inside the screen and detail-scroll endpoints |
| Real login and catalog | `PASSIVES_CONTRACT_OK`; native loopback game connection, opcode 103 handshake, 17 nodes (8/6/3), fragment reassembly |
| Draft and Apply | UI changed a legal 16-point draft; server accepted it without changing level |
| Server validation | Stale revision, two capstones and missing prerequisites were rejected without changing the authoritative build |
| Reset/reopen/logout | Confirmation reset restored 24 available points; Close and server Open worked; onGameEnd removed state and both windows |
| Missing command target | Explicit offline name returned an error and did not stop the administrator's overlay |
| Berserker | Ten successful ordinary axe hits naturally activated the eight-second phase; rage was consumed |
| Pressure | Native trace recorded actual secondary damage on an adjacent monster during ordinary attacks |
| Bloodletting | Ordinary attacks naturally accumulated three wounds. Two real clients each owned three wounds on the same target, six total |
| Ownership cleanup | Ending one overlay removed its three wounds, leaving the peer's three. Existing Cure Bleeding then removed the remaining wounds |
| Bloodguard creation | Actual hits of 89+70+62 HP damage yielded a 46-HP shield, capped by floor(779×6%) |
| Shield absorption | Shield budget decreased while still unexpired during ordinary monster attacks; native trace recorded absorption |
| Actual weapon change | Axe moved from inventory onto the ground: effects cleared, status became inactive, max HP returned to 735. Re-equipping restored derived max HP without healing |
| Vitality/Guard HP | Base 735 → 771 with 5% Vitality; 735 → 779 with 2% Vitality + 4% Guard. Stop returned max HP to 735 |
| Spell mana payment | Real Head Splitter cast with 5% Efficiency: mana 390 → 371, exactly 19 paid rather than 20 |
| Focus | Five ranks recovered 3 mana over six seconds with fractional accounting |
| Saved character state | After logout both fixture characters remained level 40, axe skill 60, permanent max HP 735; current HP did not exceed base max HP |

The first natural Berserker run and the contract tests exposed genuine integration
errors. Fixes were made before reporting success: native OTUI anchor cycles,
missing session in Open, status window closing its own saved toggle, wrong
condition ID in diagnostic quiesce and an offline-target fallback to the actor.

The two-owner probe initially checked before the peer's third wound arrived.
It now polls native metrics until both sources have their own three stacks. No
rage, wound or shield counters were forced in the natural combat tests.

## Reaver phase-one evidence files

Raw logs are retained locally under `out/`:

- `local-passives-client-build.log`, `local-passives-server-build.log`
- `passives-contract-run.log`
- `passives-combat-run.log` — complete natural three-capstone/two-owner run
- `passives-ward-run.log` — additional absorption and equipment-change run
- `passives-resources-run.log`
- `passives-small-ui-run.log`
- `local-server/passives-runtime/server-stdout.log`

Screenshots were captured by the actual client and sent in the conversation.
They are copied into `out/passives-evidence/` for easier inspection. Offline
preview images explicitly say they do not prove combat. Live images include
`passives-contract-05-bloodletting-preset.png`,
`passives-combat-01-natural-berserker.png`,
`passives-combat-02-three-owned-wounds.png`,
`passives-combat-04-bloodguard-shield.png` and
`passives-combat-05-axe-inactive.png`.

## Scope of the conclusions

The phase-one results prove Reaver can be rendered, allocated and tested through
real client/server gameplay. The expansion results additionally prove the
six-tree catalog/UI/allocation contract. Neither is a finished balance study.
Every rank, low-damage rounding case, critical probability,
kill-heal cooldown, mitigation combination and equipment interaction has not
been independently measured across all builds. Death cleanup and normal-profile
gating were reviewed in source; they have not been asserted by a dedicated live
death/baseline regression probe in this run.

There are no new classes or ascension integration, no permanent point economy,
paid respec, new spells or Rend synergy. Eligible spells are existing server
spells. All six trees remain temporary local test overlays; progression and
class/ascension integration are later work.

See `local-passives-test.md` for launchers, accounts, commands and configuration.

## Package from capstone and UI verification

Client archive SHA256 for that verification:
`ae7d5d3158a9a734c44078763212b2c55b81be54e774ac2231b71649865da675`.
Native server executable SHA256:
`d2d2b146a109700b45ffbc8221dded650a70931059f3021cee43edfc795aba81`.
Login checksum: `CS1:d08bec84`; eight critical resources and 112 passive resources.
The local startup helper copied the matching checksum files into the isolated
runtime. Nothing needs to be uploaded to the live server for these local tests.

- `out/passives-final-all-trees-contract.log`: all six native allocation/equipment/reset contracts.
- `out/passives-final-all-trees-ui.log`: six retro layouts and the 800x640 window gate on the final client package.
- `out/passives-final-resources.log`: actual discounted mana payment and fractional regeneration.
- `out/passives-final-ward.log`: Reaver natural shield absorption and equipment regression.
- `out/passives-final-party-stonebond.log`: natural shared ward creation followed by controlled native monster combat against a peer with no overlay, ward22->12 while HP735 stayed unchanged and ward remained unexpired.
- `out/passives-final-party-concord.log`: actual party healing to the peer without an overlay.

Final live screenshots:
`out/passives-evidence/passives-shapes-live.png` (Blade Storm, after the form swap)
and `out/passives-evidence/passives-lifekeeper-live.png` (Renewal and the corrected
reactive HUD). The native preview remains explicitly labeled as a rendering-only test.

The first party-absorption observer could confuse ward expiry with absorption.
The final test excludes that ambiguity by requiring at least 2.5 seconds of
ward lifetime before fixed ten-HP incoming native combat and asserting exact
budget reduction and unchanged recipient HP before expiry. No passive ward or
proc counter was forced. The timed peer client was restarted for synchronized
runs; each final party log is retained separately.
### Delayed cast/session lifecycle: PASS

`out/passives-final-delayed.log` contains `PASSIVES_DELAYED_OK`.
A real Soul Drain first hit and second pulse contributed exactly one Conduit
cast while callbacks remained pending. Stop discarded that session. An atomic
fixture restart created a new ordinary authorized Arcanist/Conduit preset with
a different session. The old spell's later baseline pulses reduced the same
living target from999666 to999115 HP; the new overlay retained progress0,
procCount0 and ready0 through the37.7-second observation window. Final Stop
restored735 max HP and logout removed the passive UI.

The atomic transition is diagnostic only: `/passiveqa restartconduit` is limited
to Passive Tester in the disposable arena. It moves the caster beyond stationary
monster melee, clears the diagnostic target/INFIGHT flag, then calls the ordinary
GOD start/preset handlers synchronously. No charge, proc or ward is forced and no
native combat gate was relaxed. Separate client commands allowed a real old pulse
to restore INFIGHT between Start and Preset, correctly triggering the normal
combat gate. Those earlier fixture attempts are not native gameplay defects.
## Central configuration verification (2026-10-05)

All implemented numeric node/capstone strengths remain in the server source
`data/lib/passives/config.lua`. Former hardcoded shared timers, Pressure hit
count/cooldown, Steady HP threshold, combined mana-discount ceiling and Reaver
rage threshold/hit counts/bleed ticks now use that same configuration. Defaults
were preserved. Node descriptions and the Reaver rage meter use server values.
Critical-chance text preserves integer basis-point precision, including 0.25.
Steady text distinguishes unconditional received-healing bonus from its
low-HP-only physical mitigation.

The focused real-client test changed only the disposable runtime's Reaver
values, never the source balance:

- `minorVitality=2`: rank5 catalog +10%, actual native/client max HP808
  (`735 + floor(735 * 10%)`). Blademaster still reported +5% at rank5.
- `minorPrecisionBps=25`: catalog +0.25 percentage points per rank.
- `majorCriticalReadyMs=16000`: catalog readiness text16 seconds.
- `rageThreshold=40`: native runtime and client HUD both40; ordinary attacks
  built rage10,20,30 and the fourth successful hit naturally activated Berserker.
  Native metrics reported exactly one Berserker proc; no proc/rage was forced.
- Stop restored735 max HP; logout removed passive state and both windows.

`out/passives-config-live.log` contains `PASSIVES_CONFIG_OK`.
`out/passives-config-default-contract.log` contains
`PASSIVES_ALL_TREES_CONTRACT_OK` after restoration, covering the default six-tree
allocation/equipment/reset/Stop/logout contract. The override was restored in
`finally`; source and runtime config SHA256 matched afterwards. The local server
is left running with normal source values. The latest catalog text correction
was syntax-checked and refreshed into that runtime.

Client/server incremental builds passed:
`out/passives-config-client-build.log`, `out/passives-config-server-build.log`.
Current client archive SHA256:
`3a7c33901353e851229239099eced95fc2616518eab168f277f5bc106953cef6`.
Native server SHA256 for the central configuration verification:
`1dee42547867b84481326071f18c6baee59c09e76aa41020e2d728b79d6e27ba`.
Login checksum remains `CS1:d08bec84` (eight critical and112 passive resources).
No commits, pushes or live-server uploads were made.

Screenshot: `out/passives-evidence/passives-config-natural.png`. Its40-rage
threshold is the temporary test override; the default is restored to100.
See `passives-balance-config.md` for units and normal editing/restart instructions.
## Existing-system regression verification (2026-10-05)

Three independent reviews mapped the shared combat, spell/timer, condition,
persistence and client-startup paths. This exposed two reproducible/compositional
risks, which were fixed before the final regression run:

1. Native HP-percent conditions included temporary passive HP in their stored
   fixed increase. The old binary reproduced771 +20%=925, then Stop889 instead
   of882 (`out/passives-regression-hp-reproduce.log`). Condition HP calculations
   now exclude only the active overlay contribution; no-overlay calculations
   retain their original behavior. No such HP-percent condition currently exists
   in authored live content; the regression exercises the existing native API.
2. Personal-store soft logout and TCP detach bypass ordinary creature-removal
   cleanup. Overlay discard now runs before vendor save and before resetting the
   current protocol. Protocol identity is checked before cleanup, so an old
   connection cannot discard a new player's session.

The final reusable runner passed all gates:
`out/passives-regression-suite-final.log`.

- `out/passives-regressions/normal-module-guard.log`: actual encrypted packaged
  module loaded with native loadfile into an isolated normal-flag environment;
  no opcode/event/UI registration. Existing offline modules/widgets present.
- `out/passives-regressions/lifecycle.log`: HP-condition ordering918/882/735,
  incompatible weapon/Stop, savedHP882/basehealthmax735, persistent ordinary buff
  after reconnect, non-admin native start denial, real store soft logout and TCP
  detach with same offline entity/IP0/maxHP735, reconnect without an overlay,
  real lethal native death with fixture skill/loot loss disabled, final baseHP735.
- `out/passives-regressions/baseline-enabled.log`: no overlays anywhere; fixed
  native damage37/healing17, three AoE targets each74 after legacy100% crit roll,
  mana shield HP loss0/mana loss37, strongest standard bleeding plus poison
  totaling10 over the observation window, independent cures, canceled/working
  Lua events, right-hand-only Head Splitter20mana, rejected recast noextra cost,
  real Light Healing20mana.
- `out/passives-regressions/baseline-disabled.log`: same successful baseline
  checks with passiveTestEnabled=false. The source config was not edited.
- `out/passives-regressions/six-trees-contract.log`: final restored config and
  six-tree allocation/equipment/reset/Stop/logout contract.

Early fixture failures were corrected at the test layer, without relaxing any
native combat gates: the normal module initially read encrypted bytes through
readFileContents rather than native loadfile; the first area shape rotated away
from the third target; death with fixture skillLoss=false immediately respawns
and uses the real server death message instead of the normal relog-window packet.
Final assertions still require all three damage targets and genuine native death.

Source/default runtime balance hashes match; passiveTestEnabled=true is restored.
The local server is left running. Client package remains
`3a7c33901353e851229239099eced95fc2616518eab168f277f5bc106953cef6`.
Final rebuilt native server SHA256:
`aee1ea59d84753033fccf4e00ab346e721318b8878ab392b4e98ba78349f6ef6`.
`out/passives-regression-server-build.log` records the successful build;
both repositories' tracked diffs pass git diff --check.

The actual client ZIP passed zipfile integrity checks and every listed legacy/
passive resource CRC matched its stored entry. All112 passive resources are listed.
Login-CS1 alone does not cover those resources. No commit/push/upload was made.

Screenshot: `out/passives-evidence/passives-regression-clean.png` shows the real
retro client after cleanup/death/reconnect,735/735 HP and no passive tree/HUD.
See `passives-regressions.md` for the repeatable command and explicit coverage
limits, including normal installed updater, PvP, all equipment/death-loss rules
and load testing. Regression expectations are also recorded in each repository's
AGENTS.md for future substantial system work.

## Permanent third-Ascension foundation (2026-10-05)

The local retro client now supports an ordinary player's locked class and saved
tree. Six classes share the existing Ascended vocation3; the class ledger is
separate. Point milestones and bank respec fees are centralized in the server
config. Starter spells are not part of this increment. No commit, push or deployed
database change was made.

`out/passives-permanent-suite-final.log` passed four real native-client scenarios:

- New third Ascension through The Nameless: cancel leaves no class; confirmation
  commits vocation3, level1, focus2, quest8 and Reaver with3 points. Three saved
  Vitality ranks survive login; baseHP150 is stored, derivedHP154 is restored.
- Level40 earns16 points and permits the first Berserker capstone. Saved rank
  removal, overspending and stale revisions are rejected by their specific
  guards. Ordinary players cannot invoke admin overlays or overwrite class.
- UI cancel, free respec, unfunded rejection and a1000 bank respec pass. Bank,
  ranks and persisted count agree; next displayed fee is2000. Later level loss
  retains16 earned points; level43 earns17 once. Final build spends16 of17.
- Real lethal death/relogin, personal-store soft logout, TCP detach and reconnect
  preserve ranks while offline maxHP/saved baseHP remain735. Ordinary topmenu
  reopening,800x640 control containment and final logout cleanup pass.
- Existing Ascended axe focus chooses Reaver; magic focus independently chooses
  Arcanist and Lifekeeper. Real Oracle Stone revisit and class confirmation keep
  level40, mana, old discipline and ordinary permissions. Each class survives
  reconnect.

`out/passives-permanent-fault-suite.log` passed intentional invalid-rank login
rejection and repaired login. The expected GUID9005 invalid-data server error is
required in addition to the disconnect; online status is cleared, the rejected
row is not rewritten, and the repaired class/UI return.

`out/passives-permanent-cold-suite.log` passed on the final native build. A real
startup offline vendor began with IP0, baseHP735 and store1. First reconnect used
runtime-only overrides:17 points,777 respec fee and808 maxHP from five Vitality
ranks at2% each. With an invalid ledger, the native class error was returned and
the same vendor remained IP0/baseHP735/store1 afterwards. Source defaults and its
original ledger were restored in `finally`.

`out/passives-permanent-regressions-final.log` passed the final native build's
normal client module guard, temporary-overlay lifecycle, ordinary combat/spells/
timers/conditions with the feature enabled and disabled, and all six tree
allocation/equipment/reset contracts. It restored the normal runtime config.
These gates cover the earlier HP-condition, store and TCP cleanup fixes as well.

The tests exposed and resolved these integration failures:

1. Snapshot reads consumed a point update before the client notification; reads
   are now pure and the think path publishes newly earned points.
2. Offline-store/TCP reconnect bypasses Lua login; native reconnect now restores
   the permanent build. Trusted startup also seeds all native configs, covering
   the first offline-store reconnect after server restart.
3. Rejecting a reconnect could clear an existing store. The failure path preserves
   it, including startup vendors that lack the soft-logout marker.

Fixture errors were corrected without changing combat/network protections:
combat-condition ID cleanup, NPC range/current-tile placement, protocol860/RSA,
shared Windows log reads, and reconnect timing above the existing five-second
IP throttle window. The PvE death probe uses removal/relogin rather than assuming
an in-place respawn. A pre-existing widget1263 cleanup warning also occurs in the
normal/no-passives probes; this increment did not establish its cause.

Canonical schema includes `player_passives`. Migration30 creates it idempotently
and advances to31 only on success; the disposable database is at31. Source Lua
syntax, PowerShell parsing and both tracked `git diff --check` gates pass.

Build logs: `out/passives-permanent-final-native-build.log` (startup configuration
and full class suite), `out/passives-permanent-vendor-failure-build.log` (the final
failed-reconnect guard). Final server SHA256:
`4c04d72bf9a3f3ae2d87e355d06aa114bdcc3e33459a25118100fe9cc70469bc`.
Client archive SHA256:
`00e62e46f4c5ccd89836783e7fa00e579bc24875fcec7ba62d6db52e7c9426f6`.
ZIP integrity and all120 listed CRCs pass: eight legacy critical resources plus
112 passive resources. Login checksum remains `CS1:d08bec84`.

Actual screenshots: `out/passives-evidence/passives-permanent-ready.png`,
`passives-permanent-small.png`, `passives-permanent-arcanist.png` and
`passives-permanent-lifekeeper.png`. Numbers/fees are provisional; these checks
establish persistence and integration, not final balance or all legacy quests.

Final manual login also passed on the final server with source-default config:
`out/passives-permanent-manual-login.log`. It restored Reaver/17 points/Berserker,
count3/4000 fee and803 derived maxHP after restart. The disposable `passiveclass`
bank was prepared with10000 gold for manual respec. Source/runtime config SHA256
match (`0046cb69e71220caa0137ffab057e8e16361e811f164395c54df85ded2def76d`).
The final clean screenshot is
`out/passives-evidence/passives-permanent-manual-ready.png`. The isolated server
remains listening on127.0.0.1:7174/7175 and its own database on33308.

## Two starter spells per permanent class (2026-10-06)

All six permanent classes now have two local starter spells. They are granted
with class choice, persisted in `player_spells`, and repaired idempotently on
permanent-class restoration. Existing learned spells are retained. The ordinary
retro client has a separate two-card Class Spells window, optional named party
healing, native32px existing glyphs and server-published shared exhaustion.
No DAT/SPR/OTB additions or new spell animations were required. No commit, push,
deployment or production database change was made.

### Actual new-feature evidence

- `out/class-spells-suite-final.log` passed Reaver and Blademaster. It then
  exposed a real Marksman gate failure: bows have no weapon-registry entry;
  their compatible ammunition does. The native gate now checks the launcher and
  registered ammunition correctly. `out/class-spells-suite-final-rest.log` passed
  Earthshaker, Marksman, Arcanist and Lifekeeper after that fix. Per-class logs are
  under `out/class-spells-tests/`.
- The six ordinary group1 characters chose through The Nameless and relogged
  with exactly their two starters. All12 actual casts, real costs/shapes,
  one-round bow payment, shared cooldown, and resource-neutral wrong-class,
  wrong-weapon, unlearned and no-mana rejections passed. Resonant Burst's later
  pulses stopped when its equipped weapon context became invalid. Cards and
  controls fit800×640; logout destroyed window, button and spell state.
- `out/class-spells-arcanist.log`: a three-pulse cast advanced Conduit once;
  natural casting prepared Resonance. The fourth cast dealt51 total primary HP
  damage and its single echo dealt15, exactly floor30% of the complete three-pulse
  budget. No later pulse charged more mana. Real TCP detach invalidated a pending
  cast; reconnect had a fresh session, no old damage and no retained native action.
- `out/class-spells-synergy-suite.log` passed real ordinary-party Renewal, Aegis
  and Concord. Mending healed the named receiver and never the caster. Non-party
  and outside7×5 targets changed no mana/HP. Renewal healed36 directly plus its
  exact7-point HoT once; Aegis's33–47 direct-heal budget produced one ward on the
  healed receiver. Essence Lash dealt30 damage and Concord healed12 from actual
  damage, with one proc. Each phase retained separate main/peer logs under
  `out/class-spells-synergy-tests/`.
- `out/class-spells-cooldown.log`: after clearing the client window/state and
  requesting a fresh catalog, both cards recovered actual remaining exhaustion
  following Cleaving Arc14mana and legacy Head Splitter20mana. Replayed deadline
  differed by only4ms/3ms, without restarting the4s timer. Real expiry re-enabled
  both cards. This exercises the new remaining-condition catalog replay.

The QA dummies initially put players in combat despite their empty attack list.
Source review confirmed that a hostile monster's normal target callback applies
fight status before attack entries run. The disposable spell dummy is now
attackable and non-hostile. Runtime-only weapons pause later ordinary swings to
keep damage/mana/ammo measurements isolated; cleanup removes that attribute.
Actual player targeting and casts still use normal combat and class gates.

### Affected existing-system evidence

- `out/class-spells-regressions-final.log` passed the normal-client module guard,
  HP-condition/overlay/death/store/TCP lifecycle, fixed native damage/healing,
  legacy AoE crit, mana shield, standard bleeding/poison/cures, legacy timers,
  Head Splitter and Light Healing with the local feature enabled and disabled,
  followed by all six temporary-tree contracts. Runtime source defaults restored.
- `out/class-spells-permanent-main.log` passed the real third Ascension's
  cancel/confirm flow, initial three points, saved ranks, point growth and respec,
  lethal death/relogin, personal-store soft logout and TCP reconnect. The extended
  probe explicitly measured0/12 starters before choice and after cancellation,
  then exactly the correct2/12 plus preserved Light Healing after Ascension,
  ordinary save and relog. Saved rows for the new spells were unique.
- `out/class-spells-permanent-fault.log` passed invalid-ledger login rejection and
  repair. `out/class-spells-permanent-cold.log` passed configured first reconnect
  to a startup offline vendor and preservation of that vendor after a rejected
  reconnect. These rerun the restoration path now responsible for starter grants.
- `out/class-spells-startup-suite.log` passed invalid-mana and missing-wrapper
  negative cases. Both produced the specific fatal cause while7174/7175 stayed
  closed. The helper restored exact runtime bytes, then restarted the valid server.

### Lore, balance and review

The Nameless's dialogue was checked against its existing flow and relevant
Eldric/Garrick/Hyacinth content. Class choices list their discipline before an
irreversible confirmation; paths are permanent and talents may be reshaped.
Fourfold training is described as future growth, and failures keep diagnostic
details in the server log. The final third-Ascension test exercised this wording.

`data/lib/class_spells/config.lua` centralizes numerical starter tuning. Rend is
12mana/3s and Rolling Thunder8mana/4s after comparing their lower raw damage
budgets with the existing Head Splitter/Ground Slam. All numbers remain provisional.
Flurry, Rolling Thunder and Scattershot are new replacement proposals for local
playtesting, rather than previously approved final spell designs.

The inherited Ascension reset leaves level1/maxmana0. New spells are learned at
choice but first fit normal mana capacity at levels2–4. Human hunting at levels1–4
and40 is still required, particularly Lifekeeper's resource economy, Flurry against
armor, Ground Slam's existing healing-exhaustion rotation and Burst Arrow/Sure
Shot versus Scattershot. This is technical integration evidence, not final
balance, production load, all element/resistance combinations or a full quest audit.

Build logs: `out/class-spells-client-build-final.log`,
`out/class-spells-server-build-final.log`. Final native server SHA256:
`fb4ea87e1ecd1f1f811371296fb6ba6c0312f3deb04de7ae7522fc74e0017775`.
The final source/runtime starter config hashes match:
`6649c9447369af983165c2cf41f4d4f33cb90c6257bc03798e4f8dde59a6800b`.
The final Nameless hashes match too:
`15f1a414b9c86b4893d8c7833cfdba4d922865e46b4b75904dffeaa4ccfc10e6`.

Clean actual retro screenshots are under `out/passives-evidence/`:
`class-spells-lifekeeper-review-ready.png`,
`class-spells-lifekeeper-review-small.png`,
`class-spells-reaver-review-ready.png`, `class-spells-reaver-review-small.png`.
Party/damage evidence includes `class-spells-concord-essence-party.png` and
`class-spells-arcanist-resonance-complete.png`.
The separate local test accounts9006–9011 and Passive Initiate9003 have10000 bank
gold for manual respec. Automated weapon-speed overrides were removed by cleanup.

The final client wording polish changed only three UI hints. Its rebuilt package
passed actual ordinary Lifekeeper/Reaver reviews at1280×800 and800×640, plus the
new/legacy cooldown replay probe (`out/class-spells-cooldown-final.log`). Final
archive SHA256:
`7f30a05621f638a63a45af8a47d228e1d556c7bfd8eb69b08a72fb0a275941d2`.
ZIP integrity and all122 listed CRCs pass (eight critical plus114 passive
resources). Login checksum remains `CS1:d08bec84`. Lua/PowerShell syntax and both
repositories' tracked `git diff --check` pass. Source and runtime are aligned;
the owned loopback server7174/7175 and database33308 remain running.

## 2026-10-06 — actual spell access and low-and-slow correction

This section supersedes the previous delivery's provisional starter values and
server/config hashes. Historical measurements above remain historical evidence.
The earlier comparison did not establish ordinary access to every registered
spell and left several new spells too efficient for the intended mana economy.
The source/map acquisition audit, all twelve before/after budgets, conditional
top-tier access and remaining hunt checks are in
[class-spell-balance-audit.md](class-spell-balance-audit.md).

### Changes

- Mending is anchored to obtainable Light Healing, not registered higher healing
  with no traced ordinary learning grant. At L40/ML6 the empty-tree raw integer
  intervals are Light24–29/20mana and Mending27–31/22mana. The old Mending
  interval was33–47/24mana. Named-party healing and paralysis removal remain.
- Physical/bow budgets and costs were revised against Head Splitter, Swipe,
  Ground Slam and ordinary-ammo Sure Shot. Rend/Flurry now use4s combat exhaustion;
  Rolling Thunder costs18 rather than8mana. Existing active spells are unchanged.
  Volley is learnable but normally blocked by disjoint melee/bow requirements;
  its advertised output is excluded from the usable baseline. Burst supply and
  highest elemental tiers remain conditional on actual gear/quest/world access.
- Focus fell from0.1 to0.025mana/s/rank. At five ranks the bonus is0.125/s,
  equivalent to25% of vocation3's normal2mana/4s food regeneration. It still works
  without food/in PZ and cannot exceed maxmana; these existing rules are explicit.
- New starters now require full weapon/ammo wield eligibility: level, ML, skill,
  vocation, premium and enabled metadata. They cannot use a forbidden item's full
  attack value. Delayed hits recheck live requirements. Legacy partial-power
  attacks remain unchanged. Retained-action validation permits successful
  consumption of the last round of bow ammo.

### Executed verification

- `out/class-spells-balance-suite.log`: all six ordinary class-choice/relogin
  scenarios and all12 revised casts passed, including actual costs, recipients,
  ammo, shared exhaustion, rejection gates and retro800×640 controls.
- Final-binary `out/class-spells-balance-wield-arcanist.log`: retained Wand of
  Vortex level6 was rejected without resources/exhaustion; level7 dealt40 real
  total damage for18mana. A fresh cast's first pulse dealt16 before real level
  loss to6; no later pulse, resource payment or passive proc continued.
- `out/class-spells-balance-wield-earthshaker.log`: Etched Warhammer's Equip
  requirement is club30, stricter than its Weapon definition's20. Retained
  effective club29 was rejected;30 dealt54 actual damage for24mana. Original
  level/skills/equipment were restored on cleanup.
- `out/class-spells-balance-wield-lifekeeper.log`: same ordinary L40/ML6 character,
  empty ranks, actual Light Healing26HP/20mana and Mending28HP/22mana. Light was
  fixture-granted for formula verification; this is not a played quest/learning
  proof or an empirical average from those two casts.
- `out/class-spells-balance-wield-marksman.log`: both starters consumed actual
  last-ammo1→0, paid14/18mana, hit2/3 monsters and left no pending/replayed action.
  Their ordinary-shot capstones did not activate from a starter cast.
- `out/class-spells-balance-cooldown.log`: revised Cleaving18mana and legacy
  Head Splitter20mana both replayed remaining4s exhaustion after UI/catalog
  rebuilding. Deadlines differed19ms/9ms and both cards waited for actual expiry.
- `out/class-spells-balance-regressions.log`: normal-client module guard,
  HP-condition/overlay/death/store/TCP lifecycle, baseline damage/healing,
  AoE crit, mana shield, ordinary bleeding/poison/cures/timers and legacy Head
  Splitter/Light Healing passed with the feature enabled and disabled, followed
  by all six temporary-tree contracts.
- `out/class-spells-balance-resources.log`: actual20mana Head Splitter paid19
  with five Efficiency ranks. Five Focus ranks recovered1mana in each of two
  contiguous9s windows,2 over18s, without resetting the fractional ledger.
  Runtime-only `quiesce` explicitly removes food regeneration for this measurement.
- `out/class-spells-balance-synergy.log`: real ordinary-party Renewal, Aegis and
  Concord passed the revised healing/cost contract. Renewal healed28 directly
  plus its exact5-point HoT once; Aegis healed30 and shielded only the receiver;
  Essence Lash dealt40 and Concord healed14 under its actual-damage/maxHP cap.
  Non-party and outside7×5 healing spent no resources or changed HP.
- `out/class-spells-balance-startup.log`: invalid mana and missing-wrapper
  cases failed before7174/7175 opened, then exact runtime files were restored.
- `out/class-spells-balance-review.log`: clean actual retro book at1280×800 and
  800×640, updated mana/formulas, native32px glyphs and logout cleanup passed.
  Reviewed screenshot: `out/passives-evidence/class-spells-balance-lifekeeper.png`.

The new requirement probes initially exposed fixture mistakes: native experience
loss changes current mana, Lua `getSkillLevel` reports base rather than effective
skill, and the test warhammer is two-handed. The fixture now snapshots payment
before level loss, measures effective skills and equips that weapon without a
shield. Those were test setup corrections; ordinary level-loss/condition/equip
behavior was not changed.

All-six casts ran on the first wield-check build. Subsequent native changes were
the Focus fallback and last-ammo retained-action rule; final-binary resource,
last-ammo, weapon-gate, cooldown, party and existing-system checks above cover
those affected inputs. Unchanged permanent-save/fault/cold-vendor restoration
tests from the preceding delivery were not repeated without a relevant change.

Final native server SHA256:
`9539f5400306975152a0da19ec5a90efc10f02c29e04e29fbc5d9aea92ca5a7d`.
Source/runtime starter config SHA256 both:
`0a70ec1486bf4c3c2a55e926f1c0de7979b47382c9c1121124db06089b6dcf2b`.
Source/runtime passive config SHA256 both:
`810404dc48817b4f65f55394a867a3a9d4c87fa6b55b182ca0dbc66011fe4660`.
Build: `out/class-spells-balance-build-final.log`. Client archive/checksums were
unchanged; values arrive from the server. Changed Lua/PowerShell syntax and both
repositories' tracked `git diff --check` passed.

The owned server7174/7175 and DB33308 are running with final source data.
All six disposable class accounts again have10000 bank gold for manual respec.
Nothing was committed, pushed or deployed. Numbers remain conservative test
balance; ordinary level1–7/40 hunts, full rotations, armor/resistance, obtainable
equipment and resource economy still require human playtesting.

## Visual class choice — 2026-10-06

Implemented a local retro class choice window owned by The Nameless. Six cards
show the class name, weapon, native Tibia outfit and playstyle, without numerical
combat values. Selection previews information; a separate server-owned
confirmation makes the permanent choice. Eligible clients receive shorter NPC
prompts, while text choice remains available. Fresh and legacy confirmations
explain their different reset consequences.

### Executed checks

| Check | Actual result |
| --- | --- |
| Native 800x640/1280x800 rendering | PASS: six cards, native portraits, selected state and both confirmation actions fit |
| Third Ascension through UI | PASS: real ordinary player, level1/mana0/quest8, focus2/Reaver, exactly two new spells, retained Light Healing, equipment leaves inventory, reconnect restores class |
| Legacy magic/sword | PASS: two/one eligible choices; confirmed Arcanist/Blademaster retain level40 and established focus, learning persists without duplicates |
| Cancel/back/default Enter, invalid token/revision/class | PASS: no class, progression or spell mutation |
| Combat, distance, 60-second expiry | PASS: rejected choices and stale requests cannot commit |
| Retained TCP entity | PASS: logout clears windows, old offer cannot grant after preexisting entity reconnect |
| Raw reserved NPC bridge text | PASS in final fresh scenario: cannot authorize prepared choice |
| Confirm replay after success | PASS in all three scenarios: class unchanged and saved starter rows remain unique |
| Existing text NPC/permanent flow | PASS: cancellation, third Ascension, saved ranks, respec, death, vendor store, TCP reconnect and earned-point milestones |
| Established five regression gates | PASS: module guard, lifecycle, enabled/disabled combat baseline, all-six-tree contract |
| Manual admin review path | PASS: stop overlay, goto The Nameless, hi, all six previews, Close without granting class |

Logs: `out/class-choice-tests/fresh.log`, `magic.log`, `sword.log`,
`manual-preview.log`, `existing-permanent-run.log`, `existing-regressions-run.log`.
Full prior flow: `out/passives-permanent-tests/third-ascension.log`.
Regression detail: `out/passives-regressions/`.

During test setup, the new harness initially paired legacy fixture IDs with the
wrong account names, then treated intentional logout EOF as a failure in the
manual preview. Both harness errors were corrected and their cases passed.
Source review also caught and fixed NPC Creature-userdata versus numeric-ID
dispatch, and stale offers across retained-player reconnect. The final fresh
run rechecked the packaged Selected label and confirmation status correction.
Tracked whitespace checks passed in both repositories.

### Final local artifacts

- Client archive SHA256:
  `9d3780ba5f48e51144a590d9f391f18593eebd549e39c98f42474adeccd5d3af`.
- Native server SHA256:
  `7bdb50b29e8d048cf4a7bd8d4589ac25be3649963264626192e4d6cc071f7da5`.
- Expected manifest SHA256 (package and server runtime match):
  `a811090f51510c43abc825833a798282e71072c329991b23694a4e64c9d81c34`.
  Eight legacy critical files and116 passive resources; login `CS1:d08bec84`.
- Nameless source/runtime SHA256 both:
  `030aa714af3c60c2e84990a8d4a9e64015595c047126a3100d2989897ee636bc`.
- Class-choice source/runtime SHA256 both:
  `9253b18d193f16d1debba4f3f4932afdd730b62d0a0e73a7448c78732bfd9ea5`.

Final screenshots are in `out/passives-evidence/class-choice-fresh-small.png`,
`class-choice-fresh-confirm.png`, and `class-choice-review-ready.png`.
Manual instructions and source contracts: [class-choice-ui.md](class-choice-ui.md).

This increment does not approve final combat balance or final illustrations.
Female native portraits were visually reviewed; male variants remain to review.
Depot-full/partial inventory transfer and injected DB faults were not rerun here.
The existing transfer moves slots individually and can leave earlier moves in
the depot when a later slot fails; durable class/reset writes remain transactional.
No commit, push or deployment. The loopback test server remains running.
