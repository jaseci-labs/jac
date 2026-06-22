# Proposal: Reduce CI cost on Blacksmith runners

> Status: data-backed draft. Baseline numbers below are pulled from real
> `test-jaseci.yml` runs via the GitHub Actions API (job + step timing), not
> estimates. The optimized-variant numbers are projections until the benchmark
> PR (see "Getting real numbers") is run.

## TL;DR

1. **The repo is PUBLIC** (`jaseci-labs/jaseci`). GitHub-hosted `ubuntu-latest`
   is therefore **free and unlimited**. Blacksmith is a paid third-party service
   bought for *speed*, not necessity. The cheapest design moves work back to free
   runners and keeps Blacksmith only where its speed actually pays for itself.
2. **A full core PR run costs ~76-80 Blacksmith runner-minutes** (measured).
3. **Setup is already cheap; test *execution* is the cost.** Caching is a minor
   lever, not the main one (corrected from an earlier draft).
4. The big levers, in order: (a) move pure-pytest jobs to free `ubuntu-latest`,
   (b) shard the long-pole suites across free runners, (c) fail-fast gate so a
   trivial lint error doesn't pay for the 80-minute fan-out.

---

## Measured baseline (real data)

Per-job wall-clock from run `27950975813` (a full run, nothing skipped). On
Blacksmith, summed job wall-clock ~= billable runner-minutes.

| Job | Wall-clock | of which: test exec | of which: install/setup |
|-----|-----------:|--------------------:|------------------------:|
| test-core-compiler | 11.6 min | 11.3 min (680s) | ~12s |
| test-pypi-build | 10.2 min | (multi-step smoke) | (builds wheels) |
| test-scale (server) | 8.3 min | 7.0 min (422s) | 64s |
| test-scale-k8s (failure-path) | 7.8 min | kind cluster | docker/network |
| test-core-runtime | 7.5 min | ~7 min | ~10s |
| test-scale (data) | 7.3 min | ~6.5 min | ~60s |
| test-scale-k8s (deploy-core) | 5.2 min | kind cluster | docker/network |
| test-client | 4.4 min | 3.8 min (228s) | 8s + 17s playwright |
| test-packages-and-docs | 4.3 min | byllm + docs build | install |
| test-scale (microservices) | 3.3 min | ~2.7 min | ~60s |
| test-scale (misc) | 2.8 min | ~2.2 min | ~60s |
| test-desktop-native | 2.0 min | ~1.5 min | ~10s |
| test-solid-jsdom | 1.9 min | ~1.5 min | ~15s |
| test-scale (deploy) | 1.9 min | ~1.3 min | ~60s |
| test-mcp | 1.4 min | 0.3 min (19s) | 59s |
| changes | 0.1 min | (path filter) | already on free `ubuntu-latest` |
| **TOTAL (Blacksmith)** | **~80 min** | | |

Cross-checked against two other runs: 75.9 min and 75.6 min. So **~76-80
runner-minutes per core PR**, billed at the Blacksmith 4-vcpu rate. Multiply by
your per-minute rate and your monthly PR volume to get the spend.

### Key insight from step-level timing

Install steps are tiny (7-64s) because Blacksmith already has a fast/cached pip
path. **Test execution is 80-95% of each job.** Therefore:

- Dependency caching (the obvious first idea) saves seconds, not minutes. It is a
  nice-to-have, not the lever.
- Cost is driven by *how long tests run* and *where they run*. The two ways down
  are: run them somewhere free, and/or finish them faster by sharding.

---

## Finding 1 (biggest lever): move pure-pytest jobs to free `ubuntu-latest`

Standard GitHub-hosted `ubuntu-latest` for **public** repos is now 4 vCPU / 16 GB
(same core count as `blacksmith-4vcpu`) and **costs nothing**. Blacksmith's
advantage is faster cores + faster disk/network, i.e. lower wall-clock - not a
capability these jobs need.

Candidates to move to free `ubuntu-latest` (no docker/k8s, just pytest):

- `test-mcp`, `test-desktop-native`, `test-solid-jsdom`, `test-packages-and-docs`,
  `test-client` (light; little latency cost)
