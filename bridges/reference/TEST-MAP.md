# Test map -- Lanes Plan exit criteria to their pinning tests

Maps every HARD exit criterion in FFI-LANES-PLAN.md to the exact test that pins
it: the file + test-name, whether it EXISTS today or is NEW, and its expected
status NOW (red / skip) versus AFTER the corresponding fix (green). "Blocked on
X" marks criteria that cannot be exercised until an ABI constant, crate, or lane
exists -- for those the test is written against the intended API and skip-gated,
never faked green.

Paths are relative to `bridges/`. na conformance tests live in
`jac-bridge-loader/tests/na/`; loader/ctypes tests in
`jac-bridge-loader/tests/`; binder tests in `jac-bridge-binder/`.

Adversarial-suite tests all live in the NEW file
`jac-bridge-loader/tests/na/adversarial_conformance.jac` (checklist 0.6.3, the
Phase 0 exit gate). They skip cleanly without the LLVM shim.

---

## Phase 0 exit criteria

Exit text: "existing conformance suites green; a new adversarial suite passes:
user lambda → non-bridge fn (must NOT be rewritten), two bridge crates in one
module (correct allocators), identity replacer (no double-free), reentrant method
call (status error, not UB), use-after-close (status error, not segfault). ABI v1
declared frozen except the Phase-1/2 append-only additions."

| # | Criterion | Test file :: test-name | Exists? | Now | After fix | Notes |
|---|---|---|---|---|---|---|
| 0-a | Existing conformance suites stay green through the 0.1/0.5 refactors | `na/owning_conformance.jac`, `na/{conformance,map,list,scalar,async}_conformance.jac`, `na/test_single_source_conformance.jac`, `na/test_generator_drift.jac` | EXISTS | green | green | Regression guard for the callback-dispatch switch (risk register: heuristic deleted only when these + adversarial suite are green). |
| 0.1.2 | User lambda → non-bridge fn must NOT be rewritten into a `{call,ctx}` trampoline | `adversarial_conformance.jac :: "user lambda to a non-bridge fn is not rewritten into a bridge trampoline"` | NEW | **red** | green | Reachable today. Proves non-rewrite by IR inspection (`JAC_DUMP_IR` at O0): asserts the emitted LLVM contains NO `__jac_cb_tramp_`. Runtime is identical either way (see caveat 1). |
| 0.1.1 | Two bridge crates in one module → each callback uses its own crate allocator | `adversarial_conformance.jac :: "two bridge crates in one module use their own per-crate allocators"` | NEW | **skip** | green | **Blocked on a second callback crate.** Only `jac-bridge-owning` exposes a `JacCallback` param today, so only one `jac_<mod>_make_buf` ever exists and the single-sink bug cannot fire. Needs e.g. `jac-bridge-owning2` (a module-renamed clone of owning). Skip-gated on `owning2.so`. |
| 0.1.3a | Identity replacer must not double-free | `adversarial_conformance.jac :: "identity replacer in a 1000-iteration loop does not double-free"` | NEW | **red** | green | Reachable today against owning. Identity callback makes `result == raw`; 1000 iters × 8 matches = 8000 double-frees → abort/segfault → `run_binary` raises. Complements existing `na/test_callback_leak.jac` (that test covers leak, not the identity double-free). |
| 0.2.2 | Reentrant method call → clean status error, not UB | `adversarial_conformance.jac :: "reentrant method call yields a clean status error, not UB"` | NEW | **skip** | green | **Blocked on a reentrancy-capable crate.** owning's `replace_all` is `&self`; no crate has a `&mut self` method that invokes a `JacCallback`. Minimal crate spec (module `reentrant`, type `Cell` with `new/bump(&mut)/apply(&mut, JacCallback)`) is documented inline in the test. Skip-gated on `reentrant.so`. |
| 0.2.1 | Use-after-close → clean status error, not segfault | `adversarial_conformance.jac :: "calling a method shim with a null (closed) handle returns a status error"` | NEW | **red** | green | Reachable today. The synthesized wrapper already guards `__closed` and zeroes `__handle` on `close()`, so a real close reaches the Rust shim with handle 0 only when bypassed -- the test bypasses the wrapper and calls the raw shim with handle 0 (exactly a closed handle). Today: null deref → segfault. After 0.2.1: nonzero status, clean exit. (See caveat 2.) |
| 0.1.3b | Zero-param callback lambda → readable compile error, not ICE | `adversarial_conformance.jac :: "zero-parameter callback lambda is a readable compile error, not an ICE"` | NEW | **red** | green | Reachable. Trampoline blind-indexes `anon_fn.function_type.args[0]` → `IndexError` ICE today. Asserts no binary + no Python traceback. (See caveat 3.) |
| 0.1.3b | Two-param callback lambda → readable compile error, not ICE | `adversarial_conformance.jac :: "two-parameter callback lambda is a readable compile error, not an ICE"` | NEW | **red** | green | Reachable. Extra declared param is silently dropped/miscompiled today; fix records an arity error. |
| 0.1.3c | Non-str-return callback lambda → readable compile error, not ICE | `adversarial_conformance.jac :: "non-str-returning callback lambda is a readable compile error, not an ICE"` | NEW | **red** | green | Reachable. Trampoline `strlen`s an `inttoptr`'d int today (miscompile/UB); fix rejects at compile time. |
| 0-b | ABI v1 frozen except append-only Phase-1/2 additions | `na/test_abi_drift.jac` | EXISTS | green | green | Guards the tag constants against silent drift. Extended (not replaced) when `TAG_F64`/`TAG_BYTES`/`TAG_WIDE` land. |

