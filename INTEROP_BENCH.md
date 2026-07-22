# interopbench

Benchmark suite for Jac's cross-codespace interop: the **marshalled**
boundaries defined in [`docs/docs/internals/interop.md`](docs/docs/internals/interop.md)
where a call becomes an RPC, an FFI thunk, or a wasm import/export and every
value that crosses must be serialised. Mirrors the `ownbench` discipline:
one benchmark scenario per kernel, `ns=` + digest output, a Jac harness,
differential-identity oracle, and compiler-regression integration.

## The gap this fills

`jac/examples/ownbench` covers the **free** `na → na` boundary and the
memory-management dial (ownership / regions / GC). Everything it measures
stays inside one runtime. None of it exercises the six marshalled cells of
the interop matrix  -  `cl↔sv`, `sv→sv` µsvc, `sv↔na`, `na↔C`, `na↔cl`  -  so
every perf claim in the interop doc (`_to_wire`/`__from_wire` cost,
zero-copy `NativeListView`, struct-by-value C ABI correctness, wasm export
cost) has no number behind it and no regression guard. This suite is that
coverage.

> **Status:** Phases 0–2 are runnable: the scalar call, inverse callback, and
> symmetric sv↔na cells have passed their acceptance gates. **Phase 3 (native
> views) is retired:** #7587 removed the `native_accel.accelerate_module`
> hot-swap the driver relied on and #7589 made native the default codespace, so
> an externally imported `.na.jac` producer no longer yields the zero-copy
> `NativeListView`/`NativeStructView` the cell measured (it returns ordinary
> Python-marshalled lists). The cell, its driver, and its producer were removed
> rather than left measuring nothing. Phase 4–7 source cells are retained for
> explicit `--experimental` runs, but remain outside the default runnable
> contract until their phase acceptance criteria pass.

### How to read the numbers (scope of valid conclusions)

The differential-identity / regression layer is the load-bearing part:
byte-identical digests across each oracle group are a real correctness and
compiler-regression witness, and the manifest/IR/ABI audits are structural facts.
The **performance** layer is narrower than a casual reading of the kernel names
suggests. The only defensible timing conclusions are about *these exact
microprograms at the chosen size on the measured machine*. In particular:
`iop_call` and `iop_symmetric` measure **execution placement** (which runtime
runs the work), not isolated boundary overhead - `iop_cb` is the cleanest
boundary cell; the `iop_ffi_*` cells report per-foreign-call time
(`m:per_ffi_call_ns`) but the scalar floor includes numeric conversions and the
struct floor averages five shapes; `xop_feed` is a sequential scalar RPC floor,
not a typed feed or serialisation curve; and `xop_wasm_call` compares asymmetric
host loops, not the same source built native-vs-wasm. No size-sweep slope,
confidence interval, or ratio uncertainty is computed. Do not publish these as
general Jac interop overhead, realistic feeds, production microservices, or
native-vs-wasm results.

## Two families, two harnesses

Parallel to ownbench's ownership + regions split (which carries two
harnesses because the metrics differ). The interop split is by harness
shape, because the boundary kind decides whether a command adapter drives
an in-process JIT/AOT binary or a host adapter owns another runtime.

| family | boundaries | harness | shape |
|---|---|---|---|
| **1. native bridges** | `sv ↔ na`, `na ↔ C` | `harness/measure.jac` | command adapters: in-process `jac run` JIT for mixed `sv↔na`; `jac nacompile` + subprocess for pure native/C |
| **2. cross-runtime** | `cl ↔ sv`, `sv → sv` µsvc, `na ↔ cl` | `harness/xbench.jac` | host adapters: server / generated-client driver / Node wasm runtime around the same result protocol |

The parsing and aggregation contract is ownbench-derived, not copied
verbatim. `ownbench/harness/measure.jac` does not parse `m:` lines, and
neither ownbench harness owns a persistent host. Interopbench therefore has
one shared `harness/common.jac` module for output parsing, subprocess runs,
aggregation, and oracle comparison; host and build lifecycles remain in the
family adapters.

## Boundary → kernel map

