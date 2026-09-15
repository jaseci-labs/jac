# Checker and kit performance calibration

`jac-check` and `build-kit` record their existing commands with GNU `time`, using
`scripts/ci_measure.sh`. These new lanes are **reporting only**: there are no
unmeasured, guessed limits, and a successful report does not mean a performance
budget passed. The existing pack-smoke budgets remain enforced separately.

The shell recorder uses the same raw accounting fields as `scripts/ci_perf.jac`.
It works before the Jac binary is built and publishes reports even when the build
fails. Reporting uses jq, already required by CI. Commands retain their exit
codes, stdin, stdout, and stderr. No extra build, cache purge, or warm-up is added.

## Measurements

| Job | Phase | Work measured |
| --- | --- | --- |
| build-kit | binary-build-attempt-1/2/3 | Each executed `zig build` attempt, separately |
| build-kit | fetch-typeshed | Materialize typeshed |
| build-kit | vendor-musl | Materialize x86-64 musl |
| build-kit | vendor-musl-linux-aarch64 | Materialize ARM64 musl |
| build-kit | vendor-wasm-libc | Materialize Wasm libc |
| build-kit | hermetic-smoke | Hermeticity and binary smoke commands |
| build-kit | program-smoke | Self-contained program execution |
| build-kit | test-runner-smoke | Self-contained test runner smoke |
| build-kit | verify-kit | Verify all artifact trees exist |
| jac-check | runtime-warmup | Existing rerouted compiler warm-up |
| jac-check | format-check | Existing scoped/full formatting check |
| jac-check | check-repository | Whole-repository check with existing ignores |
| jac-check | check-error-report | Optional unfiltered diagnostics sweep |

Each command records wall seconds, user/system CPU seconds, exit status, and peak
RSS. Normalized JSON includes commit, run, run attempt, runner, job, and cache
context. RSS is the largest process high-water mark, including waited-for
children, not the simultaneous memory consumption of parallel workers.

Each build attempt also retains its log, including Zig's `--summary all` per-step
accounting. Use that detail to identify expensive build stages before adding
stage-specific gates; the recorder currently produces one normalized measurement
per attempt, not separate normalized measurements for stages inside Zig's DAG.
Retries are not independent cold-build samples: earlier attempts may populate
caches. Retry sleeps are outside the recorded build attempts.

Both jobs publish a step summary and a 30-day artifact named
`build-kit-performance` or `jac-check-performance`, including raw files,
normalized JSON, and `context.json`, even after command failure. Context contains
step outcomes so a skipped build on a binary cache hit or an unreached checker
is not interpreted as a zero-duration success. Missing/malformed accounting
must be investigated before using a run for calibration.

## Cache states and future fixed bands

Build context records exact-hit and matched-key outputs for binary, typeshed,
Python, LLVM shim, LLVM, Bun, JIR precompile, payload-layer, and Zig package caches.
An exact-hit value of `false` alone does not imply a cold cache: a nonempty matched
key indicates a prefix restore. Empty outputs can also mean a step was skipped;
use the binary cache state and step outcomes. Cache restoration is evidence of
available inputs, not proof that every internal build stage reused them.

Checker context includes the analysis cache's exact-hit and matched-key outputs,
worker count (two), and format scope through the changed-files step outputs.
Attempts after the first deliberately skip analysis-cache restoration. A restored
analysis tree can still contain misses. Keep compiler generation, cache state,
format scope, and run attempt visible when comparing samples.

After collecting representative successful runs:

1. Separate first-attempt builds by relevant dependency-cache states; keep retries
   separate. Binary hits have no binary-build sample.
2. Separate checker cache misses from restores, and full formatting from scoped
   formatting. Do not calibrate a full sweep from skipped or small PR checks.
3. Inspect the build logs for which internal stages dominate. Downloads may occur
   inside Zig builds and materialization commands; initially report those timings
   without treating them as stable compute-only workloads.
4. Set reviewed, versioned limits per comparable phase/state using
   `ceil(maximum / 0.9)` for roughly 10% minimum headroom. Memory needs actual RSS
   samples; old GitHub step durations cannot provide it.
5. Require expected measurements for the selected state when enforcement is added,
   and retain explicit skips for conditional phases. Do not silently fall back to
   a looser band for unknown states.

Checkout, external dependency installation, cache transfers, and artifact upload
are not measured by this recorder. Setup-jac consumers without
`JAC_CI_MEASURE_DIR` simply execute the original commands, including on macOS.
No rolling baseline or automatic limit increase is introduced.

## Validation

On Linux with GNU time, jq, and Jac:

```sh
jac test scripts/test_ci_measure.jac
jac test scripts/ci_perf.jac
```
