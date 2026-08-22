# PR Review -- Round 6 (branch `bun-sv-services`)

Resolution of the round-5 external review findings. All fixes verified with
`jac check` (clean or equal to pre-existing baseline); new/changed tests run
under real bun + embedded Postgres.

| # | Finding | Disposition |
|---|---|---|
| A1 | Walker HTTP surface ships before it works | **Resolved -- premise stale**: descriptor wiring (`__jacOspDesc`/`__jacOspRT`/osp kernel) already survives Bun.build for `:pub` walkers; verified end-to-end with a real artifact (POST /walker/<name> returns reports and persists NodeAnchors through BunStore). The 500 came from running without PG env wired. Added the missing walker-route e2e: `tests/runtimelib/test_bun_walker_e2e.jac` (bundle greps for descriptor wiring + HTTP dispatch + Postgres persistence). Release-note claim stands. |
| A2 | String-bundler fallback silently mangles unexpected import lines | **Fixed**: `_rewrite_entry_line` raises RuntimeError naming the offending line/source instead of dropping it; unit tests in `tests/runtimelib/test_bun_string_bundler.jac` exercise the fallback directly (well-formed rewrite + three malformed shapes raise). |
| B1 | Repeated inline pub check | **Fixed**: `_is_pub(access)` helper in bun_service_builder.jac. |
| B2 | Novel module docstrings | **Fixed**: converted to `#` comments (sv_dispatch.jac, test_sv_host.jac). |
| B4 | Registry shims accreting callers | **Fixed**: deprecation note on get_target_registry/get_target_factory pointing at get_host_registry/get_host_factory. |
| C1 | `'webview'` literal vs HOST_WEBVIEW | **Fixed**: constant used in HOST_CAPABILITIES. |
| C2 | Spawn boilerplate duplicated across hosts | **Deferred** (review says "next pass"): shared `spawn_sibling_process` helper -- tracked below. |
| C3 | Duplicate `import shutil` | **Fixed**: hoisted to module top of bun_service_builder.jac. |
| D1 | Stringly-typed host kinds/capabilities | **Deferred as tracked debt** (pre-existing pattern; review accepts deferral but wants it tracked): HostKind StrEnum follow-up -- tracked below. |
| D2 | Raw tuple return from resolve_cl_module | **Fixed**: `obj ClModuleRef { src_name, path }`; modresolver call site updated. |
| D3 | Unchecked dict deserialization in placement.from_dict | **Fixed**: shape guard on ElementSummary.from_dict raises on missing identity keys; summary_from_bytes catches → cache miss → recompute. |
| D4 | Monolithic build_bun_service_artifact | **Fixed**: endpoint extraction extracted to `_extract_endpoints(ir, module_name)`. |
| D5 | Overly broad except in framework_for_host_kind | **Fixed**: narrowed to ImportError (AttributeError hid real bugs). |
| E1 | Grep-the-generated-JS stdlib tests never execute | **Augmented**: `tests/runtimelib/test_bun_stdlib_e2e.jac` runs datetime/hashlib/uuid/json through a real artifact over HTTP (exact sha256 parity, v4 uuid shape, ISO wall clock, json round-trip). Compile-level pins kept as cheap first-line defense. |
| E2 | Process-lifetime host-decision cache | **Fixed**: `clear_bun_host_decision_cache()` invalidator added (cache has no watcher; callers flip config mid-process must clear). |
| E3 | Salted-hash port base | **Fixed**: default_sv_base_port derives from sha1 digest -- stable across processes. |
| F10 (r4) | ValueError omits config key | **Fixed**: message now points at `[client] target` in jac.toml. |

## Tracked follow-ups (not blocking)

- **HostKind StrEnum** (D1): jac0core/host.jac models a closed option set as
  str constants + dict tables; the PR grows the table ~3x so the debt is real.
- **Shared sibling-spawn helper** (C2): scale/plugin.jac cpython path and
  impl/bun_sv_spawn.impl.jac still hand-roll log-dir + Popen + health wait.
- **`meta.extra.http_status` override** (M8/r4): revisit when envelopes carry
  status detail.

## Verdict update

A1 gate is cleared: walker dispatch works end-to-end over real artifacts and
is now pinned by an e2e test. Remaining review items are the two tracked
follow-ups above; nothing else blocks merge.