| # | Boundary | Wire | Kernel(s) | Real-world stand-in |
|---|---|---|---|---|
| 1 | `sv → sv` in-proc | free | `base_call` | plain Python-call floor (baseline) |
| 7 | `sv → na` | mixed-file JIT | `iop_call` | Python calling native code (view cell retired; see Status) |
| 8 | `na → sv` | `na {}` native→Python call | `iop_cb` | native calling back into Python |
| 12 | `na ↔ C` | `import from lib { def; obj }` | `iop_ffi_scalar`, `iop_ffi_struct`, `iop_ffi_vtable` | libm, raylib, SQLite, CEF |
| 5 | `cl ↔ sv` | HTTP+JSON / explicit SSE client | `xop_crud`, `xop_feed`, `xop_stream` | littleX post/list, SSE token stream |
| 2 | `sv → sv` µsvc | HTTP+JSON | `xop_svc_split` | billing/notification fan-out |
| 9 | `cl → na` | wasm exports | `xop_wasm_call`, `xop_wasm_game` | PolyBench, raylib_shooter in-browser |
| 10 | `na → cl` | wasm imports | `xop_wasm_cb` | native calling JS host externs |
| 11 | `sv ↔ py` | free | `base_pyimport` | numpy/sklearn floor (baseline) |

