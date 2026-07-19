# Rust bridges - remaining work

Living checklist for what is **not done** after the M2–M6 branch (na-first product
policy - see IMPLEMENTATION.md / PLAN.md). Updated 2026-07-18.

**Terminology (read this before the tables below):**

- **Wire ABI** (`ABI_VERSION = 1`, `JACBRDG1` in `jac-bridge-schema`) -- frozen tag
  algebra; scalar tags 1..=8 are full. New shapes ride `TAG_WIDE` msgpack payloads
  and append-only blob sections -- **not** a bump to `ABI_VERSION = 2`. See Phase 2.12
  in `bridges/reference/FFI-LANES-PLAN.md`.
- **FFI-LANES Phases 0–2** -- soundness debt, trait flattening, serde wide lane,
  typed records, f64/bytes tags: **landed** on this branch.
- **TYPE-MODEL-V2** -- cancelled; replaced by the wide lane + py-interop tier.
- **Do not** read “ABI v1” in older prose as “pre-wide-lane capability.” The wire
  format is v1; the binder/loader stack is post–Phase 2.

**Ship bar:** `nacompile` / `jac bundle`. CPython (`jac run`) is secondary.

---

## Before merge (housekeeping)

- [x] Push unpushed commits on `rust-ffi` - pushed 26 commits (through ffi-lanes 3.5 flagship) 2026-07-18
- [x] Land uncommitted binder / synth / docs / test changes (~1.5k LOC) - working tree clean (2026-07-17)
- [x] `docs/docs/reference/language/rust-bridges.md` already tracked (2026-07-17)
- [x] Refresh stale comments in demo crates (`jac-bridge-map`/`jac-bridge-list`) - done 2026-07-17; scalar `f64-param` note left as-is (still accurate: na miscompiles float params)
- [x] `ndarray/` (upstream reference clone) + `.pi-subagents/` gitignored (2026-07-17)
- [x] PR description updated 2026-07-18 - added Lanes Phase 2 (wide serde lane) + Phase 3 (py-interop) rows, fixed M6.3 async (was "Not started"), corrected nested containers (now shipped), added py-interop test plan entries

### Pre-existing na-test breaks (surfaced by the 2026-07-17 upstream merge probe; NOT merge-caused)

- [x] **`conformance.jac` base regex E1001 -- could NOT reproduce (2026-07-17).** Rendered
      the real regex `.na.jac` via `render_na_source` off `libjac_bridge_regex.so`, appended
      the `na_side` `with entry` probe, and `nacompile`d it: compiles to a binary and **runs
      correctly** -- the fallible path (`emsg = __jac_str_from_raw(mb[0], mb[1])`, from
      `_synth._read_msg_block`) decodes the Rust error message end-to-end (`bad "(" →
      "regex parse error: … unclosed group"`). No `E1001` at any point. The na checker does
      not enforce reassignment-type-compat on inferred `with entry` locals at all (verified:
      `chr(65)` → `int` also passes silently), so the "Cannot assign <Unknown> to str"
      verdict has no path to fire here. Treating the earlier observation as stale/transient
      (likely cold-cache). If it resurfaces in CI, capture the exact rendered source + cache
      state -- the intrinsic's `-> str` is declared in `type_registry.jac` +
      `na_builtins.pyi` and gated on `_in_native_context()`.