## Phase 1 exit criteria (hard numbers, investigation T)

Exit text: "chrono ≥ 85 bridged; sha2 ≥ 60 usable methods incl. update/digest/
finalize proven by a hash-equivalence conformance test on na; uuid ≥ 8;
determinism test still byte-identical cross-process; every flattened method or
its skip visible in the coverage report."

| # | Criterion | Test file :: test-name | Exists? | Now | After fix | Notes |
|---|---|---|---|---|---|---|
| 1-chrono | chrono ≥ 85 bridged | `jac-bridge-binder/tests/corpus.rs` (chrono floor in `corpus/coverage-baseline.toml`) | EXISTS (floor to be re-ratcheted) | red (floor unmet: 33) | green | Blocked on trait flattening (1.1) + ref-lane (1.2.4). Bump the baseline floor as part of 1.1.6. |
| 1-sha2-count | sha2 ≥ 60 usable methods | `jac-bridge-binder/tests/corpus.rs` (sha2 floor) | NEW fixture/floor | skip (sha2 fixture is 0/0 today) | green | Blocked on blanket-generic substitution (1.1.2) + `TAG_BYTES` (1.2.2). |
| 1-sha2-hash | update/digest/finalize proven by hash-equivalence on na | `na/sha2_conformance.jac` (differential vs known SHA-256 vectors, BOTH runtimes) | **NEW -- not yet written** | skip | green | **Blocked on:** `jac-bridge-sha2` crate + `TAG_BYTES` lane (1.2.2). Write as a differential na↔ctypes test against fixed digest vectors once the crate exists. Owner: task 1.2.2. |
| 1-uuid | uuid ≥ 8 | `jac-bridge-binder/tests/corpus.rs` (uuid floor) + `na/uuid_conformance.jac` (`parse_str`/`is_nil` round-trip) | binder test EXISTS; na test NEW | red (0/6) | green | Blocked on tuple-struct admission (1.2.5) + multi-ctor honesty (0.3.1). |
| 1-determinism | byte-identical cross-process | `jac-bridge-binder/tests/determinism.rs` | EXISTS | green | green | Must stay green through the flattening/self-alias changes. |
| 1-coverage-vis | every flattened/skipped item visible in coverage report | `na/test_na_coverage_floor.jac` + `jac-bridge-binder/tests/corpus.rs` (Ok→methods / Err→skips funnel) | EXISTS | green | green | Two-sided ratchet (floor AND dropped-ceiling) enforces visibility. |

## Phase 2 exit criteria (investigation S)

Exit text: "chrono ≥ 140 of the original 181 usable (~80%); a data-shaped crate
OUTSIDE the corpus added as the 6th fixture and bridged at >50% with zero
overlay; round-trip fixtures green on na AND ctypes from one source; perf gate:
scalar-only signatures show NO regression vs Phase 0; a 10k-element Vec<f64>
return measured ≤2× a memcpy floor. ABI v1 frozen for good."

