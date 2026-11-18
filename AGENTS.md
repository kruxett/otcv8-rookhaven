# Working agreements

For substantial gameplay or client/server system changes, identify existing
systems affected by the diff and verify their behavior as well as the new feature.
Use targeted regressions based on concrete dependencies; report what was actually
run, what failed/fixed, and material cases left untested. Feature screenshots and
successful compilation do not replace existing-system regression checks.

Shared development/test-selection workflow: docs/development-testing.md.
Read docs/passives-regressions.md only for passive changes or a traced shared
dependency. Select affected probes; the complete passive suite is not a default
gate for a build, new item or DEV release.
Keep the user's retro layout requirement for client work.

## Rookhaven project

This is the primary folder of the shared Rookhaven project. Work across its
three separate Git repositories as needed:

- Client: this repository, `otcv8-rookhaven`.
- Game server: `../Rookhaven` (`Windsmoore/Rookhaven`).
- Website and web API: `../RookhavenWeb` (`CroneFacade/RookhavenWeb`).

Read [the project map](docs/rookhaven-project.md) and the affected repository's
own `AGENTS.md` before cross-repository changes. Check status, branch and remote
in each affected checkout; keep commits and releases scoped to each repository.
Trace shared account, character, guild and database contracts across the web API
and game server rather than assuming their implementations are compatible.
