# Pack smoke performance

`test-jac-pack-smoke` measures the commands it already runs and compares them
with main. It adds no repeated builds, cache purges, benchmark jobs, or
base-revision builds. GNU `time` records each foreground command once (wall,
user and system CPU, peak RSS, exit status), and the existing readiness steps
save Linux uptime stamps around each server start. `scripts/ci_perf.jac` reads
everything once at the end of the job, publishes the verdict as the step
summary, and uploads the `pack-smoke-performance` artifact.

## What is gated and what is only reported

Wall time on the shared `blacksmith-4vcpu-ubuntu-2404` runner varies by about
10% run to run (a 1.6x spread between the fastest and slowest of 91 passing
runs), and CPU seconds track wall at r=0.99, so the machine itself runs at a
different speed each time. A fixed wall budget on that runner is either so tight
that it fails on noise or so loose that it only catches a cliff. Wall time is
therefore compared, never gated:

- **Gates** (the job fails): the command exited non-zero, the command was
  stopped at its hang ceiling, peak RSS crossed the limit, or a measurement is
  missing. Peak RSS varies by about 3% on this runner, so its limit is set
  15% above the highest passing value and stays fixed in version control.
- **Reported** (the job passes): each phase's wall time next to the median of
  the last main runs and the delta between them. A delta above the alert ratio
  produces a `::warning` annotation and a "Pass, +N% vs main" result cell, so a
  slower PR is visible in the checks without being blocked on a single noisy
  sample. Rerun the job before reading anything into a lone warning.

The hang ceiling is a hang detector, not a budget: it is set at roughly three
times the median so a command that is merely slow finishes and is measured,
while a wedged command still ends the job. A stopped command leaves only the
launcher's accounting behind, so the report shows `> ceiling` for it and no
CPU or RSS figures.

## Policy file

Limits live in `pack-smoke-perf.json`:

```json
{
  "baseline": {"workflow": "ci.yml", "branch": "main", "runs": 10, "alert_ratio": 1.25},
  "phases": {
    "site-check": {"measure": "command", "hang_seconds": 200, "max_rss_mib": 2350},
    "quickstart-ready": {"measure": "readiness"}
  }
}
```

A `command` phase is a foreground command wrapped in GNU `time` and `timeout`;
it needs a hang ceiling and a memory limit. A `readiness` phase is a server
start clocked between two uptime stamps; the workflow's own wait step is its
ceiling, so it carries no limits. The `baseline` block names the workflow and
branch whose `pack-smoke-performance` artifacts supply the comparison, how many
runs to take, and the ratio above which a delta is annotated.

The 91 passing runs from 2026-09-15 and 2026-09-16 that calibrated the current
policy:

| Phase | Wall p50 / p90 / max (s) | Peak RSS max (MiB) | Hang ceiling (s) | RSS limit (MiB) |
| --- | ---: | ---: | ---: | ---: |
| site-check | 67 / 79 / 89 | 2043 | 200 | 2350 |
| desktop-build | 179 / 205 / 230 | 5190 | 540 | 6000 |
| production-build | 138 / 161 / 178 | 5378 | 420 | 6200 |
| quickstart-ready | 70 / 85 / 115 | | wait step | |
| production-ready | 5 / 5 / 5 | | wait step | |
| fleet-ready | 100 / 100 / 145 | | wait step | |

With 10% noise on a single sample against a ten-run median, the 1.25 alert ratio
sits at roughly 2.4 standard deviations, so a warning on a phase should be rare
unless the PR really is slower.

## Baseline

The report lists the last main pushes of the CI workflow through the GitHub API
(the job holds `actions: read`), downloads each run's `pack-smoke-performance`
artifact, and takes a phase's wall time only when that phase completed (exit
status 0). Each phase keeps reading older runs until it has the configured
number of samples or the listing (three times that many runs) is exhausted, so a
run where one phase failed still serves the others. A phase needs at least three
samples to compare. The runs and samples used are written to `baseline.json`
inside the artifact.

A baseline that cannot be fetched is reported as unavailable and never fails the
job: the gates do not depend on it. Artifacts expire after 30 days, so the
baseline is always recent; a slow drift on main shows up as the median moving,
which the artifact history makes visible but this job does not alert on.

## Local use

Run the accounting tests:

```sh
jac test scripts/ci_perf.jac
```

Report a downloaded artifact against a hand-written baseline, or without one:

```sh
jac run scripts/ci_perf.jac -- --output /tmp/pack-smoke-performance --baseline samples.json
jac run scripts/ci_perf.jac -- --output /tmp/pack-smoke-performance --no-baseline
```

`samples.json` maps each phase to a list of wall seconds. With `GITHUB_TOKEN`
and `GITHUB_REPOSITORY` set and neither flag given, the report fetches main's
runs the way CI does.

The report expects every configured phase and must not pass after an incomplete
smoke run. Use the policy file from the measured revision when reading older
artifacts.