---

# PR Review -- Round 4 self-review (branch `bun-sv-services`)

Self-audit of commits cc7c7d7c9 + a90074bc8 against CONTRIBUTING.md
(no scaffolding, type safety, no bloat, long-term fixes over workarounds).

## Findings and dispositions

| # | Finding | Disposition |
|---|---|---|
| F1 | My own dead-code removal orphaned `BUN_STDLIB_MODULES` (codeinfo.jac) -- new dead code in the fixing commit | **Fixed**: glob removed |
| F2 | HTTP 200/500 status block copy-pasted 3x in server_runtime.jac fetchHandler | **Fixed**: single `envelopeResponse(payload)` helper mirroring `_get_http_status` |
| F3 | `pub` filtering duplicated across bun_entry.jac + server_entry.jac loops + builder comment (three enforcement points to keep in sync) | **Fixed**: single point in `bun_service_builder` (owns discovery); full lists still exported so non-pub symbols stay internally importable |
| F4 | `SCHEMA_VERSION = 1` duplicated: store.jac vs bun_store.js -- two sources of truth for the stamp input | **Fixed**: baked into generated `bun_schema.js` alongside SCHEMA_SQL/PROMOTIONS; JS imports it |
| F5 | BunStore.ensureSchema had no advisory schema-election lock; concurrent bun/cpython boots could race DDL (lock_timeout=5s only) -- round-2 TODO said "ideally the schema lock" | **Fixed**: ported `pg_try_advisory_lock` election keyed by sha256("jac:ensure_schema") (same derivation as PgStore._schema_lock_key), poll/backoff, stamp re-check after acquire, unlock in finally, proceed-unlocked after 30s deadline with warning |
| F6 | Fingerprint formula hand-ported to JS with nothing pinning it to PgStore's -- silent drift risk, exactly the class of bug round-2 flagged | **Fixed**: pure fn exported as `computeSchemaFingerprint`; new test runs it under real bun against the Python-computed expectation (verified matching manually too); advisory-lock key derived from tag string at load, not a magic constant |
| F7 | `_applyPromotionDdl` interpolates arch/fld into SQL | **Kept, flagged**: identical interpolation surface as cpython `PgStore._apply_promotions` (col is sanitized both sides; fld comes from jac.toml). Changing one side alone breaks fingerprint/DDL parity -- needs a shared-DDL follow-up if pursued |
| F8 | M2 ignores `meta.extra.http_status` override that cpython `_get_http_status` honors | **Noted**: no producer sets extra.http_status on the bun path today; revisit when envelopes carry status detail |
| F9 | `resolve_sv_service_host` has two raise sites for an unknown override (registry-available vs ImportError fallback) with slightly different messages | **Noted**: acceptable; unify if touched again |
| F10 | `host_kind_for_target` ValueError lists valid targets but not the config key responsible | **Noted**: message could say `[client] target`; small polish |
| F11 | CONTRIBUTING requires release-note fragments | **Fixed**: behavior-change bullets appended to the branch fragment `8144.feature.md` |

## Verdict on intent (CONTRIBUTING #5)

The round-3 fixes are structural, not workaround-shaped: pub enforcement moved
to the single discovery point, BunStore now implements the same protocol as
PgStore (stamp, promotions, seq migration, election lock) rather than papering
over divergence, and invalid config raises instead of falling back silently.
Remaining known gap is feature-level, not debt: `/walker/<name>` dispatch over
real artifacts needs osp_spawn descriptor wiring.

---

# PR Review -- Round 3 status (branch `bun-sv-services`)

Round-2 findings addressed. All blockers and majors M1–M7 are fixed and
verified locally; M8 and the minors remain as documented fast-follows.
Base for verification: HEAD `60ef92643` + working-tree fixes below.

## Verified this round

| Suite | Result |
|---|---|
| `tests/runtimelib/test_bun_stateless_e2e_p2` | **pass** (7.6s) |
| `tests/runtimelib/test_bun_persist_e2e_p2` | **pass** (15.1s) |
| `test_sv_spawn_health_budget` | **pass** (3/3) -- regressed by B1 in round 2, now green |
| `test_sv_auth_forward` | **pass** (32/32) |
| `jac check` on all touched files | clean or equal to pre-existing baseline |

