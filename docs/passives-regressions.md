# Passive-system regression gates

For substantial system changes, identify affected existing paths as well as the
new feature. Run focused regressions for those paths before reporting completion.
A successful capstone proc or screenshot alone does not establish baseline safety.
This is the user's requested working rule for future client/server system work.

## Re-run locally

From the client repository:

```powershell
./tools/run-passives-regressions.ps1
# When native/client source has changed and the artifacts need rebuilding:
./tools/run-passives-regressions.ps1 -Build
```

The runner restarts only the owned loopback test server (7174/7175, DB33308).
It ends active test sessions. It temporarily disables `passiveTestEnabled` only
in the disposable runtime config, restores source defaults in `finally`, and
leaves the local test server running. No Git commit, push or production upload
is performed. Fixtures are copied/registered only in that runtime, never in
tracked game talkactions. They are restricted to the known local test server,
loopback administrator and disposable GUID9001.

## Current gates

| Area | Actual evidence |
| --- | --- |
| Normal client module guard | Native `loadfile` decrypts/loads the packaged module in an isolated Lua environment with the local flag false. Actual init/terminate create no opcode handlers, events or UI. Existing offline client widgets/modules remain present. |
| Baseline with flag on, no overlay | Fixed native damage/healing, legacy three-target AoE critical, mana shield, ordinary strongest-bleed replacement alongside poison, independent cures and addEvent/stopEvent. |
| Baseline with flag off | Same native combat/conditions/timer tests and real client spells; no active overlay or passive bonuses. |
| Existing spell requirements/payment | Axe only in right hand, real Head Splitter costs20 mana, cooldown rejection spends no extra mana, real Light Healing costs20 mana and heals. |
| HP-condition composition | Base735; ordinary +20%HP condition adds147. Passive +5% adds36 independently. Applying the condition before/after the tree yields918. Stop or incompatible weapon leaves882; removing the condition leaves735. |
| Save and reconnect | Saving at full918 HP clamps stored health to882 and keeps base healthmax735. Ordinary persistent HP condition survives reconnect; passive overlay does not. |
| Personal-store soft logout | Same vendor entity remains in-world with IP0/storemode1; maxHP735 while disconnected and after reconnect, no revived overlay. |
| TCP disconnect | TCP closes before local client reset; same in-world entity is observed with IP0/maxHP735. Reconnect has no active profile/bonus. |
| Death | Real lethal native combat runs the death path. Fixture disables skill/loot loss, so the existing immediate respawn path is used. Death event/message, overlay cleanup, base HP/level and reconnect are checked. Normal death-loss amounts are not tested. |
| Six-tree contract | Final build checks six catalogs/18 presets, allocation, weapon activation, reset, Stop and logout cleanup. |

The current presets spend 16 points. The lifecycle gate separately applies a
server-validated 21-point admin build with five Vitality ranks to exercise its
fixed +5% HP assertions. This fixture is within the 24-point test-overlay budget;
it is not used as a level-40 first-capstone build.

Logs are under `out/passives-regressions/`; the console summary is retained as
`out/passives-regression-suite.log` for this run. A failed gate throws and retains
its client log. Review failures; do not relax combat/gating rules to obtain a pass.

## Regressions found and fixed

The pre-fix binary reproduced percent-HP contamination: passive maxHP771,
then +20% condition gave925; Stop left889 instead of882. The new HP-percent
condition base excludes only the temporary passive HP contribution. Without an
overlay it keeps the existing base calculation unchanged.

Soft logout and protocol detach bypassed ordinary creature removal and could
retain an overlay in an offline in-world player. Cleanup now runs before vendor
save and before detaching the current protocol. The latter remains inside the
existing protocol-identity guard; an old connection cannot clear a new session.

## Practical limits

### Starter-spell increment (2026-10-06)

The final starter-spell server and client reran all five gates above successfully
(`out/class-spells-regressions-final.log`). Additional affected-path checks passed:

- Six ordinary class choices, saved/relogged two-spell learning, all twelve real
  casts, weapon/class/learning/mana rejection, payment and one-ammunition billing.
- Resonant Burst's three pulses counted as one cast; Resonance used the whole
  primary pulse budget once. TCP detach invalidated a pending cast before later
  damage (`out/class-spells-arcanist.log`).
- Named party Mending, rejected non-party/out-of-range healing, Renewal's exact
  HoT budget without recursive procs, Aegis on the receiver, and Essence Lash's
  Concord heal from actual damage (`out/class-spells-synergy-suite.log`).
- Clearing the client spell UI and requesting a fresh server catalog restored
  actual remaining exhaustion after a new Cleaving Arc and legacy Head Splitter.
  Both cards remained blocked until real expiry, without restarting the timer
  (`out/class-spells-cooldown.log`).
- Invalid starter mana and a missing XML wrapper produced specific startup
  failures before ports 7174/7175 opened. Exact runtime bytes were restored and
  the valid server restarted (`out/class-spells-startup-suite.log`).
- The real third Ascension's cancel/confirm dialogue, two correct learned spells,
  preserved Light Healing, ordinary save/relogin, point/respec/death/store/TCP
  behavior passed (`out/class-spells-permanent-main.log`). Invalid ledger rejection
  and cold offline-vendor reconnect were rerun too
  (`out/class-spells-permanent-fault.log`, `out/class-spells-permanent-cold.log`).

The targeted cooldown probe requires an already chosen empty Reaver fixture and
learned Head Splitter. Its entitlement was seeded only for disposable GUID9006
while the owned test server was stopped. The negative startup helper and party
runner must run serially with other client/server probes.

These are integration checks. Human hunting at levels1–4 and40, the ordinary
mana/ammunition economy, all element/resistance combinations and final fun/balance
remain playtest work. All spells remain gated to the owned local test environment.

