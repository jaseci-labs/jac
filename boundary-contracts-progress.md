# Shared boundary contracts implementation

Jac will retain boundary contracts across compilation and deployment, use them for typed crossings and runtime dependency decisions, and migrate jaclang_org to those mechanisms. Superseded implementations will be removed rather than retained as compatibility paths.

| Status | Scope item | Completion requirement |
| --- | --- | --- |
| Pending | Typed Wasm exports and generated calls | Native declarations drive ordinary typed imports and generated invocation. |
| Pending | Value conversions and opaque handles | Runtime adapters preserve declared values and manage native handles without application integer casts. |
| Pending | Checked host-import interfaces | Required host signatures check implementations and drive registration. |
| Pending | Module loading and host registration | Shared runtime owns instantiation, readiness, registration, and cleanup. |
| Pending | Precise CLI and authentication boundary types | Consumers use declared records instead of dynamic field reconstruction. |
| Pending | External API contracts and response validation | Declared external shapes drive clients and validate responses. |
| Pending | Conservative effect analysis | Separate read/write dependencies and explicit unknown effects compose through calls. |
| Pending | Wildcard dependency matching | Reader and writer wildcards conservatively overlap. |
| Pending | Concurrent cache operations | Writes prevent older reads from being cached or reused as fresh results. |
| Pending | Qualified endpoint identities | App/module/declaration identities survive generation, routing, and cache metadata. |
| Pending | Reusable WebGL graphics adapter | Browser graphics implementation lives behind the shared host contract. |
| Pending | Application migration and removal of scaffolding | jaclang_org consumes the shared mechanisms; redundant paths are removed. |
| Pending | Boundary audit | Compiler exposes contracts, placement, effects, and unchecked assumptions. |

## Acceptance validation

Run jaclang_org using the development compiler and exercise it with `jac browse`, including native game rendering/input/lifecycle and relevant application interactions. This is the sole requested acceptance validation; no regression-suite requirement is added. Record observed behavior and any remaining limitations here and in the PR.

## Progress

- Created implementation branch and recorded full scope before implementation.
