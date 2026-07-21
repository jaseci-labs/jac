# interopbench

Benchmark suite for Jac's marshalled cross-codespace boundaries. Two
experiment families share one tree, one measurement discipline, and one
differential-identity oracle per cell:

| family | prefix | harness | what it measures |
|---|---|---|---|
| native bridges | `iop_*` | `harness/measure.jac` | mixed-JIT `sv↔na`, C FFI, zero-copy views |
| cross-runtime | `xop_*` | `harness/xbench.jac` | loopback RPC, generated clients, wasm hosts |

Kernels print a deterministic digest on stdout plus one `ns=<wall ns>` timing
line and typed `m:<key>=<value>` metrics. Byte-identical digests across each
cell's oracle group are the executable witness of boundary correctness; timing
values never gate CI.

Do not add a `jac.toml` here. The repository-root project configuration keeps
commands on the in-tree compiler.

## Part 1: native-bridge kernels (`iop_*`)

Mixed-JIT scalar cells (`iop_call`, `iop_cb`, `iop_symmetric`), the
full-native view consumer (`iop_view` via `harness/view_driver.jac`), and
experimental C-ABI fixtures (`iop_ffi_*`, requires `cc` for struct/vtable cells).

Read paired variants for boundary cost:

- `iop_call`: `free` vs `bridge` (`sv → na`, work in native). Execution-placement
  benchmark, not isolated boundary cost - the ratio blends the crossing with
  native-vs-server execution speed. `iop_cb` isolates the crossing.
- `iop_cb`: `free` vs `bridge` (`sv → na → sv` callback). Cleanest boundary cell:
  both variants run the work in `sv`; only `bridge` adds the round trip.
- `iop_symmetric`: `sv_local` vs `sv_to_na` and `na_local` vs `na_to_sv`
  (matched caller/callee roles, work always on the callee). Also
  execution-placement, not pure boundary overhead - moving compute into native
  changes both the crossing and which runtime does the work.
- `iop_view`: `materialised` vs `view` (explicit copy vs zero-copy views).
  Full-traversal consumer latency only; memory savings are not measured (no RSS).

## Part 2: cross-runtime kernels (`xop_*`)

Live loopback hosts only (no NIC egress). Each cell compares in-process
dispatch against a generated client, RPC, or wasm adapter:

- `xop_svc_split`: direct billing dispatch vs `jac start` microservice RPC
  (serial loopback RPC floor)
- `xop_feed`: in-process provider vs generated Node client. **Scalar RPC floor,
  not a typed feed:** the provider returns one integer per call, the client makes
  sequential scalar RPCs over a minimal `fetch` shim (not production
  `@jac/runtime`), and there is no payload/serialisation sweep.
- `xop_wasm_call`: native driver vs wasm32 export under Node. Asymmetric host
  loops (Python loop → native bridge vs JS loop → wasm export), not the same
  source built native-vs-wasm; timing source is labelled per variant.

## Running

From this directory (`jac/examples/interopbench`; the dev-mode `jac` reroutes
to the in-repo compiler anywhere inside the repo):

    ./run_bridges.sh            # family 1: identity gate + measurements + audit
    ./run_xruntime.sh --experimental [--quick] # opt-in family 2
    ./run_all.sh                # family 1 only
    ./run_all.sh --experimental # both families
    ./ci_bridges.sh             # fast native-bridge gate only (small sizes)
    ./ci_xruntime.sh --experimental # opt-in cross-runtime gate (small sizes)

Outputs land in `results/` (gitignored): `bridges_results.json`,
`interop_audit.json`, and `xruntime_results.json`.

The native-bridge kernels double as compiler regression tests:
`tests/compiler/passes/native/test_interopbench_bridges.jac` compiles and
runs every dependency-light cell at small sizes and asserts digest identity.

Phase 4–7 source cells remain available for explicit experiments, but are
not part of the default runnable contract. Use `--experimental` with the
harness/scripts to opt in; the repository-level `INTEROP_BENCH.md` remains the
source of phase acceptance criteria.

## Enabled-cell catalog

The catalog below is the complete runnable contract through Phase 3. A cell is
not enabled merely because it appears in the design document.

### `iop_call`

