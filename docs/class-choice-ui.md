# The Nameless — visual class choice

## Scope and status

Local-only retro UI for choosing one of the six existing third-Ascension classes.
The cards explain class identity and playstyle before the permanent decision.
This increment changes presentation and connects to The Nameless' existing
class-selection flow; it does not introduce another Ascension, new classes,
new starter spells, an outfit unlock, or final balance approval.

Implemented and tested locally on 2026-10-06. The actual native client rendered
all six cards at 1280x800 and 800x640, and real ordinary players completed both
third Ascension and legacy class choice through the UI. Executed evidence and
remaining cases are recorded below and in local-passives-results.md.

Sources: [client controller](../modules/game_passives/classchoice.lua),
[class-choice layout](../modules/game_passives/classchoice.otui),
[server offer controller](../../Rookhaven/data/lib/passives/class_choice.lua),
[The Nameless](../../Rookhaven/data/npc/scripts/The%20Nameless.lua).

## Card copy

English matches the existing in-game dialogue. These are present capabilities
and later talent alternatives, not promises of future taunt, threat, or PvP
mechanics. Talent points can be reset; class identity cannot be changed.

| Class | Description shown before confirmation |
| --- | --- |
| Reaver | Fight at close range with axes, using sweeping cuts and focused strikes. Develop talents for rage, bleeding, or wards earned through your attacks. |
| Blademaster | Use swords for focused strikes and short flurries. Develop finishers, shield-based counters, or critical hits that strike nearby foes. |
| Earthshaker | Deliver heavy club blows and small ground pulses. Develop aftershocks, shield-based guard, or protective wards for nearby party members. |
| Marksman | Fight at range with a bow or crossbow, combining focused shots with smaller hits on nearby monsters. Develop steady aim, movement-driven bounces, or marks that help your party. |
| Arcanist | Cast elemental pulses and short beams with a wand. Develop chains, spell echoes, or rewards for alternating offensive spells. |
| Lifekeeper | Wield a rod to heal yourself or party members while retaining a ranged attack. Develop healing over time, absorbing wards, or party healing earned through damage. |

The current card contract contains class names and playstyle, without spell-name
lists or numerical balance values. Existing two-starter entitlement is unchanged;
see [class-starter-spells.md](class-starter-spells.md) for actual spells, equipment
requirements, and first-use restrictions. Later capstones are alternatives, with
at most one active; choosing a class does not immediately grant its capstones.

## Native art and metadata

Portraits use `UICreature` and the shipped outfit sprites. They are illustrations:
previewing or confirming a class neither changes the player's outfit nor grants
premium outfits. Use south-facing, static sprites, centered inside classic frames;
no new high-resolution art, DAT/SPR/OTB entries, addons, mounts, auras, or shaders.
The client has a native fallback portrait for an unavailable outfit ID.

| Class | Outfit male / female | Head | Body | Legs | Feet | Intended palette |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Reaver | Barbarian 143 / 147 | 78 | 97 | 95 | 114 | Earth red and bronze |
| Blademaster | Knight 131 / 139 | 57 | 87 | 76 | 114 | Steel and blue |
| Earthshaker | Warrior 134 / 142 | 78 | 57 | 95 | 114 | Earth and gray |
| Marksman | Hunter 129 / 137 | 78 | 103 | 97 | 114 | Forest green and brown |
| Arcanist | Mage 130 / 138 | 57 | 89 | 108 | 114 | Violet and blue |
| Lifekeeper | Druid 144 / 148 | 78 | 44 | 21 | 95 | Moss and beige |

