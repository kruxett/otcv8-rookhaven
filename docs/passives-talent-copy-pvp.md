# Talent text and Bloodletting/Rend PvP increment

Status as of 2026-10-07: local copy/UI, existing-system regressions, the full
two-player native PvP suite and the DEV server deploy/runtime verification passed.
Two normal readonly DEV client logins also passed. Published client DEV10087 and
PROD1006 bytes are preserved; this increment rebuilt the DEV server only.

## Scope

All 174 talents now use player-facing descriptions, rank text and benefit text.
The copy pass preserves IDs, prerequisites, point gates, rank limits and numeric
gameplay configuration. It clarifies monster-only effects where those restrictions
still apply. Bloodletting's internal six-tick schedule is omitted from its player
text; the finite damage budget remains unchanged.

The gameplay change is limited to Reaver Bloodletting and Rend against players.
New applications use ordinary combat permission checks. Rend counts only the
caster's active Bloodletting wounds and retains its existing mana payment and
discount carry. Bloodletting derives its finite budget from actual triggering HP
damage after normal PvP reduction. Special player wounds recheck current owner,
weapon/rank and combat legality while ticking. Unmarked legacy player bleeding
remains ordinary bleeding. Other passive effects retain their existing PvP gates.

## Measured local evidence

Artifacts are under `out/talent-copy-20261008/`:

| Check | Result and evidence |
| --- | --- |
| Copy/config comparison | PASS: 174 descriptions, 488 rank entries and 488 benefit entries updated; gameplay numbers/config and catalog metadata preserved (`copy-evidence.json`). |
| Catalog contract | PASS: six trees, 6,978 cases, 2,880 prefixes and 564 rejections (`catalog-proof.json`). |
| Native retro UI | PASS: six actual connected trees at 1280×800 and 800×600; names, glyphs, routes, rank buttons and current/next text checked (`native-ui-final.log`, `PASSIVES_CONNECTED_VISUAL_OK`). |
| Native server build | PASS: the changed native files compiled and linked (`native-build.log`). |
| Five existing regression gates | PASS: normal client guard, lifecycle, baseline with overlay enabled/disabled and six-tree contract (`regressions.log`). |
| Ordinary starter spells | PASS: all six classes and twelve starter spells (`class-spells.log`). |
| Existing PvE Rend/wounds | PASS: normal/immune/valid-wound/finished-generator scenarios (`rend-pve.log`, `CLASS_SPELLS_REND_BLEED_OK`). |
| Real MagicField behavior | PASS: finite and legacy field behavior (`finite-field.log`, `PASSIVES_FINITE_FIELD_SUITE_OK`). |
| New ordinary-player PvP suite | PASS: 21 main scenario markers and three required peer lifecycle markers; both actual clients exited 0; exact runtime config and owned server restored (`pvp-pass.log`, receipt below). |
| DEV server deploy/runtime | PASS: real native rebuild, orderly old-server exit, independent new-process/source/artifact checks and preserved client/PROD/control bytes (receipts below). |
| Live DEV client tests | PASS: two real normal DEV10087 logins, current server Reaver catalog/detail, quiet login, class/native Cyclopedia data and ordinary admin denial; normal logout and artifact/profile restoration. Live PvP combat was not run. |

## Two-player PvP test

The new runner is `tools/run-passives-pvp-tests.ps1`. It uses only ordinary local
GUID9006/9007, loopback 7174/7175 and the isolated DB33308. It temporarily changes
only the disposable runtime's world type and restores exact config bytes in
`finally`. A final PASS requires native client exits, scenario markers, exact
config restoration and the owned local server listening again.

```powershell
./tools/run-passives-pvp-tests.ps1 -PrepareClasses
```

Run serially with all other native client/server suites. Omitting
`-PrepareClasses` requires the already prepared ordinary Reaver/Blademaster
fixtures and either empty or the suite's exact legal Bloodletting allocation.

The suite exercises genuine ordinary axe hits and genuine Rend rolls, exact
normal PvP integer halving, own-wound bonus, finite expiry/cure, initial
secure-mode/PZ/no-PvP/self rejection, ongoing PZ cancellation, normal party combat
policy, owner/recipient logout and representative victim death/relogin. Controlled
pending-marker conditions cover scheduling, the three-wound cap, weaker rejection
and stronger replacement; these are synthetic API probes, not natural proc proof.

The completed run is `out/passives-pvp-tests-20261007-204532/`. Its `result.json`
records `passed`, `nativeProofComplete`, `configRestored` and `serverRestored` all
true, source/peer ExitCode 0 and restored local server PID158976.
`out/talent-copy-20261008/pvp-pass.log` contains the final
`PASSIVES_PVP_SUITE_OK` marker emitted after successful restoration.

The natural third ordinary hit dealt 22 HP; the wound subsequently spent its exact
six-HP budget with no second PvP reduction. All six Rend cases matched genuine
rolls followed by own-wound scaling, rounding and normal integer PvP halving.
Synthetic cap/replacement spent 21 HP; synthetic expiry spent 6 HP. Bleeding cure
preserved poison. Secure mode, no-PvP, target/caster PZ and self attacks preserved
HP/mana and produced no wounds. Actual PZ-entry response established the baseline
before the zero-damage/cleanup assertion. Owner/recipient logout passed. The peer
observed the real server death text (`event=server-text`), immediate native respawn,
then deliberate normal unload/relogin; the new entity had no saved wound.

Five harness failures were corrected before the completed run:

