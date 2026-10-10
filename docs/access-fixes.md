# Player action authorization fixes

Server release source: `2224b89dd3295d060d4cf9f3980b107698581194`.
Deployed to DEV on October 10, 2026, with a successful native MSBuild and
orderly save/shutdown. Independent readback confirmed the new supervisor-owned
runtime, both game ports, all 45 release source pins and matching built/runtime
EXE bytes. The new startup-log suffix contains no errors or crashes.
DEV10094/PROD1006 client files, checksums, configuration and control scripts
remain unchanged. No client publication was required.

This release contains the ownership, service authorization and combat fixes.
The unpublished Legendary/Forgotten Works changes were excluded before the
release source was rebuilt and tested.

| System | Result |
| --- | --- |
| Smelting/reforging | Only carried items can be selected or consumed. Reforge confirmations expire, bind the current item and login, and are single-use. Equipped targets must be unequipped. |
| NPC upgrades | Current NPC identity, distance, quest access and session lifetime are checked before mutation. Fragment investment must be a valid integer. |
| Delayed combat | Soul Drain, Chain Lightning, Seismic Shockwave and Volley recheck native combat permission. Soul Drain healing follows actual HP lost. Ranged follow-ups also check their relevant distance/floor/sight rules. |
| Root spells | Toxic Root and Deadly Vines use native Combat conditions, preserving paralyze immunity. |
| Rarity equipment | Native equipment notifications reconcile bonuses once and preserve HP/mana on hand swaps. Unchanged food regeneration retains its timer. |
| Personal Store | Owned item identity, integer quantity/price, recursive bound contents, payment/removal success and stock persistence are checked. Existing tax and stack purchases remain supported. |
| Tradepacks/boats | Trusted, short-lived service sessions bind confirmations to the current actor and location. Access and successful payment are checked again when confirming. |
| Monster Essence/trade | Rewards prefer owner GUID and require successful consumption before XP. Bound rewards cannot escape through nested containers or native player trade. |
| Party tasks | Duplicate native kill callbacks credit each party recipient/task once per death. |

## Release verification

The isolated release checkout passed a fresh native server build, **211**
production-Lua test groups and **58** native client/server assertions. The
existing passive baseline passed with passives enabled and disabled. Delayed
actions, normal-profile guards, death, logout/relogin, equipment HP stacking,
mana/healing and all six passive trees passed their native regression gates.
The owned database copies and client profile were restored; their original
database/config bytes remained unchanged.

Seven offline suites are in the server repository's `tools/tests/`:
`upgrade-permissions-contract.lua`, `chain-lightning-contract.lua`,
`spell-security-contract.lua`, `forge-security-contract.lua`,
`access-review-item-combat.lua`, `access-review-ownership-quantity.lua` and
`access-fixes-service-contract.lua`. Run each with LuaJIT from the server root.
The forge suite excludes one case belonging to unpublished Forgotten Works.

The client-side native runner accepts an explicit clean server source and binary:

```powershell
./tools/run-five-fixes-native.ps1 -AccessFixes -ServerRoot $source -ServerExecutable $exe
./tools/run-five-fixes-native.ps1 -AdditionalRegressionsOnly -ServerRoot $source -ServerExecutable $exe
```

Native fixtures are copied and registered only in the owned loopback runtime.
They must never be registered on live DEV or PROD. The existing baseline's
damage-over-time check now uses the native elapsed tick count, avoiding a
bucket-timing assumption while retaining exact damage and cure assertions.

Evidence is under `out/access-fixes-deploy/` and native reports
`out/five-fixes-native-qa/20261010-233548-270668/report.json` and
`out/five-fixes-native-qa/20261010-233848-263976/report.json`.

Full multiplayer PvP, a live two-player party kill/trade, complete boat journeys,
buyer-side SQL fault injection against the native inventory, and production-load
behavior remain unmeasured. Their modeled Lua checks or compiled native paths
are not substitutes for those live cases.
