# Six local retro passive test trees

The standalone local overlays are Reaver, Blademaster, Earthshaker, Marksman,
Arcanist and Lifekeeper. They are not connected to ascension, new classes, quests
or permanent passive points. The overlays do not grant spells. No content has
been pushed. The local server and the local client must both be used for this test.

The separate [permanent class foundation](passives-permanent.md) now connects
these trees to third Ascension locally. This document describes the original
temporary admin overlays; use its separate ordinary accounts for class testing.
Admin overlays cannot replace a saved permanent class.

## Start and log in

The prepared client is `out/install/x64-LocalPassives/Start Local Passives.cmd`.
Use that launcher: its `--local-passives` flag selects the isolated profile,
forces retro, loads only the archive beside the executable, disables the updater
and selects `127.0.0.1:7174`. It does not use the ordinary DEV profile.

```powershell
./tools/start-local-passives.ps1
& './out/install/x64-LocalPassives/Start Local Passives.cmd'
# Optional real second client with its own settings profile:
& './out/install/x64-LocalPassives/Start Second Local Client.cmd'
```

| Account | Password | Character |
| --- | --- | --- |
| passivetest | passivetest | Passive Tester |
| passivepeer | passivepeer | Passive Peer |

These are disposable local fixture accounts. Both have administrative command
access but ordinary combat flags. Their baseline is level 40, weapon skills 60,
shielding skill 60, 735 HP, 390 mana and an existing orcish axe. A second client can be opened with
`Start Second Local Client.cmd`, which has its own settings profile.

### Ordinary class spells