- `test-core-compiler`, `test-core-runtime` (long poles; move + shard, see
  Finding 2)
- `test-scale` matrix (server/data/microservices/misc/deploy)
- `test-pypi-build`

Keep on Blacksmith only where its fast disk/network genuinely helps:

- `test-scale-k8s` (kind cluster: image pulls + disk-heavy)
- optionally `test-pypi-build` (builds many wheels + admin UI; network-heavy)

If ~66 of the ~80 minutes move to free runners, **Blacksmith spend drops ~80%**
(only the k8s tier remains paid). The tradeoff is wall-clock: GitHub-hosted cores
are ~1.3-1.7x slower per test, so moved jobs run a bit longer - mitigated by
Finding 2 (sharding) since the runners are free and parallel.

Note: public-repo GitHub Actions allows up to 20 concurrent standard jobs. The
current fan-out is ~14-16 jobs; aggressive sharding must stay under that ceiling
or jobs queue (still free, just slower).

---

## Finding 2: shard the long poles across free runners

The cost/latency concentration is `test-core-compiler` (11.3 min of `pytest -n
auto` on 4 cores) and `test-core-runtime` (~7 min). On Blacksmith these are a
single expensive job each. On free runners you can split them:

- Shard `jac/tests/compiler` across 2-3 `ubuntu-latest` jobs (pytest-xdist
  `--splits`/`--group`, or `pytest-split`, or path-based matrix). **Measured:**
  free-runner compiler is 27.1 min unsharded vs 11.6 min on Blacksmith; a 3-way
  shard lands the long pole at 12.6 min - i.e. sharding closes the gap at **$0**.
- Same pattern *should* apply to runtime (17.1 min unsharded on free vs 7.5 min
  on Blacksmith), but **this is not yet measured** - no runtime shard benchmark
  has been run. Treat the runtime free-runner wall-clock as unverified until a
  shard benchmark confirms it.

Net effect (compiler measured; runtime projected): equal-or-better wall-clock
than today on free infrastructure, *if* runtime shards as well as compiler does.

---

## Finding 3: `test-pypi-build` is a serial wall-clock furnace on PRs

