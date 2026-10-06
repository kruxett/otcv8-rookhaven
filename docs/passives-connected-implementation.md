# Connected passive trees: local implementation

## Scope

Implement the reviewed alternating structure in all six functional trees: 14 Minor nodes, 12 Major nodes and three Capstones per class. Each talent remains a separate node. Progress flows upward through Minor, core Major, route Minor, advanced Major and Capstone. Existing optional Majors stay beside the core row.

Class identity, existing spell learning, equipment requirements and the retro layout remain authoritative. The server validates purchases; the client presents those same rules. This work is local. Publishing remains a separate approval step.

## Integration order

1. Agree stable node IDs, route prerequisites, catalog version and configuration keys across native server, server Lua and client.
2. Implement catalog/rank validation and migration before enabling the new effects. Preserve the original first 17 saved rank positions; append the 12 new positions.
3. Implement conservative class-specific effects through existing combat, healing, equipment and mana hooks. Exclude passive recursion, conditions and inappropriate targets. Derive descriptions from tracked server configuration.
4. Promote the actual native retro UI: individually labelled nodes, direct upward paths, no permanent development legend/formula strips, clear named requirements and existing draft/error handling.
5. Build the local package and server, then exercise the integration progressively.

## Verification matrix

| Area | Evidence required |
| --- | --- |
| Catalog/rules | Six 29-node catalogs; stable IDs; exact logical dependencies; every route reachable with 16 points; budget, rank, removal and wrong-route rejection; client/server parity. |
| Save compatibility | Valid 17-rank builds normalize with zeros; incompatible legal legacy builds get a free refund; class, bank, points and respec history survive; invalid 29-rank builds cannot use legacy fallback; reconnect is idempotent. |
| New effects | Actual native damage/heal/mana/HP checks for the new node families; fractional/low-value cases; learned-spell and weapon gates; primary versus secondary targets; no recursive procs. |
| Existing gameplay | Normal enabled/disabled baseline; all existing Capstones; starter spells; bleeding budgets/immunity; rejected Apply retains draft; max-HP conditions, reconnect and cleanup; healer/party ward coexistence and delayed spell cancellation where affected. |
| UI/UX | Native screenshots for all six trees at 1280x800 and 800x600; all nameplates/controls; line-line intersections and overlaps; every advanced node's named prerequisites; focus/invested colours; Apply/Undo/respec/error/pending states. |
| Balance | Ordinary 16-point examples compared with actually learnable spells. Numeric tuning stays provisional until ordinary hunt testing; a structural/native test is not a hunt-balance claim. |

## Configuration and release handoff

Numeric values belong in the tracked server file `data/lib/passives/config.lua`. Any required additions to the server's main `config.lua` must be listed explicitly in the final handoff. Test fixtures must be registered only in the disposable local runtime. No production or DEV server is changed by this implementation.

## Execution record

The six connected trees are implemented and have passed the local native gameplay and final packaged UI gates below. Existing verification reports describing earlier 17-node functionality or isolated 29-node presentation are not evidence for this combined implementation. File hashes, successful log markers and capture hashes are recorded in [the verification manifest](passives-connected-verification.json).

### Completed gates

- Source catalog parity: 6 trees, 174 nodes, 216 logical dependencies; 6,978 checks including 2,880 purchase prefixes and 564 rejection cases.
- Actual client/server purchase contract: every one of the 36 named paths reaches its capstone with 16 points; 468 invalid native submissions rejected without changing saved ranks.
- Final packaged retro UI: every class passed at 1280x800 and 800x600, including actual Add/Remove/Undo handlers, named requirements, centered names, context lines and focus/invested colours. Twenty-four native screenshots, 60 button-handler cases and 246 selection/geometry cases passed with zero emitted connector crossings or overlaps.
- Final HUD: all six classes passed empty-tree, chosen-capstone and reset states, including reactive versus charging mechanics and the actual Open tree callback: 30 cases and 12 additional native screenshots. The rebuilt client also passed the normal module guard and actual HP/save/relogin/store/TCP/death lifecycle regressions again.
- All six classes: all 12 added node allocations per class and six route-effect families passed actual HP/mana measurements with shipped combat tuning. Lifekeeper additionally passed effective-heal and overheal checks; Reaver passed large incoming damage, capped recovery and fractional/full-HP cases.
- The new middle critical-chance talent triggered Blade Storm through a real normal attack: 68 primary HP damage, one capstone activation and 13 HP damage to each adjacent monster. Removing that talent allowed two real primary hits with no further capstone activation or secondary damage. This isolated callback test temporarily set the new talent to 100% chance and the two older chance sources to zero. The shipped 20 basis points per rank were restored byte for byte; statistical probability and hunt balance were not measured.
- All 18 capstones activated through ordinary combat, movement or healing. All 12 starter spells passed actual ordinary-player learning and casting checks.
- Permanent third-ascension choice, legacy axe/wand/rod characters, point progression, free/paid respec, stale/canceled/insufficient-funds cases, HP persistence, death/reconnect and corrupt-ledger rejection/recovery passed.
- Six save-migration cases passed: legal legacy capstone refunds, valid17 normalization, valid29 retention, invalid17/29 rejection and idempotent reconnect. Class, bank, earned points, respec history and learned spells remained intact.
- Actual combat Apply rejection preserved the two draft points and permitted a later retry. Exact bleeding budgets/immunity, Volley weapon gates, delayed-action cancellation and party shield coexistence passed.
- Arcanist's actual delayed pulses/Resonance and pending TCP-disconnect cleanup passed; Rend passed ordinary, immune, owned-wound and completed-generator cases. Real-party Renewal, Aegis and Concord passed with the new route allocations.

