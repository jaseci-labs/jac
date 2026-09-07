# Shared boundary contracts implementation

Jac will retain boundary contracts across compilation and deployment, use them for typed crossings and runtime dependency decisions, and migrate jaclang_org to those mechanisms. Superseded implementations will be removed rather than retained as compatibility paths.

| Status | Scope item | Completion requirement |
| --- | --- | --- |
| Implemented; integration pending | Typed Wasm exports and generated calls | Native declarations drive ordinary typed imports and generated invocation. |
| Implemented; integration pending | Value conversions and opaque handles | Runtime adapters preserve declared values and manage native handles without application integer casts. |
| Implemented; integration pending | Checked host-import interfaces | Required host signatures check implementations and drive registration. |
| Implemented; integration pending | Module loading and host registration | Shared runtime owns instantiation, readiness, registration, and cleanup. |
| In progress | Precise CLI and authentication boundary types | Consumers use declared records instead of dynamic field reconstruction. |
| Implemented; integration pending | External API contracts and response validation | Declared external shapes drive clients and validate responses. |
| In progress | Conservative effect analysis | Separate read/write dependencies and explicit unknown effects compose through calls. |
| Implemented; browser validation pending | Wildcard dependency matching | Reader and writer wildcards conservatively overlap. |
| Implemented; browser validation pending | Concurrent cache operations | Writes prevent older reads from being cached or reused as fresh results. |
| In progress | Qualified endpoint identities | App/module/declaration identities survive generation, routing, and cache metadata. |
| Implemented; integration pending | Reusable WebGL graphics adapter | Browser graphics implementation lives behind the shared host contract. |
| In progress | Application migration and removal of scaffolding | jaclang_org consumes the shared mechanisms; redundant paths are removed. |
| Implemented; integration pending | Boundary audit | Compiler exposes contracts, placement, effects, and unchecked assumptions. |

## Acceptance validation

Run jaclang_org using the development compiler and exercise it with `jac browse`, including native game rendering/input/lifecycle and relevant application interactions. This is the sole requested acceptance validation; no regression-suite requirement is added. Record observed behavior and any remaining limitations here and in the PR.

## Progress

- Created implementation branch and recorded full scope before implementation.

- Cache invalidation now advances endpoint generations, fences writes before and after completion (including ambiguous failures), separates pending reads by generation, and clears pending authentication-context reads. Wildcard overlap is symmetric.

- Native bindings now carry generated scalar/ownership contracts; the game uses ordinary native imports and the shared WebGL adapter.
- Browser and React/mobile caches share one implementation. Effect summaries distinguish reads, writes, and unknown calls, and use qualified identities.
- Signup now returns a declared record; GitHub endpoints use declared response shapes and strict decoding; CLI consumers use typed fields.
- Client bundles emit a boundary audit. Integration is pending: the first running-app build exposed a Wasm client compilation failure.

- Host registration now checks typed host methods against native declarations and generates method bindings; removed the old `set_na_env` API and manual WebGL ABI dictionary.
- Service walker responses retain declared report conversions. Authentication and optional service caching also fence stale reads.
- Debugged a bootstrap-parser stall caused by an extra closing brace introduced during integration; corrected the source before restarting the app.
