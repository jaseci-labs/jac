# Test262 Conformance Runner

This directory contains the js_engine runner for [tc39/test262](https://github.com/tc39/test262),
the official ECMAScript conformance test suite used by V8, SpiderMonkey, JavaScriptCore, Hermes,
QuickJS, and Boa.

---

## Quick start

```bash
# From the js_engine/ repo root:
jac run engine/tests/test262/run_test262.jac --dry-run
```

A `--dry-run` lists all tests that would be run without actually executing them.

To run a real subset:

```bash
# Run tests matching a glob (e.g. language/expressions/):
jac run engine/tests/test262/run_test262.jac --filter "*/language/expressions/*"

# Run everything (slow — ~40 000 tests):
jac run engine/tests/test262/run_test262.jac
```

---

## Bootstrapping the test262 source

The runner reads test262 from `engine/tests/test262/vendor/`. It is gitignored
and is fetched at the commit pinned in `test262.sha` before first use:

```bash
# From the js_engine/ root:
tools/fetch_test_deps.sh test262
```

This fetches only that commit (depth 1) rather than the full history, and moves
an existing checkout to it. Run it before a check (CI does), and the runner warns when `vendor/` is at any other commit: the known
failures below are only meaningful against the pinned suite. Moving the pin is
a change of its own: update `test262.sha`, run both suites, and refresh
`known_failures.txt` in the same commit.

---

## Command-line reference

| Flag | Default | Description |
|------|---------|-------------|
| `--engine PATH` | the `jac` binary's `node` | The engine to run |
| `--node` | off | Run under Node.js instead (useful for establishing a baseline) |
| `--gc` / `--nogc` | engine default | Run the engine with the garbage collector on / off |
| `--timeout N` | 10 | Per-test timeout in seconds |
| `--jobs N` | CPU count | Tests run in parallel |
| `--dry-run` | off | List tests that would run; do not execute them |
| `--filter GLOB` | all | Only run tests whose path matches this glob (or a directory prefix) |
| `--lf` | off | Re-run only the tests that failed in the last run of this `--filter` |
| `--verbose` / `-v` | off | Print each test result as it completes |
| `--check-baseline FILE` | off | Fail on any test that does not pass and is not in the known-failures list FILE |
| `--save-baseline FILE` | off | Refresh FILE's lines for this `--filter` scope from this run (or its run log) |
| `--perf-check` | off | With `--check-baseline`: also compare time/memory with the previous run of this scope |
| `--perf-baseline FILE` | off | With `--check-baseline`: compare time/memory with this run log instead |

Parallelism uses all available CPU cores (`os.cpu_count()`).

---

## Pass / fail semantics

These differ from the `qa/` harness:

| Condition | Result |
|-----------|--------|
| Exit 0, no uncaught throw | **PASS** |
| Exit non-zero | **FAIL** |
| `negative:` declared in front-matter; engine throws that error type | **PASS** |
| `negative:` declared; engine exits 0 (no throw) | **FAIL** |
| Engine hangs past `--timeout` | **HANG** (counted as failure) |

`run_test262.jac` exits with code **0** when there are no failures and **1** when there are. With
`--check-baseline` the known-failures list is the gate instead: it exits **1** only on a
regression (a failure that is not listed).

### Harness injection

test262 tests are not standalone — they rely on helpers in `test262/harness/`.
The runner automatically prepends these to each test file before execution:

1. `harness/sta.js` (always)
2. `harness/assert.js` (always)
3. Any files listed in the test's `includes:` front-matter

For tests with the `onlyStrict` flag, `"use strict";` is prepended first.

The engine sees a single concatenated JS file; it does not need to understand test262 natively.

---

## Logs

Per-test failure logs are written to `regression_logs/test262/` (mirroring the test262
directory structure). This directory is gitignored. Each `.log` file contains the result
and the first 300 characters of engine stderr/stdout.

Every run also records each test's result, time and peak memory in
`.run_logs/<scope>.json` (gitignored), keyed by `--filter`. `--save-baseline`
and `--lf` read it, and `--perf-check` compares the next run of that scope
against it.

---

## Known failures

`known_failures.txt` lists every test js_engine does not pass at the pinned
commit, one `<path>\t<FAIL|HANG>` line per test, sorted, the way V8
(`test262.status`) and QuickJS (`test262_errors.txt`) track theirs. Passing
tests are not listed, and neither are tests the skip manifest skips.

- `--check-baseline engine/tests/test262/known_failures.txt` fails on any test
  that runs, does not pass and is not listed, including tests the pinned suite
  has that the list has never seen:

  ```bash
  jac engine/tests/test262/run_test262.jac --gc --filter language \
      --check-baseline engine/tests/test262/known_failures.txt
  ```
- A listed test that now passes is reported; drop it by refreshing the list.
- Refresh a scope's lines (others are kept) after fixing or knowingly breaking
  tests:

  ```bash
  jac engine/tests/test262/run_test262.jac --gc --filter language \
      --save-baseline engine/tests/test262/known_failures.txt
  ```

Timing and memory are machine-specific, so they are not committed; compare
them with `--perf-check` against your own previous run, or with
`--perf-baseline` against a kept run log.

---

## Implementation phases

| Phase | Status | Description |
|-------|--------|-------------|
| A | Done | Runner, this README, pinned test262 checkout |
| B | Done | Known-failures list (`known_failures.txt`) |
| C | Done | CI (`test262` job in `.github/workflows/ci.yml`) |
| D | Ongoing | Fix engine bugs, watch pass-rate climb |

See `docs/TEST_SUITE_INTEGRATION_PLAN.md` for the full design rationale.
