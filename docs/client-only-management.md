# Client-only player management

Marcus's direction, 2026-11-16: accounts, characters, guild actions and house
transactions belong in the native client. The website remains public information,
client download, news, rankings and public character/guild/house information.
Rookhaven Coins are eventually bought on the website; this is distinct from
spending Coins in the existing in-client item shop.

## Delivery order and current status

1. **Implemented and locally verified, unpublished:** account/character parity with the old website. Native account
   overview, password change, character deletion, authenticator setup/removal and
   recovery codes use the selected game server's encrypted account service.
   Verify ordinary login/game login, creation, reconnect and refusal/transaction
   cases, as well as the real retro UI. Guild parity now includes leader rename and invitation withdrawal. The native
   MOTD is the existing public guild description; it is not a second text field.
2. **Implemented and locally verified, unpublished:** native house purchases,
   proxy/owner auctions, private offers, gifts/transfers, leaving/cancellation and
   native access lists through the existing Cyclopedia Houses tab, original
   house cards and seven original form panels. The abandoned replacement
   browser was removed. See
   [housing integration](housing-client-integration.md) for persistence and tests.
3. **Prepared and disabled:** website Coins page and server-owned catalogue,
   with no checkout/payment route. Payment provider,
   currency/prices and verified delivery/refund rules still need decisions.
   No live charges, payment account setup or PROD release are part of current work.

Website management routes/UI must be retired as their client replacements are
verified. Do not leave a second active account-management implementation using
the website's old SHA1-only password service.

The staged website cutover now removes management HTTP mappings and browser
login, preserves public read routes and removes its automatic schema/auction
writers. API boundary and browser checks pass; it is not published. See the web
repository's `CLIENT-ONLY-MANAGEMENT.md` for evidence and inherited test gaps.

## Email decision

Marcus explicitly deferred actual password recovery and email service setup.
Prepare code and environment settings; keep both features disabled by default:

```lua
clientAccountManagementEnabled = true
clientTwoFactorEnabled = true
clientEmailVerificationEnabled = false
clientPasswordRecoveryEnabled = false
clientAccountMailOutbox = "" -- environment-owned private absolute directory
```

The master `clientAccountServicesEnabled` remains required. The two-factor flag
controls new setup, never bypasses protection on an already protected account.
Email flags are advertised only with a configured existing outbox. The client
keeps email recovery and verification actions unavailable until the matching
capabilities are advertised. The future mail sender requires separate protected
SMTP settings; no operator credentials are embedded in the client or source.

## Native account contract

- Existing service 0x03/RHA1 creation remains supported. RHA2 adds bounded
  management requests and typed JSON response data inside the RSA/XTEA transport.
- Password verification/hashing stays on the existing bounded authentication
  pool. Mutations recheck account/hash/factor under the database transaction lock.
- Ordinary character-list and world login carry an optional MFA1 authenticator
  extension. A nonempty native account secret requires a current TOTP code.
- New authenticator setup uses a pending 160-bit key and a possession check.
  Ten 64-bit recovery codes are shown once; only their SHA256 hashes are stored.
  Lost-authenticator recovery is an explicit password-plus-recovery-code action
  that disables the old authenticator and invalidates all old codes. Recovery
  codes do not become reusable game-login passwords.
- Deletion requires the current password, the exact owned character name and
  server-side checks. It uses the existing soft-deletion field and excludes the
  character from ordinary login; later startup performs permanent cleanup.
- The account window uses existing OTUI widgets and palette. Account, Characters
  and Security tabs separate views from sensitive forms, with explicit feedback,
  cancel/back, disabled duplicate submission and generation guards for late replies.

Schema migration 35→36 adds the native security, recovery-code and mail-token
tables and widens the existing authenticator secret column. It must be tested
against a cold, isolated database before any DEV release.

## Verification evidence

Working artifacts are under ignored `out/account-management-20261116/`.
The first native Release QA engine is compiled in isolated
`C:/CodexAccountManagement-20261116` on the existing Windows build host. This
does not change the playable server, its supervisor, or the updater.

The initial native integration run passed 89 account/creation/management checks.
The expanded run passed all 61 checks (`native-management-04`), including real RH2 world-login MFA, online/Personal Store
deletion refusal, pending house commitments, feature switches and opted-in mail
queue/token behavior. No mail was sent. The old minimal
pending-transfer fixture exposed a missing sender-column compatibility case;
the guard now checks the optional column before querying it.

Native UI run `ui-04` passed registration, character creation with the selected
outfit, account tabs, delete confirmation refusal, authenticator activation and
recovery-code acknowledgement, password change, normal MFA login/world login,
starter-item preservation, Guildmaster guild creation and reconnect/legacy hash
upgrade, plus lost-authenticator recovery from the login screen. Native
screenshots at 800×640 and 1280×800 were visually inspected.
The owned QA profile and source database/config were preserved. Protocol and
settings Lua regressions pass, including malformed RHA2 capability/data replies.
No account-management release has been published; playable DEV is unchanged.

## Prepared email worker (disabled)

Server `tools/account-mail-sender.py` and `tools/account-mail.env.example` are the
future SMTP connection point. Both native email flags and
`ROOKHAVEN_ACCOUNT_MAIL_ENABLED` default off. The worker uses verified TLS
(STARTTLS or implicit TLS), generic logs and the environment's SMTP credentials.
Four isolated worker tests pass using fake delivery; no SMTP connection or real
email has been sent.

For future activation, provision one private outbox directory accessible only by
the native server and worker, configure the same absolute path on both, configure
SMTP settings outside source, then run the worker and enable the relevant native
flags. The queue contains one-use codes and needs the same private ACL/backup
treatment as credentials. `.pending` jobs have not been published by a native
transaction; only `.json` jobs are sent. A crash can leave a `.sending` job for
operator inspection before retrying (SMTP delivery may already have happened).
Expired/invalid jobs become `.rejected`; remove these and old orphaned pending
files under the operator's retention policy. A database commit followed by a
filesystem failure can require requesting another code after the cooldown.

## Release boundary

No commit, push, DEV server/website restart or updater package was produced by
this implementation work. Before a coordinated DEV release, stop the old website
auction/schema writers, migrate and verify the native server, publish matching
protected client resources/RH2 pins, then resume the public website with SELECT-
only credentials. Never leave old web house writers running alongside the native
market. Follow the normal release/package checks when publication is requested.