| field | contract |
|---|---|
| scenario | Repeated deterministic scalar checksum calls with configurable work per call and call count |
| variants | `free` (reference), `bridge` (measured boundary) |
| source/roles | `kernels/iop_call.jac`; one mixed module owns the server reference, native implementation, argument parsing, timing, and output |
| command adapter | `mixed_jit_jac_run` in `harness/measure.jac` |
| exact command | `<sys.executable> -m jaclang run <absolute>/kernels/iop_call.jac <variant> <work> <calls>` |
| direct commands | `jac run kernels/iop_call.jac free 100 10`; `jac run kernels/iop_call.jac bridge 100 10` |
| small args | `work=200`, `calls=20` |
| default args | `work=5000`, `calls=500` |
| timing owner | Kernel, using `time.perf_counter_ns()` after one same-variant warm-up call |
| prerequisites | In-repository Jac runtime and native JIT support only; no C compiler, GNU time, NumPy, Node, browser, or live server |
| reference twin | `free` in the same source, calling `sv_checksum` over the same seeds, work, call count, order, and checksum reduction |
| measured path | `bridge` in the same source, calling `native_checksum` from an inline `na {}` block once per measured call |
| canonical digest | Exactly one `call:<checksum>` line; checksum is the modulo-2^31 sum of each call's deterministic LCG result |
| timing output | Exactly one `ns=<integer>` line |
| metric keys | Exactly one `m:per_call_ns=<integer>` line, computed as total measured nanoseconds divided by call count |
| reset rule | No persistent state; every process invocation reconstructs all scalar state from fixed call-number seeds |
| oracle | Remove `ns=` and `m:` lines, require one non-empty digest line, and require byte identity between `free` and `bridge` |
| manifest audit | Exact imports: none; exact exports: `native_checksum`; `sv_checksum` has no native binding |
| RSS | Not recorded in Phase 2; result cells explicitly use `rss_scope: "not_recorded"` |

### `iop_cb`

| field | contract |
|---|---|
| scenario | Repeated deterministic scalar callbacks from native code into the server codespace, with configurable work per callback and callback count |
| variants | `free` (direct-`sv` reference), `bridge` (native-callback measured boundary) |
| source/roles | `kernels/iop_cb.jac`; `sv_direct_checksum` owns the binding-free baseline, `native_invoke_callback` owns the native export, and `sv_callback_checksum` owns the server callback imported by native code |
| command adapter | `mixed_jit_jac_run` in `harness/measure.jac` |
| exact command | `<sys.executable> -m jaclang run <absolute>/kernels/iop_cb.jac <variant> <work> <calls>` |
| direct commands | `jac run kernels/iop_cb.jac free 100 10`; `jac run kernels/iop_cb.jac bridge 100 10` |
| small args | `work=200`, `calls=20` |
| default args | `work=5000`, `calls=500` |
| timing owner | Kernel, using `time.perf_counter_ns()` after one same-variant warm-up callback |
| prerequisites | In-repository Jac runtime and native JIT support only; no C compiler, GNU time, NumPy, Node, browser, or live server |
| reference twin | `free` in the same source, calling `sv_direct_checksum` over the same seeds, work, callback count, order, and checksum reduction |
| measured path | `bridge` in the same source, calling `native_invoke_callback`, which calls `sv_callback_checksum` once per measured invocation |
| canonical digest | Exactly one `callback:<checksum>` line; checksum is the modulo-2^31 sum of each callback's deterministic LCG result |
| timing output | Exactly one `ns=<integer>` line |
| metric keys | Exactly one `m:invoke_ns=<integer>` line, computed as total measured nanoseconds divided by callback count; no registration metric |
| reset rule | No persistent state or callback registration in benchmark code; every process invocation reconstructs all scalar state from fixed call-number seeds |
| oracle | Remove `ns=` and `m:` lines, require one non-empty digest line, and require byte identity between `free` and `bridge` |
| manifest audit | Exact imports: `sv_callback_checksum`; exact exports: `native_invoke_callback`; `sv_direct_checksum` has no native binding |
| RSS | Not recorded in Phase 2; result cells explicitly use `rss_scope: "not_recorded"` |

### `iop_symmetric`

