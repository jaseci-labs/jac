# Linux CI: xdist worker crash on the single-binary test gate (RESOLVED)

The blocking gate `jac single-binary self-test` → step **"Full repo suite via the
binary"** died on linux-x86_64 with pytest **exit code 5 ("no tests ran")**
because every `pytest-xdist` worker crashed at startup:

```
[gwN] node down: ...
  File ".../python/lib/python3.12/contextvars.py", line 1, in <module>
    from _contextvars import Context, ContextVar, Token, copy_context
ModuleNotFoundError: No module named '_contextvars'
================== xdist: maximum crashed workers reached: ... =================
============================ no tests ran in ...s =============================
```

## Root cause (the real one)

**The workers were not running our binary at all — they were running the system
`/bin/python3`.**

`pytest-xdist` spawns workers via `execnet`, and execnet's popen gateway uses
`sys.executable` to pick the interpreter (`execnet/gateway_io.py`:
`args = ... if spec.python else [sys.executable]`). In the **main** `jac test`
process we boot CPython via embedding (`Py_Initialize`), and under embedding
CPython's getpath **cannot recover the launcher's own path** — it falls back to a
`PATH` search for `python3`, so `sys.executable` resolved to **`/bin/python3`**
(a foreign interpreter), not the jac binary.

execnet then spawned `/bin/python3 -u -c ...` while that child **inherited our
`PYTHONHOME`/`PYTHONPATH`** (pointing at the bundled 3.12 stdlib). So a foreign
Python loaded our *pure-Python* stdlib and tried to import builtin C-extensions
(`_decimal`, `_contextvars`) that **our** pgo-full libpython has compiled in but
that the foreign interpreter does not expose on that path → `ModuleNotFoundError`
→ every worker down → exit 5.

The captured worker context proved it:

```
executable='/bin/python3'                      <- foreign interpreter
PYTHONHOME='.../rt/<hash>/python'              <- our bundled 3.12 home (inherited)
decimal_builtin=False contextvars_builtin=False <- foreign interp lacks them here
```

### Why the original lib-dynload theory was wrong

The earlier version of this note assumed `_decimal`/`_contextvars` are **shared
extensions** in `lib-dynload` on linux-x86_64 pgo-full and that the launcher's
`PYTHONPATH` lib-dynload entry was failing to land in worker mode. That was never
verified on Linux. The pinned pbs
(`cpython-3.12.8+20241206-x86_64-unknown-linux-gnu-pgo-full`) actually compiles
nearly everything **in** — `lib-dynload` ships **one** `.so` (`_crypt`); 103
modules incl. `_decimal`/`_contextvars` are **builtin**. A correctly-launched
worker (jac binary → `Py_BytesMain`) imports them fine. The bug was the *wrong
interpreter*, not a missing extension dir.

## The fix

`jac/launcher/launcher.zig` — pin `sys.executable` to *this* binary in the boot
path so every re-spawn comes back through worker mode (`Py_BytesMain`, which
already resolves the executable correctly and has the right interpreter):

- `boot()` exports the launcher's resolved path as the `JAC_EXECUTABLE` env var.
- `BOOT_SRC` sets `sys.executable = sys._base_executable = $JAC_EXECUTABLE`
  before handing off to the jac CLI — i.e. **before** `pytest.main()` runs, so
  xdist/execnet read the corrected value when they spawn workers.

This also fixes the whole class of `subprocess.run([sys.executable, "-m",
"jaclang", ...])` and `multiprocessing` (spawn) self-invocations under the
standalone binary, which previously all targeted the foreign `/bin/python3`.

No workflow change was needed: `test-binary.yml` keeps `JAC_TEST_JOBS=auto`.

## Verify (linux-x86_64)

```bash
cd jac && zig build                                  # 0.16.0
BIN="$PWD/zig-out/bin/jac"

# 1. sys.executable now points at the jac binary (was /bin/python3):
printf 'import sys;\nwith entry { print(sys.executable); }\n' > /tmp/w.jac
W=$(mktemp -d); HOME="$W" "$BIN" run /tmp/w.jac          # -> .../zig-out/bin/jac

# 2. xdist workers stay up (was: "maximum crashed workers ... no tests ran"):
BINDIR=$(mktemp -d); ln -sf "$BIN" "$BINDIR/jac"; W=$(mktemp -d)
PATH="$BINDIR:$PATH" HOME="$W" JAC_TEST_JOBS=auto \
  "$BINDIR/jac" test tests/compiler/passes/main/test_checker_pass.jac
# -> "N workers [.. items] ... 227 passed", exit 0
```

Validated on linux-x86_64 (WSL2, same pinned pbs as CI): single-file run = 32
workers / 227 passed / **0** crashes; full `tests/` suite via the binary runs
with workers staying up.

## Local-dev gotcha (not CI): payload cache doesn't invalidate on jaclang edits

`zig build` does NOT reliably rebuild the payload when only files under
`jac/jaclang/` change (the `addDirectoryArg` input-tracking in `build.zig` isn't
invalidating). After editing files under `jaclang/` and before re-testing the
binary:

```bash
rm -rf jac/.zig-cache && (cd jac && zig build)   # pbs stays cached in jac/.pbs-build
```

(Launcher-only edits like this fix rebuild fine — the payload step stays cached.)
CI is unaffected (fresh checkouts always build clean). Worth fixing in `build.zig`
eventually, but it's not blocking.

## After the gate is green — remaining roadmap

1. Remove the now-redundant editable jaclang jobs from `test-jaseci.yml`:
   `test-solid-jsdom` and `test-desktop-native` (the binary gate covers them; it
   has node/bun/gcc). **Keep `test-client`** — it installs playwright+chromium and
   actually runs the browser e2e, which the binary gate skips (`importorskip`).
2. Migrate the remaining `pip install -e ./jac` consumers (9 left in
   `test-jaseci.yml`: plugins/docs/pypi; plus `jac-check.yml`, `deploy-docs.yml`,
   `publish-release.yml`, `contribution-checks.yml`, `create-release-pr.yml`,
   `release-{jaseci,mcp,scale,byllm}.yml`, `k8s-microservice-real-e2e.yml`,
   `test-installer.yml`). These need the plugin-install-via-binary path
   (`jac install -e ./jac-byllm` etc.) validated, and the obsolete `test-pypi-build`
   job removed (no PyPI in the clean break).
3. Delete `jac/pyproject.toml` once nothing does `pip install -e ./jac` anymore.
