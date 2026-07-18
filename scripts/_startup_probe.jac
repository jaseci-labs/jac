"""Import-budget probe used by scripts/startup_benchmark.jac.

Spawns the canonical Jac entry (`python -m jaclang` -> jaclang/__main__.py ->
jaclang.jac0core.cli_boot.start_cli, the same function the `jac` launcher
invokes) in a CLEAN python subprocess under an import counter, then reports the
set of imported top-level module names.

The counter must run in a pristine interpreter (jaclang not pre-imported), so
the measurement body ships as a `python -c` bootstrap string rather than an
importable module: running it under `jac run` would pre-load jaclang and hide
every steady-state import. `run_probe` spawns that bootstrap and parses the
single `PROBE_RESULT=` JSON line it prints.

Not intended for direct use: the harness warms the cache first so this probe
reports steady-state imports rather than one-off `.jac` compilation, then
categorizes the module names into command / feature / floor buckets.
"""
import from __future__ { annotations }
import json;
import subprocess;

# The measurement body, run in a pristine python via `python -c`. It installs a
# counting __import__ before re-entering `jaclang.__main__`, so every import the
# canonical entry triggers is recorded, then prints one PROBE_RESULT= JSON line.
glob PROBE_SRC: str = """
import builtins
import json
import os
import runpy
import sys

bench_root = os.environ.get('JAC_BENCH_ROOT')
if bench_root:
    sys.path.insert(0, bench_root)
    os.chdir(bench_root)

# `python -c CODE <args>` leaves the real args in sys.argv[1:]; mirror
# `python -m jaclang <args>` by giving argv[0] a stable command name.
sys.argv = ['jac'] + sys.argv[1:]

seen = []
real_import = builtins.__import__


def counting_import(name, globals=None, locals=None, fromlist=(), level=0):
    seen.append(name)
    return real_import(name, globals, locals, fromlist, level)


builtins.__import__ = counting_import

exit_code = 0
try:
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
except SystemExit as exc:
    exit_code = exc.code if isinstance(exc.code, int) else 1
except BaseException:
    exit_code = 1

print('PROBE_RESULT=' + json.dumps({'exit_code': exit_code, 'modules': sorted(set(seen))}))
""";

def run_probe(python_exe: str, argv: list[str], env: dict[str, str], cwd: str) -> dict {
    proc = subprocess.run(
        [python_exe, "-c", PROBE_SRC] + argv,
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True
    );
    for line in proc.stdout.splitlines() {
        if line.startswith("PROBE_RESULT=") {
            payload = json.loads(line.split("=", 1)[1]);
            payload["probe_rc"] = proc.returncode;
            return payload;
        }
    }
    raise RuntimeError(
        f"probe produced no PROBE_RESULT for argv={argv!r}\n"
        f"stdout tail: {proc.stdout[-500:]}\n"
        f"stderr tail: {proc.stderr[-500:]}"
    );
}