| # | Criterion | Test file :: test-name | Exists? | Now | After fix | Notes |
|---|---|---|---|---|---|---|
| 2-chrono | chrono ≥ 140/181 usable | `jac-bridge-binder/tests/corpus.rs` (chrono floor, re-ratcheted) | EXISTS | red | green | Blocked on the wide lane (2.1–2.9) + serde feature plumbing (2.4). |
| 2-6th-crate | 6th data crate (e.g. semver/geojson) >50%, zero overlay | `jac-bridge-binder/tests/corpus.rs` + fixture under `tests/fixtures/` | **NEW fixture** | skip (fixture absent) | green | Blocked on task 2.10. |
| 2-roundtrip | round-trip fixtures green na AND ctypes from one source | `na/wide_roundtrip_conformance.jac` (per-crate encode-ref / assert-decoded-shape) | **NEW -- not yet written** | skip | green | **Blocked on:** `TAG_WIDE` (2.1) + na msgpack codec (2.5) + ctypes codec (2.6). Also pins the manual-serde wire-shape drift guard (2.9 -- chrono NaiveDate == ISO string, uuid == hyphenated). |
| 2-fuzz | same payload identical through rmp-serde, ctypes decoder, na decoder | `na/wide_fuzz_conformance.jac` + a tiny Rust encoder bin | **NEW** | skip | green | Blocked on 2.5/2.6; risk-register mitigation for msgpack decode bugs. |
| 2-perf-scalar | scalar signatures show no wide-lane calls (per-value lane rule) | `na/test_lane_selection.jac` (generated-source / IR inspection: scalar param beside a Wide param stays TAG-lane) | **NEW** | skip | green | Blocked on lane resolution (2.8). Uses the same `JAC_DUMP_IR` inspection idiom as adversarial test 0.1.2. |
| 2-perf-bulk | 10k Vec<f64> return ≤ 2× memcpy floor | `na/wide_perf_bulk.jac` (timed, generous ceiling) | **NEW** | skip | green | Blocked on `TAG_F64`/Vec return + wide lane. Catches pathological regressions only. |
| 2-abi-frozen | ABI v1 frozen for good | `na/test_abi_drift.jac` (asserts `TAG_WIDE=8` is the final addition; 6/7 are `TAG_F64`/`TAG_BYTES`) | EXISTS (extended) | n/a | green | Final ABI constant asserted; any later need = payload evolution inside TAG_WIDE. |

## Phase 3 spike gate (task 3.0, GO/NO-GO)

Exit text: "na program boots jac_engine_boot(), imports orjson, round-trips JSON,
runs one polars read_csv + shape; append the jac trailer; run on a machine with
no system Python; measure per-call latency (target < 2 µs scalar call)."

| # | Criterion | Test file :: test-name | Exists? | Now | After fix | Notes |
|---|---|---|---|---|---|---|
| 3.0-boot | na binary boots embedded CPython + imports orjson, JSON round-trip | `jac/tests/runtimelib/client/test_pyinterop_spike.jac` (new) -- reuses `test_fused_runtime_boot.jac` scaffolding | **NEW** | skip | green | **Blocked on:** 4 forwarders in `jac/launcher/pyembed.zig` + materialized-rt orjson install. Lives in the jac tree, not bridges/. |
| 3.0-polars | polars read_csv + shape from na | same spike test | **NEW** | skip | green | Blocked on 3.0 forwarders + polars wheel in site. |
| 3.0-pythonless | runs on a machine with no system Python | CI job (pythonless container) | **NEW CI** | skip | green | Blocked on 3.0 bundling; CI-only, not a `.jac` unit test. |
| 3.0-latency | scalar call < 2 µs | spike test (timed) | **NEW** | skip | green | Blocked on 3.1 high-level surface; a measurement gate, not a pass/fail unit assertion until the surface exists. |

---

## Caveats / adversarial feedback (places the plan's fix is under-specified for a test)

