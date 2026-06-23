# De-flaking the interactive code-block E2E suite

`docs/tests/e2e/test_code_blocks.jac` is the Playwright suite that exercises the
interactive playground blocks in the docs (run a snippet, render a graph, show a
syntax error). It has been intermittently failing in CI. This document explains
the failure, the root cause, and the fix.

## Symptom

In the `test-packages-and-docs` job ("Run E2E code block tests"), a subset of
tests fail with:

```
TimeoutError: Page.wait_for_selector: Timeout 30000ms exceeded.
  - waiting for locator("#block-run-dot")
...
3 failed, 6 passed
```

The failures are always the **execution / graph** tests:

- `execution: graph renders svg`
- `execution: graph dot format`
- `execution: syntax error shows error`

The **rendering** tests on the *same* blocks (e.g. `rendering: run-dot block
buttons`, which also scrolls to `#block-run-dot`) pass. The failure is a timeout
on `wait_for_selector(..., state="attached")` — i.e. waiting for a **static**
element that is hard-coded in the fixture HTML — not an assertion about behavior.

## What the suite actually does

Each test (`_with_page`) is fully self-contained: it starts its **own** HTTP
server, launches its **own** Chromium, and loads a self-written fixture page.
The fixture page pulls every heavy dependency from public CDNs:

| Asset | CDN | Approx size | Needed by |
|---|---|---|---|
| Monaco editor | cdnjs | a few MB | all tests (editor render) |
| requirejs | jsdelivr | small | all tests |
| viz.js + full.render.js | unpkg | ~3 MB | **graph** tests |
| Pyodide v0.27.0 (WASM) | jsdelivr | **~10 MB** | **execution** tests |
| micropip + sqlite3 packages + jaclang | jsdelivr | more | **execution** tests |

Pyodide is loaded inside a Web Worker (`/js/pyodide-worker.js` →
`importScripts("https://cdn.jsdelivr.net/pyodide/v0.27.0/full/pyodide.js")`),
which then `loadPackage`s micropip and sqlite3 and installs jaclang. The fixture
also sets COOP/COEP headers (`Cross-Origin-Opener-Policy: same-origin`,
`Cross-Origin-Embedder-Policy: require-corp`) so the worker can use
SharedArrayBuffer.

## Root cause

`jac test` defaults to `JAC_TEST_JOBS=auto`, which runs pytest with
`-n auto` (pytest-xdist). On the CI runner (`blacksmith-4vcpu-ubuntu-2404`,
**4 vCPUs**), xdist spawns ~6 workers. The CI step:

```yaml
run: jac test tests/e2e/test_code_blocks.jac -x || jac test tests/e2e/test_code_blocks.jac -x
```

distributes the 9 tests across those workers, so at peak there are **~6 Chromium
instances, each spawning a Pyodide worker that downloads and compiles ~10 MB of
WASM and loads packages, all at the same time, from the same CI IP.**

That saturates CPU, memory, and network bandwidth, and invites CDN
rate-limiting (six concurrent large fetches from one address). Under that load
the browser event loop is starved enough that even a basic `wait_for_selector`
poll on a static element cannot complete within the 30 s `MONACO_TIMEOUT`.

This precisely matches the observed pattern:

- **Rendering tests pass** — they only need Monaco (relatively light), no
  Pyodide and no viz.js.
- **Execution / graph tests fail** — they additionally pull the heavy Pyodide
  (and viz.js) payloads, which is exactly what melts down under 6-way
  concurrency.
- The timeout fires at **30 s on selector-attach**, *before* the test even
  reaches the 120 s `PYODIDE_TIMEOUT` waits — the signature of resource
  starvation, not a product bug.

It is not a regression in the playground feature, and it is unrelated to the
code being tested in any given PR; it is a test-infrastructure concurrency
problem that the recent single-binary migration (which routes the step through
`jac test` and its default `-n auto`) made easy to hit. The suite has been
de-flaked twice before (#6528, #6756) and currently relies on a single `||`
retry, which only papers over the contention.

## Fix (this change)

Run the E2E suite **serially** by setting `JAC_TEST_JOBS=0` on the step:

```yaml
- name: Run E2E code block tests
  working-directory: docs
  env:
    JAC_TEST_JOBS: 0   # serial: avoid N concurrent Pyodide/Chromium downloads
  run: jac test tests/e2e/test_code_blocks.jac -x || jac test tests/e2e/test_code_blocks.jac -x
```

`jac test` reads `JAC_TEST_JOBS`: `0` means "do not pass `-n`", so pytest runs
without xdist. The tests then execute one at a time — a single Chromium and a
single Pyodide download at any moment — removing the concurrency that causes the
starvation. The suite is short (9 tests), so serial wall-clock cost is small and
well worth the stability. The `|| ... -x` retry is kept as cheap insurance
against a one-off CDN hiccup.

## Alternatives considered (not done here)

These are more robust but heavier; they can be layered on later if serial
execution alone proves insufficient:

1. **Remove the CDN dependency.** Vendor/cache Pyodide + viz.js + Monaco +
   requirejs and serve them from the local test server (or intercept the CDN
   URLs with Playwright `page.route()` and serve cached copies). Makes the suite
   fully network-independent and deterministic. Biggest robustness win, but
   Pyodide is large and this is a non-trivial change.
2. **Amortize setup.** Reuse one server + one browser + one warmed Pyodide
   across all tests in the file (session-scoped) instead of per-test, so the
   heavy assets are fetched once rather than per test.
3. **Raise `PYODIDE_TIMEOUT` / add load retries.** Pure band-aid; only helps in
   combination with reduced concurrency.

## TL;DR

Heavy CDN assets (Pyodide ~10 MB, viz.js) downloaded by ~6 parallel xdist
workers on a 4-vCPU runner starve the browser and time out static-element waits.
Running the suite serially (`JAC_TEST_JOBS=0`) removes the concurrency that
causes it.
