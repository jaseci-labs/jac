# Linux CI: get the binary test gate green (xdist worker crash)

Status as of commit `2b6782467` on `feat/launcher-zig` (PR jaseci-labs/jaseci#6855).

## TL;DR

Everything is green **except** the new blocking gate `jac single-binary self-test`
→ step **"Full repo suite via the binary"**. It dies with pytest **exit code 5
("no tests ran")** because every `pytest-xdist` worker crashes at startup:

```
[gwN] node down: ...
  File ".../python/lib/python3.12/decimal.py", line 102, in <module>
    from _decimal import *
ModuleNotFoundError: No module named '_decimal'
  ... fallback ...
    from _contextvars import Context, ContextVar, Token, copy_context
ModuleNotFoundError: No module named '_contextvars'
================== xdist: maximum crashed workers reached: 16 ==================
============================ no tests ran in 7.52s =============================
```

It is **not** a real test failure and **not** the test code. The main process is
fine; only the **xdist worker subprocesses** can't import the C-extension stdlib
modules `_decimal` / `_contextvars` (and friends) that live in `lib-dynload`.

## Why it passed locally (macOS) but fails on Linux x86_64

- **macOS-aarch64 pbs**: `_decimal` and `_contextvars` are **builtin** modules
  (`'_decimal' in sys.builtin_module_names == True`). They import no matter what
  `sys.path` is, so worker mode never exercised `lib-dynload`. `-n auto` passed.
- **linux-x86_64 pgo-full pbs**: those same modules are **shared extensions**
  (`lib-dynload/_decimal.cpython-312-x86_64-linux-gnu.so`). The worker must find
  `lib-dynload` on `sys.path`, and on this build it doesn't.

So macOS green was a false positive for this code path. This must be validated on
linux-x86_64.

## What the code already does (and where)

- `jac/launcher/launcher.zig` -- `boot()` sets, before the worker-mode branch:

  ```
  PYTHONHOME = <rt>/python
  PYTHONPATH = <rt>/site:<rt>/python/lib/python3.12/lib-dynload
  ```

  and `isPythonInvocation()` routes `-c`/`-u`/`-m` invocations (how execnet spawns
  workers) to `Py_BytesMain`. The `lib-dynload` entry on `PYTHONPATH` was added
  specifically for this; the in-code comment notes it was needed because
  "in worker mode (Py_BytesMain) on Linux the C-extension dir is otherwise not on
  sys.path even with PYTHONHOME set." That fix held for **linux-aarch64 noopt** but
  NOT for **linux-x86_64 pgo-full** (this CI).
- `jac/launcher/mkpayload.sh` -- stages the whole stdlib including `lib-dynload`
  (`cp -R "$PBS/install/lib/python3.12" ...`, with a comment "KEEP lib-dynload").

So the `.so` files *should* be shipped and `lib-dynload` *should* be on
`PYTHONPATH`. The job is to find out which of those is actually false in the
worker on x86_64.

## Reproduce on a linux-x86_64 box

```bash
cd jac
zig build                              # builds zig-out/bin/jac
BIN="$PWD/zig-out/bin/jac"
W="$(mktemp -d)"; export HOME="$W" XDG_CACHE_HOME="$W/.cache"
"$BIN" --version >/dev/null            # materialize the cache
RT="$(find "$W/.cache/jac/rt" -maxdepth 1 -mindepth 1 -type d | head -1)"

# 1. Are the .so actually shipped?
ls "$RT/python/lib/python3.12/lib-dynload/" | grep -E '_decimal|_contextvars'

# 2. Are they builtin here (expected: False on x86_64)?
"$BIN" -c "import sys; print('builtins:', [m for m in ('_decimal','_contextvars') if m in sys.builtin_module_names])"

# 3. THE KEY TEST -- worker-mode import, exactly how a worker starts (`-c`):
"$BIN" -c "import sys; print('dynload on path:', [p for p in sys.path if 'dynload' in p]); import _decimal, _contextvars; print('WORKER IMPORT OK')"
```

Interpretation of step 3:

- **Fails the same way** → the launcher/worker-mode env is the bug (PYTHONPATH not
  honored, or wrong, in `Py_BytesMain` on this build). Fix in `launcher.zig`.
- **Prints WORKER IMPORT OK** → it's an **execnet/xdist** problem: execnet builds
  the worker's command+env itself and is likely not propagating `PYTHONPATH` (or is
  resetting `sys.path`). Fix on the pytest side.

Then reproduce the actual crash directly (faster than CI):

```bash
BINDIR="$(mktemp -d)"; ln -sf "$BIN" "$BINDIR/jac"
PATH="$BINDIR:$PATH" JAC_TEST_JOBS=auto "$BINDIR/jac" test tests/compiler/passes/main/test_checker_pass.jac
# crashes with the _decimal/_contextvars worker error if unfixed
```