- [x] **ROOT-CAUSED + FIXED (2026-07-18) -- it was a TEST-HARNESS BUG, not a na-backend
      resolver bug.** `na/conformance.jac` (regex) failed `E1001: Cannot assign <Unknown>
      to str` at `emsg = __jac_str_from_raw(mb[0], mb[1])`. The earlier "resolver
      import-order priming" diagnosis was WRONG. Real cause: `conformance.jac` named its
      synthesized temp module `"conf.jac"` (line 79), while EVERY other conformance
      (`scalar_conf.na.jac`, …) uses a `.na.jac` name. `__jac_str_from_raw`'s `-> str`
      signature (na_builtins.pyi) is only consulted when the type checker's
      `_in_native_context()` is true -- and that predicate keys off the module being a
      `.na.jac` file (`is_native_module` / `UniNode.codespace`). A plain `.jac`
      auto-promoted by `nacompile` is NOT seen as native context by the checker, so the
      intrinsic fell back to the plain-builtins name entry (no signature → `<Unknown>`),
      and reassigning `emsg` (already `str`) tripped E1001. Fix: `"conf.jac"` →
      `"conf.na.jac"`. Verified: conformance now PASSES, and the na regex bridge runs
      end-to-end (`is_match("foo42")`→1, `is_match("bar")`→0). Rendered scalar source ALSO
      E1001s if you nacompile it as a bare `.jac` -- confirming the trigger is the filename,
      not the module shape. **Compiler HARDENED (2026-07-18):** `_in_native_context`
      (`type_evaluator.impl.jac`) now also returns true when the current module is the
      program's `_auto_promote_native` target (mirrors `BoundaryAnalysisPass._in_native_module`),
      so ANY `.jac` compiled via `nacompile` resolves na builtins -- the `.na.jac` naming is no
      longer load-bearing. Verified: reverting the test back to bare `conf.jac` now passes too;
      guard is scoped (a normal `jac check` of a server module still sees the intrinsic as
      Unknown); type-checker tests (`test_global_narrowing`, `test_prim_equivalence`,
      `test_subscript_assignment`, `test_shared_types_equivalence`) green. The test keeps the
      `.na.jac` name for hygiene (matches sibling conformances).