1. **0.1.2 has no pure-runtime red form under na -- it must be asserted at the IR
   level.** na resolves `Callable[[str],str]` to a function-pointer slot (not
   `IntType`), so a *correctly-typed* higher-order call already dodges the
   heuristic (green today). The heuristic only misfires when the slot is
   `IntType` (bare `Callable` / untyped) -- but na has no indirect call through an
   `i64` param, so such a lambda can never be *executed* after the fix either
   (it would be a compile error, not correct output). The only construction that
   is both reachable-red-now and green-after is: pass the callback-shaped lambda
   to a non-bridge fn that *ignores* it, and assert the emitted LLVM contains no
   `__jac_cb_tramp_`. The test therefore depends on `JAC_DUMP_IR` + `JAC_OPT_LEVEL=0`
   (added to `_harness.jac` as `nacompile_dump_ir`). If a future refactor changes
   the trampoline symbol prefix, update the grep. The plan's "assert on runtime
   behavior" wording is not achievable here; recorded as feedback.

2. **0.2.1 "use-after-close" is already defended at the Jac level.** The
   synthesized wrapper guards `__closed` on every method and zeroes `__handle`
   on `close()`, so ordinary safe-Jac `re.close(); re.is_match()` already raises
   a clean `RuntimeError` with NO Rust-shim call -- it is green today. The Rust
   shim UB the plan fixes is reachable only by *bypassing* the wrapper (raw shim
   call with handle 0, or a not-yet-existing shared-handle aliasing path). The
   test bypasses the wrapper directly. Feedback: the plan should state that
   0.2.1 is defense-in-depth for the wrapper guard, and that the *aliasing*
   variant (two wrappers, one handle, independent `__closed`) needs a crate that
   can produce two handles over one object to be exercised end-to-end.

3. **0.1.3b/c error wording is unspecified**, so the compile-error tests assert
   the *shape* of a good diagnostic (no binary produced, no raw Python traceback,
   no `IndexError`) rather than exact text. If the fix emits a specific message
   (e.g. "callback lambda must take exactly one parameter"), tighten the asserts
   to match. Today the path ICEs with an `IndexError` traceback, which the tests
   detect as red.

4. **0.1.1 and 0.2.2 are blocked on crates that do not exist.** No fake-green is
   possible; both tests are written against the intended API and skip-gated. The
   minimal crate additions are specified inline in the test and in the table
   above. These two Phase-0 exit bullets cannot be *proven* until those crates
   land -- the plan implicitly assumes a second callback crate and a `&mut`+
   callback crate exist for the exit gate, but the current tree ships neither.

## New harness helpers added (`jac-bridge-loader/tests/na/_harness.jac`)

- `nacompile_dump_ir(src, td, jac_name, bin_name, ir_name, shim) -> (Path, str)`
  -- compiles at `JAC_OPT_LEVEL=0` with `JAC_DUMP_IR` set, returns
  `(binary_path, ir_text)`. O0 keeps a dead-but-emitted trampoline observable.
- `nacompile_capture(src, td, jac_name, bin_name, shim) -> (bool, str)` --
  compiles WITHOUT raising on failure, returns `(binary_produced, output)` for
  compile-error assertions.

---

## Red-first execution log (2026-07-10)

Ran the suite red-first with the local LLVM shim. What actually happened when we
tried to make the two SKIP tests runnable and confirm the RED tests:

### Prerequisite breakage found & fixed (the base was not green)

- **Harness was dead at import.** `_harness.jac` imported the removed
  `find_lib_in_dirs` (now `find_bridge_lib`) and `workspace()` was off-by-one
  (`jac-bridge-loader` instead of the `bridges` workspace root). The entire na
  suite failed to import → the "dark CI" of plan 0.6 was literal. FIXED.