[test-pypi-build](../../.github/workflows/test-jaseci.yml#L412-L726) builds all
wheels + admin UI, then `jac create`s **three jacpacks over the network** and
polls three servers with `sleep 15` loops (up to 6 min of pure sleeping per
server). It is a release-gate smoke, already non-required.

- Move it to `push` (main) + nightly `schedule`, off the PR path. Removes ~10
  min/PR directly, plus its Blacksmith cost.
- Tighten readiness polls to 5s.

---

## Finding 4: stage the pipeline so cheap checks gate the heavy suite

Today `contribution-checks`, `jac-check`, and the ~14 jobs of `test-jaseci` fire
**in parallel**. A PR that fails a trivial check (formatting, blocked `.py`,
AI co-author trailer, type error) still pays for the entire fan-out before the
cheap failure shows. On a team where the first push often has a lint slip, that
is ~80 minutes wasted on the most common failure mode.

Fix: a lightweight `preflight` job (on free `ubuntu-latest`) that every heavy job
`needs:`. The cheapest signals need near-zero setup - the git-only checks (AI
co-author, block-`.py`, release-notes) need no install; `jac format --check` and
`jac check` need only `pip install -e jac`.

```yaml
jobs:
  changes:        # existing path filter, free runner
    ...
  preflight:      # NEW - cheap gate on FREE ubuntu-latest
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      # git-only: block AI co-author / block new .py / release-notes
      - uses: actions/setup-python@v5
        with: { python-version: '3.12', cache: pip }
      - run: pip install -e jac
      - run: jac format --check ...           # from jac-check
      - run: jac check . --nowarn ...         # from jac-check

  test-core-compiler:
    needs: [preflight]
    ...
  # ...every heavy job adds `preflight` to its `needs:`
```

This also folds most of `contribution-checks` + `jac-check` into one free gate,
removing two paid full-install 4-vcpu jobs.

Tradeoff: gating serializes wall-clock on *passing* PRs (`preflight + heavy`).
Acceptable because preflight is ~1-2 min and the savings on failing PRs are
large. If green-PR latency matters, gate only the expensive tier behind
preflight and let the required core jobs run alongside it.

Related knob: `test-scale`/`test-scale-k8s` use `fail-fast: false`, so all matrix
shards run after one fails - good for debugging, extra cost on red PRs.

---

## Recommended hybrid architecture

| Tier | Runs on | Jobs |
|------|---------|------|
| Gate | free `ubuntu-latest` | `changes`, `preflight` (lint + format + type + git checks) |
| Unit/integration (pytest) | free `ubuntu-latest`, sharded | compiler, runtime, client, mcp, desktop, solid, packages-docs, scale matrix |
| Heavy infra | Blacksmith (paid, fast) | `test-scale-k8s` (kind), optionally `test-pypi-build` |
| Release/nightly | Blacksmith or free | `test-pypi-build` + jacpack smokes (off PR path) |

Expected: Blacksmith spend down ~80% (only the k8s tier stays paid), wall-clock
roughly flat or better (free sharding offsets slower cores), and the common
lint-failure PR costs ~2 min instead of ~80.

---

## Getting real numbers (the benchmark PR)

We can produce a true before/after, not projections:

1. **Baseline (already measured, above):** historical `test-jaseci` runs pulled
   via `gh api repos/jaseci-labs/jaseci/actions/runs/<id>/jobs` -> per-job and
   per-step durations. ~76-80 Blacksmith min/run.
2. **Experiment:** open a PR with the hybrid workflow (free `ubuntu-latest` +
   sharding + preflight gate). Let CI run, then pull the same per-job timing and
   diff against the baseline. The report writes itself from `gh api`.

The report would show, per job: runner type, wall-clock, billable-vs-free
minutes, and total $ delta.

### Caveat to resolve before running

The local remote is a fork (`ahzan-dev/jaseci`). Blacksmith runners are
org-scoped, so `runs-on: blacksmith-...` jobs will not find a runner on the fork
and will hang. The benchmark must run either against upstream `jaseci-labs/jaseci`
(consumes the org's Blacksmith budget, needs maintainer CI approval) or with the
Blacksmith jobs swapped to `ubuntu-latest` on the fork (measures the free-runner
side only - which is still the main thing we want to prove).

---

## Rollout plan (alternative free-runner path - NOT the recommendation)

> Note: the steps below describe the *free-runner migration* that was considered
> first (move pure-pytest jobs to `ubuntu-latest` for ~80% savings via runner
> tier). The **recommended** design is in Section G (path-driven test selection
> + label/merge-gated `jac check`, heavy suite kept on Blacksmith for speed).
> This table is retained as the documented alternative, not the chosen rollout.
> See Section G's "Recommended rollout".

| Step | Effort | Risk | Est. savings |
|------|--------|------|--------------|
| 1. Move pure-pytest jobs to free `ubuntu-latest` | Low-Med | Low | ~80% of Blacksmith spend |
| 2. Shard compiler + runtime across free runners | Med | Low | keeps wall-clock flat post-move |
| 3. Move `test-pypi-build` smokes to push/nightly | Low | Low | ~10 min/PR |
| 4. `preflight` gate on free runner | Med | Low-Med | ~80 min saved on lint-fail PRs |

Trade-off of this path: free runners are 1.5-2.3x slower per job (recovered by
sharding). The recommended Section G design keeps the heavy suite on Blacksmith
so ready PRs stay fast, and gets its savings from *frequency* instead.

---

# Part 2: Measured results (real data)

This section supersedes the projections above with measured numbers.

## A. Spend and waste (real, from GitHub Actions Analytics, 30-day, normalized minutes)

Top jobs by billable minutes per 30 days:

| Job | Norm. min / 30d | Failure % | P50 |
|-----|----------------:|----------:|----:|
| jac-check (type check) | 64,964 | 14.33% | 11.5 min |
| test-scale-k8s | 63,434 | 8.38% | 17.5 min |
| test-scale | 58,396 | 6.12% | 10.2 min |
| test-pypi-build | 55,116 | 4.93% | 9.1 min |
| test-core-compiler | 54,912 | 4.89% | 9.4 min |
| test-client | 39,580 | 8.50% | 3.9 min |
| test-core-runtime | 33,792 | 13.43% | 5.4 min |
| test-packages-and-docs | 33,426 | 3.61% | 5.1 min |
| K8s real-app e2e | 31,620 | 7.12% | 7.6 min |
| test-scale-k8s (deploy-core) | 23,088 | 6.26% | 12.7 min |
| **Visible total** | **458,328** | | |

Waste from failures + reruns:

- **Floor** (minutes spent on the failed job-attempts themselves):
  ~36,400 min/30d (~8%).
- **Realistic** (a failed required job blocks merge, so the whole run re-runs;
  sibling passing jobs are wasted too): ~2-3x the floor =
  **~75,000-110,000 min/month (16-22%)**.
- Cost depends on the Blacksmith contract rate. At $0.004 / $0.008 / $0.016 per
  minute, total spend is ~$1.8k / $3.7k / $7.3k per month and realistic waste is
  ~$300-$1,700/month.
- Biggest waste contributors: **jac-check** (14.33% fail on the single most
  expensive job) and **test-core-runtime** (13.43%).

## B. Does every job need Blacksmith? No - only the 2 k8s jobs

Public repo => `ubuntu-latest` is free. Blacksmith only earns its cost where fast
disk/network matter:

| Job | Runner | Why |
|-----|--------|-----|
| test-scale-k8s | **Blacksmith** | kind cluster: image pulls, disk-heavy |
| K8s real-app e2e | **Blacksmith** | microk8s real cluster |
| test-pypi-build | free, or nightly | heavy but network-bound; not a per-PR signal |
| compiler / runtime | free + shard | pure pytest |
| client / scale / mcp / desktop / solid / packages-docs | free | pure pytest |
| jac-check / contribution-checks | free | lint / type / policy |

So ~2 of ~14 jobs keep Blacksmith; the rest move to free runners.

## C. Free-runner benchmark (measured on a fork, run 27953581830)

| Job | Blacksmith (paid) | Free ubuntu-latest | Ratio |
|-----|------------------:|-------------------:|-------|
| compiler (single) | 11.6 min | 27.1 min | 2.3x slower |
| compiler (sharded x3) | 11.6 min | 12.6 min (slowest shard) | ~same, $0 |
| runtime | 7.5 min | 17.1 min | 2.3x |
| scale (server) | 8.3 min | 12.3 min | 1.5x |
| client | 4.4 min | 6.8 min | 1.5x |

Conclusion: free runners are 1.5-2.3x slower per job, but **3-way sharding erases
the long-pole wall-clock gap at $0**.

## D. jac-check scans every file on every run (the biggest single fix)

[jac-check.yml](../../.github/workflows/jac-check.yml#L40-L50) runs
`jac format --check` over **all** `.jac` files and `jac check .` over the
**whole repo** every run - and it is the #1 billable-minute job (64,964/30d).

- **`jac format --check`: diff-scope to changed files. Always safe.**
- **`jac check` (type): diff-scope on PRs, whole-repo on `main`.** Changed-files
  type checking can miss breaks in *dependents*; the main-branch whole-repo run
  is the safety net. Implemented in `ci-tiered.yml` `t1-typecheck`.

## E. Time-optimal fail-fast pipeline

Order checks by **failures caught per minute** (`fail% / P50`); gate slow
expensive jobs behind cheap fast ones:

| Order | Check | catches/min | fail% | P50 |
|------:|-------|------------:|------:|----:|
| 1 | test-core-runtime | 2.50 | 13.4% | 5.4 min |
| 2 | test-client | 2.19 | 8.5% | 3.9 min |
| 3 | jac-check (type) | 1.24 | 14.3% | 11.5 min |
| 4 | K8s real-app e2e | 0.94 | 7.1% | 7.6 min |
| 5 | test-packages-and-docs | 0.71 | 3.6% | 5.1 min |
| 6 | test-scale | 0.60 | 6.1% | 10.2 min |
| 7 | test-pypi-build | 0.54 | 4.9% | 9.1 min |
| 8 | test-core-compiler | 0.52 | 4.9% | 9.4 min |
| 9-10 | test-scale-k8s | ~0.48 | 8.4% | 17.5 min |

Sequential *between* tiers, parallel *within* (implemented in `ci-tiered.yml`):

```
Tier 0  (~30s, free)   policy checks + jac format --check (DIFF-SCOPED)
Tier 1  (~6 min)       runtime || client || jac check (diff-scoped)
Tier 2  (~10 min)      compiler(sharded) || scale || mcp/desktop/solid
Tier 3  (slow/$$)      test-scale-k8s || K8s e2e || pypi  (Blacksmith or nightly)
```

A PR that breaks runtime/types (the common ~13% case) fails in ~6 min having
spent ~6 min, instead of triggering the full ~80-100 min fan-out including the
17-min k8s jobs. Gating keeps the ~173,000 min/month of Tier-3 work from running
on core-broken PRs - an estimated ~20,000+ min/month saved on top of the
free-runner move and format scoping.

## F. The .jir cache is NOT dependency-aware (rules out cached incremental check)

Investigated whether `jac check` could be made cheap by caching across runs.
The per-project `.jac/cache/*.jir` cache key
([`compute_module_key`](../../jac/jaclang/jac0core/jir.jac#L303)) hashes the
jaclang version, Python version, format version, the file's own content, and
[`_related_files`](../../jac/jaclang/jac0core/jir.jac) - which resolves to only
the module's `.impl.jac` / `.test.jac` / variant / style **sibling** files,
**not its imported dependencies**.

Consequence: if module A changes and module B imports A but B's own source is
unchanged, B's cache key is unchanged -> B loads stale cached JIR -> B is **not**
re-checked against the new A. A cached incremental whole-repo check would
therefore miss cross-file type breaks - the same blind spot as diff-scoping.
Making the cache transitively aware is a jaclang-core change (out of scope per
project policy), so the fix is at the CI level, not the compiler.

## G. Final architecture (recommended): path-driven tests + gated jac check

Two independent gates: **what changed** selects which tests run, and a **label /
merge** gate controls the expensive whole-repo `jac check`.

### G.1 Test selection by changed path (every push)

A `dorny/paths-filter` job classifies the diff; each test job is gated on its
area. `core` (`jac/**`) folds into every gate because the compiler+runtime
underlies everything.

| Changed files | Tests that run |
|---------------|----------------|
| **No `.jac`** (md / docs / yaml only) | **none** |
| **core** (`jac/**`) | **all** test jobs |
| **scale only** (`jac-scale/**`) | scale only |
| **byllm only** (`jac-byllm/**`) | byllm only |
| **mcp / desktop / client only** | that package only |

Build/dependency config (`*/pyproject.toml`, `jac.toml`, lockfiles, the workflow
file itself) folds into `core` -> run all, since a dependency bump can break any
test without a `.jac` change. This is why a pure-docs PR runs **zero** tests, but
a `pyproject.toml` bump runs everything.

### G.2 Whole-repo `jac check` gate

`jac check` (the #1 cost job, 64,964 min/30d, runs on *every* PR today with no
path filter) runs **only** when:

```
(.jac files changed)  AND  (ready-for-review label present  OR  push to main)
```

- **md-only / non-`.jac` change** -> skipped (nothing to type-check).
- **WIP push with `.jac` changes** -> a cheap **diff-scoped** `jac check`
  (changed files only) for fast feedback; the whole-repo check does not run yet.
- **`ready-for-review` label** -> authoritative whole-repo (cold) `jac check`.
- **push to `main` (merge)** -> whole-repo (cold) `jac check` as the safety net,
  catching cross-file breaks the diff-scoped PR check could miss.

Whole-repo is required because the `.jir` cache is **not** dependency-aware
(Section F): a changed type in A is not re-checked against an unchanged
dependent B. Diff-scoping is fast feedback; the gated whole-repo run is the
correctness guarantee.

### G.3 Heavy test suite (label-gated)

When the `ready-for-review` label is present, the selected test suite (G.1) runs
in full on **Blacksmith** (fast, so ready PRs get quick feedback). Because this
only happens on ready PRs, keeping it on paid-but-fast runners costs little - the
savings come from *frequency*, not the runner tier. (k8s needs Blacksmith
regardless.)

### G.4 Required check + triggers

- **Stable required check:** a single `ready-status` job always runs and passes
  unless something actually failed (skipped jobs count as ok). Make *that* the
  one required status check, so branch protection never hangs on
  "waiting for status" when an area or the label is absent.
- **Trigger event set:** the workflow listens on
  `pull_request: [opened, synchronize, reopened, labeled, unlabeled,
  ready_for_review]` and `push: [main]`. `labeled` fires the run when the label
  is added; `synchronize` re-runs it on each subsequent push while labeled, so a
  "ready" result never goes stale. To force a re-check after a flake with no new
  commit, push an empty commit or re-run the job (GitHub does not re-fire
  `labeled` if the label is already present).

Optional stronger guarantee: layer a merge queue (`merge_group`) so the
whole-repo check also runs against the latest `main` immediately before landing.

### Recommended rollout

1. Add the `dorny/paths-filter` selection (G.1) and gate the currently-ungated
   required jobs (`test-core-compiler/runtime/client`) on `core`. Land the
   `ready-status` shim and make it the required check first.
2. Remove the per-PR-push run of `jac-check`; gate it per G.2 (diff-scoped on
   push, whole-repo on label/merge).
3. Label-gate the heavy suite (G.3).
4. Move `test-pypi-build` + jacpack smokes to nightly.

## H. Projected savings (from the 30-day dashboard)

Baseline: **458,328 billable minutes / 30d** across the visible top jobs (real
GitHub Actions Analytics numbers).

In the chosen design the heavy suite stays on Blacksmith but runs **only on
ready PRs**, so the lever is *frequency*. Scaling the heavy minutes by the
fraction of runs that happen on a labeled (ready) PR:

| Ready-runs = | Blacksmith min / 30d | vs today |
|--------------|---------------------:|---------:|
| 50% of pushes | 229,164 | **-50%** |
| 40% of pushes | 183,331 | **-60%** |
| 30% of pushes | 137,498 | **-70%** |

Dollar impact (Blacksmith rate is contract-dependent; 40%-ready case):

| Rate | Now / mo | After / mo | Saved / mo | Saved / yr |
|------|---------:|-----------:|-----------:|-----------:|
| $0.004/min | $1,833 | ~$733 | ~$1,100 | ~$13,200 |
| $0.008/min | $3,667 | ~$1,467 | ~$2,200 | ~$26,400 |
| $0.016/min | $7,333 | ~$2,933 | ~$4,400 | ~$52,800 |

Bigger-but-slower alternative: move the pure-pytest heavy jobs to **free
`ubuntu-latest`** (sharded) and keep only k8s on Blacksmith. That pushes the
reduction to **~85-90%** but makes the ready-PR suite ~1.5-2.3x slower per job
(recovered by sharding). The table above keeps the faster Blacksmith runners per
the chosen design; the free-runner option is there if cost outranks ready-PR
latency.

Not modeled here (further upside): contributors running the full suite on their
own free fork runners pre-PR; fewer reruns from the ~25% failure rate caught
earlier by the cheap gate; and diff-scoping the jac-check that today scans every
file (64,964 min/30d) on every push.

Measured evidence (free-runner benchmark, fork run): compiler single 27.1 min
vs Blacksmith 11.6, but a 3-way shard lands the long pole at 12.6 min - i.e.
sharding closes the free-vs-paid wall-clock gap if the free-runner option is
taken.

Headline: **~50-70% lower Blacksmith spend** in the chosen (fast, Blacksmith)
design, or **~85-90%** if the heavy pure-pytest jobs also move to free runners.