## Fix options

### Option 0 -- immediate unblock (serial), if you just want CI green to continue

In `.github/workflows/test-binary.yml`, the "Full repo suite" step: change
`JAC_TEST_JOBS=auto` → `JAC_TEST_JOBS=0` (serial, no workers → no worker crash).
Slower but green. Restore `auto` once the real fix lands. This is enough for the
downstream work (removing redundant jobs, workflow migration, pyproject deletion).

### Option A -- launcher/worker env (if step 3 above fails)

The worker's `Py_BytesMain` isn't getting `lib-dynload` onto `sys.path`. Things to
try, in `jac/launcher/launcher.zig`:

- Confirm the `PYTHONPATH` string is correct on x86_64 (print it; verify the path
  exists). The dir is `<rt>/python/lib/python3.12/lib-dynload`.
- `Py_BytesMain` derives paths partly from `argv[0]`/executable location, which is
  the jac binary, not a python under `<rt>/python/bin`. PYTHONHOME is meant to pin
  the prefix, but on pgo-full it evidently doesn't pull in `lib-dynload`. Consider
  driving the worker through an explicit `PyConfig` (`Py_InitializeFromConfig` /
  `PyConfig.module_search_paths_set = 1` with site + stdlib + **lib-dynload**)
  instead of `Py_BytesMain`, OR set `PYTHONPLATLIBDIR` / point `home` so getpath
  finds the platform stdlib. Validate with step 3 until it prints OK.

### Option B -- execnet/xdist env (if step 3 above succeeds)

execnet's popen gateway builds the worker process; if it doesn't carry our
`PYTHONPATH`, fix it at the pytest layer (our `jac test` wires xdist):

- Ensure the spawned worker inherits the parent env (it should, but verify execnet
  isn't scrubbing `PYTHONPATH`).
- Or set `PYTHONPATH` for workers via a `conftest.py`/`pytest_configure` so it's
  present regardless of execnet, or via xdist `--tx popen//env:PYTHONPATH=...`.

### Why not just bundle differently

Re-pinning pbs to a build where these are builtin (e.g. `noopt`) "fixes" it but
loses pgo. Prefer making `lib-dynload` resolution robust so any pbs flavor works.

## Verify the fix

```bash
cd jac && zig build
BINDIR="$(mktemp -d)"; ln -sf "$PWD/zig-out/bin/jac" "$BINDIR/jac"; W="$(mktemp -d)"
PATH="$BINDIR:$PATH" HOME="$W" JAC_TEST_JOBS=auto "$BINDIR/jac" test tests/ | tail -5
# expect: workers stay up, "<N> passed, ... " with no "node down" / "maximum crashed workers"
```

Expected ballpark on Linux with node/bun/gcc present: ~3000+ passed, a handful of
skips, **0** worker crashes. (Local macOS parity run: 3082 passed / 0
binary-specific failures.)

Then push; the `jac single-binary self-test` gate should go green on the PR.

## Local-dev gotcha (not CI): payload cache doesn't invalidate on jaclang edits

`zig build` does NOT reliably rebuild the payload when only files under `jac/jaclang/`
change (the `addDirectoryArg` input-tracking in `build.zig` isn't invalidating).
After editing jaclang/launcher and before re-testing the binary:

```bash
rm -rf jac/.zig-cache && (cd jac && zig build)   # pbs stays cached in jac/.pbs-build
```

CI is unaffected (fresh checkouts always build clean). Worth fixing in `build.zig`
eventually, but it's not blocking.

## After the gate is green -- remaining roadmap (so I can continue)

1. Remove the now-redundant editable jaclang jobs from `test-jaseci.yml`:
   `test-solid-jsdom` and `test-desktop-native` (the binary gate covers them; it has
   node/bun/gcc). **Keep `test-client`** -- it installs playwright+chromium and
   actually runs the browser e2e, which the binary gate skips (`importorskip`).
2. Migrate the remaining `pip install -e ./jac` consumers (9 left in
   `test-jaseci.yml`: plugins/docs/pypi; plus `jac-check.yml`, `deploy-docs.yml`,
   `publish-release.yml`, `contribution-checks.yml`, `create-release-pr.yml`,
   `release-{jaseci,mcp,scale,byllm}.yml`, `k8s-microservice-real-e2e.yml`,
   `test-installer.yml`). These need the plugin-install-via-binary path
   (`jac install -e ./jac-byllm` etc.) validated, and the obsolete `test-pypi-build`
   job removed (no PyPI in the clean break).
3. Delete `jac/pyproject.toml` once nothing does `pip install -e ./jac` anymore.