- **Callbacks segfaulted in standalone nacompile.** `_register_bridge_metadata`
  received the bare synthesized soname; `open()` failed under `cwd=jac_root`; the
  `except: return` swallowed it; `_callback_make_buf` stayed `None`; the lambda
  was passed as a plain value where Rust expects `{call,ctx}` → SIGSEGV. The
  flagship `owning_conformance` was RED (segfault), not green. FIXED (bare-soname
  resolution via `JAC_RUST_BRIDGES_PATH`/`LD_LIBRARY_PATH` +
  `compile_env` exports it + warn-don't-swallow on unparseable blob).
  `owning_conformance` now GREEN, 32/32 obs na≡CPython.

### Reference crates built (0.0.1 / 0.0.2)

- `jac-bridge-owning2` (module `owning2`, `Regex2::replace_all`) and
  `jac-bridge-reentrant` (module `reentrant`, `Cell` with `&mut` `bump`/`apply`)
  build, export the expected symbols, and load+work via the CPython loader.

### Two SKIP tests → now runnable, and what they reveal

- **Two-crate allocator test (0.1.1): GREEN today, not RED.** With both crates on
  the default global allocator the single-sink misrouting is benign (`owning` +
  `owning2` merged probe exits 0, correct output). A valid runtime red needs a
  second crate with a *distinct* allocator; otherwise assert per-crate `make_buf`
  by IR inspection. Test wired to `run_na_probe2`; leave it as an IR-assert or
  give `owning2` a distinct allocator.
- **Reentrancy test (0.2.2): BLOCKED on a deeper bug (0.1.4).** The reentry itself
  did not crash; instead a *capturing closure inside `try/except`* segfaults
  **non-deterministically** (recompiling identical source flips crash↔clean; a
  fixed binary is stable across runs → compilation-non-determinism, an
  uninitialized capture-env / stack-lifetime bug). Reproduced on BOTH `owning`
  (`&self`) and `reentrant` (`&mut self`). The reentrancy test needs capture +
  `try/except`, so it can't be reliably green until 0.1.4 is fixed. New plan task
  0.1.4 + risk-register row added.

### Net

Base callback vertical restored to green; two prerequisite crates landed; two of
the five Phase-0 exit-gate scenarios re-scoped (0.1.1 needs a distinct allocator
or IR-assert; 0.2.2 gated behind new 0.1.4). The RED loop/null-handle/compile-
error tests remain valid as written.

### Update 2026-07-10 (both re-scoped items closed)

- **0.1.4 RESOLVED -- and re-diagnosed.** The "capturing closure under try" theory
  was wrong. A capture×try×call×scope isolation matrix showed capture is
  irrelevant: a `try/except` around a *pure-Jac* call (no bridge, no capture) also
  crashed. Real cause: `_codegen_try` registers the except-bound `e` as a
  function-scope local, so the epilogue RC-releases its slot unconditionally, but
  `e` is only stored on the exception path → on the no-exception path the cleanup
  frees uninitialized stack (nondeterministic; correct output then crash at
  cleanup). Fix = null-init the except-var alloca in the entry block
  (`exceptions.impl.jac`, 3 lines). GENERAL na fix. All 12 isolation variants +
  the reentrant `&mut` probe now deterministically green; `exceptions.na.jac`
  gen-pass suite still 12/12 (the lone `runtime_errors` red is a pre-existing
  cast-attr-access feature gap). **0.2.2 unblocked.**
- **0.1.1 two-crate test now a genuine RED.** `owning2` given a guarded
  `#[global_allocator]` (magic-tagged header, `abort()` on cross-crate free). The
  merged two-crate probe now aborts (`EXIT -6`, `free(): invalid pointer`) under
  the current single-sink compiler; single-crate owning2 (na + CPython, 1000-iter
  loop) stays green. It flips back to green once 0.1.1's per-crate sink lands --
  i.e. it now actually tests the misroute instead of masking it.

### Update 2026-07-10 (0.1.1 per-crate sink IMPLEMENTED)

- **0.1.1 DONE.** Replaced the single `_callback_make_buf` sink with a per-crate
  map: `_register_bridge_metadata` records `type → owning module`, `_note_bridge_sink`
  records `make_buf sym → fn`, and `_callback_make_buf_for(func)` routes each
  callback via the callee's receiver-type crate. Two-crate probe flipped RED→GREEN
  (`a=[HELLO WORLD]`, `b=[<foo> <bar>]`, EXIT 0); the guarded owning2 allocator no
  longer aborts because the buffer is now minted by `jac_owning2_make_buf`.
- **Three-crate interleaved probe added** (`scratchpad/run_threecrate.py`, crate
  `jac-bridge-owning3` with its own guarded allocator). Interleaves
  owning→owning3→owning2→owning; GREEN with all-correct output -- proves routing
  for N≥3 crates in mixed order, not just "the second one works".
- **No regressions.** Single-crate callback battery (12 runs), reentrant, and the
  `exceptions.na.jac` gen-pass suite all green. The 2 failing `clib` gen-pass tests
  (struct-coerce, bytes-pointer) are pre-existing feature-gap/IR-assert reds
  (verified identical on the pristine compiler), structurally unrelated to callback
  routing.
