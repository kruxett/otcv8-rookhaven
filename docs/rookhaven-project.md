# Rookhaven: client, game server and website

The local Rookhaven project includes three sibling checkouts under
`C:/GitRepos/kruxett`. The client remains the primary project folder; the game
server and website are additional project folders. They retain independent Git
repositories, branches, commits and releases.

| Component | Local folder | GitHub repository |
| --- | --- | --- |
| OTCv8 client | `C:/GitRepos/kruxett/otcv8-rookhaven` | [kruxett/otcv8-rookhaven](https://github.com/kruxett/otcv8-rookhaven) |
| TFS game server | `C:/GitRepos/kruxett/Rookhaven` | [Windsmoore/Rookhaven](https://github.com/Windsmoore/Rookhaven) |
| Website and web API | `C:/GitRepos/kruxett/RookhavenWeb` | [CroneFacade/RookhavenWeb](https://github.com/CroneFacade/RookhavenWeb) |

Paths describe this workstation. Discover the actual roots on other hosts.
Read each affected checkout's `AGENTS.md` and current Git status before editing.
Do not assume the three repositories use the same default or development branch.

## Where to start

| Area | Client / game server | Website |
| --- | --- | --- |
| Player interface | Client `modules/`, `layouts/retro/`, `data/` | `frontend/src/`, existing components and styles |
| Accounts and characters | Client `modules/client_entergame/`, `modules/gamelib/protocolaccounts.lua`; game server `src/accountservices.cpp`, `src/authentication.cpp`, `src/passwordhash.cpp` | `RookHavenWeb.Server/Endpoints/`, `Services/Account/`, `Services/Authentication/`, `Security/Hashing/PasswordHasher.cs`; frontend `src/services/api/` |
| Guilds | Client `modules/game_guild/`; game server `data/lib/guild_system.lua` and Guildmaster NPCs | `RookHavenWeb.Server/Endpoints/GuildEndpoints.cs` and its services |
| Database | Game server `schema.sql`, `data/migrations/`, private runtime `config.lua` | `RookHavenWeb.Server/Data/`, `schema.sql`, application configuration and `README-Database.md` |
| Local web orchestration | Separate from native client/server QA | `RookHavenWeb.AppHost/`, `docker-compose.dev.yml`, `scripts/` |

## Shared contracts

The native client's account/character creation talks to the selected game
server's login service. Database access stays on the server. The website has a
separate .NET API and database access; adding its checkout does not route the
native client through that API.

Changes to account creation, login, password changes/recovery, characters,
guilds, currency or shared tables need the relevant readers and writers checked
in both servers. Use the game server's actual progression, permissions and data
formats when checking website behavior.

### Imported website compatibility

At import on 2026-11-16, the website is .NET 10 with a React/TypeScript/Vite
frontend. Its account password service supports SHA1 only. The native game
server now uses versioned scrypt hashes, with legacy SHA1 migration after a
successful login. Website authentication against upgraded game accounts therefore
needs compatibility work before use with the current game database.

The website's `Data/DatabaseInitializer.cs` runs in Development and can execute
schema changes and the bundled SQL. That SQL seeds `db_version=29`; the current
native game server requires version 38. Treat the website SQL as an older local
fixture until its schema and web-specific additions have been reconciled with
native migrations. Connecting the unreviewed development initializer to live
DEV/PROD is not part of adding this repository.

## Environment configuration

- Native server: private `config.lua` supplies the environment's database,
  account-service flags and private RSA key. See [account services](account-services.md).
- Native client: the build selects server address, updater channel and matching
  public RSA key; no database credentials belong in the client.
- Web API: ASP.NET configuration selects its environment. Database configuration
  uses `ConnectionStrings:TibiaDatabase` (with `DefaultConnection` fallback in
  `Program.cs`); the normal environment-variable name is
  `ConnectionStrings__TibiaDatabase`. Inspect the initializer's separate config
  lookup before relying on a fallback. Keep actual connection strings/JWT keys
  outside committed source and frontend assets.
- Web frontend: inspect `frontend/src/services/api/client.ts` and Vite
  configuration before selecting the environment's API address.

## Verification and releases

Use [development-testing.md](development-testing.md). Inspect web test fixtures
before running database integration tests; use an isolated database. Existing
entry points are `npm run lint` / `npm run build` from `frontend/`, and the two
`RookHavenWeb.Server.Tests.*` projects with `dotnet test`. These are entry points,
not a claim that a test or local web runtime has been run during repository setup.

Commit and deploy the affected components separately, with compatible contracts
and environment settings. A website-only content edit does not require rebuilding
the native client. Changes to shared accounts or tables need cross-component
verification. Existing DEV authorization does not authorize a PROD deployment.

## Client-only cutover, 2026-11-17

Native account/character management and housing/guild parity are live on
DEV10105 as of 2026-11-18. See the
[release record](dev10105-management-housing-release.md). The website's staged
source removes player-authentication/mutation routes and automatic schema/auction
writers; that website cutover has not been deployed. Use SELECT-only website
database credentials when publishing it.
Read [client-only management](client-only-management.md) and
[housing integration](housing-client-integration.md) for current flags and evidence.
Coins catalogue/page preparation remains disabled; it does not activate payments.
The native client/server are published on DEV; the website changes remain unpublished.