Prefix convention (matches ownbench's `own_*` / `reg_*`): **`iop_*`** =
in-process bridge (family 1), **`xop_*`** = cross-runtime (family 2),
**`base_*`** = a named free floor. Identity is never checked against a
generic floor: every marshalled cell names an exact reference twin that runs
the same operation over the same deterministic input.

## Kernel conventions (load-bearing)

Inherited from ownbench, extended for the boundary crossings:

- One benchmark scenario and one canonical digest per kernel. Family 1 may
  fit in one Jac source; family 2 necessarily has role-specific provider,
  caller, and host files under one kernel directory.
- Deterministic output: fixed LCG seeds, sorted iteration, fresh/reset state,
  and no clocks, generated IDs, transport envelopes, or object addresses in
  the digest.
- Each invocation prints exactly one non-empty canonical digest line, exactly
  one effective `ns=<integer>` line, and zero or more unique integer
  `m:<key>=<value>` lines. The parser removes both `ns=` and `m:` from digest
  input and rejects missing/multiple timing lines, duplicate metrics,
  changing metric-key sets, and nondeterministic digests.
- `with entry { }` reads size/variant arguments from `sys.argv`. The kernel
  owns `ns=` when both paths share a clock. A JS/browser driver that cannot
  share that clock returns only the canonical digest and metrics; the host
  adapter injects the single `ns=` wall-clock line.
- Each run selects exactly one named work size (`--sizes`), so a single run
  reports per-batch or per-call time at that size only. The harness does **not**
  currently fit a fixed-cost intercept or a per-byte slope, and no kernel claims
  one from a single sample. Separating boundary overhead from callee work needs a
  multi-size sweep that is not yet implemented; until then, treat every number as
  "this exact microprogram at this size on this machine." Invocations within a run
  are interleaved per variant (paired sampling) so drift hits both sides evenly.
- No comments / docstrings in kernel bodies (repo fmt strips them). Boundary
  declarations stay minimal and mechanical so a named manifest/IR audit can
  inspect them.
- Every differential pair has an explicit pair record: scenario, variants,
  commands, arguments, timing owner, prerequisite set, canonical digest,
  metrics, reset rule, and reference twin. Identity compares only variants
  in that record; decomposition experiments are not silently treated as
  semantic twins.

## Kernels

### Family 1  -  native bridges (`iop_*`, `base_*`)

Ownbench-shaped result protocol with two execution adapters: in-process
`jac run` for mixed `sv↔na`, and `jac nacompile` + subprocess for pure
native/C. Each cell has its own exact reference twin.

- `base_call` / optional `base_pyimport`  -  named plain `sv → sv` and
  `sv ↔ py` floors. The fast gate uses only repository/stdlib dependencies;
  NumPy is an explicitly selected research cell, never a default prerequisite.
- `iop_call`  -  first vertical slice. One mixed source contains a deterministic
  scalar workload in ordinary `sv` and inside `na { ... }`; a variant arg
  selects the exact reference or bridge path. Both run under in-process
  `jac run`, because standalone `nacompile` rejects mixed modules with
  Python/server `native_imports`. Warm up once, then emit `m:per_call_ns` =
  wall / outer-calls at one size. **This is an execution-placement benchmark,
  not an isolated boundary cost:** `free` runs the LCG in `sv` and `bridge` runs
  the same LCG inside `na {}`, so the ratio blends the `sv → na` crossing with
  native-vs-server execution speed. For the crossing in isolation see `iop_cb`,
  where both variants run the work in `sv` and only the callback path adds a
  round trip. No fixed cost or slope is fitted (see the sweep note above).
- `iop_cb`  -  second mixed-JIT cell. A `na {}` function calls a Python-side
  scalar `def`; the same source has a direct-`sv` reference variant and emits
  `m:invoke_ns`. Callback registration occurs before kernel entry, so compile/
  setup time may be measured externally but is not printed as
  `m:register_ns` without dedicated runtime instrumentation.
- `iop_view`  -  **retired** (see Status). It measured full-native-module
  zero-copy `NativeListView` / `NativeStructView` consumption via the
  `native_accel.accelerate_module` hot-swap; #7587 removed that hot-swap and
  #7589 made native the default codespace, so an externally imported `.na.jac`
  producer now returns ordinary Python-marshalled lists and the cell no longer
  has a real measurement behind it.
- `iop_ffi_scalar`  -  `sqrt` churn via `import from "libm.so" { def sqrt(x:
  f64) -> f64; }`. The kernel makes `n` foreign calls per outer call, so the
  metric is `m:per_ffi_call_ns` = wall / (`n` × outer-calls), i.e. per foreign
  call, not per batch. It is an FFI-plus-`float`/`int`-conversion floor, not a
  pure ABI floor: `ffi` computes `int(sqrt(float(i*i)))` while `ref` returns `i`,
  so the delta includes the two numeric conversions on each iteration.
- `iop_ffi_struct`  -  a deterministic `support/interopbench.c` fixture exports
  take/return functions for `_Static_assert`ed 4/12/16/24/44-byte structs (the
  asserts are compiled into the fixture); Jac calls them through public
  `obj`-in-`import-from` syntax. Each outer call makes 10 C calls across 5 struct
  shapes, so `m:per_ffi_call_ns` = wall / (10 × `n` × outer-calls) is an
  **average across heterogeneous struct shapes**, not a per-shape cost; split by
  shape before quoting a single ABI-class number. Linux x86_64 runtime covers
  System V register vs `byval`/`sret`; arm64 starts as cross-target
  classifier/IR assertions unless an arm64 runner exists.
- `iop_ffi_vtable`  -  the same C fixture accepts a struct with a function-
  pointer field and invokes the Jac callback. Runtime prints only steady-state
  `m:trampoline_call_ns`; `__clibcb.{n}` creation/caching is a compile/IR
  audit, not an in-kernel build-time metric.

### Family 2  -  cross-runtime (`xop_*`)

`xbench.jac` brings up the host (`jac start` for `xop_crud`/`xop_feed`/
`xop_stream`/`xop_svc_split`; a Node/browser host for `xop_wasm_*`),
drives the kernel, tears down. Same `ns=` + digest + `m:` convention.

- `xop_crud`  -  littleX-shaped `PostMessage` / `ListMessages` /
  `DeleteMessage` over generated client calls to `POST /walker/*`. It enters
  scope only after a spike proves the compiled `.cl.jac` caller runs under
  the chosen Node/browser adapter; a Python/Jac raw HTTP caller does not
  exercise client `_to_wire`/`__from_wire`, localStorage auth, or endpoint
  cache logic. Add plain RPC first, then auth, then cache reset/invalidation.
- `xop_feed`  -  **as implemented this is not a typed-feed or
  serialisation-scaling benchmark.** The provider (`feed_provider.jac`) is a
  scalar `def feed_checksum(seed, work) -> int`; the client makes sequential
  scalar RPCs and checksums the returned integers. There are no typed feed
  records, no N = 10/100/1000 payload lists, no payload-byte sweep, and no
  serialisation-scaling measurement. It is therefore a **sequential scalar
  generated-client/HTTP floor**, useful only as such - do not read it as a
  HyperProtoBench-style serialisation curve. It also does not measure the
  production `@jac/runtime`: `harness/cl_host.mjs` substitutes a minimal custom
  `fetch` shim for `__jacCallFunction`, so it measures the generated-client shape
  over that shim, not the shipped runtime. A real typed feed with a payload sweep
  is future work.
- `xop_stream`  -  SSE generator endpoint driven by an explicit streaming
  client. The normal generated client RPC helper calls `response.json()` and
  is not an SSE consumer. Keep SSE as a separate protocol adapter (or move it
  to the `sv→sv` streaming client) and compare canonical token checksum/count
  with one equivalent blob response.
- `xop_svc_split`  -  `sv import from billing { ChargeCard }` between two
  loopback `jac start` deployments (`JAC_SV_<MOD>_URL`). Its reference is
  direct dispatch to the same provider operation with the same fresh input;
  a generic `base_call` would not isolate server dispatch/serialisation.
- `xop_wasm_game`  -  `shooter_headless.na.jac` compiled to `wasm32`, driven
  from the existing `web/` JS host. Per-frame budget, total frames, digest
  of the scripted-pilot outcome. The one kernel that is a real
  application, not a microbench.
- `xop_wasm_call`  -  after the scalar wasm slice, optional PolyBench-C
  kernels (`deriche`, `floyd-warshall`, `nbody`) via
  `jac nacompile --target wasm32`, called from JS through `WasmLinker`
  exports. **Caveat on the current implementation:** the `native` reference is
  `native_driver.jac`, a Python/server outer loop that crosses one `sv → na`
  bridge per call; the `wasm` variant is a JavaScript loop with BigInt
  conversions calling a wasm export. So the comparison is `Python loop → native
  bridge` vs `JavaScript loop → wasm export`, **not** the same source compiled
  native and wasm under equal host loops. Read it as a rough wasm-export vs
  native-bridge floor, not an isolated wasm-vs-native codegen result; the timing
  source is labelled per variant (`kernel_perf_counter_ns` for native,
  `host_node_performance_now` for wasm) because the two do not share a clock.
- `xop_wasm_cb`  -  native calling one deliberately declared application
  import under `env`; the Node adapter separately supplies the versioned
  `jac_host1` runtime host. This stable import-table hop is the inverse of
  `xop_wasm_call`.

## Running

After the corresponding phases are implemented, run from
`jac/examples/interopbench` (the dev-mode `jac` reroutes to the in-repo
compiler anywhere inside the repo; do not add a nested `jac.toml`):

    ./run_bridges.sh             # family 1: identity gate + measurements (+ enabled audits)
    ./run_xruntime.sh --experimental [--quick] # opt-in family 2
    ./run_all.sh                 # family 1 only
    ./run_all.sh --experimental  # both families
    ./ci_bridges.sh              # fast differential-identity gate (small sizes)

Outputs land in `results/` (gitignored): `bridges_results.json`,
`xruntime_results.json` (median ns, labelled RSS scope, per-`m:` metric
medians, digest per kernel × variant), and - after phase 2 - `interop_audit.json`
(named manifest/wrapper/IR facts for enabled cells).

## Harness

```
interopbench/
  README.md
  .gitignore               # bin/ results/
  run_bridges.sh           # family 1: ci_bridges.sh + measure.jac + enabled audits
  run_xruntime.sh          # family 2: ci_xruntime.sh + xbench.jac (host lifecycle)
  run_all.sh               # umbrella
  ci_bridges.sh            # fast family-1 differential-identity gate (small sizes)
  ci_xruntime.sh           # fast family-2 differential-identity gate (small sizes)
  kernels/
    base_call.jac
    base_pyimport.jac
    iop_call.jac           # na {} block + exact sv reference
    iop_cb.jac
    iop_symmetric.jac      # matched sv↔na caller/callee pair
    support/interopbench.c # deterministic struct/callback implementation
    iop_ffi_scalar.na.jac
    iop_ffi_struct.na.jac
    iop_ffi_vtable.na.jac
    xop_crud/              # walker + .cl.jac caller, littleX-shaped
    xop_feed/
    xop_stream/
    xop_svc_split/
    xop_wasm_game/         # shooter_headless port + web/ host
    xop_wasm_call/
    xop_wasm_cb/
  harness/
    common.jac             # strict parser + aggregate + oracle + result schema
    measure.jac            # family 1: command/build adapters
    xbench.jac             # family 2: host lifecycle adapters
    audit.jac              # named manifest/wrapper/IR facts
    wasm_host.mjs          # Node host for xop_wasm_*
  results/                 # gitignored JSON
  bin/                     # gitignored compiled binaries / staged .so
```

`harness/common.jac` owns the small shared interface: parse one invocation,
aggregate invocations, compare one declared oracle group, and write versioned
JSON. `measure.jac` adds mixed-JIT and native-binary command/build adapters.
`xbench.jac` adds process lifecycle adapters with readiness polling, captured
logs, reset hooks, timeouts, and terminate-then-kill cleanup in every exit
path. Browser/Node/wasm details stay behind their host adapter rather than
leaking into the common parser.

Results are schema version 2. Every document carries a `provenance` block
(host, platform, machine, processor, cpu_count, python, UTC capture time) so a
number is never quoted without the machine it came from; each cell records
`samples`, `median_ns`, `min_ns`, `max_ns`, `stdev_ns`, and `iqr_ns` (a robust
spread). What is **not** yet computed: confidence intervals, ratio uncertainty,
or an explicit outlier policy - spread is reported, not gated. Invocations are
interleaved per variant (paired sampling), but node/wasm hosts still get only a
single warm-up call, which is not enough to guarantee stable V8 tiering; treat
first-run cross-runtime numbers as provisional.

Results label `command_adapter`, `timing_source`, and `rss_scope`; cross-runtime
cells that do not share a clock label `timing_source` **per variant** (e.g.
`xop_feed`/`xop_wasm_call` record `kernel_perf_counter_ns` for the Python-driven
variant and `host_node_performance_now` for the Node-driven one) rather than
stamping one catalog-level label over a mixed pair. Family-1
mixed-JIT process RSS and standalone-native RSS are not directly comparable.
For a warm persistent family-2 host, the request-loop wall time belongs to
the driver; client RSS is recorded separately, while server RSS is either
sampled by PID and labelled or omitted. Host startup is excluded from steady-
state timing and state/cache/auth are reset between variants.

## CI gate (`ci_bridges.sh` / `ci_xruntime.sh`)

Mirrors `ownbench/ci_own.sh` in policy, not implementation: enabled kernels,
small sizes, canonical digest identity across each declared pair, and named
manifest/IR invariants. It filters both `ns=` and `m:` lines. Timing values
never gate CI.

The first gate contains only the dependency-light mixed-JIT scalar slice.
Live servers, generated clients, C helpers, optional NumPy, Node/browser, and
wasm enter a CI job only after their prerequisites and runtime are guaranteed.
A family-2 host is reused only by scenarios compiled into the same aggregate
provider; otherwise `xbench.jac` starts and tears down one host per scenario.

## Test integration

Mirrors ownbench's doubling as a compiler regression test:

- `jac/tests/compiler/passes/native/test_interopbench_bridges.jac` starts
  with the mixed-JIT scalar pair, invokes both paths through
  `sys.executable -m jaclang run`, and asserts canonical digest identity.
  It has no GNU-time, NumPy, C compiler, Node, server, or wasm prerequisite.
- Manifest/codegen audits inspect named facts: expected
  `InteropManifest.native_exports` / `native_imports`, known generated Python
  wrapper markers, C ABI attributes, or cached trampoline symbols. There is
  no generic boundary-stub counter today, and LLVM-only inspection cannot
  prove absence of Python ctypes stubs.
- ABI, marshal, and trampoline bugs discovered while adding later cells get
  minimal regressions in their existing owner tests (`test_abi_lib.jac`,
  `test_native_marshal.jac`, or `test_native_gen_pass.jac`) rather than an
  advance-created catch-all regression file.

Family 2 live-host execution stays out of the compiler-test gate. Focused
compiler/codegen tests for generated client and wasm artifacts remain in
their existing owning suites.

## What this does NOT cover (yet)

- **Cold-start / bundle size** for `sv → cl` (row 6)  -  a delivery metric,
  not steady-state; separate startup bench if anyone cares.
- **Concurrency**  -  all kernels single-caller. A concurrent-RPS sweep on
  `xop_crud` (N in-flight readers + a writer vs the endpoint cache) is the
  natural follow-on; defer until serial numbers are stable.
- **Network egress**  -  `xop_*` stay on loopback so the number is the bridge,
  not the NIC.

## Real-world workload selection

These are the **design targets and analogues**, not claims about what the
current cells implement. The billing/feed/HyperProtoBench/TechEmpower/PolyBench
references below describe the intended direction; as implemented the enabled
cells are synthetic scalar microprograms and the "Real-world stand-in" column of
the boundary map is aspirational until the corresponding payload/workload sweeps
land. Cross-checked against the polyglot/FFI benchmark community so the kernels
are comparable to something outside Jac:

- **CLBG**  -  `binarytrees`/`nbody`/`fannkuch`. ownbench already uses
  `binarytrees`; `nbody` is the canonical compute kernel for `xop_wasm_call`.
- **PolyBench / PolyBench-C**  -  the standard wasm-vs-native suite; reused
  directly in `xop_wasm_call`.
- **gRPC benchmark methodology**  -  separates fixed per-call cost from
  per-byte work; the sweep shape for `iop_call` and `xop_feed`.
- **HyperProtoBench** (Google)  -  serialization at scale; the payload-growing
  axis of `xop_feed` is the JSON analogue.
- **TechEmpower**  -  realistic web-endpoint benchmarks; `xop_crud` is a
  Jac-shaped slice.
- **Wasm-R3-Bench**  -  more realistic than PolyBench for wasm; informs
  `xop_wasm_game` (real game loop over pure kernel).

No established suite exists for "Python ↔ wasm ↔ native in one language."
This suite is that comparison, with the free baselines as the anchor.

## Reviewed implementation scope

These are decisions, not open questions:

- Land family 1 before family 2, but split it into mixed-JIT and native-binary
  adapters rather than pretending every cell is one AOT binary.
- CI gates semantic identity and named structural invariants only. Timings
  remain research output with no machine-independent threshold.
- Keep cross-language chess/perft outside interopbench; it compares language
  implementations, not one Jac program crossing a marshalled seam.
- Linux x86_64 is the first C-ABI runtime platform. Arm64 begins as
  classifier/IR coverage until an arm64 runner is available.
- Do not add `jac/examples/interopbench/jac.toml`; it would change the project
  root and can silently bypass the in-repo compiler reroute.

### Phase 0  -  freeze the cell contract ✅

**Files:** this document, then `jac/examples/interopbench/README.md`.

For every enabled cell, add a catalog record containing: scenario, variant
names, source/role files, exact command adapter, small/default args, timing
owner, prerequisite list, reference twin, canonical digest definition,
metric keys, and reset rule. Define result schema version 1 with
`command_adapter`, `timing_source`, and `rss_scope`.

**Accept when:** a model can determine the exact command and oracle for every
enabled cell from the catalog alone; no enabled cell says "same as" another
without naming files, args, and expected output shape.

### Phase 1  -  minimal vertical slice ✅

**Deliverables:**

```
jac/examples/interopbench/
  README.md
  .gitignore
  ci_bridges.sh
  run_bridges.sh
  run_all.sh
  harness/common.jac
  harness/measure.jac
  kernels/iop_call.jac
jac/tests/compiler/passes/native/test_interopbench_bridges.jac
```

`iop_call.jac` contains both a plain-`sv` scalar checksum and the same
checksum in `na {}`. `free` and `bridge` variants use the same integer inputs,
warm up once, print `call:<checksum>`, `m:per_call_ns=<integer>`, and one
`ns=<integer>`. Use `jac run` for both. Do not pass lists/objects, import
NumPy, compute a per-byte slope, invoke a C compiler, or start a host.

`common.jac` is the deep module: strict output parser, subprocess result,
aggregation, identity comparison, versioned JSON. `measure.jac` supplies the
cell catalog and mixed-JIT command adapter. `ci_bridges.sh` delegates to it with
small args and one invocation; shell does not duplicate parsing or kernel
arguments. `run_bridges.sh` runs the gate then writes default measurements.
`run_all.sh` runs the Phase 0–3 family by default. Pass `--experimental` to
include the cross-runtime family; it must not report an empty family-2 success.

**Commands:**

```
jac check jac/examples/interopbench/kernels/iop_call.jac
jac run jac/examples/interopbench/kernels/iop_call.jac free 100 10
jac run jac/examples/interopbench/kernels/iop_call.jac bridge 100 10
jac run jac/examples/interopbench/harness/measure.jac \
  --kernels iop_call --variants free,bridge --sizes small \
  --invocations 2 --out /tmp/interopbench.json
jac test jac/tests/compiler/passes/native/test_interopbench_bridges.jac
```

**Accept when:** filtered outputs are the same non-empty digest; malformed or
nondeterministic output fails loudly; JSON contains both cells with non-null
timing and identical digests; the compiler test has no optional dependency.
This is the first merge. Everything below is out of scope until it passes.

### Phase 2  -  inverse callback and manifest audit ✅

Add `kernels/iop_cb.jac` with direct-`sv` and native-callback variants, scalar
arguments only, and `m:invoke_ns`. Extend the differential test. Add
`harness/audit.jac` only after identifying the exact `JacProgram` interface;
it records expected manifest imports/exports and generated-wrapper markers.
Do not invent `m:register_ns` or a generic stub count.

**Accept when:** callback identity passes repeatedly; the baseline has no
native bindings; `iop_call` and `iop_cb` contain exactly their named
exports/imports; audit output is versioned JSON.

### Phase 3  -  native views ⛔ retired

Originally: a full `kernels/iop_view.na.jac` producer and a dedicated driver
using the native wrapper/layout path, keeping native storage alive while
checksumming the zero-copy view against a materialised copy.

**Retired** after #7587 removed the `native_accel.accelerate_module` hot-swap
the driver depended on and #7589 made native the default codespace. An
externally imported `.na.jac` producer now returns ordinary Python-marshalled
lists rather than `NativeListView` / `NativeStructView`, so the acceptance gate
(driver verifies it received native views) can no longer be met. The cell,
driver, and producer were removed instead of left measuring plain-list copies.

### Phase 4  -  C ABI floor, structs, and callback vtable

Add `kernels/support/interopbench.c` first. Build it with an explicit Linux
`cc -shared -fPIC` adapter into `bin/`, verify exported symbols, and stage it
where the Jac loader expects it. The fixture owns scalar echo/math,
`_Static_assert`ed struct layouts, take/return functions, and a function that
invokes a callback slot. Each Jac kernel has a direct reference variant over
identical inputs.

Order: `iop_ffi_scalar` → one small and one MEMORY-class struct → remaining
sizes → vtable callback. Add named IR/classifier assertions after execution
works. Never label cross-target arm64 IR as an arm64 runtime measurement.

**Accept when:** helper build and loading fail with actionable errors; all
reference/FFI digests match; System V named ABI assertions and exactly-one
trampoline cache assertions pass; existing ABI/native-gen tests stay green.

### Phase 5  -  first cross-runtime slice: `sv → sv` service split

This is family 2's lowest-risk host lifecycle. Add one provider plus free and
explicit-`sv import` consumers under `kernels/xop_svc_split/`.
`xbench.jac` allocates a port, starts `jac start`, polls readiness, captures
logs, passes `JAC_SV_<MODULE>_URL`, resets state, and tears down in `finally`
with terminate-then-kill. Reuse `common.jac` only for parsing/aggregation.

**Accept when:** direct and RPC canonical digests match; startup timeout and
provider errors include log tails; no child remains after success, failure,
timeout, or interrupt; quick mode writes labelled host/client timing data.

### Phase 6  -  generated `cl → sv` spike, then feed/CRUD

Before writing workload suites, prove one compiled `.cl.jac` function can be
driven by the selected Node or headless-browser adapter and that generated
JS executes `__jacCallFunction` / `__jacSpawn`, `_to_wire`, and
`__from_wire`. A raw Python/Jac HTTP request is a different benchmark and
must not satisfy this gate.

After the spike: implement a typed feed at 10/100/1000, then plain CRUD, then
auth, then cache hit/invalidation with explicit reset hooks. Keep raw HTTP
and pre-serialised response measurements as named decomposition experiments.
Add SSE last with its own streaming client; do not route it through the JSON
RPC helper.

**Accept when:** the generated-client digest matches direct provider dispatch;
client cache/auth variants prove their setup state; all host-owned wall times
produce one injected `ns=` line; teardown leaves no server/browser process.

### Phase 7  -  wasm microbench directions, then the game

Compile one deterministic integer kernel to native and wasm32; Node invokes
the wasm export and supplies the current `jac_host1` runtime host. For the
inverse hop, declare a stable application import under `env` rather than
relying on `malloc` or `__multi3` remaining imported under every libc setup.
Check Node and vendored wasm-libc prerequisites explicitly and keep them
separate from native musl setup.

Only after export and import microbenches pass may `xop_wasm_game` or
PolyBench ports enter scope.

**Accept when:** native/wasm digests match; the import manifest names the
intended `env` symbol and required `jac_host1` host; Node exits cleanly; the
harness labels its wall-clock timing source.

### Explicitly out of Phases 0–3

The source tree contains C FFI cells and cross-runtime host cells for
experimentation, but they are gated behind `--experimental` and excluded from
normal scripts and CI. All C FFI cells, NumPy, all live hosts, generated-client
RPC, SSE, wasm,
game/PolyBench ports, arm64 runtime execution, macOS RSS, concurrency/RPS,
network egress, cold start, bundle size, timing thresholds, chess/perft, and
compiler fixes not surfaced by the mixed-JIT scalar, callback, and view slices.