### Defects repaired during integration

- Corrected a Lua nil/`or` fallback that disabled otherwise valid Add/Remove rank buttons. Actual native Add/Remove/Undo handlers passed for every class and both window sizes.
- Kept the actionbar's mouse grabber alive across logout; canceled pending drag and cooldown callbacks before destroying session widgets. Native verification passed two real relogs, six actual drag handlers, three canceled drags, and module unload/reload with exactly one grabber destruction.
- Cleared new same-target preparation immediately when the selected target changes, rather than waiting for a later landed attack.
- Separated capstone activation diagnostics from new Major effects, preventing false-positive capstone tests.
- Removed duplicate effect text, clarified Applied versus unapplied Draft capstones, and showed long alternative support lines only when inspecting the relevant optional talent.
- Hid charge meters and duplicate mechanic labels before a capstone is saved, keeping the retro HUD compact. Choosing a capstone restores the appropriate combat controls.
- Bounded the disposable QA observer to the native text-message limit after its duplicated full-catalog telemetry produced an oversized packet. This observer is registered only in the isolated test runtime.

The HUD probe waits for the chosen capstone's authoritative combat-status packet.
Rank snapshots arrive immediately; runtime status follows the server's periodic
player update. An arbitrary 200 ms test delay was insufficient and was replaced
with a bounded wait for the actual new packet. Assertions were retained.

### Built artifacts

- Client: `out/install/x64-LocalPassives/RookhavenClient.exe`.
- Client archive SHA256: `3c0b1f5abe1a5ffb3cc3fae36cb67bbffd577ad9ccaca49264c0704e39f212ee`.
- Matching local login checksum: `CS1:d08bec84`. This was checked by actual successful logins; no manual remote checksum edits were performed.
- Server: `../Rookhaven/build/local-passives/tfs.exe`.

The final client archive postdates the last client source change and predates the
refreshed visual/HUD/lifecycle runs. Combat evidence uses the final native server
binary; the later client change only removes misleading empty-capstone HUD rows.
UI checks exercise real native widgets and their handlers; they do not claim
operating-system mouse automation.

### Native screenshots

Each tree has four final captures covering the large view, small view, named
requirements and foundation row. Local test headings and chat commands in these
captures belong to the administrative overlay.

| Tree | Final native tree | Small-screen requirements |
| --- | --- | --- |
| Reaver | [1280x800](images/passives-connected/passives-connected-reaver-1280x800.png) | [800x600](images/passives-connected/passives-connected-reaver-800x600-requirements.png) |
| Blademaster | [1280x800](images/passives-connected/passives-connected-blademaster-1280x800.png) | [800x600](images/passives-connected/passives-connected-blademaster-800x600-requirements.png) |
| Earthshaker | [1280x800](images/passives-connected/passives-connected-earthshaker-1280x800.png) | [800x600](images/passives-connected/passives-connected-earthshaker-800x600-requirements.png) |
| Marksman | [1280x800](images/passives-connected/passives-connected-marksman-1280x800.png) | [800x600](images/passives-connected/passives-connected-marksman-800x600-requirements.png) |
| Arcanist | [1280x800](images/passives-connected/passives-connected-arcanist-1280x800.png) | [800x600](images/passives-connected/passives-connected-arcanist-800x600-requirements.png) |
| Lifekeeper | [1280x800](images/passives-connected/passives-connected-lifekeeper-1280x800.png) | [800x600](images/passives-connected/passives-connected-lifekeeper-800x600-requirements.png) |

[Empty-capstone HUD](images/passives-connected/passives-status-hud-lifekeeper-no-cap.png)
and [chosen-capstone HUD](images/passives-connected/passives-status-hud-lifekeeper-cap.png)
show the final transition without invented charge meters.

### Runtime and rollback notes

The local-only integration record above predates ordinary DEV enablement. **DEV now requires `passivesEnabled = true` and `passiveTestEnabled = false` in the server's main `config.lua`, followed by restart.** See [the DEV release instructions](passives-dev-release.md). Numeric tuning lives in tracked `data/lib/passives/config.lua`; topology lives in tracked `data/lib/passives/routes.lua`. Both ship with server Git changes. Administrative overlays retain the separate strict local test gate.

Valid saves normalize to 29 rank positions. An older 17-node server cannot read those saves. A future release needs a database backup and coordinated rollback procedure; swapping only the executable back is insufficient.

Return and Sustain spend their charge on the next successful eligible normal attack, including when self HP is full. Whole healing that cannot fit is lost; the sub-unit fractional remainder persists. Native Reaver Return and Sustain full-HP checks passed, alongside HP-cap and sub-unit recovery checks.

Ordinary hunt balance, maximum-population load and the global 128-retained-action saturation policy remain unmeasured. Shipped tuning is conservative and centrally configurable; activation tests do not establish long-term balance.

### Local manual playtest

Start `out/install/x64-LocalPassives/Start Local Passives.cmd`. The local server uses login port7174 and game port7175; the isolated database uses33308. Log in with the disposable account `passivetest` / `passivetest`, character `Passive Tester`.

Use `/passivetest start reaver`, replacing `reaver` with `blademaster`, `earthshaker`, `marksman`, `arcanist` or `lifekeeper`. `/passivetest help` lists overlay controls. These administrative overlays leave permanent class choice unchanged. The ordinary `class<class>` fixtures are reserved for the automated permanent-class tests.

No commit, push or remote deployment has been performed.
