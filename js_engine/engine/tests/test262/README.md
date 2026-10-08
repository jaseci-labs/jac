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
and is fetched at a pinned commit before first use:

```bash
# From the repo root:
tools/fetch_test_deps.sh test262
```

This fetches only that commit (depth 1, about 50 MB instead of the full ~500 MB history).

---

## Command-line reference

| Flag | Default | Description |
|------|---------|-------------|
| `--engine PATH` | `bin/js_engine` | Path to the JS engine binary |
| `--node` | off | Run under Node.js instead (useful for establishing a baseline) |
| `--timeout N` | 10 | Per-test timeout in seconds |
| `--dry-run` | off | List tests that would run; do not execute them |
| `--filter GLOB` | all | Only run tests whose path matches this glob |
| `--verbose` / `-v` | off | Print each test result as it completes |

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

`run_test262.jac` exits with code **0** when there are no failures. It exits **1** when there are failures.

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

---

## Baseline pass rate

> Phase B baseline not yet recorded.  
> Run `jac run engine/tests/test262/run_test262.jac --node` to establish a Node.js baseline,
> then `jac run engine/tests/test262/run_test262.jac` for the engine baseline.
> Record both here once available.

---

## Implementation phases

| Phase | Status | Description |
|-------|--------|-------------|
| A | Done | Runner, this README, test262 submodule |
| B | Pending | Baseline run |
| C | Pending | Wire into CI (`make test262`) |
| D | Ongoing | Fix engine bugs, watch pass-rate climb |

See `docs/TEST_SUITE_INTEGRATION_PLAN.md` for the full design rationale.