All have `addons = 0`. Color indices are from the native
[133-color outfit palette](../src/framework/util/color.cpp#L52), not arbitrary RGB
values. Palette intentions require visual review on the actual outfits; colorable
regions differ among sprites. The server chooses the matching male/female type.

Each offer contains six records with `id`, `name`, `weapon`, `tagline`,
`description`, `allowed`, `reason`, and `outfit = {type, head, body, legs, feet,
addons}`. Ineligible classes remain visible with an explicit reason, and cannot
be selected. Server-owned legacy discipline filters choices: axe, sword, club,
or distance retain their discipline; magic can choose wand or rod; an Ascended
player with no established discipline can choose among all six.

## Interaction and server contract

1. Greet The Nameless at the existing eligible quest/class stage. The local
   client advertises `classChoice = true` through opcode 103 hello. Unsupported
   clients retain the NPC text flow.
2. Server sends `class_choice_offer` with `offer`, `ttlMs`, `classes`, and
   `consequences`. Offer lifetime is 60 seconds; it is bound to the player GUID,
   runtime ID, NPC, vocation, quest progress, and existing discipline.
3. Clicking a card changes only local selection and details. `Choose class`
   sends `class_choice_select` with `offer` and `classId`; this prepares the
   existing NPC confirmation, without granting a class.
4. Server sends `class_choice_confirm` with `offer`, `revision`, `selectedId`,
   `name`, and `consequences`. Final `class_choice_confirm` from the client
   must echo the offer and exact revision. The separate dialog defaults keyboard
   focus to `Go back`, and describes the permanent choice.
5. `class_choice_back` uses the same revision and returns to preview.
   `class_choice_cancel` clears the NPC choice. X/Close, selection Escape,
   logout, NPC loss/range failure, changed eligibility, and expiry invalidate
   the offer. Escape in confirmation means Go back.
6. Commit is dispatched through The Nameless' one-use server guard. The offer
   is consumed before inventory/DB side effects. Duplicate/stale requests cannot
   grant a second class. `class_choice_result` carries authoritative success or
   failure; `class_choice_close` invalidates the display. Preview is never proof
   of a saved class.

The third-Ascension confirmation describes level 1, experience 0, current and
maximum mana 0, inventory transfer to depot, reconnect, retained skill/magic
mastery and its progress, and future fourfold training of the chosen discipline.
An already-Ascended player choosing a class keeps level, mana, possessions, and
mastery; the existing discipline restriction still applies. The two paths must
not share misleading reset text.

`Player:passiveTest('busy')` is a local read-only native operation. It reuses the
same predicate as permanent class choice: attacked target, INFIGHT, or any valid
retained action. The offer can be previewed during battle; the NPC checks this before accepting
a selection and again before commit, including the third-Ascension offline path. [Native predicate](../../Rookhaven/src/passives.cpp#L192)
and [binding](../../Rookhaven/src/luascript.cpp#L10283).
`PassiveTest.state()` reads the passive snapshot for class lock/test-overlay
state, but does not itself prove combat readiness. Calling `choosePermanent`
as a readiness probe would incorrectly write class, discipline, and spells.

The existing depot transfer moves inventory slot by slot and returns failure if
a later item cannot move, without rolling back earlier successful moves. The UI
closes the consumed offer on failure; it does not make this inventory operation
atomic. The offline transaction keeps durable Ascension/class/focus/quest/spell
writes atomic, but inventory rollback is outside this UI increment's scope.
[Existing transfer](../../Rookhaven/data/npc/scripts/The%20Nameless.lua#L80).

A native protocol detach clears passive client capability, including classless
players. Offer validation requires that capability; a new hello cancels any old
offer before enabling the new connection. This protects retained offline-vendor
actors whose reconnect bypasses Lua login. These are source-level safeguards;
actual reconnect behavior still needs its targeted runtime check.

## Review plan — not yet a test result

- At **800×640**, all six cards, names, eligibility reasons, selection frame,
  permanent-choice reminder and action buttons remain readable and accessible.
  Scrollable descriptions and consequences must not cover the buttons.
- Inspect each native outfit at actual rendered size: distinct silhouette,
  classic pixel edges, deliberate palette, male/female variants, no premium or
  appearance grant. Inspect selected, disabled, waiting, and confirmation states.
- Mouse and keyboard: card click previews only; Tab/arrows navigate available
  cards; Enter proceeds to confirmation; Go back and Escape preserve safe
  navigation. Double click, response timeout and expiry cannot silently commit.
- Exercise fresh third-Ascension and legacy class choice, including legacy magic
  with two choices, incompatible disciplines, active test overlay, combat and
  pending delayed action. Check state again at confirmation, not only on open.
- Exercise No/cancel/bye/logout/out-of-range, stale offer/revision, raw reserved
  NPC text, inventory/depot failure, DB failure, and repeated confirm. No failed
  or cancelled flow may persist a class. Check and report partial inventory
  movement on a depot failure separately; the existing transfer is not atomic.
- After actual commit and reconnect, verify permanent class and its two starters,
  retained legacy spell learning, discipline and quest progress. Existing NPC
  conversation and feature-disabled text selection must continue to work.

Record the actual probe outputs, screenshots, failures/fixes, and remaining human
review in the delivery report. Existing-system requirements are in
[passives-regressions.md](passives-regressions.md); compilation or screenshots
alone do not verify NPC, inventory, persistence, or learned-spell behavior.

## Executed local review — 2026-10-06

- Native UI: six available cards for fresh third Ascension; two for legacy magic;
  one for legacy sword. Cards/actions/confirmation remained inside the 800x640
  viewport. Female outfit variants were actually rendered; male variants have
  not received the same visual review yet. Class art uses existing game sprites.
- Preview and cancellation: card browsing, Go back/default Enter, Close, wrong
  revision, invented offer, incompatible discipline, expired offer, remote NPC
  interaction and combat rejection preserved class/progression/learning.
- Reconnect: preview windows cleared on TCP logout; old confirmations could not
  grant a class after reconnecting the same retained player entity.
- Real commit: fresh third Ascension persisted Reaver, correct focus/quest,
  level1/maxmana0, and exactly two starters while retaining Light Healing.
  Equipped axe/shield left the inventory. Legacy magic/sword choices preserved
  level40 and their discipline; class/spells survived reconnect without duplicates.
- An exact reserved NPC bridge message sent as normal NPC chat could not confirm
  the prepared choice. Final success replay was also rejected.
- Existing text NPC choice and permanent progression, respec, death, vendor save,
  TCP reconnect and earned point milestones passed. All five established passive
  regression gates passed: normal module guard, lifecycle, enabled/disabled combat
  baseline and six-tree contract.

Evidence: `out/class-choice-tests/fresh.log`, `magic.log`, `sword.log`,
`manual-preview.log`, `existing-permanent-run.log`, `existing-regressions-run.log`.
The final fresh UI run includes the Selected label and corrected confirmation
status. Legacy scenario runs preceded these two presentation-only refinements.
Screenshots: `out/passives-evidence/class-choice-fresh-small.png`,
`class-choice-fresh-confirm.png`, and `class-choice-review-ready.png`.

Depot-full/partial-transfer and injected DB-failure scenarios were not rerun for
this UI increment. The existing slot-by-slot inventory limitation described above
remains. Sustainable combat balance and final art approval require playtesting.

## Manual local preview

Open `out/install/x64-LocalPassives/Start Local Passives.cmd`. The owned server
listens on 127.0.0.1:7174/7175. Log in with `passivetest / passivetest`, character
`Passive Tester`, which currently has no permanent class. Then:

```text
/passivetest stop
/goto The Nameless
hi
```

Say `hi` to the NPC. This route was verified in the native client, with all six
choices and cancellation without a class grant. Selecting a card is a preview;
the separate Confirm class action is permanent. The NPC currently exists in the
running test world. After recreating the runtime, the fixture's NPC placement may
need to be run again before `/goto The Nameless` can find him.

Reproduce the ordinary-player test scenarios with
`tools/run-class-choice-tests.ps1` (only disposable IDs9003..9005 on DB33308).
