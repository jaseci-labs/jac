# Pack smoke performance budgets

`test-jac-pack-smoke` measures the commands it already runs. It adds no repeated
site builds, cache purges, benchmark jobs, or base-revision builds. GNU `time`
records the foreground commands directly, and the existing readiness steps save
Linux uptime timestamps. `scripts/ci_perf.jac` checks all measurements once at the
end and publishes the verdict. This avoids repeatedly launching a Jac helper:
that cost about seven seconds per invocation in the local overhead probe.

The checker and its targeted tests are written in Jac, using the existing object
model and CLI. The tests and final report add a small amount of work, but the
application workload is unchanged. The report's own startup and memory are
outside the measurements. No memory sampling or forced garbage collection runs.

GNU `time` records wall time, user/system CPU time, exit status, and peak RSS.
GNU `timeout` enforces each foreground command's configured wall budget and
terminates its process group. On Linux this RSS metric is the largest process
high-water mark, including waited-for children, not the simultaneous sum of a
process tree. Memory gates run in the final Jac check; they are not allocation
limits and do not establish that a long-lived server is leak-free.

The three server timestamps start immediately before launch and end at the
existing HTTP readiness probes. They include the existing sleeps and polling
resolution. The final checker applies the exact startup budgets; the workflow
also caps the readiness steps to stop a server that never becomes ready. These
clocks measure startup only, not the browser journey or server memory. Dependency
downloads, apt installation, and browser interactions are outside these budgets.

## Workloads and initial limits

Limits live in `pack-smoke-budgets.json`. The runner is
`blacksmith-4vcpu-ubuntu-2404`, with `JAC_NO_DEV_SOURCE=1` and the sealed artifact
from `build-kit`. The existing command order is part of the measurement contract:
the kit is warmed, purged, and started; then the project is scaffolded and checked,
the desktop is built, the quickstart runs, the production artifact is built and
served, and the fleet starts. These are not isolated cold client-build numbers.

The initial wall budgets use successful CI runs
[34729528764](https://github.com/jaseci-labs/jac/actions/runs/34729528764) and
[34733877811](https://github.com/jaseci-labs/jac/actions/runs/34733877811):

| Phase | Observed seconds | Budget seconds |
| --- | ---: | ---: |
| Site type check | 59-60 | 90 |
| Desktop build | 152-157 | 240 |
| Production build | 118-121 | 180 |
| Quickstart readiness | 55-65 | 120 |
| Production readiness | 5 | 30 |
| Fleet readiness | 85 | 180 |

The type-check RSS budget is 2560 MiB. Its completed instrumented step in
[run 34765459547](https://github.com/jaseci-labs/jac/actions/runs/34765459547)
used 2012.4 MiB and 63.65 seconds; that run was subsequently cancelled when the
Jac checker revision was pushed. The initial build limits are 6144 MiB, including
the bundler. Those are explicit resource budgets, not peaks inferred from the old
CI logs, which did not capture memory. Review the recorded workflow measurements
when calibrating these limits. Standalone client-build measurements are a
different workload and must not be used as this job's baseline.

Command timeouts fail their existing steps. The final Jac gate rejects exceeded
budgets and missing or failed measurements and uploads `pack-smoke-performance`, including per-phase JSON with
the commit, run, metrics, and limits, alongside the raw accounting files. The job summary presents the same
numbers. The timed commands preserve their original failure and timeout exit codes.

Budgets are fixed in version control; successful runs do not automatically raise
them. Change a budget only with a reviewed explanation and relevant runner
measurements. A single shared-runner sample needs headroom: these limits catch
substantial regressions, not statistically establish a small percentage change.
Use the saved CPU and wall measurements together when investigating noise.

## Targeted validation

Run the same short subprocess tests locally:

```sh
jac test scripts/ci_perf.jac
```

To check a downloaded `pack-smoke-performance` artifact locally:

```sh
jac run scripts/ci_perf.jac -- --output /tmp/downloaded-pack-smoke-performance
```

The checker expects every configured phase. It must not pass after an incomplete
smoke run. Use the budget file from the measured revision when comparing older
artifacts.
