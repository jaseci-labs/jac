# interopbench

`interopbench` measures Jac's marshalled cross-codespace boundaries. The
runnable slice covers both mixed-JIT scalar directions and full-native value
views: `sv → na` calls, `sv → na → sv` inverse callbacks, and zero-copy
`NativeListView` / `NativeStructView` consumption. Later cells remain
design-only in the repository-level `INTEROP_BENCH.md` until their phase
acceptance gates pass.

Do not add a `jac.toml` here. The repository-root project configuration keeps
commands on the in-tree compiler.

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
| small args | `work=100`, `calls=10` |
| default args | `work=1000`, `calls=100` |
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
| small args | `work=100`, `calls=10` |
| default args | `work=1000`, `calls=100` |
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
| default args | `count=1000` |
| timing owner | Driver, using `time.perf_counter_ns()` after wrapper activation and one producer warm-up; native-view checksum and materialise-plus-copy-checksum scopes are timed separately |
| prerequisites | In-repository Jac runtime, native JIT support, and the existing `jaclang.jac0core.native_accel` / `native_marshal` wrapper path only |
| reference twin | `materialised`, checksumming ordinary `list[int]` and `list[tuple[int, int]]` copied from the same native result |
| measured path | `view`, checksumming `NativeListView` values and `NativeStructView` fields directly while producer-owned native globals retain both lists |
| canonical digest | Exactly one `view:<checksum>` line; both consumers use the same ordered integer/field reduction modulo 2^31−1 |
| timing output | Exactly one `ns=<integer>` line covering both consumers, excluding import/JIT/wrapper setup |
| metric keys | Exactly `m:view_ns=<integer>` and `m:materialise_ns=<integer>` |
| reset rule | Each `produce_views(count)` call replaces both retained native globals; every command runs in a fresh process and warms with a separate one-element batch before creating the measured batch |
| oracle | Require both top-level results to be `NativeListView`, every struct element to be `NativeStructView`, require the in-process view/copy checksums to match, then require canonical digest identity between variants |
| wrapper seam | The driver calls the existing `accelerate_module` entry before timing because a cached plain import may otherwise retain Python implementations; no compiler-test fixture or manual `JacProgram`/ctypes setup is copied into the suite |
| RSS | Not recorded in Phase 3; result cells explicitly use `rss_scope: "not_recorded"` |

The scalar cells use mixed-file `jac run`; standalone `jac nacompile` is not
a valid adapter for them. `iop_view` also uses `jac run`, but its dedicated
driver activates the full-native producer through the existing native
acceleration and wrapper/layout seam before measurement.

## Result schema version 1

`harness/common.jac` writes one document with this stable top-level shape:

```json
{
  "schema_version": 1,
  "suite": "interopbench",
  "family": "native_bridges",
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
          "median_ns": 0,
          "min_ns": 0,
          "max_ns": 0,
          "stdev_ns": 0,
          "canonical_digest": "call:<checksum>",
          "digest": "<sha256-prefix>",
          "metrics": {"per_call_ns": 0}
        }
      }
    }
  }
}
```

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

## Running

From this directory:

```bash
./ci.sh
./run_bridges.sh
./run_all.sh
jac run harness/audit.jac
```

Direct harness use:

```bash
jac run harness/measure.jac \
  --kernels iop_call,iop_cb --variants free,bridge --sizes small \
  --invocations 2 --out /tmp/interopbench.json
jac run harness/measure.jac \
  --kernels iop_view --variants materialised,view --sizes small \
  --invocations 2 --out /tmp/interop_view.json
jac run harness/audit.jac --out /tmp/interop_audit.json
```

Omit `--variants` when selecting cells with different oracle groups (or when
running the default catalog); the harness then uses each cell's declared
variants.

`ci.sh` runs one small invocation per scalar variant, exercises `iop_view` at
empty, one-element, and small-list sizes, and then runs the named mixed-JIT
manifest/wrapper audit. It does not reimplement output parsing or structural
checks in shell. `run_bridges.sh` runs that gate, writes default
measurements to `results/bridges_results.json`, and writes the structural audit
to `results/interop_audit.json`. `run_all.sh` currently invokes only the
implemented native-bridge family; it does not claim a cross-runtime result.

From the repository root, the compiler regression gate is:

```bash
jac test jac/tests/compiler/passes/native/test_interop_differential.jac
```
