# Rust bridges - remaining work

Living checklist for what is **not done** after the M2–M6 branch (na-first product
policy - see IMPLEMENTATION.md / PLAN.md). Updated 2026-07.

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
- [x] **ROOT-CAUSED + FIXED (2026-07-18) — it was a TEST-HARNESS BUG, not a na-backend
      resolver bug.** `na/conformance.jac` (regex) failed `E1001: Cannot assign <Unknown>
      to str` at `emsg = __jac_str_from_raw(mb[0], mb[1])`. The earlier "resolver
      import-order priming" diagnosis was WRONG. Real cause: `conformance.jac` named its
      synthesized temp module `"conf.jac"` (line 79), while EVERY other conformance
      (`scalar_conf.na.jac`, …) uses a `.na.jac` name. `__jac_str_from_raw`'s `-> str`
      signature (na_builtins.pyi) is only consulted when the type checker's
      `_in_native_context()` is true — and that predicate keys off the module being a
      `.na.jac` file (`is_native_module` / `UniNode.codespace`). A plain `.jac`
      auto-promoted by `nacompile` is NOT seen as native context by the checker, so the
      intrinsic fell back to the plain-builtins name entry (no signature → `<Unknown>`),
      and reassigning `emsg` (already `str`) tripped E1001. Fix: `"conf.jac"` →
      `"conf.na.jac"`. Verified: conformance now PASSES, and the na regex bridge runs
      end-to-end (`is_match("foo42")`→1, `is_match("bar")`→0). Rendered scalar source ALSO
      E1001s if you nacompile it as a bare `.jac` — confirming the trigger is the filename,
      not the module shape. **Compiler HARDENED (2026-07-18):** `_in_native_context`
      (`type_evaluator.impl.jac`) now also returns true when the current module is the
      program's `_auto_promote_native` target (mirrors `BoundaryAnalysisPass._in_native_module`),
      so ANY `.jac` compiled via `nacompile` resolves na builtins — the `.na.jac` naming is no
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

## ABI v1 ceiling (honest skips until v2)

These are **not** “finish M6” items - they need the Lanes Plan (`bridges/reference/FFI-LANES-PLAN.md`, serde wide lane + py tier) or accepted v1 limits:

| Gap | Example |
|-----|---------|
| Floats | `f32` / `f64` - macro rejects; f64-return works, f64-PARAM still na-broken |
| ~~Bytes~~ | **DONE** all 3 runtimes: `Vec<u8>` / `&[u8]` / `Option<Vec<u8>>` - wire+CPython+binder, and na as of 2026-07-18 (both na-backend bytes bugs fixed; `_synth` emits the lane; scalar na↔CPython conformance green) |
| Collection **params** | pass `Vec` / `HashMap` **into** Rust |
| Nested containers | `list[list]`, `dict[str, list]` |
| Nullable scalars | `Option<bool>`, `Option<int>` |
| General callbacks | only `str→str` replacer; `replacen` still skipped |
| na callback detection | `_lambda_arg_is_callback` keys off lambda + i64 slot + `make_buf` sink, not callee `TAG_FN` (ABI v1 heuristic) |
| Tuples | non-empty |
| Struct / enum by value | opaque handles only |
| Unpinned generics | `Date<Tz>` dropped without overlay |
| Trait-object APIs | uuid 0/6, sha2 0/0 |

Reference: `bridges/reference/FFI-LANES-PLAN.md` (cancels TYPE-MODEL-V2)

---

## Lanes Plan -- broad interop (serde wide lane + py tier) - ~3–6 months

Replaces cancelled TYPE-MODEL-V2. See `bridges/reference/FFI-LANES-PLAN.md` for full plan. Phases:

0. Foundation - `jac-bridge-typemodel`, postcard metadata, shared `_marshal.jac`, re-encode existing shapes
1. Floats
2. Bytes
3. Nullable scalars / general `Option` / `Result`
4. Nested containers + collection params
5. Tuples
6. Record / Variant by value
7. Real callback signatures (`Func` / `FnSig`)

---

## Explicitly not doing

- **cl / wasm** third consumer (dropped 2026-07-03)
- **Dual-runtime parity** as a product requirement (CPython catches up when cheap)
- **Hand-authored per-crate bridges** (principle zero - binder + overlays only)

---

## Coverage floors today (binder corpus)

| Crate | Bridged | Total | Comment |
|-------|---------|-------|---------|
| regex | 31 | 84 | north-star; ~37% |
| chrono | 33 | 181 | needs overlays for `Date<Tz>` / `DateTime<Tz>` |
| base64 | 1 | 11 | |
| uuid | 0 | 6 | structural |
| sha2 | 0 | 0 | `Digest` trait aliases |

Ratchet floors in `bridges/jac-bridge-binder/tests/corpus/coverage-baseline.toml` as rules land.

---

## Suggested order

1. Merge branch (housekeeping)
2. Ship **experimental** - regex + registry + native-only docs
3. Seed crates + overlays + use-site monomorphization
4. na polish (`Option<String>`, Windows na if needed)
5. Lanes Plan Phase 0 (serde wide lane) when v1 ceiling blocks real users
