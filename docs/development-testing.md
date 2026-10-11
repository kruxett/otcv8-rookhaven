# Rookhaven development and test selection

This is the shared test-selection policy for client and server work. Select
tests from the current change and its actual dependencies. The passive system
is one subsystem; its complete suite is not a default gate for Rookhaven work.

## From change to verification

1. Establish the intended behavior and acceptance criteria. Inspect the diff,
   relevant callers, data consumers and client/server contract. Identify which
   existing behaviors could change, including failure paths and persistence
   when they are involved.
2. Implement the smallest coherent change. For a bug fix, add or adapt a focused
   regression that fails for the old behavior when this is useful and practical.
   Reuse existing tests; avoid new tests that only restate implementation or
   add no evidence for a text/documentation edit.
3. Select checks at the lowest level that can establish the behavior. Use unit
   or contract checks for isolated rules, integration/native checks for actual
   engine, transaction or protocol behavior, and a native UI check for the
   changed view. Build only targets whose sources or dependencies changed.
4. Run the new/changed behavior and focused regressions for affected existing
   consumers. For a substantial change, state the short connection:
   **changed behavior → affected existing path → selected check**. A few lines
   in the working update suffice; a separate test-plan artifact is optional.
5. If publishing, verify the package and deployment separately from gameplay.
   Report actual checks, failures/resolutions and material untested cases.

A shared filename, C++ rebuild, new item ID, local runtime named `passives`, or
release tool under `tools/passives/` is not evidence that all passive behavior
changed. Trace the modified function/data and its consumers instead.

## Match scope to impact

| Change | Usual verification | Widen when |
| --- | --- | --- |
| Documentation or static player text | Content, references and formatting; affected native view for player text | A dynamic value, parser, input or behavior also changes |
| Sprite-only replacement | Lossless import, SID/CID/sprite mapping, unchanged unrelated records/flags and native rendering | Definitions, animation handling or item behavior also changes |
| Shop price/catalog data | Correct offer, price and icon; existing purchase validation as relevant to the data | Debit, grant, currency or history transaction code changes |
| Isolated item/spell/quest logic | Success, relevant refusal/boundary cases, costs/state and real use path | A shared hook or service changes behavior for existing consumers |
| Shared combat, container, persistence or protocol code | Focused rule tests plus integration cases for affected existing consumers | A common invariant or broad contract affects many consumers and cannot be bounded safely |
| UI behavior | Changed interactions, ordering/state, reopen/refresh where relevant and small supported retro layout | Shared widgets, transport or state model changes other views |
| Build/package/deployment | Changed artifact/source equality, checksums/version, compatibility, updater/startup and runtime readback as relevant | Build tooling, compatibility, migration or restart behavior changes |

Cover meaningful failures: for example, a rejected craft must preserve donor,
materials and payment; a refused spell must not charge or apply an effect.
Persistence, reconnect, death, PvP and all classes are conditional test cases,
not mandatory steps for every feature. Choose them when the changed path can
affect their behavior.

Use a broader subsystem suite when common subsystem behavior changes across
many consumers, a focused scope cannot establish the shared invariant, or the
user explicitly requests that suite. Give the concrete reason before running
it. A request to test a feature thoroughly means its behavior and dependencies;
it does not automatically select every existing subsystem suite. Full-project
runs belong to an explicit release/cross-system test scope, or a demonstrated
cross-system change, rather than every patch.

## When passive tests apply

Read [passives-regressions.md](passives-regressions.md) only when the change
directly affects passive behavior or a traced shared path it consumes. Choose
the relevant probes; the complete five-gate runner has a broader scope than
an individual probe.

Examples:

- **Tooltip wording or sprite-only import:** verify text/rendering and asset
  integrity. No passive combat, lifecycle or all-tree checks.
- **Shared ammunition resolution:** verify ordinary ammo plus affected weapon
  and Marksman spell/stat consumers. Other talent trees, class choice and
  passive lifecycle do not follow merely from this dependency.
- **Legendary ward or healing hook:** verify the affected normal damage/healing
  path and the actual interacting ward/passive, such as Aegis. Include
  mana-shield behavior where the changed hook participates in its resolution.
  Shared absorption does not by itself require all-tree allocation/UI tests.
- **Common maxHP calculation or disconnect cleanup:** verify ordinary behavior
  and affected passive HP composition/cleanup. Include save/reconnect, death or
  store logout only where those paths consume the changed code. Broader
  lifecycle coverage can be justified without testing unrelated tree UI.
- **Passive Apply/Respec ledger:** verify permissions, validation, revision,
  transaction atomicity, saved ranks and relevant reconnect behavior. All-tree
  contract checks apply when shared allocation/catalog rules change.

The existing loopback runtime and probe helpers can support other systems.
Reuse the environment without inheriting every test that historically used it.
Inspect each helper's fixture assumptions and side effects before execution.

## Package checks and release smoke

Package/source equality and preserved checksum paths remain required for the
artifacts being released, even when they include unchanged passive resources.
These are artifact-integrity checks, not fresh gameplay regression tests.
Likewise, a matching hash or successful compilation does not prove gameplay.

For a new client release, verify the real updater path to the new package and
its compatibility with the server. For a server deployment, verify the intended
source/binary, startup, listeners, stable runtime and relevant config. Exercise
the changed live path on a designated QA character when that test is in scope
and available; otherwise report the gap. Release smoke does not require a full
combat, passive or quest suite merely because a package was published.

## Evidence and stopping point

Keep source/build/package identities tied to the checks. Previous results can
support unchanged behavior when their relevant code, data, contract and artifact
identity still apply. Changed shared logic invalidates evidence for its affected
consumers. Label reused evidence explicitly rather than claiming a fresh run.

Stop when selected acceptance and regression checks pass and the identified
risks are resolved. Add or rerun tests only after another relevant change, a
failure or a concrete unresolved dependency. Do not broaden testing just because
another runner exists. Natural farm times, drop/proc frequency and player feel
need separate playtesting/telemetry when balance is in scope.

Use owned fixtures and profiles, serialize helpers that share state, and preserve
unrelated player/config/profile data. On failure, retain evidence and establish
whether product code or the test setup is wrong before repairing and rerunning
the affected checks. Never weaken gameplay rules to make a test pass.