This is a targeted regression suite, not an exhaustive balance/performance study.
It does not exercise a normal installed DEV/PROD updater end-to-end, all modified
active spells, PvP damage/mana combinations, every equipment rarity/condition,
every death-loss rule or production load. DEV/PROD startup isolation and opcode
compatibility were reviewed in source; the dynamic client guard is tested in the
actual local package. Previous natural capstone/party/delayed-cast evidence remains
in `local-passives-results.md` and is separate from baseline evidence.

Login-CS1 covers eight legacy resources. It does not cover the passive assets;
package integrity therefore uses the archive SHA256 and its listed resource CRCs,
not successful login alone. Keep source, built artifacts and copied runtime aligned.

## Passive-tree UI and prerequisite presentation follow-up

The 2026-10-06 UI increment reran all five gates above and the permanent Reaver
scenario. The six-tree contract now also verifies visible Guard progress at
0/4, locked3/4, unlocked4/4 and Undo0/4; forged wrong-area, below-threshold and
dependent-removal packets are rejected by the native server with unchanged ranks
and revision. All four areas accept legal3+1 splits, and all18 presets still pass.

Native layout checks cover all six trees at both1280×800 and800×640, including
all21 catalog connections and the absence of connector/frame/caption collisions.
Offline requirement-summary equivalence, actual scope, artifact identities and
screenshots are in [passives-ui-review.md](passives-ui-review.md). No prerequisite
threshold, saved-build migration or native balance change was made in this run.

## Talent-name presentation correction

The later 2026-10-06 talent-name correction reran normal-profile guard, lifecycle
and the connected six-tree contract successfully. Native layout checks now verify
actual text alignment and all 17 nameplate clicks in each of the six trees at
two window sizes. Baseline enabled/disabled and permanent Reaver checks were not
rerun for this presentation-only follow-up. Current screenshots, scope and
artifact identities are in [passives-ui-review.md](passives-ui-review.md).

## Starter balance and wield eligibility follow-up

The 2026-10-06 low-and-slow correction changed starter budgets, Focus regeneration
and new-starter wield validation. Acquisition sources and provisional tuning are
in [class-spell-balance-audit.md](class-spell-balance-audit.md); executed evidence
and final hashes are in [local-passives-results.md](local-passives-results.md).

The final native binary passed this document's complete five regression gates
(`out/class-spells-balance-regressions.log`). Focus's reduced fractional ledger
was checked separately with `passives-resources.lua`, without food regeneration.
Ordinary fixed class players were checked by `class-spells-wield.lua` for retained
weapon level6/7, effective club29/30, cancellation after real level loss, exact
healing formula/costs and last-round bow consumption. Run the fresh six-class
suite first to prepare their empty saved ranks; then run wield probes for
`arcanist`, `earthshaker`, `lifekeeper` and `marksman` before the party suite.
The party suite allocates saved Lifekeeper ranks and must follow baseline probes.

Revised starter/legacy cooldown replay, real-party Renewal/Aegis/Concord and
startup rejection cases also passed. These tests verify eligibility, accounting
and preservation of affected systems. They do not establish sustainable hunt
balance or ordinary acquisition of a spell explicitly learned by a fixture.

## DEV10086 login, identity, administration and sustain follow-up

The2026-10-07 increment passed all five gates, the real permanent first-choice
scenario and native draft/result feedback. It explicitly verifies a saved-rank
decrease is rejected with both current revision and forged revision0 before the
first respec, while unsaved draft undo has no HP/database effect. Login/status/
snapshot synchronization stays closed; explicit toolbar opens still work.

Nine native admin cases verify default-off and each role, all stages/classes,
stale/session/bounds/combat/death gates, real SQL rollback and reconnect, plus
flag-off point behavior. The fixture is registered only in the owned runtime.

Run fresh `tools/run-class-spells-tests.ps1` before the changed-budget guard and
real-party suites. `tools/run-passives-guard-balance-tests.ps1` checks Bloodguard
absorption, real Stonebond blocks and Stoneguard charge damage/consumption. Its
spell proc baseline is taken at cast entry, because selecting a target can
cause an intervening ordinary autoattack. `passives-balance.lua` checks actual
low-budget kills and baseline rod Concord with fractional/no-banking/weapon
cleanup. All passed on the final native binary, followed by the existing
Renewal/Aegis/Concord real-party suite.

Readonly native Cyclopedia checks passed the nonzero-rank Reaver fixture and all
six ordinary starter classes. They verify actual look, Class/Ascension, HP,
applied rank descriptions, armor/defense/interval/critical/mana data and the real
client parser. Native presentation and shaped-critical-roll math checks passed.
Full executed evidence, release/access status and practical limits are in
[passives-dev10086-results.md](passives-dev10086-results.md).

The deployment exposed a late passive timer release during orderly server
shutdown. After its native lifetime fix, rerun the five gates and then
`tools/run-passives-shutdown-tests.ps1`. The shutdown runner requires the owned
loopback database/config and the empty ordinary Earthshaker fixture prepared by
the starter suite. It tests a real delayed cast, `stopEvent` reference release
and shutdown with a real pending managed timer, requires actual native/client
ExitCode0 with no new dump, then restores the disposable fixture/runtime. The
optional `ExitReceiptPath` in the native probe records the client process result.
The fixed server also passed an actual orderly DEV restart without a new dump.

DEV10087 additionally passed real native updater download/promotion/restart and
temporary-executable cleanup, followed by two ordinary readonly DEV logins and
native Cyclopedia/toolbar assertions. Final artifacts, earlier failures, profile
restoration and unmeasured cases are recorded in the linked results document.
