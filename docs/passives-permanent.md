# Permanent passive classes — local foundation

This increment connects the six existing trees to third Ascension. It is enabled
only on the isolated loopback server and retro local client. Nothing is deployed
or pushed. Two starter spells per class are now included locally. Their numeric
balance remains provisional; see [class-starter-spells.md](class-starter-spells.md).

## Player flow

1. Complete The Ascent and speak to The Nameless.
2. The retro local client opens a visual class picker with names, playstyles and
   native portraits. Preview a card, then confirm one permanent class separately.
   Declining or leaving does not choose it. Unsupported clients retain text choice.
   See [class-choice-ui.md](class-choice-ui.md) for screenshots, test commands and
   the server-owned offer contract.
3. Third Ascension resets level and moves equipment to the depot as before.
   The chosen class also preserves the matching fourfold skill discipline.
4. The confirmed class grants its two starter spells. Open the separate Class
   Spells window from the `Learned class spells` button beside the passive button.
5. Allocate points in the retro tree; Apply saves them on the server. Open it again
   from the ordinary passive button or `!passives`.
6. Respec refunds allocated points within the chosen class. It cannot change class
   or replace the class's starter spells.

| Class | Equipment | Existing discipline storage value |
| --- | --- | --- |
| Reaver | Axe | 2 |
| Blademaster | Sword | 3 |
| Earthshaker | Club | 1 |
| Marksman | Bow/crossbow | 4 |
| Arcanist | Wand | 5 |
| Lifekeeper | Rod | 5 |

Vocation remains `3` (Ascended). Class is stored separately, avoiding changes to
legacy vocation formulas, quest checks, skill multipliers and Ascension stages.

Already Ascended players retain their existing discipline. Magic focus permits
either Arcanist or Lifekeeper; other focuses permit their matching class. A player
without a saved discipline gets one with class confirmation. To return to The
Nameless before choosing a class, say `arcanis exevo infus` beside an Oracle Stone.
The local revisit does not consume mana or repeat Ascension. It requires leaving
combat and ending any temporary test overlay. The Nameless returns existing
Ascended players to the temple after choosing; `leave` returns them before choosing.

## Using Class Spells in the retro client

The Class Spells button appears after the local server publishes the chosen
permanent class and its two learned spells. It requires ordinary player access,
not an administrator. Each card shows the incantation, **Base mana**, range,
shared exhaustion and description. Press **Cast**, or put the displayed words in
an existing text hotkey. The new cards are separate from the legacy spellbook
and action bar; those systems have not been redesigned or given a new icon atlas.

| Class | First starter | Second starter |
| --- | --- | --- |
| Reaver | Cleaving Arc — `exori sec arc` | Rend — `exori sec vul` |
| Blademaster | Focused Thrust — `exori sis punct` | Flurry — `exori sis duo` |
| Earthshaker | Crushing Blow — `exori mal grav` | Rolling Thunder — `exevo mal ton` |
| Marksman | Blitzshot — `exevo sagitta duo` | Scattershot — `exevo sagitta mas` |
| Arcanist | Resonant Burst — `exori arcan pul` | Arcane Surge — `exevo arcan lux` |
| Lifekeeper | Mending Thread — `exura vita filo` | Essence Lash — `exori vita` |

Equip the class's matching weapon. Offensive starters attack monsters; focused
attacks need an attack target, while sweeps and the beam depend on facing.
Marksman also needs compatible ammunition. Mending Thread defaults to healing
yourself. For a party member, enter their name without quotes in the window's
target field. The equivalent text hotkey is `exura vita filo "Starter Reaver"`.
The recipient must be in your party, on the same floor, within 7 tiles
horizontally and 5 vertically, with line of sight. Clear the field to heal yourself.

The countdown comes from the server. Casting a combat spell locks both combat
cards for that cast's shared exhaustion; existing same-kind spells also update
that lock. Healing and combat are separate groups, so Lifekeeper's two cards can
be ready independently. This is not an additional timer for each starter.
**Base mana** is the configured cost before passive discounts. The server decides
actual cost, learned-spell access, class, weapon, range and exhaustion; rejected
casts are reported through the normal game messages. A ready button does not
guarantee that all those requirements are met.

Closing the window keeps the class and spells. Logout removes the window, button
and cooldown state; the server republishes the saved class's learned spells on
login. The local launcher remains required. The window uses existing native
32-pixel icons and retro assets, with no DAT/SPR/OTB changes.

## Central tuning

Server: `../Rookhaven/data/lib/passives/config.lua`.

`common` and `trees` tune effects. `progression` tunes point milestones and fees:

```lua
progression = {
  unlockLevel=1, startingPoints=3, levelsPerPoint=3, maxPoints=24,
  respecCosts={0,1000,2000,4000,8000},
}
```

These are provisional local values: 3 points at level1, 16 at level40, 24 at
level64. One rank costs one point. The existing graph allows the first capstone
at 16 spent points. Earned points remain after later level loss; regaining the
same level does not grant duplicate points. The native foundation currently
bounds the configurable budget at24. Lowering configuration does not erase
already earned points or purchased ranks.

The first nonempty respec is free; subsequent fees use the list in order and
repeat its last entry. Fees are taken from the bank. Bank debit, ranks and respec
count commit in one transaction. An empty reset consumes no respec. Apply permits
adding ranks and undoing new draft ranks; removing saved ranks requires respec.
Both actions require leaving combat, the current session and revision. Respec
also checks the displayed fee and respec count. Refresh/restart local runtime
after changing config; live reload is not supported.

