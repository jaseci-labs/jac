# Pack smoke performance budgets

`test-jac-pack-smoke` measures the commands it already runs. It adds no repeated
site builds, cache purges, benchmark jobs, or base-revision builds. The accounting
tests take a few seconds; the measurement wrapper adds process startup and report
writing, without sampling, compiler imports, or forced garbage collection.

`scripts/ci_perf.py` runs on the runner's Python, outside the Jac binary under
test. It uses GNU `time` for wall time, user/system CPU time, and peak RSS, and GNU
`timeout` for the wall deadline and process-group termination. A memory budget is
checked when the command finishes; it is not an allocation limit. On Linux this
RSS metric is the largest process high-water mark, including waited-for children,
not the simultaneous sum of a process tree. It catches a large compiler or
bundler process but does not establish that a long-lived server is leak-free.

The three server clocks start immediately before launch and end at the existing
HTTP readiness probes. They include the existing sleeps and polling resolution.
The wait loops check the deadline before each probe and check again on success.
These clocks measure readiness only, not the browser journey or server memory.
Dependency downloads, apt installation, and browser interactions have separate
functional checks and are excluded from the performance budgets.

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

The initial peak-process RSS budgets are 4096 MiB for type checking and 6144 MiB
for the builds, which also include the bundler. These are explicit resource
budgets, not peaks measured from the old CI logs (those logs did not capture
memory). Review the new CI measurements when calibrating these limits. Standalone
client-build measurements are a different workload and must not be used as this
job's baseline.

Each step gates its own result. The final report also rejects missing or failed
measurements and uploads `pack-smoke-performance`, including per-phase JSON with
the commit, run, command, metrics, and limits. The job summary presents the same
numbers. Original command failures and timeout exit codes are preserved.

Budgets are fixed in version control; successful runs do not automatically raise
them. Change a budget only with a reviewed explanation and relevant runner
measurements. A single shared-runner sample needs headroom: these limits catch
substantial regressions, not statistically establish a small percentage change.
Use the saved CPU and wall measurements together when investigating noise.

## Targeted validation

Run the same short subprocess tests locally:

```sh
python3 -m unittest discover -s scripts -p test_ci_perf.py -v
```

To measure one existing command manually, choose a fresh output directory:

```sh
python3 scripts/ci_perf.py --output /tmp/my-pack-smoke run site-check -- jac check
```

Run this from the intended project, using an absolute path to the script when
necessary. `report` expects every configured phase; it must not pass after an
incomplete smoke run.
