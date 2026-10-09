# Magic Quiver

Magic Quiver is a nonstackable ammunition container equipped in the ammo slot.
It holds 20 ammo stacks and supplies the first compatible stack to the equipped
bow or crossbow. Normal ammunition consumption and carrying weight still apply.
It grants no damage or combat bonuses. Ordinary equipped ammunition remains
supported. Non-ammunition and nested containers are rejected.

The existing hunter's quiver (SID 12425), including Garrick's quest reward, is
unchanged. The new item uses SID 12830 → CID 11867 → SPR 36660 and the container flags
from bag 1987. Artwork is a provisional native 32×32 sprite; the source and
definition are under `assets/items/magic-quiver/`.

## Obtain and test

The current shop uses character TEST points. Utility → Magic Quiver costs 150
points and grants one empty quiver. An unsuccessful inventory delivery neither
charges points nor adds history. The new offer cannot fall back to floor delivery.
The 20-stack capacity and 150-point price are confirmed for this item.

Admin/God character groups 5/6 with access can use:

```text
/quiver give Krux
/quiver status Krux
/quiver give
/quiver help
```

Named characters must be online; an omitted name means yourself. Account type
is not an additional permission requirement. Equip the quiver in the ammo slot,
open it and place arrows or bolts inside. Shoot with a matching bow/crossbow;
the next compatible stack is used when the current stack runs out.

## Implementation and affected systems

XML `ammoContainer=true` marks the special container. Native
`Player::getAmmunition(requiredAmmo)` preserves the direct ammo-slot path, or
selects a positive compatible stack directly inside a marked container.
`getWeapon(false)`, native ordinary shots, Marksman spell payment and damage
estimates share that selection. Other bags do not feed launchers.

Sure Shot, Volley and the Marksman starter projectile helper use Lua
`player:getAmmunition()`. Volley reserves one real
round for each scheduled shot, resolving again at stack boundaries. The existing
target cap, range, delays and damage formulas are retained.

The permanent command is registered in `data/talkactions/talkactions.xml`.
`tools/quiver-fixture/quiver_native.lua` is registered only in the disposable
loopback runtime; it is not a live game command.

DEV 8.60 validates the quiver's client ID/container/nonstack/pickup flags before
allowing login. A missing or incompatible item table prompts a client restart
to obtain the update. The check lives in `game_features/features.lua`, one of
the eight native critical login resources. Updating this resource changes the
server compatibility checksum; after coordinated publication, clients using
the old 10090 resources must update before entering the game.

## Verification status

The [final DEV10091 evidence index](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/final-dev10091-verification.json)
links the local, publication, updater and focused live results with their exact scope.

- Asset mapping, semantic DAT/OTB container and nonstack flags, lossless sprite
  decode and preservation of unrelated records passed.
- Server native build passed. DEV10091 client package preflight verifies final
  encrypted DAT/SPR, shop/inventory and existing monitored resource equality.
  The published compatibility package advances the critical-eight login checksum
  from `CS1:d08bec84` to `CS1:5e69735b` while reusing the existing native EXE.
  Its `data.zip` SHA-256 is
  `07a53011c712ec10e1f825f34e3b30933135a29806e492f136f13fc8fc3f47d9`.
  The generated server checksum file retains all 133 monitored paths, including
  108 `/data/` paths. The checksum exporter was corrected to preserve prior
  non-module paths as well as `/modules/` entries.
- The focused native asset guard passed with the matching package and with only
  the older 10090 DAT substituted. Matching assets loaded with versions 860;
  older DAT produced one visible update message, `isLoaded=false` and versions
  0. Both native DAT/SPR parsers succeeded, so rejection came from the intended
  guard. Original profiles were restored with byte and recursive DACL checks.
  See the [native compatibility receipt](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/native-compatibility-verified.log).
- 47 isolated checks execute the actual shop configuration, handler and admin
  command. 27 server-feature contracts passed. These use API doubles.
- All five existing native passive regression gates passed. Ordinary Marksman
  starter spells, mana/ammo payment, cooldown and negative gates passed.
- Actual native quiver contracts passed: 20 slots/2,000 arrows, normal weight,
  overflow and non-ammunition rejection, direct ammo compatibility, bow/crossbow
  selection and unchanged equipment damage estimates.
- Sure Shot paid one arrow/eight mana. Volley paid three arrows/40 mana across
  two stacks, hit three targets and retained incompatible bolts. Cooldown
  rejection replayed neither payment nor damage. Marksman starters passed both
  with direct ammo and with ammo inside the quiver.
- 101 ordinary shots at the normal 2,000ms interval consumed exactly 101 arrows,
  caused 7,936 observed damage against the owned dummy and retained five bolts.
  Original equipment and resources were restored.
- Normal logout/fresh login retained the equipped quiver and three separate
  stacks: ten arrows/five bolts, selection/order and weight. Actual shop UI
  purchased one empty quiver for 150 points (1,000 to 850) with history; the
  owned purchase, points and history were then restored.
- Visual review used actual 1280×800 and 800×640 native screenshots. All 443
  opaque inventory pixels match the imported 32×32 PNG. The provisional sprite
  has simpler shading and more compact proportions than the concept image.
  See the [inventory crop](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/quiver-native-inventory-crop.png)
  and full [1280×800](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/quiver-native-equipped-1280x800.png)
  and [800×640](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/quiver-native-equipped-800x640.png) frames.
- These phases passed in focused runs; fixture failures were corrected without
  replaying the successful 101-shot phase. Restoration now handles dynamic
  defense/idempotence, client container counts use the 8.60 item list, spell
  measurement waits for the first actual shot, and each account handshake uses
  a fresh ProtocolLogin. Logs are under `out/quiver-dev10091-20261009/` and
  `out/quiver-shop-only-native.log`.
- DEV10091 was [published](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/actual-publication-result.json)
  with server commit `2189321d8ec1bc6601cf727402b3caa69f0b42ab`. The
  [reconciled deployment](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/actual-reconciled-deploy-result.json)
  enabled DEV client checksum enforcement. The
  [final runtime readback](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/actual-runtime-final.json)
  confirmed the same native server throughout live QA on ports 7173/7174, no
  new crash dumps and unchanged PROD1006.
- The [actual native updater](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/native-updater-c4f13316bf104cb1bd4e38bb0bc0aa69/result.json)
  upgraded a complete 10090 client to 10091 through the real DEV HTTP endpoint,
  downloaded the new archive and restarted the native child. The EXE was
  unchanged. Original profiles were restored with byte and recursive DACL checks.
- The [focused live DEV probe](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/live-quiver10091/result.json)
  passed two normal logins/safe logouts, native quiver flags/sprite, the actual
  Utility offer 4001 at 150 points, ordinary `/quiver status` denial and native
  inventory. Level, XP, position, inventory slots and shop points stayed
  unchanged. Shop/inventory frames were captured at 1280×800 and 800×640; the
  live shop icon fits the retro UI without clipping. Original profiles were
  restored with byte and recursive DACL checks, and both installs were unchanged.
  See the live [1280×800 shop](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/live-quiver10091/live-qa-qv91a9fc-cycle2-shop.png)
  and [800×640 shop](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10091-20261009/live-quiver10091/live-qa-qv91a9fc-cycle2-minimum-shop.png).
- A direct old-10090 login rejection, live Admin/God item grants, live PvP/combat
  and purchases by normal DEV players have not been verified. Full-inventory
  shop failure is covered by the actual handler with API doubles.