Trusted server startup seeds all six native class configurations before offline
vendors are restored. Login configuration remains idempotent. An offline vendor
or TCP-detached player reconnects through a separate native path; that path also
restores saved talents before initial stats are sent. A rejected reconnect keeps
an existing offline store active.

## Persistence and lifecycle

Paths in this document are relative to the client repository root. New databases
use `../Rookhaven/schema.sql`. Existing databases upgrade through
`../Rookhaven/data/migrations/30.lua` to version31; the migration checks that table
creation succeeds before advancing the version. The idempotent local preparation
SQL is `../Rookhaven/tools/passives-fixture/permanent-schema.sql`.
`player_passives` holds class, earned points, respec count and17 ranks. Its player
reference cascades on player deletion. New passive data does not reserve storage
keys. The existing Ascent quest/focus/popup storages are reused for their existing
purpose.

New third Ascension writes vocation reset, converted skill progress, class and
quest/focus completion atomically after logout. Failed transactions do not grant
a class or announce successful Ascension. Existing Ascended class and missing
focus are likewise committed together.

Combat counters, wards, bleeding and derived HP are transient. Death clears them
and restores the saved build with a fresh session after respawn. Logout, personal
store logout and TCP detach remove derived bonuses from the offline player;
relogin reloads saved ranks. Saved base HP remains separate from passive bonuses.
Admin `start`, `stop`, `preset` and client `end` cannot replace a permanent class.
Old24-point admin overlays remain available on characters without a class.

## Local verification and manual play

```powershell
./tools/build-local-passives.ps1 -Jobs 8
./tools/run-passives-permanent-tests.ps1
./tools/run-passives-permanent-fault-tests.ps1
./tools/run-passives-permanent-cold-tests.ps1
./tools/run-passives-regressions.ps1
```

The permanent runner resets only disposable GUID9003–9005 in
`rookhaven_passives_test` on port33308, after stopping the owned local server.
It does not reset the admin fixtures or connect to a deployed database. Native
client probes cover the actual Nameless dialogue, Apply/Respec UI, protocol
rejections, saved rows, logout/relogin, death, store and TCP detach. Legacy focus
cases include axe, wand and rod, with the real Oracle Stone talkaction.
The fault runner requires the preceding suite's disposable GUID9005 Reaver. It
corrupts only that row while the owned server is stopped, checks login rejection
and the server's specific invalid-data error, then repairs it in `finally`.
The cold runner temporarily changes only runtime balance/progression, restores a
real offline store at startup, verifies first-connect tuning and preservation on
rejected reconnect, then restores source defaults and the fixture ledger.

Launch `out/install/x64-LocalPassives/Start Local Passives.cmd`.
Test accounts: `passiveclass / passiveclass`, `passivelegacy / passivelegacy`,
`passivemagic / passivemagic`. These have ordinary player permissions. Admin
accounts `passivetest` and `passivepeer` retain the temporary test workflow.

The prepared manual `passiveclass` character is Reaver at level43, with17 earned
points,16 allocated and Berserker selected. Its bank has10000 fixture gold for
testing respec. Integration tests already used its free reset and two paid resets;
the next quote is4000. `passivelegacy` is an empty level40 Reaver tree and
`passivemagic` an empty level40 Lifekeeper tree. Use `!passives` or the passive
button to reopen. These are disposable local characters.

### Starter-spell test characters

The starter-spell runner creates these separate ordinary-player fixtures in the
same isolated database. Each account's password is identical to its account name.
They start at level40 with vocation3 and the matching saved discipline; the
runner chooses their class through the actual Nameless dialogue and checks
relogin. Their current ranks, bank and combat state are disposable test data and
may change between scenarios.

| Player GUID | Account/password | Character | Class |
| --- | --- | --- | --- |
| 9006 | `classreaver` | Starter Reaver | Reaver |
| 9007 | `classblademaster` | Starter Blademaster | Blademaster |
| 9008 | `classearthshaker` | Starter Earthshaker | Earthshaker |
| 9009 | `classmarksman` | Starter Marksman | Marksman |
| 9010 | `classarcanist` | Starter Arcanist | Arcanist |
| 9011 | `classlifekeeper` | Starter Lifekeeper | Lifekeeper |

Use the same `Start Local Passives.cmd` launcher. If a fixture has not yet chosen
its class, follow the Oracle Stone/Nameless flow above. After choosing, open Class
Spells, equip the correct weapon and try the two cards or their text hotkeys.
Use `!passives` to inspect the saved build; admin overlay `start`/`preset` commands
are not part of this workflow. Automated spell fixtures temporarily suppress
ordinary autoattacks; their `/classspellqa cleanup` removes that fixture override
and owned arena monsters before normal manual combat.

Available isolated runners (these commands are not a record of passed tests):

```powershell
./tools/run-class-spells-tests.ps1
# A selected class; omitting -KeepClasses resets that selected disposable fixture:
./tools/run-class-spells-tests.ps1 -Trees arcanist -KeepClasses
# Requires the already chosen Reaver and Lifekeeper fixtures from the spell suite:
./tools/run-class-spells-synergy-tests.ps1
```

The spell runner uses GUID9006–9011. The party/synergy runner resets Lifekeeper's
build for its three scenarios and prepares the Reaver peer in the isolated
database. These runners control local server/client processes; do not run them
during a manual session you want to keep. Logs are under `out/class-spells-tests`
and `out/class-spells-synergy-tests`; actual results belong in the separate
delivery and regression records. Party, startup and new regression results must
not be inferred from this usage guide.

Evidence/results are recorded separately after running the tests. Numeric balance,
fun, all legacy quest chains and production rollout are not established by these
integration checks.