Note: runs on this machine are flaky when other sessions share
`~/.cache/jac` (compile-cache lock contention) and `/tmp` is full --
retry before diagnosing code.

## Fixed

### B1 -- function-body docstring parse error (`sv_dispatch.jac`)

Docstring moved to a comment block above the declaration. This also exposed a
second latent break: `impl/bun_sv_spawn.impl.jac` re-imported `SpawnedBunService`
from its own base module → circular import. Removed (impl files already inherit
base-module scope, cf. `transport.impl.jac` using `ErrorInfo`).

### B2 -- nonexistent fields `value_expr`/`boundary_expr` (`bun.impl.jac`)

Now `u.value` / `a.try_expr`, matching `reactive_intent.jac` and
`react.impl.jac:320`. File passes `jac check`.

### B1.5 (new, found while verifying M1) -- `EndpointMeta.pub` was always False

`bun_service_builder.jac` tested `'pub' in str(item.access)` but `str(access)`
renders `<SubTag object>`, so **every** endpoint was non-pub. The M1 filter
exposed it. Now compares `item.access.tag.name == Tok.KW_PUB` (same check as
`placement._is_pub_element`). Without this fix the pub filter would have
served nothing.

### M1 -- endpoint visibility enforced

`build_bun_server_entry_script` and `emit_server_entry` only emit handlers,
routes, `/functions`, `/walkers`, healthz listings for `` `pub `` endpoints;
non-pub symbols never enter `server.mjs`. Matches cpython semantics where
non-pub endpoints are auth-required (bun host has no auth layer yet).

### M2 -- HTTP statuses

All handler paths return `Response.json(payload, {status})` with 200/500,
mirroring `_get_http_status` in `scale/server/impl/serve.impl.jac`.
Caveat found while implementing: Jac's `?:` ternary mislowers under
EsastGenPass (emits `payload.ok.`), so statuses use explicit if/else.

### M3 -- BunStore adopts the PgStore schema-stamp protocol

- Same stamp key + byte-identical fingerprint:
  `<SCHEMA_VERSION>:<sha256(version, server major, SCHEMA_SQL, sorted promotion
  column tuples)[:24]>` -- including Python's `str(tuple)` rendering.
- Promotions baked at artifact-build time: builder calls
  `promotions_for(base_path)`, `emit_server_entry` writes them into
  `bun_schema.js` (`export const PROMOTIONS`).
- Applies SCHEMA_SQL, the missing-`seq` migration, and promotion DDL
  (columns + partial indexes) under `lock_timeout='5s'`, skipping when the
  stamp matches.
- Also parameterized hydration SQL (`root_id = $1`) instead of concatenation.

### M4 -- hydration marks done only on success

`__jacHydrationDone` set only after a completed replay; in-flight guard
prevents double-hydration; core-not-published returns "incomplete" so a later
request retries; `__jacInitBunStore` gates on schema-ready AND hydrated.

### M5 -- core-mode bun children tracked + diagnosable

- `runtime.impl.jac`: `dispatch_sv_service(..., on_spawn=...)` registers an
  atexit terminate hook (scale mode keeps its registry; core mode is
  self-contained).
- `bun_sv_spawn.impl.jac`: core mode now logs to `.jac/logs/<module>.log`
  like scale mode (was DEVNULL); unhealthy RuntimeError includes exit status
  vs stall detail plus the log path.

### M6 -- port retry parity

`sv_dispatch` uses `pick_free_port(module_name)` (100 retries near the
hash-derived base) instead of one hard-coded port.

### M7 -- silent fallbacks → defaults only for absent config

- `backends/registry.jac`: blanket `except Exception → react` removed.
- `jac0core/host.jac`: unknown *explicit* target raises ValueError listing
  valid targets; absent target still defaults to browser.
  `resolve_project_host_kind` swallows only ImportError.
- `sv_service_host.jac`: unrecognized `JAC_SV_<MODULE>_HOST` /
  `[scale.microservices.services.*] host` values raise instead of silently
  executing on another host.
- Schema gap confirmed and fixed: documented per-service `host` key added to
  `[scale.microservices.services]` nested_each in `plugin_config.jac`
  (strict validation would have rejected the documented key).

## Round-3 cleanup (commit a90074bc8)

- Minors cleared: dead `is_bundled_cl_module` removed; Jac-side
  `BunStore(Store)` shell replaced with a documentation pointer to the real
  JS adapter; `tests/support.jac` now resolves bun via the jac-managed
  `get_bun()`; shared `write_service` helper replaces the p1/p2 duplicate;
  the p2 grep test now asserts the JS adapter's fingerprint protocol.
- **M8** boundary made explicit: `emit_server_entry` compiles
  `server_runtime.jac` with `type_check=False` and a rationale comment
  instead of leaning on defaults. Drift protection exists (e2e suites build
  and execute the artifact through real `Bun.build`, which rejects
  mislowered JS). A full checker-clean rewrite of server_runtime.jac remains
  optional polish.

## Remaining

- `/walker/<name>` dispatch over a real bun artifact reports "No walker
  runtime available" today -- wiring osp_spawn descriptors into generated
  artifacts is a feature gap, and the natural home for the walker-route e2e
  the review asked for.
- Stringly host-kind globs: pre-existing pattern, deferred by review.
- Scope: `60ef92643` ([?:Type] filter lowering) still recommended for its own
  PR + release fragment.

---

# External review (round 5) -- intent, patterns, duplication, Jac quality, bloat

Scope: full diff `jac/main...bun-sv-services` (~90 files). Verified against
CONTRIBUTING.md rules (no scaffolding, type safety, bloat audit, long-term
fixes) and the jac-idiomatic checklist.

## A. Intent / long-term fix (Q5)

- **A1. MAJOR -- walker HTTP surface ships before it works.**
  `runtimelib/bun_store.js:605` -- `__jacServerSpawnWalker` throws
  "No walker runtime available for Bun host" because generated artifacts never
  define `globalThis.__jacOspRT` / `__jacOspDesc`. The `__jac_run` fast path
  above it is also never produced by codegen. So every `POST /walker/<name>`
  against a real artifact 500s; only `/function/<name>` works end-to-end.
  The release note advertises "root-touching walkers persist through
  BunStore". Long-term fix: wire osp descriptors into the emitted entry at
  build time (`server_entry.jac`) and add the walker-route e2e this review
  already asked for. Do not merge the surface as functional until then -- or
  scope the release-note claim to functions.
- **A2. MINOR/MAJOR -- string-bundler fallback is a workaround-shaped path.**
  `bun_service_builder.jac:_string_bundle_bun_artifact` rewrites ES import
  lines with substring surgery (`' from "./x"'`, `line.rindex('}')`,
  single-line assumption). Any codegen formatting change silently produces a
  broken bundle instead of an error. If bun-build is a hard requirement,
  fail loudly when it's unavailable rather than degrading to text munging;
  if the fallback must stay, raise on any import line that doesn't match the
  expected shape, and add a test that exercises the fallback.

## B. Established patterns (Q1)

- **B1. OK** -- `item.access.tag.name == Tok.KW_PUB`
  (`bun_service_builder.jac:176,196`) matches the codebase idiom
  (`esast_gen_pass.impl.jac:139` etc.). Nit: repeated inline twice → extract
  a one-line `_is_pub(access)` helper in the builder.
- **B2. MINOR -- module docstrings are novel here.**
  `sv_dispatch.jac:1`, `test_sv_host.jac:1` use `"""..."""` module
  docstrings; no other runtimelib/jac0core `.jac` file does (and function-body
  docstrings already broke the parser once -- commit cc7c7d7c9). Convert to
  `#` comments per codebase convention.