| field | contract |
|---|---|
| scenario | Matched sv↔na scalar calls where the callee always executes the same LCG work once per call |
| variants | `sv_local` (sv caller, sv callee), `sv_to_na` (sv caller, na callee), `na_local` (na caller, na callee), `na_to_sv` (na caller, sv callee) |
| source/roles | `kernels/iop_symmetric.jac`; `sv_lcg` owns the binding-free server implementation, `native_lcg` owns the native implementation, and `run_na_local` / `run_na_to_sv` own the native-side outer loops |
| command adapter | `mixed_jit_jac_run` in `harness/measure.jac` |
| exact command | `<sys.executable> -m jaclang run <absolute>/kernels/iop_symmetric.jac <variant> <work> <calls>` |
| direct commands | `jac run kernels/iop_symmetric.jac sv_local 100 10`; `jac run kernels/iop_symmetric.jac na_to_sv 100 10` |
| small args | `work=200`, `calls=20` |
| default args | `work=5000`, `calls=500` |
| timing owner | Kernel, using `time.perf_counter_ns()` after five same-variant warm-up calls |
| prerequisites | In-repository Jac runtime and native JIT support only |
| reference twins | Compare `sv_local` vs `sv_to_na`, and `na_local` vs `na_to_sv`. These ratios are **execution-placement** deltas (they change both the crossing and which runtime runs the callee work), not isolated boundary overhead |
| measured paths | `sv_to_na` crosses once per call with work in na; `na_to_sv` crosses once per call with work in sv |
| canonical digest | Exactly one `symmetric:<checksum>` line |
| timing output | Exactly one `ns=<integer>` line |
| metric keys | Exactly one `m:per_call_ns=<integer>` line |
| reset rule | No persistent state; every process invocation reconstructs all scalar state from fixed call-number seeds |
| oracle | Require byte identity across all four variants |
| manifest audit | Exact imports: `sv_lcg`; exact exports: `native_lcg`, `run_na_local`, `run_na_to_sv` |
| RSS | Not recorded; result cells use `rss_scope: "not_recorded"` |

### `iop_view`

| field | contract |
|---|---|
| scenario | Produce deterministic native integer and struct lists, consume both as zero-copy views, then explicitly materialise and checksum Python-owned copies |
| variants | `materialised` (reference), `view` (measured boundary) |
| source/roles | `kernels/iop_view.na.jac` owns `Sample`, retained native storage, and `produce_views`; `harness/view_driver.jac` owns wrapper activation, runtime type checks, timing, materialisation, and output |
| command adapter | `full_native_view_driver` in `harness/measure.jac` |
| exact command | `<sys.executable> -m jaclang run <absolute>/harness/view_driver.jac <variant> <count>` |
| direct commands | `jac run harness/view_driver.jac materialised 17`; `jac run harness/view_driver.jac view 17` |
| acceptance args | `empty=0`, `one=1`, `small=17` |
| default args | `count=5000` |
| timing owner | Driver, using `time.perf_counter_ns()` after wrapper activation and one producer warm-up; native-view checksum and materialise-plus-copy-checksum scopes are timed separately |
| prerequisites | In-repository Jac runtime, native JIT support, and the existing `jaclang.jac0core.native_accel` / `native_marshal` wrapper path only |
| reference twin | `materialised`, checksumming ordinary `list[int]` and `list[tuple[int, int]]` copied from the same native result |
| measured path | `view`, checksumming `NativeListView` values and `NativeStructView` fields directly while producer-owned native globals retain both lists |
| canonical digest | Exactly one `view:<checksum>` line; both variants use the same ordered integer/field reduction modulo 2^31−1 |
| timing output | Exactly one `ns=<integer>` line covering only the selected consumer, excluding import/JIT/wrapper setup |
| metric keys | Exactly `m:view_ns=<integer>` and `m:materialise_ns=<integer>`; the non-selected metric is zero |
| reset rule | Each `produce_views(count)` call replaces both retained native globals; every command runs in a fresh process and warms with a separate one-element batch before creating the measured batch |
| oracle | Require each selected consumer to receive `NativeListView`/`NativeStructView` values, then require canonical digest identity between variants |
| wrapper seam | The driver calls the existing `accelerate_module` entry before timing because a cached plain import may otherwise retain Python implementations; no compiler-test fixture or manual `JacProgram`/ctypes setup is copied into the suite |
| RSS | Not recorded in Phase 3; result cells explicitly use `rss_scope: "not_recorded"` |