- The redirected-log reader lacked sharing with its still-open native writer.
- Lua `return assert(creature, message)` passed the message as `Game::attack`'s
  cancel argument, suppressing the attack packet. The helper now returns one value.
- The death observer listened only for the relog-window packet. With fixture skill
  loss suppressed, native death immediately respawns and sends its actual death
  text. Both genuine event paths now feed one guarded, deduplicated observer.
- The PZ baseline preceded movement and included one legal normal-zone tick. It
  now starts at the actual server reply confirming PZ entry.
- Final intentional source logout lacked its intentional-disconnect flag, so
  expected EOF was treated as a failure after completed combat/lifecycle checks.

These fixes are confined to test tools. LuaJIT syntax and actual argument-count
and writer-sharing checks passed; the completed native run establishes the final
integration result.

## DEV server deployment

`out/talent-copy-pvp-20261008/dev-native-deploy-receipt.json` records server commit
`9718b2c59c8f6f9dcda8e9f6cd41f90d2189ed1b`, native MSBuild ExitCode 0 with drained
streams and orderly old TFS ExitCode 0. The independently read runtime receipt,
`dev-runtime-verified.json`, confirms clean tracked source and all nine normalized
LF source hashes against the frozen commit/baseline pins. The root executable
matches the rebuilt binary and predates the actual new process:
SHA256 `ca52e9508d378df552fd85476c5d70a3e0276f4e72807f5539232de594931587`.

The existing supervisor restarted DEV as PID8172, parent PID4708, listening on
7173/7174. Supervisor PID4708 and updater Node PID4556 retain their original process
identity. Protected config/control/DLL bytes, earlier dumps and whole published
DEV10087/PROD1006 trees are preserved; no new dump or deployment request remains.
The deployment receipt delegates runtime checking; the separate runtime receipt
provides that later verification. These checks establish deployment identity and
startup; the following normal-client checks provide actual connection/UI evidence.
The post-login receipt `dev-runtime-after-live.json` again confirms the same
runtime identity, preserved protected/release bytes and no new dump or request.

## Live DEV client verification

`out/talent-copy-pvp-20261008/live-catalog.log` records the wrapper's successful
native two-login run and actual updater HTTP response `upToDate=true` on DEV10087.
The unfiltered native log,
`live-catalog107-4edc2e5a/cyclopedia-stdout.log` beneath that directory, contains
`LIVE_TALENT_COPY_OK` for both cycles: 29 current server Reaver descriptions passed
the forbidden-token scan and actual native Bloodletting detail showed the cleaned
Rend wording. The wrapper filter omits these two markers; inspect the native log
when reviewing catalog evidence. Native stderr is empty.

Both logins used only the existing ordinary QA GUID48. Tree and Cyclopedia stayed
closed until manual opening. Self-look reported Reaver; the actual opcode31 parser
and native Cyclopedia showed Class Reaver and separate Ascension Ascended. The
ordinary role's admin command was denied. The unchanged zero-rank/inactive-weapon
character reported no passive HP bonus. No Apply, respec, class, item or admin
mutation was performed; the client logged out normally.

Eight native captures are retained in
`out/talent-copy-pvp-20261008/live-catalog107-4edc2e5a/` as
`live-qa-4edc2e5a-cycle1-quiet.png`, `live-qa-4edc2e5a-cycle1-tree.png`,
`live-qa-4edc2e5a-cycle1-profile.png`, `live-qa-4edc2e5a-cycle1-passive-stats.png`,
`live-qa-4edc2e5a-cycle2-quiet.png`, `live-qa-4edc2e5a-cycle2-tree.png`,
`live-qa-4edc2e5a-cycle2-profile.png` and `live-qa-4edc2e5a-cycle2-passive-stats.png`.
Visual review of the actual cycle2 tree/profile captures found clean retro presentation.
`LIVE_QA_PROFILE_RESTORED` confirms original artifacts, normal config and test
profile restored. This is readonly live catalog/identity/parser evidence; genuine
Bloodletting/Rend PvP combat was exercised only by the local two-player suite.

## Limits

- Another active Reaver's special-wound ownership and independent PvP stack cap
  are not covered by this two-player fixture. Foreign unmarked legacy bleeding is
  tested separately and does not establish that case.
- Victim death covers immediate native respawn followed by normal unload/relogin
  with disposable skill/loot-loss suppression. Same-object PvP-arena wound-state
  observation before logout and real death-loss amounts remain
  unmeasured; special-condition removal before the death branches is source evidence.
- The completed run's hypothetical leech budget was 0.912 HP, below a whole unit;
  it observed zero healing but cannot independently exclude fractional leakage.
  An earlier incomplete run (`out/passives-pvp-tests-20261007-203250/source.log`)
  recorded 1.104 HP of hypothetical leech with zero observed healing from an injured
  source. That is complementary whole-unit evidence for this build, not an overall
  suite PASS or coverage of other ranks/rates.
- Every skull/PK combination, black-skull damage, all armor/resistance/equipment
  combinations, secure-mode changes during an existing wound, production load and
  human low-level economy/fun playtests remain outside this narrow suite.
- Live DEV verification covers the Reaver catalog and an unchanged zero-rank
  ordinary character. Live PvP combat, live respec/allocation and the other five
  classes' live catalogs were not exercised by this readonly probe.

Use [the passive regression workflow](passives-regressions.md) for subsequent
changes. Keep this increment's local evidence separate from earlier DEV results.