- [x] **Parenthesized-lambda syntax updated in na tests (2026-07-17).** Fixed in
      `owning_conformance.jac`, `aliasing_conformance.jac`, `adversarial_conformance.jac`,
      `test_callback_leak.jac` (19 lambdas + 2 prose comments). NOTE: the earlier fix
      guidance was wrong -- current jac does **not** accept `lambda m: str -> str : …`
      (that's `E0022: Expected '{' after lambda parameters`). The branch grammar requires a
      **block body**: `lambda (m: str) -> str { … ; }` (parens + return type kept, `: expr`
      → `{ expr; }`, implicit last-expr return) -- exactly the form aee1298d1 used in
      `_search_dirs`. All four files now parse; the three `_assert_readable_compile_error`
      inputs (arity0/2, wrong retty) now reach their intended *semantic* callback-ABI error
      instead of a syntax `E0002`. Full na execution stays CI-gated (SHIM + `.so`).

---

## M6 - close the milestone

| Item | Status | Notes |
|------|--------|-------|
| M6.1 na closures (`{call, ctx}`) | ✅ Done | |
| M6.2 integers + `HashMap→dict` / `Vec→list` returns | ✅ Done | flat `V ∈ {bool, int, str}` only |
| M6.3 `async fn` as blocking | ✅ Done | module-owned Tokio runtime + block_on shim (`jac-bridge-async`); CI: workspace binder tests + `test_async.jac` loader + `async_conformance.jac` na vertical |
| `Option<String>` on na | ✅ Done | binder `classify_return` now emits `OptStrValue` for a plain `-> Option<String>` (was skipped); macro (`Tag::Opt(Str)`), na `_synth` (`-> str \| None`, null-ptr → None), and ctypes all already decoded the `TAG_OPT_BIT \| TAG_STR` lane. Fixture: geo_demo `Canvas::shape_name`; binder classify+codegen tests + emitted-wrapper macro-compile verified 2026-07-18 |
| `Option<Vec<u8>>` on na | ✅ Done | binder `classify_return` now emits `OptBytesValue` for a plain `-> Option<Vec<u8>>` (byte analogue of `OptStrValue`; also `Option<Array<u8, _>>`); macro (`Tag::Opt(Bytes)`, in-band null `JacBuf`), na `_synth` (`-> bytes \| None`, null-ptr → None), and ctypes all already decoded the lane. Fixture: geo_demo `Canvas::shape_name_bytes`; binder classify+emit tests + emitted-wrapper macro-compile verified 2026-07-18 |
| Callback `retain`/`release` | ⏸ Deferred | only when Rust **stores** a callback past the call |

---

## Production v1 (na) - ~1–2 months after merge

### Packaging & distribution

- [ ] Populate registry with real artifacts (not just regex); extend CI matrix crates as binder allows
- [ ] Document **experimental** ABI v1 limits in user-facing docs (partially in `rust-bridges.md`)
- [ ] One real app dogfood (not only conformance tests) on `nacompile` + `jac bundle`

### Binder / crates

- [ ] **2–4 seed crates with overlays** (chrono `monomorphize`, base64, …) - prove not regex-only
- [ ] **Use-site instantiation manifests** - na compiler emits concrete generic instantiations seen at call sites; local-build binder consumes them (today: hand `monomorphize` overlays only)
- [ ] ABI stability / semver policy for `abi_version` and blob format

### na platform gaps

- [ ] **Windows na** - immature; prioritize if Windows native ship matters (ctypes is not the path)
- [ ] **Static-musl binaries** - bridges require dynamic link today; document or implement staticlib path (D1.1 v2)
- [ ] Local dev ergonomics - LLVM shim (`zig build jacllvm`) is heavy; document or automate

---

## Remaining FFI gaps (post–Phase 2)

Honest skips and platform gaps **after** the serde wide lane landed. These are not
“waiting for ABI v2” -- they are the next lanes, overlays, or na fixes. Authoritative
detail: `bridges/reference/FFI-LANES-PLAN.md`.

| Gap | Status | Example / notes |
|-----|--------|-----------------|
| ~~Bytes~~ | **DONE** | `Vec<u8>` / `&[u8]` / `Option<Vec<u8>>` on wire + CPython + na (`scalar_conformance.jac`) |
| ~~Wide serde lane~~ | **DONE** | `TAG_WIDE` msgpack; typed records; nested/container/enum fields (`geo_demo` 8/8) |
| ~~`Option<String>` / `Option<Vec<u8>>` returns on na~~ | **DONE** | geo_demo fixtures; M6 tail |
| ~~Trait flattening (sha2/uuid)~~ | **DONE** | sha2 54/186 (hashing surface complete); uuid 42/108 live |
| `f64` **params** on na | **OPEN** | `TAG_F64` return works; na miscompiles float params -- synthesizer skips them |
| Collection **params** (non-serde) | **OPEN** | pass `Vec<T>` / `HashMap` **into** Rust on the list/map wire lanes |
| Serde collection **params** | **partial** | `IntoIterator<Item=S>` monomorphized to `Wide<Vec<String>>` where the binder pins it (regex set builders) |
| Nullable scalar **params** | **partial** | `Option<int>` **returns** bridge; `Option<bool>` / nullable scalar args still thin |
| General callbacks | **OPEN** | `str→str` replacer (`replace_all`) works; `replacen`, typed signatures deferred |
| na callback detection | **OPEN** | shape-based (`i64` slot + `make_buf`), not callee `TAG_FN` in blob metadata |
| Tuples | **partial** | INTEGER tuple **returns** bridge (`Time::as_hms -> (u8,u8,u8)`, `to_hms*`; `BridgeReturn::Tuple`) -- re-projected onto the existing `List` wire lane as `Vec<i64>`, decoded as `list[int]`, no new tag. Float / mixed (`(i32, Month, u8)`) / `u64`-element / string tuples and tuple **params** still open |
| Struct / enum by value (non-serde) | **OPEN** | opaque handles + wide lane for derived-serde types only |
| Unpinned generics | **OPEN** | `Date<Tz>` / `DateTime<Tz>` dropped without `monomorphize` overlay |
| Trait-object returns | **OPEN** | `Box<dyn DynDigest>` etc. -- sha2’s remaining skips are duplicates, not new capability |
| Standing cdylibs for corpus crates | **N/A** | Product uses auto-binder + registry; workspace members are acceptance fixtures only |
| Static-musl / `.a` link path | **OPEN** | dynamic `cdylib` only today (D1.1) |

---

## Lanes Plan status

See `bridges/reference/FFI-LANES-PLAN.md` for the full checklist. Summary:

| Phase | Status | What landed |
|-------|--------|-------------|
| **0** Soundness + debt | **Done** | per-crate allocators, adversarial suite, SlotKind spec, borrowed-handle lane |
| **1** Trait flattening + small lanes | **Done** | bytes, `&mut self`, ref-lane, tuple-struct admission, `FN_STATIC`, sha2/uuid/chrono floors met |
| **2** Serde wide lane | **Done** | `TAG_WIDE`, typed records, semver + geo_demo fixtures, ABI frozen (append-only within v1) |
| **3** py-interop tier | **In progress** | forwarders + spike landed; flagship polars groupby acceptance landed; CI/pythonless polish remains |
| **4** Productionization | **Backlog** | registry artifacts, seed overlays, use-site monomorphization, Windows na |

Cancelled: **TYPE-MODEL-V2** recursive type table (superseded by wide lane + py tier).

---

## Explicitly not doing

- **cl / wasm** third consumer (dropped 2026-07-03)
- **Dual-runtime parity** as a product requirement (CPython catches up when cheap)
- **Hand-authored per-crate bridges** (principle zero - binder + overlays only)

---

## Coverage today

Two metrics -- see `bridges/reference/EXAMPLE-PASS-METRIC.md` for why both exist.

### 1. Binder item-coverage (corpus ratchet)

Gate: `jac-bridge-binder/tests/corpus.rs::coverage_does_not_regress` vs
`tests/corpus/coverage-baseline.toml`. Run: `cargo test -p jac-bridge-binder
coverage_does_not_regress -- --nocapture`.

| Crate | Bridged / Total | % | Dropped | In bridges workspace? |
|-------|-----------------|---|---------|----------------------|
| geo_demo | 8 / 8 | 100% | 0 | rustdoc fixture only |
| regex | 79 / 97 | 81% | 10 | yes -- acceptance / conformance seed |
| semver | 12 / 15 | 80% | 3 | yes -- acceptance seed (**37/39** with opaque overlay) |
| chrono | 197 / 305 | 65% | 6 | rustdoc fixture only; needs overlay for `Date<Tz>` |
| uuid | 42 / 108 | 39% | 1 | rustdoc fixture only (floor 25 -- **ratchet pending**) |
| sha2 | 54 / 186 | 29% | 0 | rustdoc fixture only; hashing surface **complete** at 54 |
| base64 | 6 / 13 | 46% | 4 | rustdoc fixture only |

**Product path is NOT “add a `jac-bridge-<crate>` workspace member per crate.”**
Principle zero: the auto-binder is the only front door (`IMPLEMENTATION.md` D6).
Users declare `jac add rust:<crate>`; `jac install` resolves cache → registry →
**local auto-build** (`jaclang/compiler/rust_bridge/_build_core.jac`: crates.io
fetch → rustdoc JSON → binder → generated cdylib). CI publishes the same
pipeline's output via `bridges/tools/build_bridge_artifacts.jac` +
`rust-bridges-artifacts.yml` (registry-as-cache). Workspace `jac-bridge-*` crates
are **binder acceptance fixtures**, not a catalog of hand-maintained bridges.

Item-% is a **trend line** for binder breadth, not a ship definition.

### 2. Example-pass (north-star ship gate)

Roster: `jac-bridge-loader/tests/na/examples.toml`. Each `required` crate must
match the docs golden on **both** na and CPython.

| Crate | Example-pass | Blocker |
|-------|--------------|---------|
| semver | **GREEN** | -- |
| regex_binder | **GREEN** | -- |
| uuid | seeded, skips | na test harness looks in `bridges/target/release` only; no auto-built `.so` in that tree yet |
| sha2 | seeded, skips | same -- test infra, not a missing binder lane |

uuid/sha2 examples are written against surface the binder already bridges. To
unblock them: run the **auto-build pipeline** in CI (extend `DEFAULT_CRATES` in
`rust-bridges-artifacts.yml`, or point the harness at a `jac install` cache
path) -- **not** hand-authored `jac-bridge-uuid` workspace crates.

### 3. na synthesizer floors (hand-built fixtures)

`jac-bridge-loader/tests/na/na-coverage-floor.toml` -- owning 12/12, list/map 7/7,
semver ≥13/14, regex spike 2/2. Proven by `*_conformance.jac` verticals.

---

## Suggested order

1. Merge branch (housekeeping)
2. Ratchet uuid floor in `coverage-baseline.toml` (live 42/108 > floor 25)
3. Extend registry CI seed set (`rust-bridges-artifacts.yml` `DEFAULT_CRATES`) as
   binder coverage allows; wire example-pass harness to auto-built artifacts
4. Overlays where needed (chrono `monomorphize`, base64) -- data, not hand bridges
5. na: `f64` params, collection params, callback metadata-driven detection
6. Lanes Plan Phase 3 polish (pythonless CI) + Phase 4 productionization