Permanent class testing uses separate ordinary accounts `classreaver`,
`classblademaster`, `classearthshaker`, `classmarksman`, `classarcanist` and
`classlifekeeper` (password equals account name; player GUID9006–9011). The
starter-spell runner prepares them; their saved class/build depends on the last
scenario. See [passives-permanent.md](passives-permanent.md#starter-spell-test-characters)
for character names, class selection and manual instructions.

After choosing a permanent class, click **Learned class spells** beside the
passive button to open the two-card retro Class Spells window. Cast from a card
or use its words in an existing text hotkey. **Base mana** excludes passive
discounts. The server's shared combat/healing countdown also reflects legacy
spells; same-kind cards lock together. Mending Thread's empty target field heals
self; a filled field names a party member within Heal Friend range and sight.
This window belongs to the permanent class workflow; temporary admin overlays
do not grant these spells.

## Tree commands

```text
/passivetest list
/passivetest help
/passivetest start reaver, Passive Tester
/passivetest start blademaster, Passive Tester
/passivetest start earthshaker, Passive Tester
/passivetest start marksman, Passive Tester
/passivetest start arcanist, Passive Tester
/passivetest start lifekeeper, Passive Tester
/passivetest open
/passivetest preset Passive Tester, duelist
/passivetest reset
/passivetest status
/passivetest trace Passive Tester,on
/passivetest stop
```

The same administrator can target another online local player:
`/passivetest start reaver, Passive Peer`. Omit the target for yourself. Switching
trees ends the old session and starts a new empty overlay only after the server
accepts the out-of-combat gate. A rejected combat-time switch retains the old tree.

Preset names must belong to the current tree; the full `cap_` prefix also works.

| Tree | Presets | Disposable fixture weapon |
| --- | --- | --- |
| `reaver` | `berserker`, `bloodletting`, `bloodguard` | Orcish axe, server item 2428 |
| `blademaster` | `duelist`, `riposte`, `bladestorm` | Sword, 2376 |
| `earthshaker` | `aftershock`, `stoneguard`, `stonebond` | Clerical mace, 2423 |
| `marksman` | `deadeye`, `skirmisher`, `quarry` | Bow, 2456, with ordinary arrows 2544 |
| `arcanist` | `conduit`, `resonance`, `spellweaver` | Wand of vortex, 2190 |
| `lifekeeper` | `renewal`, `aegis`, `concord` | Snakebite rod, 2182 |

For example: `/passivetest preset Passive Tester, resonance` after starting
Arcanist. Presets spend all 24 points and select exactly one capstone. They are
convenient legal test builds, rather than final recommended character builds.

Click a node and use Add/Remove rank, then Apply. Draft points do not affect
combat until the server accepts Apply. Reset is free. Builds cannot be changed
while fighting. Stop is an administrative cleanup action and also works in
combat. The checkbox controls the retro combat-status window; its Open tree
button reopens the allocator.

The test has 24 points, eight minor nodes (up to five ranks), six major nodes
(up to three ranks) and three capstones (one rank, only one chosen). Core majors
need four minor ranks in their region. Bridge majors connect two regions.
Capstones need 15 other points and two relevant major nodes at rank two. Each
capstone has three qualifying pairs; legal access is possible with 16 points.

Read the tree from the bottom upwards. The larger bronze frames at the top are
capstones. Selecting one highlights its qualifying major cards in gold; choose
any two of those at rank two. All capstone links remain visible, with upward
arrows and shared rails for common routes. Selecting a capstone highlights its
paths as well as its qualifying majors. The ranks and detail requirements show
eligibility; a highlighted path alone does not mean its prerequisites are met.

## Combat fixtures

The following tools and monsters are registered only in the copied local
runtime, not in the source game's normal registrations:

```text
/passiveqa arena
/passiveqa join Passive Tester,1
/passiveqa join Passive Peer,2
/passiveqa attack Passive Tester
/passiveqa stop Passive Tester
/passiveqa metrics Passive Tester
/passiveqa equip blademaster,Passive Tester
/passiveqa learn Passive Tester
/passiveqa hurt Passive Tester,400
/passiveqa focus Passive Tester,1
/passiveqa targets
/passiveqa heal Passive Tester
/passiveqa quiesce Passive Tester
/passiveqa cure
/passiveqa cleanup
```

`arena` finds a clear place outside a protection zone and creates three stationary
monsters with ordinary melee attacks, 1,000,000 HP, no experience and no loot.
Attack the central one normally. `heal` is a diagnostic refill; `quiesce` removes
fixture monsters and clears combat for the next scenario. Neither is evidence of
a naturally generated passive effect. `bleedprobe PlayerName,30` applies a finite
source-owned condition through the real condition API; it is an API diagnostic,
not evidence of a naturally reached Bloodletting trigger.

`equip <tree>[,PlayerName]` works for all six tree IDs and only for the two
disposable fixture characters. It removes their current hand/ammunition items
and supplies the table's weapon in the left hand. Non-bow setups also get shield
2512 in the right hand; Marksman gets arrows instead. These item changes belong
to the disposable fixture, not to the passive overlay or a real player account.

`learn [PlayerName]` teaches a selected list of **existing** spells to the
disposable fixture. It does not grant the permanent class starter spells. Useful
current words are:

| Tree | Existing test spells |
| --- | --- |
| Reaver | Head Splitter `exori sec`; Axe Throw `exevo sec` |
| Blademaster | Swipe `exori sis`; Pommel Strike `exori sis con` |
| Earthshaker | Ground Slam `exori mal`; Seismic Shockwave `exevo mal` |
| Marksman | Sure Shot `exevo sagitta`; Volley `exevo gran sagitta` |
| Arcanist | Wand Lightning Bolt `exori vis lux`; Wand Shock Blast `exori gran vis` |
| Lifekeeper | Wand Ensnare `exori tera con`; Light Healing `exura`; Heal Friend `exura sio "Passive Peer` |

Choose **defensive fight mode** for Riposte, Stoneguard and Stonebond. They need
a real shield defense block, not merely an armor reduction or a forced counter.
The fixture has shielding skill 60 and an actual shield. Other offensive runs
use offensive fight mode. Initial login/teleport pacification must expire before
attacks; the automated campaign waits eleven seconds after arena placement.

`hurt PlayerName,amount` creates a nonlethal diagnostic HP deficit, at most 500
HP. It does not trigger damage passives. Cast a real healing spell afterward to
test Renewal or Aegis; attack a monster afterward to test Concord. `focus` selects
one of the three owned dummies and `targets` reports their actual HP/positions.
For party effects, log in the real second client, invite/join through the normal
party UI, and keep it without a passive overlay. Move it to arena slot two with
`/passiveqa join Passive Peer,2`.

## Values and limits

Server values are centralized in
`../Rookhaven/data/lib/passives/config.lua`. Rebuild and refresh the local runtime
after native changes; refresh the runtime after Lua changes. Stop overlays
before changing their configuration.

- Berserker: 10 rage per successful ordinary axe attack; at 100 rage, eight
  seconds of 20% more eligible damage. No rage builds during Berserk.
- Bloodletting: every third successful ordinary axe attack creates a wound with
  a total budget of 30% of that hit's actual HP damage, over 18 seconds.
  A source owns at most three finite wounds per PvE target. Stronger wounds can
  replace weaker remaining budgets. Other sources retain the legacy behavior.
  The duration was changed from 12 to 18 seconds so ordinary two-second attacks
  can actually accumulate three wounds. Total damage per wound is unchanged.
- Bloodguard: after three ordinary hits, shield budget is 30% of their actual
  HP damage, limited to 6% of max HP and lasting at most 12 seconds. Wards do
  not stack. A stronger one can replace a weaker one.

Reaver bonuses require an axe and apply to eligible PvE combat. Its existing
eligible legacy spells are Head Splitter and Axe Throw. Permanent Reaver now has
Rend with a bonus against its own Bloodletting wound; the admin overlay does not
grant that starter. Very small hits can round a shield down to
zero; very small wounds have a minimum one-HP budget. These values are prototype
starting points, not a completed balance study.

Each other tree requires its matching weapon. Rods and wands share the native
weapon enum but are separated by verified server item IDs. Existing rod offense
is supported where the old element/item scripts permit it. See
`local-passives-expansion.md` for all 18 capstone contracts, current tuning,
weapon/spell allowlists and the provisional minor/major node definitions.

Weapon changes, death, logout and Stop clear transient combat effects. Max HP is
derived without free healing and is removed when the overlay ends. Server saves
clamp current HP to the permanent base maximum while an overlay is active.
Ranks, classes and progression are not written to the database by this system.

## Balance configuration

Numeric tuning is centralized in the server's `data/lib/passives/config.lua`.
See [passives-balance-config.md](passives-balance-config.md) for shared values,
per-tree overrides, units and the refresh workflow. Supported numeric changes
need a local server refresh, not a client/server rebuild.

## Rebuild, refresh and stop

Client and server sources remain separate sibling repositories:

```text
C:/GitRepos/kruxett/otcv8-rookhaven
C:/GitRepos/kruxett/Rookhaven
```

```powershell
./tools/build-local-passives.ps1 -Jobs 8
./tools/start-local-passives.ps1 -Refresh
./tools/start-local-passives.ps1 -Stop
```

The client uses `C:/vcpkg-client` (static); the server uses `C:/vcpkg-server`
(dynamic). Build outputs are `out/build/x64-LocalPassives`,
`out/install/x64-LocalPassives` and `../Rookhaven/build/local-passives`.

The runtime is `out/local-server/passives-runtime`; its own MariaDB data is
`out/local-server/passives-db` on loopback port 33308. The existing item-test
database on 33307 is read only when first cloning the disposable fixture.
The game ports are 7174/7175. Startup refuses conflicting listeners.

The ordinary profile is not used. Manual, peer and automated probe clients each
have separate profile names under the existing Rookhaven Client AppData folder.
No item OTB, DAT or SPR changes are needed for this prototype.

## Checksums and automated probes

The final archive's resource CRC32 values are generated by
`tools/passives/package-checksums.py`. The resulting `checksum_expected.txt` is
copied to the local runtime's `data/`; the eight existing critical resource CRCs
form the native `CS1` login checksum. The JSON manifest also records archive
SHA256 and the actual packaged passive-resource count. SHA256 does not replace
the login checksum. Regenerate the manifest after final six-tree packaging,
then refresh the local server data.

```powershell
./tools/run-passives-preview.ps1 -Script passives-small-ui.lua
./tools/run-passives-probe.ps1
./tools/run-passives-preview.ps1 -Script passives-all-trees-ui.lua
./tools/run-passives-probe.ps1 -Script passives-all-trees-contract.lua -Success PASSIVES_ALL_TREES_CONTRACT_OK -TimeoutSeconds 120
```

The first is explicitly an offline native UI preview. The second logs in to the
real local server and verifies catalog, allocator, validation, reset and logout.
Automated packages are disposable copies under `out/`; the manual package never
needs `test.lua`. Screenshots are written to the probe profile in AppData.

Additional isolated checks:

```powershell
./tools/run-passives-probe.ps1 -Script passives-combat.lua -Phase ward -Success PASSIVES_WARD_OK -TimeoutSeconds 70
./tools/run-passives-probe.ps1 -Script passives-resources.lua -Success PASSIVES_RESOURCES_OK -TimeoutSeconds 50
```

For two-owner combat, run the peer probe and combat probe in separate terminals:

```powershell
./tools/run-passives-probe.ps1 -Script passives-peer.lua -Success PASSIVES_PEER_OK -Peer -TimeoutSeconds 230
./tools/run-passives-probe.ps1 -Script passives-combat.lua -Success PASSIVES_COMBAT_OK -TimeoutSeconds 190
```

Wait for `PASSIVES_PEER_READY` in `out/passives-peer-peer/stdout.txt` before
starting the second command. A success marker is meaningful only if the runner
also reports a clean result. See `local-passives-results.md` for actual findings.

Run one new capstone through natural gameplay, for example:

```powershell
./tools/run-passives-probe.ps1 -Script passives-capstones.lua -Tree blademaster -Cap duelist -Success 'PASSIVES_CAPSTONE_OK blademaster duelist' -TimeoutSeconds 210
```

Replace tree/cap with one of the fifteen new entries in the preset table. The
script equips a normal fixture weapon, selects a legal build and then uses real
attacks, shield blocks, movement, spell casts or effective healing. It ends the
overlay and checks logout/UI cleanup. A positive proc marker proves activation;
it does not by itself measure the precise balance multiplier or every target.

For Stonebond or Concord's real party recipient test, run the second client first:

```powershell
./tools/run-passives-probe.ps1 -Script passives-party-peer.lua -Success PASSIVES_PARTY_PEER_OK -Peer -TimeoutSeconds 190
./tools/run-passives-probe.ps1 -Script passives-capstones.lua -Tree earthshaker -Cap stonebond -Party -Success 'PASSIVES_CAPSTONE_OK earthshaker stonebond' -TimeoutSeconds 210
```

Wait for `PASSIVES_PARTY_PEER_READY` in
`out/passives-party-peer-peer/stdout.txt` before the main command. For Concord,
use `-Tree lifekeeper -Cap concord -Party` and its matching success marker.

## Delayed callback regression fixture

`tools/run-passives-probe.ps1 -Script passives-delayed.lua -Success PASSIVES_DELAYED_OK -TimeoutSeconds 75`
uses real Soul Drain pulses. Runtime-only `/passiveqa quiet` moves the caster
outside stationary monster melee while retaining the living callback target.
`/passiveqa restartconduit` synchronously uses ordinary authorized start/preset
handlers so a baseline pulse cannot restore the combat flag between commands.
These are disposable diagnostic transitions; ordinary allocation/reset/switch
commands continue to enforce combat gates. They do not force passive counters.
## Regression checks

For substantial passive/client/server changes, run the affected existing-system gates as well as new-feature tests. See [passives-regressions.md](passives-regressions.md) and `./tools/run-passives-regressions.ps1`.
