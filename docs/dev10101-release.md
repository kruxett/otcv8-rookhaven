# DEV10101 — spell-focus rewards and talent art

Published 2026-10-29 after Marcus requested committing all outstanding work and
deploying both client and server to DEV.

## Deployed change

- Forgotten Ancients offers one Epic Dusk Wand or Gravebloom Rod through the
  compact retro choice UI. Weapon type, element, level, damage, mana and bonuses
  appear beside each item. Both current rewards are death weapons; neither has
  a class requirement. Arcanist/Lifekeeper names do not imply that the recipient
  has completed third Ascension.
- Previous recipients can exchange their old quest wand once at Plipus,
  preserving its actual enchantments. New choices cannot use that exchange.
- Ordinary custom wands and rods share the approved level steps 7/13/20.
- All 174 approved talent icons and their matching server catalog paths are
  included. Existing spell artwork and gameplay metadata are preserved.
- Outstanding outfit authoring/reference material and its tools were committed.

See [rod/wand details](lifekeeper-rods.md) and
[talent artwork](passives-art.md) for implementation and acquisition evidence.

## Publication

Deployment job `47cc8e5c-4ece-475d-9b44-367077f510ff` finished `SUCCEEDED`.
It used the ordinary 60-second warning, verified native shutdown, backups,
manifest-last client publication and 60-second runtime stability check. The
owned restart hold was cleared.

- Server source: `5ceddc7e7067f5e5c1ee60d6ae955bc1f7be3d9e`.
- Client build source: `a617787af52be8379a1b95df24dabeb4ab638fa3`.
- Server Lua/data were reloaded through a normal supervisor restart. Native
  sources and build inputs were unchanged; `buildRequired=false` reused the
  verified existing server binary.
- DEV login: `testserver2.rookhaven-ot.com:7173:860`.
- [Full DEV10101 client ZIP](http://updater2.rookhaven-ot.com/files/dev/Rookhaven-DEV10101-client.zip).

| Artifact | SHA256 |
| --- | --- |
| Running server EXE | `8a0e3fa249706f52800c3738691d9bb26cbaa4c3d47d159875007f2e045365b0` |
| Client EXE | `7cadb2f73df73e4deee1fac73939f643b23486694fc158e8f589255ef9b6023c` |
| Encrypted data.zip | `baa1586a560fbc0415bea89d6e2b7514af0a46891c7f57076e8050b9b1ab690e` |
| Full client ZIP | `3ae4625832da40c7b6fb3e16d3cbb05f55fb63bcf7ca60866c7da0dc45770f07` |

RH2 resource fingerprint:
`4fb714551a0f13830f835160cc1963312cbcebe2873dc0def7a036a9f92f3fdb`.
The matching RH2 pin and 334-entry encrypted CRC inventory were installed with
the client pair. Readback matched all six publication artifacts, source HEAD,
runtime identity and the deployment job. Startup had no matching script/load
errors. Live configuration and both PROD files retained their baseline hashes;
PROD remains version 1006.

## Verification

Selection followed the changed dependencies:

- Quest choice/session/grant → actual rarity and affix libraries: 304 contract
  checks, plus 29 client UI checks. Existing client-request contracts (91), NPC
  dialog regression (20 cases / 53 checks), and forge regression (33 groups)
  passed.
- Weapon tiers → both hands at six level boundaries: the October 29 native
  evidence covers 336 equip checks and six ordinary-knife checks.
- Final inline UI and pre-Ascension eligibility → real loopback chest, both
  rewards, cancel, duplicate denial, CAP refusal/retry, actual Plipus exchange
  and reconnect persistence passed with an ordinary Unawakened character.
- Talent icon paths → all 174 unique approved PNGs, 108 preserved legacy PNGs,
  and the unchanged spell catalog passed. All six catalog/client topology paths
  passed 6,978 cases, 2,880 purchase prefixes and 564 rejection cases.
- Protected client → 2,110 build-input files matched the local source. The full
  1,446-resource manifest regenerated identically. Direct decoded equality
  covered all 285 quest-module/passive-image files. Native verification accepted
  the matching pair and rejected the old archive and a changed quest module.
- Public HTTP → 10100 is offered 10101; 10101 is up to date. The downloaded full
  ZIP and its inner executable/archive hashes match the staged artifacts. The
  canonical PROD API retains version 1006 and its two original hashes.
- Real native updater → actual HTTP 10100→10101 download, executable/archive
  promotion, restart and native helper deletion passed. Both guarded runs
  restored all four original profile trees with identical file/path/owner/DACL
  fingerprints and stopped their owned clients. The restarted client log records
  the new resource fingerprint and archive mount.
- Normal DEV login → the owned ordinary QA account passed character selection
  and the new retail RH2 claim. Old RH2, a missing verification block and QA mode
  were refused. Read-only shop init/history/init retained the 26 outfit variants,
  ten other offers and points after first initialization, followed by logout.
  No purchase or gameplay commands and no native GUI authentication were used.

Initial build-wrapper failures treated a CMake developer warning as a fatal
PowerShell error and omitted PowerShell from the session PATH. Both were fixed;
the final configure/build/package and native checks passed. The first updater
run verified download, promotion and restart but its hidden GUI prevented visual
inspection. The QA wrapper now launches its interactive client visibly; the
original run and its limited visual observation are retained. Activation/capture
also failed in the visible rerun, so a visible version/login-screen inspection
is **not verified**. No further UI actions were attempted after that failure.

Evidence is under `out/dev10101-20261029/`,
`out/ancients-reward-20261029/`, and the explicitly named 10101 updater runs
under `out/release-smoke-20261027/`. These paths contain operational receipts,
not player database backups or credentials.

The full dungeon route has not been played through for this release. The quest
reward flow was tested locally; release compatibility checks use the ordinary
DEV route. The unchanged passive combat systems did not require a full passive
suite rerun.
