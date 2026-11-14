# DEV10102: accounts and characters inside the client

Published to DEV on 2026-11-14. The production manifest remains version 1006 and
both production artifacts retain their pre-release SHA256. No production server
or production authentication setting was changed.

## Delivered behavior

* Retro **Create account**, mandatory email and confirmed password; ordinary login
  opens an empty character list with **Create character**.
* Character name/sex, real outfit preview and server-owned ordinary level-1
  Unawakened defaults. Starter equipment comes from the existing first-login path.
* The selected login endpoint supplies the service; no additional DEV-only API
  address is embedded in these modules. Production endpoint configuration is
  documented in [account services](account-services.md).
* Guild founding already exists through Crestwick/Grimald/Osmund and the Guild
  Manager. Revisiting an NPC no longer lets a member found another guild.
* Native XTEA session keys now use OpenSSL randomness. Unchecked Remember password
  no longer writes plaintext credentials during a failed login.

## Published identities

| Artifact | Identity |
| --- | --- |
| Client runtime/source feature commit | `1139ce533b45a8915ac66131b3f79bd22edaef89` |
| Server feature commit | `a7f36080` |
| Server live commit, including client pins | `9f07f6381d6ca2e06569ed05c10ba1bdbe1ce705` |
| Deployment job | `5df338b0-c1c2-4a3a-8c8a-369f8e3f9fff`, `SUCCEEDED` |
| Native client fingerprint | `d2f14771953bedbd115fb54bb41be06e9f1e780528cc456ccb429fe969285248` |
| Client EXE SHA256 | `cc30cf37758f12313135a7bf8ba9007cd8599f39f0e95b4cec6f02e9f9a0e64e` |
| Client data.zip SHA256 | `1501d84674159e3546b5b5829bb39a4d5f62cf100c42f7d460d4d2d555931bb6` |
| Full DEV ZIP SHA256 | `6185b37f5a1198a23e5b8894aa6fdb0f2f397a8e2c866c25a5558691b1904cc3` |
| Live server EXE SHA256 | `42b297f71d7d5b7e8436bdb8596d5f0526533c0885d44841cc1fe60acb8fcf3e` |

The only private config edit appended `clientAccountServicesEnabled = true`.
The original bytes remain in an operator-only backup. Post-edit config SHA256 is
`59046569a778ec6acadaab7b55d88d8306dc2c19c355408da65be692ae9c3e4a`.
Final readback verified the same server process owns ports 7173/7174, the runtime
is ready, no restart hold remains and the expected client pins match publication.

## Verification actually run

Evidence lives under `out/account-services-20261114/`:

* `native-wire-final/result.json`: real native RSA/XTEA and MariaDB. Validation,
  mandatory email, ordinary privileges, duplicate names, bans, concurrent caps,
  deleted slots, old account rules, closed features, invalid town, SQL rollback,
  recovery, redacted private errors and reconciliation after losing a creation reply.
* `native-full-02/result.json` and `native-ui-02/`: native forms at 800x640 and
  1280x800, empty/populated lists, cancel/reopen, duplicate submit, matching preview,
  actual first items, encrypted Remember password, maximum credential lengths,
  ordinary game login/reconnect, NPC founding and persisted guild leader permissions.
* `native-attacks/result.json`: actual SQL-injection payloads in registration and
  authentication, quoted email roundtrip, forbidden staff prefix, injected privilege/
  level suffixes, oversized packets, unknown version and missing RSA magic. Every
  attack was refused without creating a character; normal creation/login still worked.
* `protocol.lua` and `login-settings.lua`: encrypted credential ordering, malformed
  responses, closed services, cancellation/timeouts/late callbacks and existing
  login settings behavior. Both passed using the actual client Lua implementation.
* Retail native archive checks accepted the matching package and rejected both the
  previous archive and a tampered account protocol. 35 focused decoded resources
  matched source/bytecode, with 1,450 total manifest entries and 367 CRC entries.
  1,843 runtime/native source files matched the current feature commit locally.
* `live-services-result.json`, `live-compatibility.json`: real DEV registration
  required email, refused wrong-password creation and created an ordinary character.
  Normal login returned it. Old/missing/QA-mode client proofs were refused and the
  current retail proof logged in and out successfully. Only read-only catalog calls
  followed login. The temporary ordinary account/player were verified and removed.
* `final-readback.json`, `profile-final.json`: deployment/runtime/publication match;
  production unchanged; all four original profile byte/path/owner/DACL fingerprints
  restored and no owned client remains running. Disposable credentials were removed.

Actual updater HTTP 10101 -> 10102, native binary promotion/restart, correct final
EXE/archive and self-deletion passed. The combined updater harness retained a failed
GUI-phase timeout: window capture returned a white content area and the user was
away. That failure is not relabeled as a full GUI pass. An independent protected
retail-mode diagnostic copy, with only a read-only framebuffer snapshot/timed exit
added to `main.cpp`, rendered the exact distributed archive normally and showed
Rookhaven Client 10102. The diagnostic was not published; original build/source
bytes were restored. See `retail-normal-render/retail-internal-frame.png`.

The first four-profile updater attempt stopped before native startup because a
profile's fingerprint changed in its backup location. A harmless inverse-move
probe reproduced this; moving the untouched original back restored the exact
saved fingerprint. The retry moved only retail profiles; QA profiles were checked
read-only before/after. Original failed receipts and recovery evidence are retained.
Package verification also caught a truncated build-command endpoint; quoting and
rebuilding corrected it before publication. The initial retained cold database
had lost its InnoDB system files, so native tests use a fresh owned database from
the retained SQL seed. These setup failures did not modify live player data.

## Security boundary and remaining cases

[The targeted security review](account-services.md#production-security-work-remains)
confirmed inherited unsalted SHA1 and the publicly shipped default RSA private key.
These upgrades have not been made in this release. DEV10102 is not a claim of
production-ready authentication; use disposable test credentials until corrected.
Email verification/recovery is also not implemented.

No full repository security audit or full passive gameplay suite was run. Deliberate
database power loss/unknown-COMMIT fault injection was not performed for this service;
statement failures and a lost creation reply were exercised. Native GUI account/game
login against live DEV was not performed; full native GUI flow ran locally, with
real DEV wire creation/login and the independent retail render check above.
An unchanged quest-log shutdown hook logged a missing fallback settings directory
when closing a completely fresh profile before entering the game; no quest progress
existed in that diagnostic profile. It is not counted as a newly fixed behavior.