The scalar cells use mixed-file `jac run`; standalone `jac nacompile` is not
a valid adapter for them. `iop_view` also uses `jac run`, but its dedicated
driver activates the full-native producer through the existing native
acceleration and wrapper/layout seam before measurement.

## Result schema version 2

`harness/common.jac` writes one document with this stable top-level shape.
Version 2 adds a `provenance` block (so a timing is never quoted without its
machine) and per-variant `samples` / `iqr_ns`:

```json
{
  "schema_version": 2,
  "suite": "interopbench",
  "family": "native_bridges",
  "provenance": {
    "captured_utc": "<iso-8601>",
    "host": "<hostname>",
    "platform": "<os-release>",
    "machine": "<arch>",
    "processor": "<cpu>",
    "cpu_count": 0,
    "python": "<impl version>",
    "executable": "<path>"
  },
  "cells": {
    "iop_call": {
      "scenario": "scalar checksum call churn",
      "source": "kernels/iop_call.jac",
      "reference": "free",
      "size_set": "small",
      "oracle": {
        "variants": ["free", "bridge"],
        "canonical_digest": "call:<checksum>",
        "identical": true
      },
      "variants": {
        "free": {
          "args": ["100", "10"],
          "invocations": 1,
          "command_adapter": "mixed_jit_jac_run",
          "timing_source": "kernel_perf_counter_ns",
          "rss_scope": "not_recorded",
          "samples": 1,
          "median_ns": 0,
          "min_ns": 0,
          "max_ns": 0,
          "stdev_ns": 0,
          "iqr_ns": 0,
          "canonical_digest": "call:<checksum>",
          "digest": "<sha256-prefix>",
          "metrics": {"per_call_ns": 0}
        }
      }
    }
  }
}
```

Invocations are interleaved per variant (paired sampling). `timing_source` is
per variant, so cross-runtime cells that do not share a clock label the Python
and Node sides distinctly. Reported spread (`stdev_ns`, `iqr_ns`) is descriptive
only; confidence intervals and ratio uncertainty are not computed and no timing
gates CI.

The strict parser rejects a missing or repeated `ns=` line, malformed or
duplicate metrics, anything other than one non-empty digest line, changing
metric-key sets, and nondeterministic digests across invocations. The oracle
then rejects a digest mismatch across selected variants. Timing values never
gate CI.

`harness/audit.jac` separately writes schema-versioned
`results/interop_audit.json`. It compiles each audited mixed-JIT source through
`JacProgram.compile`, requires exact `InteropManifest.native_imports` and
`native_exports` symbol sets, verifies named generated-Python address lookup,
`CFUNCTYPE`, and callback-registration markers, and confirms each direct-`sv`
baseline symbol has no native binding. It does not report a generic stub count.

## Running (harness details)

Direct harness use:

```bash
jac run harness/measure.jac \
  --kernels iop_call,iop_cb --variants free,bridge --sizes small \
  --invocations 2 --out /tmp/interopbench.json
jac run harness/measure.jac \
  --kernels iop_symmetric \
  --variants sv_local,sv_to_na,na_local,na_to_sv --sizes small \
  --invocations 2 --out /tmp/interop_symmetric.json
jac run harness/measure.jac \
  --kernels iop_view --variants materialised,view --sizes small \
  --invocations 2 --out /tmp/interop_view.json
jac run harness/audit.jac --out /tmp/interop_audit.json
```

Omit `--variants` when selecting cells with different oracle groups (or when
running the default catalog); the harness then uses each cell's declared
variants.

`ci_bridges.sh` delegates identity checks to `harness/measure.jac` at small
sizes and then runs the named mixed-JIT manifest audit. It does not
reimplement output parsing or structural checks in shell. `run_bridges.sh`
runs that gate, writes default measurements to `results/bridges_results.json`,
and writes the structural audit to `results/interop_audit.json`.
`run_xruntime.sh` mirrors the pattern for `results/xruntime_results.json`.

From the repository root, the compiler regression gate is:

```bash
jac test jac/tests/compiler/passes/native/test_interopbench_bridges.jac
```