- **B3. OK** -- `type_check=False` on `server_runtime.jac` is now explicit
  with rationale and drift protection via real-Bun e2e. Good boundary.
- **B4. NIT** -- `targets/registry.jac:69-73`: `get_target_registry/factory`
  shims kept for one caller (`cli.jac`); mark deprecated with a removal note
  so they don't accrete callers.

## C. Repetition / duplication (Q2)

- **C1. MINOR -- `'webview'` literal vs `HOST_WEBVIEW` constant.**
  `jac0core/host.jac:33` defines `HOST_WEBVIEW` but line 37 keys
  `HOST_CAPABILITIES` with the bare `'webview'` literal. Rename drift waiting
  to happen; use the constant.
- **C2. MINOR -- spawn boilerplate duplicated across hosts.**
  `scale/plugin.jac` cpython sibling path still hand-rolls log-dir creation +
  Popen + `wait_for_health` alongside `impl/bun_sv_spawn.impl.jac`.
  `dispatch_sv_service` unified dispatch but not the per-host plumbing;
  consider one shared `spawn_sibling_process(cmd, env, base_path, ...)` next
  pass.
- **C3. NIT -- duplicate `import shutil`** in
  `bun_service_builder.jac` (top of `_bundle_bun_artifact` and again inside
  `build_bun_service_artifact`).
