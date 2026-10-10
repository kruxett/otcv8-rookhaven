# Magic Quiver

Magic Quiver is a nonstackable ammunition container equipped in the ammo slot.
It holds 20 ammo stacks and supplies the first compatible stack to the equipped
bow or crossbow. Normal ammunition consumption and carrying weight still apply.
It grants no damage or combat bonuses. Ordinary equipped ammunition remains
supported. Non-ammunition and nested containers are rejected.

The existing hunter's quiver (SID 12425), including Garrick's quest reward, is
unchanged. The current DEV10092 item uses SID 12830 → CID 11867 → SPR 36661 and the
container flags from bag 1987. DEV10091 used SPR 36660. The updated provisional
artwork is drawn directly at 32×32 with 16 colors including transparency: an
empty dark opening, indigo leather, aged gold metal, a cyan gem and connected
cyan rune. The generated 1254×1254 empty-quiver reference supplies color and form
only; it is never downsampled into the game sprite. Source, definition and
artwork provenance are under `assets/items/magic-quiver/`.

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

The DEV10092 update adds a number to the equipped quiver's inventory
icon. With a bow, it shows the arrows available; with a crossbow, the bolts
available. Without either launcher, it shows the total ammunition. Hovering
shows the total, arrows and bolts separately, plus how much is usable with the
equipped launcher. A filled quiver with incompatible ammo shows zero usable
rounds; it is described as empty only when its total is zero.

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

The inventory counter receives a server-authoritative opcode 104 JSON snapshot
(`schema=1`, `equipped`, `quiverCid`, `total`, `arrows`, `bolts`, `compatible`,
`requiredAmmo`, `launcherReady`). The server pushes final state on login,
equipped-quiver content changes and ammo/hand-slot changes, even when the
container is closed. The client can request one coalesced `status` recovery;
it does not poll or derive contents from its container cache. A separate
non-interactive label preserves the item's native stack count and inventory
interactions. Quiver replacement, weapon change, logout and module unload clear
old state before accepting a fresh snapshot.

## DEV10092 verification

DEV10092 is published. The updated sprite and inventory counter passed the
focused local native test, the real DEV updater and the read-only live probe.
The current native PNG SHA-256 is
`2bb347cbd3b5b00c4792da84f4a36cc236b28c9a3c176b1402022daa20941e0d`.

The focused source test executes the actual client counter and JSON decoder
with UI/transport doubles. All 65 checks passed, including 0/1/100/101/2,000
rounds, compatible/total display policy, malformed snapshots, closed-container
pushes, same-CID replacement, weapon changes, stale callbacks, logout/relogin and
unchanged ordinary ammunition counts. This does not verify native readability
or actual server/client event delivery. Run it with LuaJIT:

```text
luajit tools/tests/quiver-counter-contract.lua modules/game_inventory/quiver.lua modules/corelib/json.lua
```

The [actual native counter receipt](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/counter-native-1a16dd5bcadb40849c276adf6e37b2ac/native-result.json)
passed with native exit 0 and original profile bytes and recursive DACL restored.
The closed-quiver cases verified 0/1/100/101/2,000 rounds, mixed arrows/bolts,
bow/crossbow switching, total-count fallback without a launcher, content moves
and stack changes, same-CID quiver replacement, unequip and ordinary arrows at
99. Normal safe logout/fresh login retained 101 arrows/nine bolts and refreshed
the counter. One real ordinary shot at the normal 2,000ms interval consumed one
arrow and updated the counter; original equipment and resources were restored.

Actual 1280×800 and 800×640 frames show 101 and 2000 without clipped digits.
The empty opening, cyan details and count remain visible in the existing retro
inventory frame. See the [lossless inventory crop](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/native-visual-review/quiver-counter-inventory-crop.png),
the [2000-count minimum-resolution crop](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/native-visual-review/quiver-counter-2000-minimum-inventory-crop.png)
and the [4× nearest-neighbour comparison](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/native-visual-review/quiver-counter-inventory-montage.png).
The [crop receipt](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/native-visual-review/crop-result.json)
confirms that each crop preserves the exact source framebuffer pixels.

The first harness run wrongly rejected the normal logout EOF and captured a
late class dialog over the smaller frame. Test-only handling was corrected;
the passing rerun uses unobstructed frames. No production change was needed
for either harness issue.

The [DEV10092 publication](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/actual-publication-result.json)
and [server deployment](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/actual-deployment-result.json)
passed. The client EXE is unchanged; the new `data.zip` SHA-256 is
`108b1cd0cb7dadbc8d85ae4d1db30b233690bd5e37662b8c769c5bb979b71150`.
The eight-file login contract remains `CS1:5e69735b`; the generated server
checksum export covers 134 monitored paths.

The [actual native updater](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/native-updater-df1fbc3fa18c4156a10e7b97c81787e0/result.json)
upgraded a complete DEV10091 client to DEV10092 through the real DEV HTTP endpoint,
downloaded the archive and restarted the native child. Original profile bytes
and recursive DACL were restored, and the original install was unchanged.

The [focused live DEV probe](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/live-quiver10092/result.json)
passed two normal logins/safe logouts, native quiver flags/SPR36661, the actual
Utility offer 4001 at 150 points, ordinary `/quiver status` denial and inventory.
Each login verified the ordinary character's own canonical opcode 104 clear
snapshot and hidden quiver badge. Level, XP, position, inventory and shop points
stayed unchanged. Original profile bytes and recursive DACL were restored, and
both DEV10091/10092 installs were unchanged. The actual shop icon was reviewed
at [1280×800](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/live-quiver10092/live-qa-qv92c10f-cycle2-shop.png)
and [800×640](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/live-quiver10092/live-qa-qv92c10f-cycle2-minimum-shop.png).

The [final runtime readback](C:/GitRepos/kruxett/otcv8-rookhaven/out/quiver-dev10092-20261010/actual-runtime-final.json)
confirmed the same native server throughout live QA on ports 7173/7174, no new
crash dumps, unchanged config/control/DLL files and unchanged PROD1006.
Equipped-counter gameplay and the real shot above were tested in the disposable
loopback runtime. Live equipped-counter updates/shots, Admin/God grants, PvP and
shop purchases were not tested in this read-only live run.

## DEV10091 verification history

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
