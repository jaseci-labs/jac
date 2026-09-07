# Shared boundary contracts implementation

Jac will retain boundary contracts across compilation and deployment, use them for typed crossings and runtime dependency decisions, and migrate jaclang_org to those mechanisms. Superseded implementations will be removed rather than retained as compatibility paths.

| Status | Scope item | Completion requirement |
| --- | --- | --- |
| Implemented | Typed Wasm exports and generated calls | Native declarations drive ordinary typed imports and generated invocation. |
| Implemented | Value conversions and opaque handles | Runtime adapters preserve declared values and manage native handles without application integer casts. |
| Implemented | Checked host-import interfaces | Required host signatures check implementations and drive registration. |
| Implemented | Module loading and host registration | Shared runtime owns instantiation, readiness, registration, and cleanup. |
| Implemented | Precise CLI and authentication boundary types | Consumers use declared records instead of dynamic field reconstruction. |
| Implemented | External API contracts and response validation | Declared external shapes drive clients and validate responses. |
| Implemented | Conservative effect analysis | Separate read/write dependencies and explicit unknown effects compose through calls. |
| Implemented | Wildcard dependency matching | Reader and writer wildcards conservatively overlap. |
| Implemented | Concurrent cache operations | Writes prevent older reads from being cached or reused as fresh results. |
| Implemented | Qualified endpoint identities | App/module/declaration identities survive generation, routing, and cache metadata. |
| Implemented | Reusable WebGL graphics adapter | Browser graphics implementation lives behind the shared host contract. |
| Implemented | Application migration and removal of scaffolding | jaclang_org consumes the shared mechanisms; redundant paths are removed. |
| Implemented; verification waived | Boundary audit | Compiler exposes contracts, placement, effects, and unchecked assumptions. |

## Acceptance validation

Validated jaclang_org with `jac browse` in development mode: home and source explorer rendering, native arena rendering with updating health/death counters, navigation to JacYac, local signup and automatic login, post creation/deletion with feed and trending updates, logout, and docs navigation. The validation post was deleted. The GitHub project flow decoded public repository and commit responses and correctly rejected a repository containing no Jac code. No application console errors were observed in these flows.

The production bundle also served the home page successfully before the final audit-retention change. That change retains interop records in serialized client artifacts after syntax-tree eviction; its final production/audit verification was explicitly waived by the user. The latest rebuild was still running when that check was waived. No benchmarks or regression suites were run, as requested. Browser validation does not establish exhaustive cache-race, ABI, or external OAuth coverage.

## Implementation notes

- Native declarations generate scalar/ownership contracts and host registration. The shared WebGL adapter replaces application-owned ABI wiring; the old `set_na_env` API is removed.
- Endpoint identities survive generated calls, routing, cache metadata, and compiler artifacts. Browser/React caches share invalidation and concurrent-read handling. Unknown effects disable caching; declared effects remain visible assumptions.
- Signup and CLI consumers use declared records. External GitHub responses use typed contracts with response validation.
- Client artifact format 3 and compiler cache format 25 replace their predecessors. Boundary metadata is retained in artifacts and collected into the production audit.

All implementation items are committed. The audit verification waiver is a validation limitation, not a claim that the final audit output was checked.