- **C4. OK** -- bun_store.js ↔ store.impl.jac migration protocol duplication is
  inherent (two runtimes) and now pinned by a cross-runtime fingerprint test.
  Correct handling of unavoidable duplication.

## D. Jac quality / idiomatic style (Q3)

- **D1. MAJOR -- host kinds/capabilities are stringly-typed globs.**
  `jac0core/host.jac` models a closed option set as ~20 `str` constants +
  `dict[str, list[str]]` tables. CONTRIBUTING type-safety rule says enums for
  option sets; a `HostKind` StrEnum would make `host_provides_kind`,
  `TARGET_HOST_KIND`, and config parsing statically checkable. Deferred by
  prior rounds as pre-existing pattern -- acceptable deferral, but this PR
  grows the table ~3x, so it should be tracked as follow-up debt, not
  forgotten.
- **D2. MINOR -- raw tuple return violates type-safety rule.**
  `codeinfo.jac:resolve_cl_module -> tuple[(str | None, str | None)]`.
  CONTRIBUTING: named types over raw tuples. Return a small
  `obj ClModuleRef { has src_name: str | None, path: str | None; }` or at
  least document positional meaning at both call sites
  (`modresolver.jac:327` already unpacks blind).
- **D3. MINOR -- unvalidated dict deserialization.**
  `placement.jac` `from_dict` chains unchecked `.get()` + casts
  (`es.index = int(d.get('index', -1))` ×14). One shape-validation guard at
  the top would beat 14 silent-default coercions.
- **D4. MINOR -- monolithic builder function.**
  `build_bun_service_artifact` (~108 lines) mixes compile, endpoint-metadata
  extraction, export injection, visibility filtering, bundling, stamping.
  Extract `_extract_endpoints(ir, module_name)` at minimum -- that part is
  independently testable.
- **D5. NIT -- overly broad except.**
  `host.jac:framework_for_host_kind` catches `(ImportError, AttributeError)`
  and swallows; AttributeError there hides real bugs. Narrow to ImportError.

## E. Bloat / brittleness / scalability (Q4)

- **E1. MAJOR -- grep-the-generated-JS tests, no runtime execution.**
  `tests/compiler/test_host_bun_stdlib_p2.jac` asserts substrings like
  `'CryptoHasher' in js`, `'Date.now' in js`, `'(i * 7 + len' not in js`.
  These pin formatter output, not behavior, and no test ever *executes* a
  cl_stdlib function under bun (the p2 e2e services don't import stdlib).
  Fix: replace/augment with one e2e service importing datetime/hashlib/uuid
  and asserting computed results over HTTP.
- **E2. MINOR -- process-lifetime cache without invalidation.**
  `codeinfo.jac:_bun_host_decision_cache` memoizes `project_uses_bun_host`
  forever; tests (or watchers) that flip `[plugin.client].target` mid-process
  get stale host decisions. Key by (path, target) or expose an invalidator.
- **E3. NIT -- salted-hash port base.**
  `sv_dispatch.jac:default_sv_base_port` uses Python `hash(str)`, which is
  per-process salted; two processes derive different bases. Harmless today
  (retries cover it, single caller) but it reads like a stable port choice
  and isn't -- use a stable hash (sha1[:4] % 1000) if the function stays.
- **E4. OK -- not scaffolding:** cl_stdlib modules are production-wired via
  `modresolver.jac:326`; HOST_TEST/test_sv_host replaces production
  `_test_clients`. No dead exports found beyond B4/C3.

## Verdict

Solid parity work (pub-endpoint gating, HTTP status envelopes, shared
migration protocol with drift test are the right long-term shape). Gate the
merge on **A1**: either land descriptor wiring + walker e2e, or cut the
walker claim from the release note and track it as an immediate follow-up.
