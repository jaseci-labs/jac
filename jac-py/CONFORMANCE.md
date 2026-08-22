# D2 Conformance Dashboard & Ratchet

PLAN.md §2 defines **D2** as: a pinned, published subset of CPython's own
`Lib/test` suite passes, tracked per-module on a conformance dashboard, with
the pass-set only growing (ratchet CI, §9 M2/M3). This directory holds the
tooling that makes the ratchet visible and enforceable.

## Components

| File | Role |
|---|---|
| `tools/conformance_dashboard.py` | Single stdlib-only CLI: markdown report, ratchet check, baseline update. Never runs suites; it only reads manifests the gates already wrote. |
| `tools/conformance_baseline.json` | Pinned pass-set (grow-only ratchet state). |
| `tools/test_conformance_dashboard.py` | Fast pytest unit tests (<1s), no jac needed. |
| `jac-py/tests/conformance_manifest*.json` | Source data: per-wave module rows (`stem`, `gate_type`, `status`) plus `libtest_results` / `jac_differential_results` / `jacpython_results`. Written by the existing P2/P3 gate pipeline (`p2_conformance_gate.py`, `p2_conformance_waves_gate.py`). |

## Usage

```bash
# Markdown per-module pass table (stdout, or --out FILE)
python3 jac-py/tools/conformance_dashboard.py

# Ratchet check (CI mode): exit 0 iff nothing regressed
python3 jac-py/tools/conformance_dashboard.py --check

# Re-pin the baseline from current manifests
python3 jac-py/tools/conformance_dashboard.py --update-baseline
```

Options: `--tests-dir DIR` (default `jac-py/tests`) and `--baseline FILE`
(default `jac-py/tools/conformance_baseline.json`) for testing or alternate
manifest trees.

## Ratchet semantics

An entry is one module stem (e.g. `_bisectmodule`). It is *passing* when its
gate pipeline marked it `gated`, exactly the condition
`p2_conformance_gate.py` / `p2_conformance_waves_gate.py` assert in CI.
`--check` fails if any pinned entry:

1. disappeared from the manifests,
2. lost its `gated` status, or
3. dropped below its previously-recorded passing `jacpython_results` case
   count (catches silent coverage shrinkage inside a still-gated module).

New gated entries and higher case counts are always allowed; `--check` lists
unpinned new entries so the baseline can be grown deliberately via
`--update-baseline`.

Baseline schema (versioned):

```json
{
  "schema": 1,
  "updated": "YYYY-MM-DD",
  "entry_count": 50,
  "entries": {
    "<stem>": {
      "wave": "p2_wave1",
      "gate_type": "oracle|libtest|deferred",
      "status": "gated",
      "cases_passed": 1,
      "cases_total": 1
    }
  }
}
```

## Workflow rules

- **Grow-only:** a PR may add entries/cases to the baseline; it must never
  shrink them. If `--check` fails on your branch, fix the regression; do not
  re-pin downward.
- **Re-pinning:** run `--update-baseline` after landing genuinely new gated
  modules, and commit the regenerated `conformance_baseline.json` in the same
  PR.
- **No local suite runs:** the dashboard never invokes `jac test`; it derives
  everything from gate-written manifests, so it is safe to run anywhere.

## Suggested CI wiring (not yet wired)

Add one non-blocking-elsewhere job to jac-py's workflow:

```yaml
conformance-ratchet:
  steps:
    - uses: actions/checkout@v4
    - run: python3 jac-py/tools/conformance_dashboard.py --check
    # optional, publish the table as a job summary / artifact:
    - run: python3 jac-py/tools/conformance_dashboard.py --out dash.md
    - if: always()
      uses: actions/upload-artifact@v4
      with: { name: conformance-dashboard, path: dash.md }
```

Because `--check` reads only JSON manifests, the job needs no venv, no jac
binary, and finishes in seconds.

## Current coverage

Seeded 2026-07 from waves 1–11: **50/50 modules gated**
(10 oracle/libtest in wave 1 + 4 per wave for waves 2–11), jacpython libtest
case coverage 1/5 (wave 1's `getplatform` passes; bisect/heapq snippets are
not yet jacpython-capable). See the generated dashboard for the live table.
