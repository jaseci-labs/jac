# Regression tests

Executable checks for the JavaScript / Node-compatible engine. Tests are plain **`.js`** scripts (plus **`.mjs`** where ESM is required), occasional **`.sh`** wrappers, and **`.fixture.js`** helpers loaded by parents—not run as top-level tests.

## How to run

From the repository root (after `make` so `bin/js_engine` exists):

```bash
python3 run_reg.py
```

Run against **Node.js** for baseline comparison:

```bash
python3 run_reg.py --node
```

`--node` runs **every** discovered suite under Node (no skip filtering).

### Suite contract (pass/fail)

Each runnable suite (`*.js` except `*.fixture.js`, and `*.sh`) must:

1. Print a line containing **`REGRESSION_TESTCASE_FINISHED`** (with `failures=N`) before exiting normally.
2. Exit with code **`0`** only when `N == 0` (all checks passed). A non-zero exit code is the **failure count** (capped at 255); multiple failing checks are accumulated, not fail-fast.

[`run_reg.py`](../run_reg.py) marks a suite **PASS** only when the exit code is `0` **and** the completion marker appears in captured output (avoids false positives if the process exits early).

### Skip manifest (default `js_engine` runs)

Known **failing** or **hanging** suites are listed in [`skip_manifest.json`](./skip_manifest.json) with `skip_type`, `reason`, and a `qa_issues/…` ticket path. By default, `run_reg.py` **does not run** those entries when using `bin/js_engine`.

- `--run-fail` — also run suites marked `fail`
- `--run-hang` — also run suites marked `hang`
- `--all` — run both skipped categories

Pass specific files or directories under `regression/` to narrow the run (see `python3 run_reg.py --help` / source for flags).

Logs for the last run are written under `regression_logs/`, mirroring the folder layout of `regression/`.

## Layout

| Path | Contents |
|------|-----------|
| [`02_language/`](./02_language/) | Syntax and semantics: variables, scope, control flow, operators, functions, classes, modules, strict mode, async, iterators, known gaps, etc. Numbered subfolders group topics (e.g. `01_variables`, `19_modules`). |
| [`03_builtins/`](./03_builtins/) | Built-in objects and globals: `Number`, `String`, `Array`, `Object`, `Function`, `Promise`, `Map`/`Set`, `RegExp` (`18_regexp/`), `console`, `Error`, and related. |
| [`04_node_modules/`](./04_node_modules/) | Node-style built-ins: `fs`, `path`, `os`, `events`, `stream`, `buffer`, `process`, `timers`, `assert`, `url`, `http`, `net`, `tls`, `fetch`, etc. Subdirs are ordered by topic (`01_fs`, `02_path`, …). |
| [`05_integration/`](./05_integration/) | Cross-cutting integration scripts, including Vite API smokes (`test_vite_*_smoke.js`) and Phase 0 Vite CLI smokes (`test_vite_cli_*_smoke.sh`; see [`docs/vite_phase0_baseline.md`](../docs/vite_phase0_baseline.md)). |

## Conventions

- Top-of-file comments often cite a **`testing_plans`** document and section ID (for example `VARIABLE_COMPREHENSIVE_TEST_PLAN §…`). After the plan reorganization, those files live under [`testing_plans/03_ecmascript_language/`](../testing_plans/03_ecmascript_language/README.md); the plan **name** in comments is still valid.
- Failures that represent engine bugs or spec gaps may be tracked in [`qa_issues/`](../qa_issues/README.md).

## Related docs

- High-level parity checklist: [`testing_plans/MASTER_TEST_PLAN.md`](../testing_plans/MASTER_TEST_PLAN.md)  
- Detailed language plans: [`testing_plans/03_ecmascript_language/README.md`](../testing_plans/03_ecmascript_language/README.md)  
- Smaller staged plan (if used): [`testing_phases/`](../testing_phases/README.md)
