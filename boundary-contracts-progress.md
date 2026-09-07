# Shared boundary contracts implementation

Jac will retain boundary contracts across compilation and deployment, use them for typed crossings and runtime dependency decisions, and migrate jaclang_org to those mechanisms. Superseded implementations will be removed rather than retained as compatibility paths.

| Status | Scope item | Completion requirement |
| --- | --- | --- |
| Implemented; integration pending | Typed Wasm exports and generated calls | Native declarations drive ordinary typed imports and generated invocation. |
| Implemented; integration pending | Value conversions and opaque handles | Runtime adapters preserve declared values and manage native handles without application integer casts. |
| Implemented; integration pending | Checked host-import interfaces | Required host signatures check implementations and drive registration. |
| Implemented; integration pending | Module loading and host registration | Shared runtime owns instantiation, readiness, registration, and cleanup. |
| Implemented; integration pending | Precise CLI and authentication boundary types | Consumers use declared records instead of dynamic field reconstruction. |
| Implemented; integration pending | External API contracts and response validation | Declared external shapes drive clients and validate responses. |
| Implemented; integration pending | Conservative effect analysis | Separate read/write dependencies and explicit unknown effects compose through calls. |
| Implemented; browser validation pending | Wildcard dependency matching | Reader and writer wildcards conservatively overlap. |
| Implemented; browser validation pending | Concurrent cache operations | Writes prevent older reads from being cached or reused as fresh results. |
| Implemented; integration pending | Qualified endpoint identities | App/module/declaration identities survive generation, routing, and cache metadata. |
| Implemented; integration pending | Reusable WebGL graphics adapter | Browser graphics implementation lives behind the shared host contract. |
| Implemented; integration pending | Application migration and removal of scaffolding | jaclang_org consumes the shared mechanisms; redundant paths are removed. |
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

- Native signatures and host requirements are retained in InteropManifest and persisted in the compiler cache. The cache format is bumped for the clean break.
- Generated endpoint calls carry qualified identities; HTTP handlers verify that a supplied identity names the actual routed declaration.
- Explicit opaque-operation effect declarations are recorded as audit assumptions rather than silently inferred purity.

- Preserved existing boundary finalization while adding endpoint IDs. Service walker writes now fence caches on completion and failure. Native calls reject conflicting aliases before ownership transfer, and borrowed handles track parent/module lifetimes.
- Audit records merge callers and include native host requirements. Explicit effects apply to public endpoint declarations as well as transitive calls.
- Browser session is prepared; the development compiler is rebuilding before application acceptance checks.

- Application startup exposed native `import type` declarations being pulled into client placement. The solver now excludes type-only imports from execution placement; rebuilding the app with that fix.
- Game HUD reads preserve declared types and check session lifetime after each await. Native argument adapters reject inexact or out-of-range integers.

- Resolved the native placement import failure, an AST unparse API mismatch, and a bootstrap import cycle. Client bundle diagnostics now include the self-hosting compiler program's errors.
- Corrected signup JSON narrowing/status conversion and Wasm host object typing. The five shared client runtime modules produce compiler artifacts in diagnostic runs; application/browser acceptance remains pending.
- Host registration now resolves `ClassType` scopes (including bases), replacing an empty legacy scope shortcut; rebuilding the app to validate this correction.

- Browser acceptance in development mode: home and source explorer render; arena renders at about 60 fps with updating health/deaths; navigation to JacYac succeeds without application console errors.
- A local browser account completed signup, automatic login, post creation, post deletion, and logout. Feed and hashtag counts updated after both mutations; the validation post was removed.
- The GitHub project flow fetched a public repository and commit through the typed contracts and correctly rejected the repository for containing no Jac code. The docs page loaded its 105-page navigation.
- Production build and emitted audit verification are in progress. Browser observations do not claim exhaustive cache-race, ABI, or external OAuth coverage.
