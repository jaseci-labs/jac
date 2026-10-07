# Node.js Core Test Runner

This directory contains the js_engine runner for the [nodejs/node](https://github.com/nodejs/node)
core test suite (fetched into `engine/tests/node/vendor` at a pinned `v24.x` commit by `tools/fetch_test_deps.sh node`).

Unlike test262, Node tests are self-contained programs that `require('../common')` and
exit `0` on success. This runner executes them in place (no harness injection).

---

## Quick start

```bash
# From the js_engine/ repo root (options: append `-- --help`):
jac run engine/tests/node/run_node_tests.jac --dry-run

# Any specific test file (path relative to repo, to test/, or absolute):
jac run engine/tests/node/run_node_tests.jac \
  engine/tests/node/vendor/test/module-hooks/test-async-loader-hooks-globalpreload-warning.mjs

# Or the same file via --filter (searches all suites under test/):
jac run engine/tests/node/run_node_tests.jac --filter \
  'module-hooks/test-async-loader-hooks-globalpreload-warning.mjs'

# Run fs module tests under system Node (baseline):
jac run engine/tests/node/run_node_tests.jac --node --filter 'test-fs-*'

# Same subset against js_engine:
jac run engine/tests/node/run_node_tests.jac --filter 'test-fs-*'

# Entire suite directory:
jac run engine/tests/node/run_node_tests.jac --suite module-hooks
# or:
jac run engine/tests/node/run_node_tests.jac engine/tests/node/vendor/test/module-hooks
```

---

## Bootstrapping the Node.js source

```bash
tools/fetch_test_deps.sh node
```

This fetches nodejs/node at the pinned `v24.x` commit (depth 1).

---

## Command-line reference

| Flag | Default | Description |
|------|---------|-------------|
| `--engine PATH` | `bin/js_engine` | Path to the JS engine binary |
| `--node` | off | Run under system Node.js (baseline) |
| `--timeout N` | 60 | Per-test timeout in seconds (always enforced; timed-out tests are force-killed) |
| `--mem-limit GB` | 0.1 | Per-test virtual memory limit (always enforced for engine runs) |
| `--dry-run` | off | List tests; do not execute |
| `PATH…` | — | Positional test file(s) or directories under `test/` |
| `--filter GLOB` | all | Paths relative to `test/` (searches **all** suites unless `--suite` is set) |
| `--suite LIST` | `parallel`* | Comma-separated suites, or `all`. *Default is `all` when `--filter` is set |
| `--verbose` / `-v` | off | Extra detail (e.g. skip reasons) |
| `--save-baseline FILE` | — | Write JSON baseline after the run |
| `--check-baseline FILE` | — | Fail on functional regressions vs baseline |
| `--perf-check` | off | With `--check-baseline`, also check time/memory |

---

## Pass / fail / skip semantics

| Condition | Result |
|-----------|--------|
| Exit 0 | **PASS** |
| Exit 0 and TAP `1..0 # Skipped: …` (from `common.skip`) | **SKIP** |
| Exit non-zero | **FAIL** |
| Exceeds `--timeout` | **HANG** |
| Exceeds `--mem-limit` (engine only) | **HANG** (oom) |

The process exits **0** when there are no FAIL/HANG results (skips are OK).
Exit **1** on failures or baseline regressions.

### Flags and env directives

Tests may declare:

```js
// Flags: --expose-internals
// Env: FOO=bar
```

The runner parses these (same as Node's `test/common`) and forwards them to the
engine / `node` binary. `NODE_SKIP_FLAG_CHECK=true` is set so `common` does not
re-spawn the process.

---

## Suites

Any directory under `engine/tests/node/vendor/test/` is a suite
(except helpers: `common/`, `fixtures/`, `tools/`, `testpy/`, `cctest/`).

- No args → default suite `parallel`
- `--filter …` → searches **all** suites
- `PATH` args → run those files/dirs directly (any suite)
- `--suite all` → every suite under `test/`

Useful suites: `parallel`, `sequential`, `module-hooks`, `es-module`,
`async-hooks`, `pummel`, `message`, `internet` (needs network). Build-dependent
suites (`addons`, `node-api`, …) are included in `all` but may need native builds.

---

## Logs

Per-test failure logs go to `regression_logs/node/` (gitignored), mirroring the
suite path (e.g. `regression_logs/node/parallel/test-fs-access.js.log`).

---

## Examples

```bash
# All parallel tests matching http (workers = nproc):
jac run engine/tests/node/run_node_tests.jac --filter 'test-http-*'

# parallel + sequential, engine run, save baseline:
jac run engine/tests/node/run_node_tests.jac \
  --suite parallel,sequential \
  --filter 'test-fs-*' \
  --save-baseline docs/regression_logs/node_fs_baseline.json

# Check for regressions:
jac run engine/tests/node/run_node_tests.jac \
  --filter 'test-fs-*' \
  --check-baseline docs/regression_logs/node_fs_baseline.json
```
