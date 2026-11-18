# DEV10105: account, guild and house management

Published and live-verified on DEV, 2026-11-18. Website changes are not deployed
by this release. PROD client files and manifest settings were preserved.

## Published behavior

- Native account overview, character deletion, password change, authenticator
  setup and recovery codes; existing registration/character creation retained.
- Guild leader rename and invitation withdrawal, using existing guild permissions.
- Native house market using the existing Cyclopedia tab, original cards and seven
  original panels: bids/proxies, purchases, offers, transfers/gifts, cancellation,
  leaving and native access lists. No replacement house-browser window remains.
- Real map captures for all 57 houses in the existing preview frame. Riverside's
  22 houses use town 4; Rookhaven has 26, Stillshore 9, and Gravefall none.
- DEV enables account management, new authenticator setup and native housing.
  Email verification, email password recovery and mail outbox remain disabled.
  No SMTP or real-money Coins checkout was activated.

## Release identity

- Client runtime source: `f8cfc5f46e58c068f31a93c117abc6c374a4def8`.
- Server feature source: `770dfc317d506b9dd6bcf0ddb3859f9f3204dc40`.
- Deployed server source, including final client pins:
  `764c1ed2b2f85c794c9024daa86e66c3d23e3fde`.
- Client EXE SHA256:
  `649dea793838e63430a925a3542ba2b95767e8052fa7d09e961fa1bb2c2130a8`.
- Client data.zip SHA256:
  `2d4a9bd41ab5755c2b2dcccbf3da892c62f5eb99c9f393ea7647b08e23f7197c`.
- RH2 resource fingerprint:
  `d1cfb164cfeeabca8ca05e2bf30d2970b5110560fa61bc75f1ccf80fc48c0d1a`.
- Production-mode server EXE SHA256:
  `73601d5dcdeb9cde0a11ac4f32e71f4b4bec7b6ac46f6252245a222c8de69b7e`.

The persistent deployment job `23107a86-6992-49c9-a604-297cadcdea6f` completed
SUCCEEDED. It used the normal 60-second countdown, matching shutdown persistence
receipt/zero exit, private database and release backups, a fresh MSBuild release
build (zero errors), six-artifact client publication, and a stable new server
with both expected listeners. Database migrations advanced 35 to 37. The engine
and supervisor were not modified. Runtime config changes were limited to the
native feature flags above; its original bytes have a separate private checkpoint.

## Actual verification

- Final protected client passes native archive verification. 709 resource/source
  comparisons pass, including native account, guild, Cyclopedia and all photos.
  The validation-only QA server binary supplied to the offline exporter was not
  published; the deployment worker built the actual server above independently.
- The earlier local account, persistence/fault, proxy/refund, rent, guild, original
  panels, city-filter and photo checks remain supporting evidence for unchanged
  code. All 28 changed native source files match the earlier tested source.
  They are not represented as fresh live runs.
- Real public updater transition DEV10104 to DEV10105 passes, including actual
  HTTP downloads of EXE and archive, native promotion/restart, final hashes and
  bounded temporary-executable cleanup. Windows inspection shows the native
  login window and visible version 10105. No injected scripts or authentication
  automation were used in that GUI session.
- Fifteen native live protocol checks pass: capabilities with deferred mail off,
  owned QA account/character creation, account overview, normal character list,
  old release proof rejection, matching new world login, all four town filters
  and pagination, logout, native character deletion and empty login list afterward.
  The one temporary character was removed; its empty QA account is retained with
  owner-only diagnostic credentials. No existing player's property was modified.
- PROD release files compare unchanged. Final DEV source/binary, RH2 pin,
  configuration, schema 37, startup/readiness and listeners were read back.

Two test-harness errors were corrected without changing the published application:
copying LuaJIT's jit modules enabled local bytecode verification; a same-volume
profile move changed the root inherited DACL, so the prelaunch guard stopped
before any client started. The exact original profile was returned and matched
its original fingerprint. Matching the private test parent ACLs to the original
profile parent then passed a roundtrip and the real updater test. The protocol
smoke's first attempt also used QA mode 1; it was corrected to retail mode 0 and
resumed only its already-created owned actor. All original profile file bytes,
owners/DACLs and original absences match after final cleanup.

Evidence is under ignored `out/management-housing-dev-20261118/`, with the updater
receipt under `out/release-smoke-20261027/native-updater-10104-to-10105-20261118-retry1/`.
Remote rollback data is under the existing deployment backup root for the job;
actual database/config backups remain private on the DEV host.

Live financial house mutations and manual in-world GUI interactions were not
performed. Their functional evidence is the earlier isolated native tests; live
house coverage here is read-only. No broad combat/passive suite was selected.
